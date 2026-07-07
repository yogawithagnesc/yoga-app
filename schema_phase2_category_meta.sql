-- ============================================================
-- LUMEN — Phase 2 Gap-Fill Migration
-- Run this in Supabase Dashboard → SQL Editor, after
-- schema.sql and schema_phase1_gaps.sql
--
-- Adds the two columns the log-screen type grid needs to render
-- entirely from data (subtitle line + stable ordering) instead of
-- the hard-coded TYPES array, and backfills them for the 12
-- existing system styles. Idempotent — safe to re-run.
-- ============================================================

ALTER TABLE public.practice_categories
  ADD COLUMN IF NOT EXISTS subtitle   text,
  ADD COLUMN IF NOT EXISTS sort_order integer NOT NULL DEFAULT 0;

UPDATE public.practice_categories SET subtitle = 'Flow & breath',        sort_order = 1  WHERE name = 'Vinyasa'     AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Classic alignment',    sort_order = 2  WHERE name = 'Hatha'       AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Deep passive holds',   sort_order = 3  WHERE name = 'Yin'         AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Active & dynamic',    sort_order = 4  WHERE name = 'Yang'        AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Traditional series',   sort_order = 5  WHERE name = 'Ashtanga'    AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Rest & recovery',      sort_order = 6  WHERE name = 'Restorative' AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Core & control',       sort_order = 7  WHERE name = 'Pilates'     AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Machine-based',        sort_order = 8  WHERE name = 'Reformer'    AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Resistance training', sort_order = 9  WHERE name = 'Strength'    AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Range of motion',      sort_order = 10 WHERE name = 'Mobility'    AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Breath techniques',    sort_order = 11 WHERE name = 'Pranayama'   AND is_system = true;
UPDATE public.practice_categories SET subtitle = 'Stillness & focus',    sort_order = 12 WHERE name = 'Meditation'  AND is_system = true;
