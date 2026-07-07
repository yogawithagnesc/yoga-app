-- ============================================================
-- LUMEN — Phase 1 Gap-Fill Migration
-- Run this in Supabase Dashboard → SQL Editor
--
-- PREREQUISITE: schema.sql must already be applied (profiles,
-- practice_categories, practice_logs, studio_linkages,
-- community_feeds tables must exist). If you're not sure, open
-- Table Editor and check for a "profiles" table first — if it's
-- missing, run schema.sql in full before this file.
--
-- This migration is additive and safe to re-run: every statement
-- uses IF NOT EXISTS / DROP-then-CREATE / ON CONFLICT guards, so
-- running it twice will not error or duplicate data.
--
-- Adds what the current schema is missing for the next build phase:
--   1. focus_areas        — the 15 training-focus chips (log form)
--   2. practice_logs.focus_area_ids — persists the chips selected
--      above (currently captured in the UI but never saved)
--   3. session_media       — one row per uploaded photo/video
--   4. practice-media      — Storage bucket + RLS for #3
--   5. feedback            — P2 placeholder table (teacher notes)
--   6. Reformer            — missing system category (log page
--      already offers it as a 12th style; schema.sql only seeded 11)
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. FOCUS AREAS
--    Static reference list for the "Focus" chips in the log form.
--    Seeded with the 15 chips currently hard-coded as FOCUSES in
--    lumen-log-practice-3d.html.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.focus_areas (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  label       text        NOT NULL UNIQUE,
  sort_order  integer     NOT NULL DEFAULT 0,
  is_active   boolean     NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.focus_areas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "focus_areas_authenticated_select" ON public.focus_areas;
CREATE POLICY "focus_areas_authenticated_select" ON public.focus_areas
  FOR SELECT USING (auth.role() = 'authenticated' AND is_active = true);

INSERT INTO public.focus_areas (label, sort_order) VALUES
  ('Lower Back',   1), ('Upper Back',  2), ('Core / Abs',  3), ('Hips',        4),
  ('Glutes',       5), ('Hamstrings',  6), ('Quads',       7), ('Shoulders',   8),
  ('Chest',        9), ('Arms',       10), ('Inversions', 11), ('Balance',    12),
  ('Flexibility', 13), ('Breath',     14), ('Mindfulness',15)
ON CONFLICT (label) DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- 2. practice_logs.focus_area_ids
--    The log form already lets a user pick focus chips (selFocus
--    in lumen-log-practice-3d.html) but savePractice() never sends
--    them — this column gives Phase 2 somewhere to write them to.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.practice_logs
  ADD COLUMN IF NOT EXISTS focus_area_ids uuid[] NOT NULL DEFAULT '{}';


-- ────────────────────────────────────────────────────────────
-- 3. SESSION MEDIA
--    One row per uploaded photo/video, linked to its practice log.
--    Actual file bytes live in the practice-media Storage bucket
--    (see #4); this table is the queryable index over them.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.session_media (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id   uuid        NOT NULL REFERENCES public.practice_logs(id) ON DELETE CASCADE,
  user_id      uuid        NOT NULL REFERENCES public.profiles(id)     ON DELETE CASCADE,
  storage_path text        NOT NULL,
  media_type   text        NOT NULL CHECK (media_type IN ('image', 'video')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS session_media_session_id_idx ON public.session_media (session_id);

ALTER TABLE public.session_media ENABLE ROW LEVEL SECURITY;

-- Owners have full CRUD over their own media rows
DROP POLICY IF EXISTS "session_media_own_all" ON public.session_media;
CREATE POLICY "session_media_own_all" ON public.session_media
  FOR ALL USING (user_id = auth.uid());

-- Linked teachers/studios can read media on non-private sessions
DROP POLICY IF EXISTS "session_media_linked_select" ON public.session_media;
CREATE POLICY "session_media_linked_select" ON public.session_media
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.practice_logs pl
      JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
      WHERE pl.id = session_media.session_id
        AND pl.is_private   = false
        AND sl.entity_id     = auth.uid()
        AND sl.status        = 'active'
        AND sl.consent_given  = true
    )
  );


-- ────────────────────────────────────────────────────────────
-- 4. STORAGE — practice-media bucket
--    Path convention: {user_id}/{session_id}/{filename}
--    Per-file limit 50MB (update log page upload copy from 100MB
--    to match — see Phase 2).
-- ────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'practice-media',
  'practice-media',
  false,
  52428800, -- 50MB
  ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/quicktime','video/webm']
)
ON CONFLICT (id) DO NOTHING;

-- Owner full access — path's first folder segment is the uploader's user_id
DROP POLICY IF EXISTS "practice_media_owner_all" ON storage.objects;
CREATE POLICY "practice_media_owner_all" ON storage.objects
  FOR ALL USING (
    bucket_id = 'practice-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'practice-media'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- Linked teacher/studio read-only access, gated on session privacy + consent
DROP POLICY IF EXISTS "practice_media_linked_select" ON storage.objects;
CREATE POLICY "practice_media_linked_select" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'practice-media'
    AND EXISTS (
      SELECT 1 FROM public.session_media sm
      JOIN public.practice_logs pl ON pl.id = sm.session_id
      JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
      WHERE sm.storage_path = storage.objects.name
        AND pl.is_private    = false
        AND sl.entity_id      = auth.uid()
        AND sl.status         = 'active'
        AND sl.consent_given   = true
    )
  );


-- ────────────────────────────────────────────────────────────
-- 5. FEEDBACK  (P2 placeholder — table only, per spec)
--    Teacher/studio notes left on a student's shared session.
--    No INSERT policy yet — write path is P2 scope; the table
--    exists now so it doesn't require a schema change later.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feedback (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid        NOT NULL REFERENCES public.practice_logs(id) ON DELETE CASCADE,
  author_id  uuid        NOT NULL REFERENCES public.profiles(id)      ON DELETE CASCADE,
  body       text        NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "feedback_session_owner_select" ON public.feedback;
CREATE POLICY "feedback_session_owner_select" ON public.feedback
  FOR SELECT USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.practice_logs pl
      WHERE pl.id = feedback.session_id AND pl.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- 6. SEED GAP-FILL — Reformer
--    lumen-log-practice-3d.html's TYPES array has 12 styles;
--    schema.sql's seed only inserted 11 (Reformer was missed).
-- ────────────────────────────────────────────────────────────
INSERT INTO public.practice_categories (name, category_type, icon, is_system, created_by, visibility)
SELECT 'Reformer', 'movement', '🏋️', true, NULL, 'system'
WHERE NOT EXISTS (
  SELECT 1 FROM public.practice_categories WHERE name = 'Reformer' AND is_system = true
);
