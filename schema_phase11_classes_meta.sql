-- ============================================================
-- LUMEN — Phase 11 Migration (M4 Phase A: Class Scheduling)
-- Run this in Supabase Dashboard → SQL Editor, after the earlier
-- schema files (1 → 2 → … → 10 → 11).
--
-- Adds the provisioning metadata the M4 scheduling form needs on
-- the existing `classes` table (room, prerequisites, featured flag,
-- assigned teacher), and relaxes redeem_join_code() so a Teacher can
-- bind to a Studio's join code (the "Teacher Matrix Binding" of
-- PRD §3.5.1). The `classes`/`bookings` tables, capacity trigger and
-- RLS already exist in schema.sql — this is purely additive.
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. CLASSES — provisioning metadata (PRD §8.1)
--    room:               free-text room / studio-space label
--    prerequisites:      free-text booking prerequisite note
--    is_featured:        Studio merchandising flag — featured
--                        instances render in the hero banner atop
--                        linked students' Classes tab (PRD §3.5.2)
--    assigned_teacher_id: the profile actually teaching the class,
--                        which can differ from teacher_id (the owner
--                        that scheduled it). Lets a Studio schedule a
--                        class and assign one of its linked Teachers;
--                        the Teacher's "today's teaching schedule"
--                        header then matches on either column.
--                        ON DELETE SET NULL so removing a teacher
--                        profile doesn't cascade-delete studio classes.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS room                text;
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS prerequisites       text;
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS is_featured         boolean NOT NULL DEFAULT false;
ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS assigned_teacher_id uuid
  REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS classes_assigned_teacher_idx
  ON public.classes (assigned_teacher_id);

-- Partial index for the featured-hero query (published + featured only).
CREATE INDEX IF NOT EXISTS classes_featured_idx
  ON public.classes (start_time)
  WHERE is_featured = true AND status = 'published';


-- ────────────────────────────────────────────────────────────
-- 2. RLS — let an assigned teacher read the class they teach
--    even if a Studio owns (scheduled) it, and read its roster.
--
--    schema.sql already grants SELECT on published classes to every
--    authenticated user, and roster SELECT to the owning teacher_id.
--    These add the assigned teacher to the same read scopes so a
--    studio-scheduled class shows up in the assigned teacher's
--    header and roster. No new INSERT/UPDATE/DELETE surface — the
--    owner (teacher_id) still solely controls the row.
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "classes_assigned_select" ON public.classes;
CREATE POLICY "classes_assigned_select" ON public.classes
  FOR SELECT USING (assigned_teacher_id = auth.uid());

DROP POLICY IF EXISTS "bookings_assigned_teacher_select" ON public.bookings;
CREATE POLICY "bookings_assigned_teacher_select" ON public.bookings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id                  = bookings.class_id
        AND c.assigned_teacher_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- 3. redeem_join_code() — Teacher Matrix Binding (PRD §3.5.1)
--
--    The original (Phase 5) version hard-required the caller to be a
--    student. This relaxes it so a Teacher may also redeem, but ONLY
--    a Studio's code — modelling "every facility where they teach".
--    Rules enforced:
--      • student  → teacher OR studio   (unchanged)
--      • teacher  → studio only         (new)
--      • studio   → nothing             (blocked)
--      • no self-link                   (unchanged)
--    The studio_linkages row reuses student_id as "the linking
--    party's id"; entity_type records the target's role, so a
--    teacher→studio bind is student_id=<teacher>, entity_type='studio'.
--    Callers already filter their own linkages by entity_type, so
--    this stays unambiguous.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.redeem_join_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
  v_jc   RECORD;
  v_name text;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();

  IF v_role NOT IN ('student', 'teacher') THEN
    -- studios cannot redeem codes to link outward
    RAISE EXCEPTION 'only_students_or_teachers_can_redeem_join_codes';
  END IF;

  SELECT * INTO v_jc FROM public.join_codes
  WHERE code = upper(trim(p_code))
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > now());

  IF v_jc IS NULL THEN
    RAISE EXCEPTION 'invalid_or_expired_code';
  END IF;

  IF v_jc.owner_id = auth.uid() THEN
    RAISE EXCEPTION 'cannot_link_to_self';
  END IF;

  -- Teachers may only bind to Studios, not to other Teachers.
  IF v_role = 'teacher' AND v_jc.owner_role <> 'studio' THEN
    RAISE EXCEPTION 'teachers_can_only_bind_to_studios';
  END IF;

  INSERT INTO public.studio_linkages (student_id, entity_id, entity_type, join_code_used, consent_given, status)
  VALUES (auth.uid(), v_jc.owner_id, v_jc.owner_role, v_jc.code, true, 'active')
  ON CONFLICT (student_id, entity_id) DO UPDATE
    SET status = 'active', consent_given = true, join_code_used = v_jc.code;

  SELECT display_name INTO v_name FROM public.profiles WHERE id = v_jc.owner_id;

  RETURN jsonb_build_object('entity_id', v_jc.owner_id, 'entity_type', v_jc.owner_role, 'display_name', v_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_join_code(text) TO authenticated;
