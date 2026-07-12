-- ============================================================
-- LUMEN — Phase 16 — M7 On-Demand Video Catalog
-- Run this in Supabase Dashboard → SQL Editor (after phase 15)
--
-- Creates the videos table for multi-video support, replacing
-- the hardcoded single-entry VIDEO_CATALOG in index.html
-- ============================================================

-- Videos table: multi-video catalog with Mux metadata
CREATE TABLE IF NOT EXISTS public.videos (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title                 text        NOT NULL,
  description           text,
  mux_playback_id       text        NOT NULL UNIQUE,  -- Mux asset playback ID
  duration_seconds      integer,
  thumbnail_url         text,
  teacher_id            uuid        REFERENCES public.profiles(id) ON DELETE CASCADE,
  studio_id             uuid        REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_published          boolean     NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- RLS: published videos visible to all authenticated users
-- Unpublished videos visible only to creator/linked students
DROP POLICY IF EXISTS "videos_published_read" ON public.videos;
CREATE POLICY videos_published_read ON public.videos
  FOR SELECT
  TO authenticated
  USING (
    is_published
    OR teacher_id = auth.uid()
    OR studio_id = auth.uid()
  );

-- Teachers/studios can insert videos they own
DROP POLICY IF EXISTS "videos_teacher_insert" ON public.videos;
CREATE POLICY videos_teacher_insert ON public.videos
  FOR INSERT
  TO authenticated
  WITH CHECK (
    teacher_id = auth.uid()
    OR studio_id = auth.uid()
  );

-- Teachers/studios can update their own videos
DROP POLICY IF EXISTS "videos_teacher_update" ON public.videos;
CREATE POLICY videos_teacher_update ON public.videos
  FOR UPDATE
  TO authenticated
  USING (
    teacher_id = auth.uid()
    OR studio_id = auth.uid()
  );

-- Teachers/studios can delete their own videos
DROP POLICY IF EXISTS "videos_teacher_delete" ON public.videos;
CREATE POLICY videos_teacher_delete ON public.videos
  FOR DELETE
  TO authenticated
  USING (
    teacher_id = auth.uid()
    OR studio_id = auth.uid()
  );

-- Video progress tracking (resume-watching)
-- Tracks user's last playback position in each video
CREATE TABLE IF NOT EXISTS public.video_progress (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  video_id              uuid        NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  position_seconds      integer     NOT NULL DEFAULT 0,
  completed             boolean     NOT NULL DEFAULT false,
  last_watched_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, video_id)
);

-- RLS: users can only see their own progress
DROP POLICY IF EXISTS "video_progress_user" ON public.video_progress;
CREATE POLICY video_progress_user ON public.video_progress
  FOR ALL
  TO authenticated
  USING (user_id = auth.uid());

-- Index for fast video progress lookups
CREATE INDEX IF NOT EXISTS idx_video_progress_user_id ON public.video_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_video_progress_video_id ON public.video_progress(video_id);
