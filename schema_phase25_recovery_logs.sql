-- ============================================================
-- LUMEN — Phase 25 Migration: Recovery & Treatment Logs (M7-3)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase24
--
-- Adds a dedicated log type for recovery/treatment sessions
-- (sports massage, physiotherapy, chiropractic, dry needling,
-- acupuncture, stretch therapy, self-care, etc.) distinct from
-- practice/fitness logs.
--
-- WHY A SEPARATE TABLE (not another practice_categories row):
-- A treatment is semantically the *opposite* of a practice. A hard
-- session ADDS load/soreness; a treatment RELIEVES it. Overloading
-- practice_logs would make fields like `intensity`/`muscle_feelings`
-- mean the reverse of what they mean today, and every body-status
-- computation would need special-casing. A dedicated table keeps
-- practice analytics pure and lets recovery act as a "mitigating
-- factor" in the Body Status / Rest engine (index.html) via the
-- shared muscle-zone taxonomy.
--
-- The `areas_treated` JSONB mirrors practice_logs.muscle_feelings'
-- convention: an array of { zone, relief } objects, where `zone`
-- reuses the exact canonical zone keys (incl. "L "/"R " prefixes)
-- so BODY_ZONE_MAP and the rest engine keep working unchanged.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. TABLE
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recovery_logs (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  treatment_type   text        NOT NULL,   -- e.g. 'Sports Massage', 'Physiotherapy', 'Dry Needling', custom
  practitioner     text,                   -- optional clinic / practitioner name
  treatment_date   date        NOT NULL DEFAULT CURRENT_DATE,
  start_time       time,
  duration_minutes integer     NOT NULL DEFAULT 60 CHECK (duration_minutes > 0),
  areas_treated    jsonb       NOT NULL DEFAULT '[]'::jsonb,  -- [{ zone, relief }]
  relief_rating    integer     CHECK (relief_rating BETWEEN 1 AND 5),
  soreness_before  integer     CHECK (soreness_before BETWEEN 1 AND 5),
  soreness_after   integer     CHECK (soreness_after BETWEEN 1 AND 5),
  notes            text,
  media_urls       text[]      NOT NULL DEFAULT '{}',  -- storage paths in the practice-media bucket
  follow_up_date   date,
  is_private       boolean     NOT NULL DEFAULT true,
  notes_shared     boolean     NOT NULL DEFAULT false,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS recovery_logs_user_date_idx
  ON public.recovery_logs (user_id, treatment_date DESC);

-- ────────────────────────────────────────────────────────────
-- 2. updated_at TRIGGER (reuse the shared touch function if present,
--    else define one — mirrors practice_logs' updated_at behaviour)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS recovery_logs_updated_at ON public.recovery_logs;
CREATE TRIGGER recovery_logs_updated_at
  BEFORE UPDATE ON public.recovery_logs
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- ────────────────────────────────────────────────────────────
-- 3. ROW-LEVEL SECURITY (mirrors practice_logs exactly)
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.recovery_logs ENABLE ROW LEVEL SECURITY;

-- Users have full CRUD over their own recovery logs.
DROP POLICY IF EXISTS "recovery_own_all" ON public.recovery_logs;
CREATE POLICY "recovery_own_all" ON public.recovery_logs
  FOR ALL USING (user_id = auth.uid());

-- Linked teachers/studios can read non-private recovery logs of students
-- they have an active, consented linkage with. Private logs stay invisible.
DROP POLICY IF EXISTS "recovery_linked_select" ON public.recovery_logs;
CREATE POLICY "recovery_linked_select" ON public.recovery_logs
  FOR SELECT USING (
    is_private = false
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id    = recovery_logs.user_id
        AND sl.entity_id     = auth.uid()
        AND sl.status        = 'active'
        AND sl.consent_given = true
    )
  );

-- ────────────────────────────────────────────────────────────
-- 4. REALTIME — full row in WAL so DELETE events carry user_id
--    for client-side filters (same reasoning as phase23).
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.recovery_logs REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'recovery_logs'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.recovery_logs;
  END IF;
END $$;
