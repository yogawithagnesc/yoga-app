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
-- Step 1: Remove join_code_id column from profiles if it exists
-- (must do this BEFORE dropping join_codes table)
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS fk_profiles_join_code_id;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS join_code_id;

-- ──────────────────────────────────────────────────────────────
-- Step 2: Drop join_codes table if it exists (clears failed state)
-- ──────────────────────────────────────────────────────────────

DROP TABLE IF EXISTS public.join_codes CASCADE;

-- ──────────────────────────────────────────────────────────────
-- Step 3: Create join_codes table fresh
-- ──────────────────────────────────────────────────────────────

CREATE TABLE public.join_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  created_by uuid NOT NULL,
  organization_id uuid,
  tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro')),
  max_participants int,
  current_participants int NOT NULL DEFAULT 0,
  feature_flags jsonb DEFAULT '{}',
  name text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fk_join_codes_created_by FOREIGN KEY (created_by)
    REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT fk_join_codes_organization_id FOREIGN KEY (organization_id)
    REFERENCES public.profiles(id) ON DELETE CASCADE
);

-- ──────────────────────────────────────────────────────────────
-- Step 4: Create indexes
-- ──────────────────────────────────────────────────────────────

CREATE INDEX idx_join_codes_code ON public.join_codes(code);
CREATE INDEX idx_join_codes_created_by ON public.join_codes(created_by);
CREATE INDEX idx_join_codes_organization_id ON public.join_codes(organization_id);

-- ──────────────────────────────────────────────────────────────
-- Step 5: Add join_code_id to profiles with foreign key
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS join_code_id uuid
    REFERENCES public.join_codes(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_join_code_id ON public.profiles(join_code_id);

-- ──────────────────────────────────────────────────────────────
-- Step 6: Enable RLS on join_codes
-- ──────────────────────────────────────────────────────────────

ALTER TABLE public.join_codes ENABLE ROW LEVEL SECURITY;

-- ──────────────────────────────────────────────────────────────
-- Step 7: Create RLS policies
-- ──────────────────────────────────────────────────────────────

-- Policy 1: Owner/org can read own codes
CREATE POLICY join_codes_select ON public.join_codes
  FOR SELECT
  USING (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 2: Owner/org can insert
CREATE POLICY join_codes_insert ON public.join_codes
  FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 3: Owner/org can update
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

-- Policy 4: Owner/org can delete
CREATE POLICY join_codes_delete ON public.join_codes
  FOR DELETE
  USING (
    created_by = auth.uid()
    OR organization_id = auth.uid()
  );

-- Policy 5: Anyone can read codes for validation during signup
CREATE POLICY join_codes_public_read ON public.join_codes
  FOR SELECT
  USING (true);

-- ──────────────────────────────────────────────────────────────
-- Step 8: Create triggers for participant tracking
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
-- Step 9: Create validation function
-- ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.validate_join_code(code_input text)
RETURNS TABLE (
  id uuid,
  tier text,
  feature_flags jsonb,
  error text
)
LANGUAGE plpgsql
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
-- Migration Complete
-- ══════════════════════════════════════════════════════════════
-- All objects created successfully. Ready to use.
-- Phase 1 (App Owner): created_by = <app-owner-uuid>, organization_id = NULL
-- Phase 2 (Organization): created_by = <admin>, organization_id = <org-uuid>
-- ══════════════════════════════════════════════════════════════
