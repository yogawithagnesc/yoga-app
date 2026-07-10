-- ============================================================
-- LUMEN — Phase 6 Repair Migration
-- Run this in Supabase Dashboard → SQL Editor, after the earlier
-- schema files.
--
-- Fixes the role-select redirect loop: accounts registered BEFORE
-- schema.sql was run have no public.profiles row, so saving a role
-- updates zero rows (no error), index.html finds no role, and the
-- user bounces back to role-select.html forever.
--
-- 1. Re-asserts the auto-create-profile trigger (in case an earlier
--    non-idempotent run of schema.sql aborted before creating it).
-- 2. Backfills a profiles row for every existing auth.users account
--    that is missing one.
-- 3. Adds an INSERT policy on profiles so the client can self-heal
--    (role-select.html now upserts its own row if it's missing).
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. Re-assert the new-user trigger (phase-4 version, with the
--    OAuth display-name fallbacks)
-- ────────────────────────────────────────────────────────────
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
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ────────────────────────────────────────────────────────────
-- 2. Backfill profiles for accounts created before the trigger
-- ────────────────────────────────────────────────────────────
INSERT INTO public.profiles (id, email, display_name)
SELECT
  u.id,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'display_name',
    u.raw_user_meta_data->>'full_name',
    u.raw_user_meta_data->>'name'
  )
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;


-- ────────────────────────────────────────────────────────────
-- 3. Let users create their own profile row (self-heal path
--    used by role-select.html's upsert)
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_own_insert" ON public.profiles;
CREATE POLICY "profiles_own_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);


-- ────────────────────────────────────────────────────────────
-- Verify: should return 0
-- ────────────────────────────────────────────────────────────
SELECT count(*) AS users_missing_profile
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL;
