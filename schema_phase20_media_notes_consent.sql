-- ============================================================
-- LUMEN — Phase 20 — Consent-Gated Sharing: Media, Notes & RLS Fix (M6c)
-- Run this in Supabase Dashboard → SQL Editor (after phase 19)
--
-- CRITICAL SECURITY FIX included below (see step 3): the
-- practice_logs_studio_block policy added in phase 15 is a
-- PERMISSIVE FOR SELECT policy whose USING clause is TRUE for any
-- authenticated non-studio user, with no ownership or linkage
-- check. PostgreSQL combines multiple permissive policies on the
-- same table with OR, so that policy ALONE currently grants any
-- authenticated non-studio user read access to every row of
-- practice_logs (notes, muscle_feelings, everyone's sessions),
-- regardless of is_private or linkage. The app never surfaces this
-- because every UI query adds its own .eq('user_id', ...) filter,
-- but a direct REST/PostgREST call bypasses that entirely.
--
-- Fix: drop logs_linked_select AND practice_logs_studio_block,
-- leaving logs_own_all as the only row policy on practice_logs.
-- ALL linked-teacher reads now go through the new SECURITY DEFINER
-- get_linked_practice_logs() RPC below, which does its own
-- authorization and returns only a redacted, consent-gated field
-- set (this also closes the notes-sharing gap, since RLS is
-- row-level and cannot redact a single column on an otherwise-
-- visible row — a SECURITY DEFINER function is the correct tool).
-- ============================================================

-- 1. Consent columns
ALTER TABLE public.practice_logs
  ADD COLUMN IF NOT EXISTS notes_shared boolean NOT NULL DEFAULT false;

ALTER TABLE public.session_media
  ADD COLUMN IF NOT EXISTS shared_with_teacher boolean NOT NULL DEFAULT false;

-- 2. Tighten media RLS: a teacher may only read a file the student
--    explicitly marked shared, on top of the existing linkage +
--    non-private-log checks.
DROP POLICY IF EXISTS "session_media_linked_select" ON public.session_media;
CREATE POLICY "session_media_linked_select" ON public.session_media
  FOR SELECT USING (
    shared_with_teacher = true
    AND EXISTS (
      SELECT 1 FROM public.practice_logs pl
      JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
      WHERE pl.id = session_media.session_id
        AND pl.is_private   = false
        AND sl.entity_id     = auth.uid()
        AND sl.status        = 'active'
        AND sl.consent_given = true
    )
  );

DROP POLICY IF EXISTS "practice_media_linked_select" ON storage.objects;
CREATE POLICY "practice_media_linked_select" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'practice-media'
    AND EXISTS (
      SELECT 1 FROM public.session_media sm
      JOIN public.practice_logs pl ON pl.id = sm.session_id
      JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
      WHERE sm.storage_path = storage.objects.name
        AND sm.shared_with_teacher = true
        AND pl.is_private    = false
        AND sl.entity_id      = auth.uid()
        AND sl.status         = 'active'
        AND sl.consent_given  = true
    )
  );

-- 3. CRITICAL FIX — remove the leaking permissive policies.
--    logs_own_all (FOR ALL USING (user_id = auth.uid())) remains
--    and is now the ONLY row policy on practice_logs: no non-owner
--    row access exists any more except via SECURITY DEFINER RPCs.
DROP POLICY IF EXISTS "logs_linked_select" ON public.practice_logs;
DROP POLICY IF EXISTS "practice_logs_studio_block" ON public.practice_logs;

-- 4. get_linked_practice_logs() — the only sanctioned path for a
--    linked teacher to read a student's sessions. Studios remain
--    aggregate-only (unchanged precedent); this function returns
--    an empty set for any caller whose role isn't 'teacher', or
--    who lacks an active, consented linkage to the student.
CREATE OR REPLACE FUNCTION public.get_linked_practice_logs(p_student_id uuid)
RETURNS TABLE (
  id                  uuid,
  practice_date       date,
  style_name          text,
  duration_minutes    integer,
  mood                text,
  muscle_feelings     jsonb,
  notes               text,
  media_shared_count  integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (SELECT profiles.role FROM public.profiles WHERE profiles.id = auth.uid()) IS DISTINCT FROM 'teacher' THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.studio_linkages
    WHERE studio_linkages.student_id = p_student_id
      AND studio_linkages.entity_id   = auth.uid()
      AND studio_linkages.status      = 'active'
      AND studio_linkages.consent_given = true
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    pl.id,
    pl.practice_date,
    pl.style_name,
    pl.duration_minutes,
    pl.mood,
    COALESCE(
      (SELECT jsonb_agg(elem) FROM jsonb_array_elements(pl.muscle_feelings) elem
       WHERE elem->>'feeling' IN ('pain', 'injured')),
      '[]'::jsonb
    ) AS muscle_feelings,
    CASE WHEN pl.notes_shared THEN pl.notes ELSE NULL END AS notes,
    (SELECT count(*)::int FROM public.session_media sm
     WHERE sm.session_id = pl.id AND sm.shared_with_teacher = true) AS media_shared_count
  FROM public.practice_logs pl
  WHERE pl.user_id = p_student_id
    AND pl.is_private = false
  ORDER BY pl.practice_date DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_linked_practice_logs(uuid) TO authenticated;

-- 5. get_shared_session_media() — helper RPC to fetch media files a
--    teacher can access for a given session. Encapsulates the same
--    authorization checks (teacher role, active consented linkage,
--    non-private log) but returns only the storage paths and media types
--    for files explicitly marked shared_with_teacher = true.
CREATE OR REPLACE FUNCTION public.get_shared_session_media(p_session_id uuid)
RETURNS TABLE (
  storage_path  text,
  media_type    text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (SELECT profiles.role FROM public.profiles WHERE profiles.id = auth.uid()) IS DISTINCT FROM 'teacher' THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    sm.storage_path,
    sm.media_type
  FROM public.session_media sm
  JOIN public.practice_logs pl ON pl.id = sm.session_id
  JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
  WHERE sm.session_id = p_session_id
    AND sm.shared_with_teacher = true
    AND pl.is_private = false
    AND sl.entity_id = auth.uid()
    AND sl.status = 'active'
    AND sl.consent_given = true
  ORDER BY sm.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_shared_session_media(uuid) TO authenticated;

-- Idempotent: safe to re-run.
