-- ============================================================
-- LUMEN — Phase 24 Migration: Bulletin Owner (Teacher) SELECT Fix
-- Run this in Supabase Dashboard → SQL Editor after schema_phase23
--
-- ROOT CAUSE of "teacher cannot see any bulletin messages, even one
-- just sent": schema_phase13 gave group_bulletins a SELECT policy
-- for group MEMBERS (students, via is_group_member()) and an INSERT
-- policy for the group OWNER (teacher/studio) — but never a SELECT
-- policy for the owner. A teacher's INSERT succeeds, but the very
-- next SELECT (to redisplay the bulletin list, e.g. after sendBulletin()
-- calls loadGroups()) is silently filtered to zero rows by RLS,
-- because no policy grants the owner read access to their own
-- group's bulletins. This has been true since phase13 shipped — it
-- is not a regression from phase22/23.
--
-- Idempotent — safe to re-run.
-- ============================================================

DROP POLICY IF EXISTS "group_bulletins_owner_select" ON public.group_bulletins;
CREATE POLICY "group_bulletins_owner_select" ON public.group_bulletins
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_bulletins.group_id
        AND g.owner_id = auth.uid()
    )
  );
