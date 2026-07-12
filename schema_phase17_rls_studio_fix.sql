-- ============================================================
-- LUMEN — Phase 17 — RLS Studio Linkage Fix
-- Run this in Supabase Dashboard → SQL Editor (after phase 16)
--
-- Issue: logs_linked_select policy allows studios to read
-- linked students' logs, bypassing practice_logs_studio_block
-- (RLS uses OR logic — if ANY policy allows, access is granted).
--
-- Fix: Add role check to logs_linked_select to exclude studios.
-- ============================================================

-- Drop and recreate logs_linked_select with studio exclusion
DROP POLICY IF EXISTS "logs_linked_select" ON public.practice_logs;
CREATE POLICY "logs_linked_select" ON public.practice_logs
  FOR SELECT USING (
    is_private = false
    AND (SELECT role FROM public.profiles WHERE id = auth.uid()) != 'studio'
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id  = practice_logs.user_id
        AND sl.entity_id   = auth.uid()
        AND sl.status      = 'active'
        AND sl.consent_given = true
    )
  );

-- Idempotent: safe to re-run.
-- If phase 15 created practice_logs_studio_block, this fix
-- complements it by preventing studios from accessing logs
-- via the logs_linked_select path.
