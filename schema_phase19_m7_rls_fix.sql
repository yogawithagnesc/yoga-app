-- ============================================================
-- LUMEN — Phase 19 — M7 RLS Security Fix (M7)
-- Run this in Supabase Dashboard → SQL Editor (after phase 18)
--
-- Issue: schema_phase16's videos_published_read policy allowed
-- ANY authenticated user to see ANY published video, with no
-- linkage check. This is a critical security flaw.
--
-- Fix: Update the policy to require that non-creators either:
--   (a) are linked to the video's teacher/studio via studio_linkages
--   (b) with status='active' and consent_given=true
--
-- This ensures published videos are visible only to:
--   - The creator (teacher_id or studio_id)
--   - Students with active, consented linkages to the creator
-- ============================================================

-- Drop the old permissive policy and recreate with linkage check
DROP POLICY IF EXISTS "videos_published_read" ON public.videos;
CREATE POLICY videos_published_read ON public.videos
  FOR SELECT
  TO authenticated
  USING (
    -- Creator can always see their own videos
    teacher_id = auth.uid()
    OR studio_id = auth.uid()
    OR (
      -- Non-creators can see published videos only if linked
      is_published
      AND (
        EXISTS (
          SELECT 1 FROM public.studio_linkages
          WHERE student_id = auth.uid()
          AND (entity_id = videos.teacher_id OR entity_id = videos.studio_id)
          AND status = 'active'
          AND consent_given = true
        )
      )
    )
  );

-- Idempotent: safe to re-run.
