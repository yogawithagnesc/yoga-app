-- ============================================================
-- LUMEN — Phase 9 Migration: Dynamic Practice Categorization Engine
-- Run this in Supabase Dashboard → SQL Editor, after
-- schema_phase8_fix_like_count.sql.
--
-- Implements PRD v2.0 §3.2.1 (Dynamic Practice Categorization Engine)
-- and §3.2.2 (Hierarchical Practice Focus & Ecosystem Recommendation).
--
-- Adds a user-owned "category" layer (PRD's Yoga/Fitness containers)
-- on top of the existing practice_categories table (which holds what
-- the PRD calls "practice types" — Vinyasa, Hatha, Running, etc.).
-- Existing tables/columns are untouched; this is purely additive.
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. PRACTICE GROUPS
--    The PRD's user-owned "categories" — every profile gets
--    exactly two seeded rows (Yoga, Fitness) that can be renamed
--    but not deleted. Users may add unlimited custom groups.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.practice_groups (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name         text        NOT NULL,
  sort_order   integer     NOT NULL DEFAULT 0,
  default_key  text        CHECK (default_key IN ('yoga', 'fitness')),
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS practice_groups_user_id_idx ON public.practice_groups (user_id);

-- Only one default-key group per user per key (guards against the
-- seed trigger firing twice for the same profile).
CREATE UNIQUE INDEX IF NOT EXISTS practice_groups_user_default_key_uidx
  ON public.practice_groups (user_id, default_key)
  WHERE default_key IS NOT NULL;

ALTER TABLE public.practice_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "practice_groups_own_all" ON public.practice_groups;
CREATE POLICY "practice_groups_own_all" ON public.practice_groups
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- 2. SEED YOGA + FITNESS ON PROFILE CREATION
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.seed_default_practice_groups()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.practice_groups (user_id, name, sort_order, default_key)
  VALUES
    (NEW.id, 'Yoga',    1, 'yoga'),
    (NEW.id, 'Fitness', 2, 'fitness')
  ON CONFLICT (user_id, default_key) WHERE default_key IS NOT NULL DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_created_seed_groups ON public.profiles;
CREATE TRIGGER on_profile_created_seed_groups
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.seed_default_practice_groups();

-- Backfill: existing profiles created before this migration.
INSERT INTO public.practice_groups (user_id, name, sort_order, default_key)
SELECT p.id, 'Yoga', 1, 'yoga'
FROM public.profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM public.practice_groups g WHERE g.user_id = p.id AND g.default_key = 'yoga'
);

INSERT INTO public.practice_groups (user_id, name, sort_order, default_key)
SELECT p.id, 'Fitness', 2, 'fitness'
FROM public.profiles p
WHERE NOT EXISTS (
  SELECT 1 FROM public.practice_groups g WHERE g.user_id = p.id AND g.default_key = 'fitness'
);


-- ────────────────────────────────────────────────────────────
-- 3. PRACTICE GROUP ITEMS
--    Per-user placement override: which group a given practice
--    type (practice_categories row) currently sits in for this
--    user. Only written when a user drags a type to a non-default
--    group — absence of a row means "use the category_type
--    fallback" (yoga/breathwork → Yoga group, movement → Fitness
--    group), resolved client-side.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.practice_group_items (
  user_id             uuid        NOT NULL REFERENCES public.profiles(id)            ON DELETE CASCADE,
  practice_category_id uuid       NOT NULL REFERENCES public.practice_categories(id) ON DELETE CASCADE,
  group_id            uuid        NOT NULL REFERENCES public.practice_groups(id)     ON DELETE CASCADE,
  sort_order          integer     NOT NULL DEFAULT 0,
  updated_at          timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, practice_category_id)
);

CREATE INDEX IF NOT EXISTS practice_group_items_group_id_idx ON public.practice_group_items (group_id);

ALTER TABLE public.practice_group_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "practice_group_items_own_all" ON public.practice_group_items;
CREATE POLICY "practice_group_items_own_all" ON public.practice_group_items
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- 4. FOCUS AREAS — CUSTOM + ECOSYSTEM PROMOTION (PRD §3.2.2)
--    Extend the existing system-only dictionary with per-user
--    custom entries and teacher/studio → linked-student promotion,
--    mirroring the practice_categories visibility model.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.focus_areas
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS visibility text NOT NULL DEFAULT 'system'
    CHECK (visibility IN ('system', 'private', 'linked'));

-- Own custom focuses: full CRUD for the creator.
DROP POLICY IF EXISTS "focus_areas_own_all" ON public.focus_areas;
CREATE POLICY "focus_areas_own_all" ON public.focus_areas
  FOR ALL USING (created_by = auth.uid()) WITH CHECK (created_by = auth.uid());

-- Students can read 'linked' focus items from teachers/studios they follow —
-- these render client-side as "Recommended Focus" badges.
DROP POLICY IF EXISTS "focus_areas_linked_select" ON public.focus_areas;
CREATE POLICY "focus_areas_linked_select" ON public.focus_areas
  FOR SELECT USING (
    visibility = 'linked'
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id = auth.uid()
        AND sl.entity_id  = focus_areas.created_by
        AND sl.status     = 'active'
        AND sl.consent_given = true
    )
  );
