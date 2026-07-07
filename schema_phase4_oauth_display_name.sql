-- ============================================================
-- LUMEN — Phase 4 Gap-Fill Migration
-- Run this in Supabase Dashboard → SQL Editor, after the earlier
-- schema files.
--
-- Google/Apple OAuth sign-ins populate raw_user_meta_data with
-- 'full_name' or 'name', not 'display_name' (which only exists for
-- email/password sign-ups via register.html's signUp() call). Without
-- this fix, every OAuth first-timer's profiles.display_name would be
-- NULL and the dashboard greeting/avatars would be blank.
--
-- CREATE OR REPLACE is idempotent — safe to re-run.
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, display_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NEW.raw_user_meta_data->>'display_name',
      NEW.raw_user_meta_data->>'full_name',
      NEW.raw_user_meta_data->>'name'
    )
  );
  RETURN NEW;
END;
$$;
