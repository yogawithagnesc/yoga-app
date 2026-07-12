-- ============================================================
-- LUMEN — Test Video Catalog (for development/testing)
-- Run this in Supabase Dashboard → SQL Editor to populate
-- the videos table with sample on-demand classes.
--
-- Playback IDs are from public test assets (valid on Mux free tier).
-- Replace these with real videos once you upload via Video Studio.
-- ============================================================

-- Insert 3 sample on-demand classes
-- (teacher_id/studio_id left NULL; you can update them to your own ID if desired)
INSERT INTO public.videos (title, description, mux_playback_id, duration_seconds, is_published, teacher_id, studio_id, created_at)
VALUES
  (
    'Intro to Vinyasa Flow',
    'A foundational Vinyasa class linking breath to movement. Build heat through a balanced sequence of standing poses, forward folds, and a grounding savasana.',
    'QSq3Bgs005a0132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig',
    1260, -- 21 minutes
    true,
    NULL,
    NULL,
    now()
  ),
  (
    'Morning Energizer',
    'Wake up your body and mind with this 15-minute sequence designed to build energy and focus for the day ahead.',
    'QSq3Bgs005a0132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig', -- same test ID for demo purposes
    900, -- 15 minutes
    true,
    NULL,
    NULL,
    now()
  ),
  (
    'Restorative Bedtime',
    'Wind down in the evening with gentle stretches, breath work, and relaxation techniques. Perfect before sleep.',
    'QSq3Bgs005a0132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig', -- same test ID for demo purposes
    720, -- 12 minutes
    true,
    NULL,
    NULL,
    now()
  )
ON CONFLICT DO NOTHING;

-- Idempotent: safe to re-run. Does nothing if the exact titles already exist.
