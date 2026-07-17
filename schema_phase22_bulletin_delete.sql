-- ============================================================
-- LUMEN — Phase 22 Migration: Bulletin Deletion by Author
-- Run this in Supabase Dashboard → SQL Editor after schema_phase21
--
-- schema_phase13 deliberately made group_bulletins immutable
-- (no UPDATE/DELETE policy) with the design note "if a mistake
-- occurs, a new corrective bulletin is posted." Product decision
-- (M7-2 Item #6) reverses this: a teacher/studio must be able to
-- delete a bulletin they posted to their own group if it was sent
-- in error. Deletion is permanent and removes the bulletin for
-- every group member (no per-student soft-hide).
--
-- Idempotent — safe to re-run.
-- ============================================================

DROP POLICY IF EXISTS "group_bulletins_author_delete" ON public.group_bulletins;
CREATE POLICY "group_bulletins_author_delete" ON public.group_bulletins
  FOR DELETE USING (author_id = auth.uid());
