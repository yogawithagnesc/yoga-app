-- Phase 12 (M4 Phase B) — Saved class filters
--
-- Studio/teacher/student users can filter the Classes tab by date range,
-- teacher, and style, then "star" a filter setup as a named shortcut chip.
-- Stored as a small JSONB array directly on profiles (expected cardinality
-- is a handful of filters per user — a separate table would be overkill).
--
-- Idempotent: safe to re-run.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS saved_filters jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Each array element: { id, name, dateMin, dateMax, teacherId, style, createdAt }
-- No new RLS needed — profiles already restrict UPDATE to the owning row
-- (see schema.sql "profiles_update_own" or equivalent).
