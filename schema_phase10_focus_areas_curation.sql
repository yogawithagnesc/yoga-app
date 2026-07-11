-- ============================================================
-- LUMEN — Phase 10: Focus Areas Curation
-- Run this in Supabase Dashboard → SQL Editor, after
-- schema_phase9_categorization_engine.sql
--
-- Replaces the 15 default focus areas with a curated set of 9
-- designed for broader accessibility and clearer progression:
-- - Upper body, Lower body, Core, Full body (body regions)
-- - Flexibility, Strength, Balance (capabilities)
-- - Mindfulness, Breathing (mental/restorative)
--
-- Students and teachers can still add custom focus areas.
-- Idempotent — safe to re-run.
-- ============================================================

-- Deactivate all system focus areas (created_by IS NULL)
UPDATE public.focus_areas
SET is_active = false
WHERE created_by IS NULL;

-- Insert the new curated system focuses
INSERT INTO public.focus_areas (label, sort_order, is_active, visibility, created_by)
VALUES
  ('Upper body',   1, true, 'system', NULL),
  ('Lower body',   2, true, 'system', NULL),
  ('Core',         3, true, 'system', NULL),
  ('Full body',    4, true, 'system', NULL),
  ('Flexibility',  5, true, 'system', NULL),
  ('Strength',     6, true, 'system', NULL),
  ('Balance',      7, true, 'system', NULL),
  ('Mindfulness',  8, true, 'system', NULL),
  ('Breathing',    9, true, 'system', NULL)
ON CONFLICT (label) DO UPDATE
SET is_active = true, visibility = 'system', created_by = NULL;
