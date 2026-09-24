-- JOIN_CODES_TEST_SETUP.sql
-- Run this in Supabase Dashboard → SQL Editor
-- Creates 4 test join codes for P0 validation

-- First, get the app owner (creator) user ID
-- Copy the value from the result below and use in INSERT queries
SELECT auth.uid() AS your_user_id;

-- ─────────────────────────────────────────────────────────
-- CREATE TEST CODES
-- Replace 'YOUR_USER_ID' below with the actual UUID from above
-- ─────────────────────────────────────────────────────────

INSERT INTO join_codes (code, display_name, tier, max_participants, created_by, organization_id, feature_flags, is_active)
VALUES
  ('TESTFREE01', 'Test Free Tier', 'free', 5, 'YOUR_USER_ID'::uuid, NULL, '{"video":false,"recovery_log":false,"media_upload":false}'::jsonb, true),
  ('TESTPRO02', 'Test Pro Tier', 'pro', 20, 'YOUR_USER_ID'::uuid, NULL, '{"video":true,"recovery_log":true,"media_upload":true}'::jsonb, true),
  ('TESTMAX01', 'Test Max Tier (Cap=2)', 'pro', 2, 'YOUR_USER_ID'::uuid, NULL, '{"video":true,"recovery_log":true,"media_upload":true}'::jsonb, true),
  ('TESTINACTIVE', 'Test Inactive Code', 'free', 10, 'YOUR_USER_ID'::uuid, NULL, '{"video":false}'::jsonb, false)
ON CONFLICT (code) DO NOTHING;

-- ─────────────────────────────────────────────────────────
-- VERIFY CREATION
-- ─────────────────────────────────────────────────────────

SELECT code, display_name, tier, max_participants, current_participants, is_active
FROM join_codes
WHERE code LIKE 'TEST%'
ORDER BY code;

-- ─────────────────────────────────────────────────────────
-- CLEANUP (Optional: Run ONLY to reset tests)
-- ─────────────────────────────────────────────────────────
-- DELETE FROM join_codes WHERE code LIKE 'TEST%';
