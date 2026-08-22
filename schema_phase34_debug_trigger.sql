-- ============================================================
-- LUMEN — Phase 34 Migration: Debug Trigger (M9)
-- Simplify handle_new_user to test basic signup without join_code_id.
-- Run in Supabase Dashboard → SQL Editor.
--
-- SCOPE: Temporarily remove join_code_id handling to isolate
-- whether the issue is auth/profile creation or join_code_id extraction.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Step 1: Simplify handle_new_user (no join_code_id for now)
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
    display_name
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name'
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- Migration Complete
-- ══════════════════════════════════════════════════════════════
-- Simplified trigger without join_code_id extraction.
-- Test if basic signup works. If yes, the issue is join_code_id extraction.
-- ══════════════════════════════════════════════════════════════
