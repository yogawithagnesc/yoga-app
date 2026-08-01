-- ============================================================
-- LUMEN — Phase 28 Migration: Manual Body-Status Check-In (M7-6-4)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase27
--
-- RATIONALE: Body Status is normally computed only from muscle_feelings
-- recorded during a practice log. Users reported that how a muscle
-- actually feels often shifts 1-2 days AFTER a practice (soreness peaks
-- late, or eases sooner than the 14-day decay implies) — with no logged
-- practice on those days, there was no way to reflect that. This adds a
-- lightweight, practice-independent "how does this area feel right now"
-- check-in.
--
-- DESIGN: per user decision (recommended default — no direct response
-- received when raised as a question), a check-in is NOT a manual
-- override of the computed status. It is stored as its own row and the
-- client's computeBodyStatus() folds it into the SAME weighted-decay
-- scoring model used for practice-log feelings (BODY_FEELING_WEIGHT +
-- the same recency buckets), just keyed directly by body CATEGORY
-- (Shoulders/Lower Back/Hamstrings/Hips/Knees/Core) rather than a
-- specific muscle zone — a check-in is intentionally coarser-grained
-- than a full practice log. This keeps one scoring model / source of
-- truth rather than two competing signals.
--
-- SCOPE NOTE: check-ins feed the category-level Body Status score only,
-- not the per-muscle-zone Rest Engine (computeRestNeeds()) — that engine
-- counts sore/pain/injured per specific muscle zone, and a category-level
-- check-in has no single zone to attribute it to without fabricating one.
--
-- Idempotent — safe to re-run.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.body_checkins (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  checkin_date date        NOT NULL DEFAULT CURRENT_DATE,
  category     text        NOT NULL CHECK (category IN ('Shoulders', 'Lower Back', 'Hamstrings', 'Hips', 'Knees', 'Core')),
  feeling      text        NOT NULL CHECK (feeling IN ('relax', 'feelgood', 'sweetpain', 'tight', 'sore', 'pain', 'injured')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS body_checkins_user_date_idx
  ON public.body_checkins (user_id, checkin_date DESC);

ALTER TABLE public.body_checkins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "body_checkins_own_all" ON public.body_checkins;
CREATE POLICY "body_checkins_own_all" ON public.body_checkins
  FOR ALL USING (user_id = auth.uid());

-- No linked-teacher SELECT policy: check-ins are a personal, private
-- signal feeding the student's own Body Status widget only (unlike
-- practice_logs/recovery_logs, which are shareable when not private).
