-- ============================================================
-- LUMEN — Phase 31 Migration: Join Codes System (M9)
-- Unified schema for app-owner codes (Phase 1) & organization
-- codes (Phase 2). Run in Supabase Dashboard → SQL Editor.
--
-- SCOPE (Phase 1): App owner creates/edits/deletes join codes
-- to control early access, pricing tier assignment, and
-- participant limits.
--
-- SCOPE (Phase 2 — deferred): organization_id allows studios
-- to manage their own join codes for member invitations.
--
-- Idempotent — safe to re-run.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- Create join_codes table
-- ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.join_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  created_by uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  organization_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  max_participants int,
  current_participants int NOT NULL DEFAULT 0,
  feature_flags jsonb DEFAULT '{}',
  name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_join_codes_code ON public.join_codes(code);
CREATE INDEX IF NOT EXISTS idx_join_codes_created_by ON public.join_codes(created_by);
CREATE INDEX IF NOT EXISTS idx_join_codes_organization_id ON public.join_codes(organization_id);

-- ──────────────────────────────────────────────────────────────
-- Add join_code_id to profiles for redemption tracking
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS join_code_id uuid REFERENCES public.join_codes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_join_code_id ON public.profiles(join_code_id);

-- ──────────────────────────────────────────────────────────────
-- RLS Policies for join_codes table
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.join_codes ENABLE ROW LEVEL SECURITY;

-- Policy 1: Read own codes (created_by = user) OR codes for own organization
DROP POLICY IF EXISTS join_codes_select ON public.join_codes;
CREATE POLICY join_codes_select ON public.join_codes
  FOR SELECT
  USING (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 2: Insert codes (only as created_by, not organization_id yet)
-- Phase 1: only app owner (created_by) can insert
-- Phase 2: organizations can also insert with organization_id set to their ID
DROP POLICY IF EXISTS join_codes_insert ON public.join_codes;
CREATE POLICY join_codes_insert ON public.join_codes
  FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    OR (organization_id = auth.uid())
  );

-- Policy 3: Update own codes
DROP POLICY IF EXISTS join_codes_update ON public.join_codes;
CREATE POLICY join_codes_update ON public.join_codes
  FOR UPDATE
  USING (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  )
  WITH CHECK (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 4: Delete own codes
DROP POLICY IF EXISTS join_codes_delete ON public.join_codes;
CREATE POLICY join_codes_delete ON public.join_codes
  FOR DELETE
  USING (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 5: Anyone can READ a code (to validate during signup)
-- NOTE: This is a separate SELECT policy to allow public code validation
DROP POLICY IF EXISTS join_codes_public_read ON public.join_codes;
CREATE POLICY join_codes_public_read ON public.join_codes
  FOR SELECT
  USING (true);

-- ──────────────────────────────────────────────────────────────
-- Trigger: Increment participant count when profile added with code
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.increment_join_code_participants()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.join_code_id IS NOT NULL THEN
    UPDATE public.join_codes
    SET current_participants = current_participants + 1,
        updated_at = now()
    WHERE id = NEW.join_code_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_increment_join_code ON public.profiles;
CREATE TRIGGER profiles_increment_join_code
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.increment_join_code_participants();

-- ──────────────────────────────────────────────────────────────
-- Trigger: Decrement participant count when profile deleted
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.decrement_join_code_participants()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF OLD.join_code_id IS NOT NULL THEN
    UPDATE public.join_codes
    SET current_participants = greatest(current_participants - 1, 0),
        updated_at = now()
    WHERE id = OLD.join_code_id;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS profiles_decrement_join_code ON public.profiles;
CREATE TRIGGER profiles_decrement_join_code
  AFTER DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.decrement_join_code_participants();

-- ──────────────────────────────────────────────────────────────
-- Helper function: Validate & redeem join code
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.validate_join_code(code_input text)
RETURNS TABLE (
  id uuid,
  tier text,
  feature_flags jsonb,
  error text
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_code record;
BEGIN
  -- Find the code
  SELECT j.* INTO v_code FROM public.join_codes j
  WHERE j.code = code_input AND j.active = true;

  -- Code not found
  IF v_code IS NULL THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::jsonb, 'Code not found or inactive'::text;
    RETURN;
  END IF;

  -- Code at capacity
  IF v_code.max_participants IS NOT NULL
     AND v_code.current_participants >= v_code.max_participants THEN
    RETURN QUERY SELECT NULL::uuid, NULL::text, NULL::jsonb, 'Code has reached max participants'::text;
    RETURN;
  END IF;

  -- Valid
  RETURN QUERY SELECT v_code.id, v_code.tier, v_code.feature_flags, NULL::text;
END;
$$;

-- ══════════════════════════════════════════════════════════════
-- Summary
-- ══════════════════════════════════════════════════════════════
-- Phase 1 (App Owner): created_by = <app-owner-uuid>, organization_id = NULL
-- Phase 2 (Organization): created_by = <admin>, organization_id = <org-uuid>
--
-- Feature flags example:
--   '{"video": true, "recovery_log": false, "media_upload": true}'
--
-- Usage in signup flow:
--   1. User enters join code in register.html
--   2. Validate via SELECT * FROM validate_join_code(code_input)
--   3. On signup completion, set profiles.join_code_id = validated_code.id
--   4. In role-select.html, fetch tier + features via:
--      SELECT tier, feature_flags FROM join_codes WHERE id = profiles.join_code_id
--   5. On profile save, insert with tier = code.tier
-- ══════════════════════════════════════════════════════════════
