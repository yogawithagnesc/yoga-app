-- ============================================================
-- LUMEN — Phase 21 Migration: Account Deletion RPC
-- Run this in Supabase Dashboard → SQL Editor after schema_phase20
--
-- Implements profile deletion via RPC function. The associated
-- auth.users record deletion is handled by a Vercel serverless
-- function (/api/delete-user.js) that calls the Supabase Admin API.
--
-- Deletion flow:
-- 1. Client calls db.rpc('delete_user_account') → deletes profiles row
--    and cascades to all user data (logs, focus_areas, etc.)
-- 2. Client calls /api/delete-user → deletes auth.users record via
--    Supabase Admin API (makes email/password completely unusable)
-- 3. Client signs out and redirects to login
--
-- Idempotent — safe to re-run.
-- ============================================================

-- Create RPC function to delete user profile (cascades to all user data)
CREATE OR REPLACE FUNCTION public.delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Delete profile (cascades to all user data via FK constraints)
  DELETE FROM public.profiles WHERE id = auth.uid();
  RAISE NOTICE 'User profile and associated data deleted';
END;
$$;

-- Allow authenticated users to call this function
GRANT EXECUTE ON FUNCTION public.delete_user_account() TO authenticated;
