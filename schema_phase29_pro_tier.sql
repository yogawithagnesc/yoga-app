-- ============================================================
-- LUMEN — Phase 29 Migration: Pro Tier Infrastructure (M7-6-8)
-- Run this in Supabase Dashboard → SQL Editor after schema_phase28
--
-- RATIONALE: user wants to restrict some future teacher/studio functions
-- to a paid "Pro" tier. This pass sets up the schema + flag ONLY — no
-- payment processing, checkout flow, or billing integration. Per the
-- recommended default (no direct response received when raised as a
-- question): a `tier` column on `profiles`, defaulting every account to
-- 'free', flippable to 'pro' for now only by a developer running SQL
-- directly in the Supabase Dashboard (no self-service upgrade path exists
-- yet). Future work (a real checkout/Stripe integration) can set the same
-- column without any further schema change.
--
-- Idempotent — safe to re-run.
-- ============================================================

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free', 'pro'));

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pro_since timestamptz;

-- Guard against a user granting themselves Pro via the client: a normal
-- authenticated request has auth.uid() = the row being updated, so any
-- client-side attempt to change `tier`/`pro_since` on one's own row is
-- silently reverted. Direct SQL run in the Dashboard (or a future
-- SECURITY DEFINER checkout-completion function) runs without a request
-- JWT, so auth.uid() is NULL there and the change goes through.
CREATE OR REPLACE FUNCTION public.protect_tier_column()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF (NEW.tier IS DISTINCT FROM OLD.tier OR NEW.pro_since IS DISTINCT FROM OLD.pro_since)
     AND auth.uid() = OLD.id THEN
    NEW.tier      := OLD.tier;
    NEW.pro_since := OLD.pro_since;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_protect_tier ON public.profiles;
CREATE TRIGGER profiles_protect_tier
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_tier_column();

-- To manually grant Pro to a teacher/studio account (until a checkout
-- flow exists), run in the SQL Editor:
--   UPDATE public.profiles SET tier = 'pro', pro_since = now() WHERE id = '<user-uuid>';
