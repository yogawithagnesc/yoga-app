-- ============================================================
-- LUMEN — Phase 35 Migration: Fix NOT NULL Role Constraint (M9)
-- Update handle_new_user() to provide default role value.
-- Run in Supabase Dashboard → SQL Editor.
--
-- SCOPE: The `role` column is NOT NULL (phase30), but the trigger
-- wasn't providing a value, causing profile creation to fail.
-- This fixes the trigger to include role='student' as default.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Step 1: Update handle_new_user to include default role
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_join_code_id uuid;
BEGIN
  -- Safely extract and cast join_code_id from metadata
  BEGIN
    v_join_code_id := CASE
      WHEN NEW.raw_user_meta_data->>'join_code_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN (NEW.raw_user_meta_data->>'join_code_id')::uuid
      ELSE NULL
    END;
  EXCEPTION WHEN OTHERS THEN
    v_join_code_id := NULL;
  END;

  INSERT INTO public.profiles (
    id,
    email,
    display_name,
    role,
    join_code_id
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name'
    ),
    'student',
    v_join_code_id
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- Migration Complete
-- ══════════════════════════════════════════════════════════════
-- handle_new_user() now includes:
-- - role='student' (safe default, will be changed in role-select.html)
-- - join_code_id extraction with safe UUID handling
-- ══════════════════════════════════════════════════════════════
