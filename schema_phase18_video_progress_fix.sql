-- ============================================================
-- LUMEN — Phase 18 — Video Progress Column Fix (M7)
-- Run this in Supabase Dashboard → SQL Editor (after phase 17)
--
-- Issue: schema_phase16 tried to CREATE TABLE IF NOT EXISTS
-- video_progress with columns (position_seconds, completed,
-- last_watched_at, video_id uuid), but the table already existed
-- from the base schema.sql with different columns (current_time,
-- total_duration, updated_at, video_id text) — so IF NOT EXISTS
-- was a no-op and the old columns stuck around. index.html's
-- Continue Watching feature was written against phase 16's
-- intended columns and has been silently failing.
--
-- Fix: rename/migrate the live table to phase 16's column set,
-- convert video_id to uuid + FK it to videos(id), and consolidate
-- RLS onto phase 16's single FOR ALL policy.
-- ============================================================

-- 1. Add new columns (nullable at first so we can backfill)
ALTER TABLE public.video_progress ADD COLUMN IF NOT EXISTS position_seconds integer;
ALTER TABLE public.video_progress ADD COLUMN IF NOT EXISTS completed boolean NOT NULL DEFAULT false;
ALTER TABLE public.video_progress ADD COLUMN IF NOT EXISTS last_watched_at timestamptz;

-- 2. Backfill from old columns if they still exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'video_progress' AND column_name = 'current_time'
  ) THEN
    UPDATE public.video_progress SET position_seconds = COALESCE(position_seconds, "current_time");
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'video_progress' AND column_name = 'updated_at'
  ) THEN
    UPDATE public.video_progress SET last_watched_at = COALESCE(last_watched_at, updated_at);
  END IF;
END $$;

-- 3. Finalize defaults / NOT NULL now that data is backfilled
UPDATE public.video_progress SET position_seconds = 0 WHERE position_seconds IS NULL;
ALTER TABLE public.video_progress ALTER COLUMN position_seconds SET DEFAULT 0;
ALTER TABLE public.video_progress ALTER COLUMN position_seconds SET NOT NULL;

UPDATE public.video_progress SET last_watched_at = now() WHERE last_watched_at IS NULL;
ALTER TABLE public.video_progress ALTER COLUMN last_watched_at SET DEFAULT now();
ALTER TABLE public.video_progress ALTER COLUMN last_watched_at SET NOT NULL;

-- 4. Drop the touch_updated_at trigger + old columns (base schema.sql origin)
DROP TRIGGER IF EXISTS video_progress_updated_at ON public.video_progress;
ALTER TABLE public.video_progress DROP COLUMN IF EXISTS "current_time";
ALTER TABLE public.video_progress DROP COLUMN IF EXISTS total_duration;
ALTER TABLE public.video_progress DROP COLUMN IF EXISTS updated_at;

-- 5. Convert video_id from text (base schema) to uuid + FK to videos(id).
-- Legacy rows with a non-UUID text key (old hardcoded VIDEO_CATALOG slugs
-- like "intro-vinyasa-flow") can't map to any videos row, so they're
-- dropped — they were resume-position rows for a video that no longer
-- exists as a DB-backed catalog entry anyway.
DO $$
BEGIN
  IF (
    SELECT data_type FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'video_progress' AND column_name = 'video_id'
  ) = 'text' THEN
    DELETE FROM public.video_progress
    WHERE video_id !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

    ALTER TABLE public.video_progress ALTER COLUMN video_id TYPE uuid USING video_id::uuid;
  END IF;
END $$;

-- 6. Add FK to videos(id) if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE table_schema = 'public' AND table_name = 'video_progress'
      AND constraint_name = 'video_progress_video_id_fkey'
  ) THEN
    ALTER TABLE public.video_progress
      ADD CONSTRAINT video_progress_video_id_fkey
      FOREIGN KEY (video_id) REFERENCES public.videos(id) ON DELETE CASCADE;
  END IF;
END $$;

-- 7. Consolidate RLS: drop base schema's 4 separate policies and any
-- prior copy of phase 16's policy, then recreate a single FOR ALL policy.
DROP POLICY IF EXISTS "video_progress_own_select" ON public.video_progress;
DROP POLICY IF EXISTS "video_progress_own_insert" ON public.video_progress;
DROP POLICY IF EXISTS "video_progress_own_update" ON public.video_progress;
DROP POLICY IF EXISTS "video_progress_own_delete" ON public.video_progress;
DROP POLICY IF EXISTS "video_progress_user" ON public.video_progress;
CREATE POLICY video_progress_user ON public.video_progress
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Idempotent: safe to re-run.
