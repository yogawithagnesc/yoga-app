-- ============================================================
-- LUMEN — Phase 32 Migration: Fix Join Code Signup Flow (M9)
-- Unified schema for app-owner codes (Phase 1) & organization
-- codes (Phase 2). Run in Supabase Dashboard → SQL Editor.
--
-- SCOPE: Update handle_new_user() trigger to extract join_code_id
-- from auth user metadata during profile creation at signup.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Step 1: Update handle_new_user to extract join_code_id
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    display_name,
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
    CASE
      WHEN NEW.raw_user_meta_data->>'join_code_id' IS NOT NULL
      THEN (NEW.raw_user_meta_data->>'join_code_id')::uuid
      ELSE NULL
    END
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- Migration Complete
-- ══════════════════════════════════════════════════════════════
-- handle_new_user() now extracts join_code_id from auth metadata.
-- Signup flow (register.html → role-select.html) can now work end-to-end.
-- ══════════════════════════════════════════════════════════════
