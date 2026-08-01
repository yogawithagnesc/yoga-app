-- ============================================================
-- LUMEN — Phase 27 Migration: Practice Log Teacher Selection (M7-6-6)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase26
--
-- Lets a student optionally record which teacher a logged practice was
-- with. Useful when a student is linked to multiple teachers/studios and
-- wants their practice history to reflect who taught the session.
--
-- Scope note: this is intentionally the minimal slice — just the column +
-- RLS needed for student-side selection. The broader "informal attendance"
-- studio-analytics aggregation described in WORKPLAN's M8 Follow-up
-- (class_id linkage, studio_class_tiers() updates) is deferred until a
-- studio actually needs that reporting.
--
-- Idempotent — safe to re-run.
-- ============================================================

ALTER TABLE public.practice_logs
  ADD COLUMN IF NOT EXISTS teacher_id   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS teacher_name text; -- free-text fallback for a teacher not in the system

CREATE INDEX IF NOT EXISTS practice_logs_teacher_id_idx ON public.practice_logs (teacher_id);

-- No RLS change needed: practice_logs' existing "logs_own_all" policy
-- (FOR ALL USING (user_id = auth.uid())) already covers inserting/updating
-- these new nullable columns on the student's own rows. teacher_id merely
-- references a profile — it does not grant the referenced teacher any new
-- read access (a teacher only sees a student's log via the existing
-- "logs_linked_select" policy, same as before this migration).
