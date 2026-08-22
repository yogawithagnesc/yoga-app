-- ============================================================
-- LUMEN — Phase 33 Migration: Safer Join Code UUID Cast (M9)
-- Handle invalid UUID strings gracefully during profile creation.
-- Run in Supabase Dashboard → SQL Editor.
--
-- SCOPE: Improve handle_new_user() to safely cast join_code_id
-- without throwing errors on malformed UUID strings.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Step 1: Update handle_new_user with safe UUID casting
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
    v_join_code_id
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- Migration Complete
-- ══════════════════════════════════════════════════════════════
-- handle_new_user() now safely handles join_code_id casting.
-- Invalid UUIDs are silently ignored (treated as NULL).
-- ══════════════════════════════════════════════════════════════
