-- ============================================================
-- LUMEN — Phase 5 Gap-Fill Migration
-- Run this in Supabase Dashboard → SQL Editor, after the earlier
-- schema files.
--
-- The current linking system is a single immutable profiles.join_code
-- column (auto-generated, 8 chars, never deactivatable). profile.html's
-- "Generate Join Code" card needs multiple, deactivatable, 6-char
-- codes per teacher/studio — this migration adds that as a proper
-- join_codes table plus RPCs for creating and redeeming codes, and
-- backfills each existing teacher/studio's current code so nothing
-- they've already shared stops working.
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. JOIN CODES
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.join_codes (
  code       text        PRIMARY KEY,
  owner_id   uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  owner_role text        NOT NULL CHECK (owner_role IN ('teacher', 'studio')),
  is_active  boolean     NOT NULL DEFAULT true,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS join_codes_owner_id_idx ON public.join_codes (owner_id);

ALTER TABLE public.join_codes ENABLE ROW LEVEL SECURITY;

-- Owners can see and deactivate their own codes. No client INSERT
-- policy — creation goes through create_join_code() below so the
-- server (not the client) picks the role and generates the code.
DROP POLICY IF EXISTS "join_codes_owner_select" ON public.join_codes;
CREATE POLICY "join_codes_owner_select" ON public.join_codes
  FOR SELECT USING (owner_id = auth.uid());

DROP POLICY IF EXISTS "join_codes_owner_update" ON public.join_codes;
CREATE POLICY "join_codes_owner_update" ON public.join_codes
  FOR UPDATE USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

-- Backfill: turn each existing teacher/studio's current profiles.join_code
-- into a live join_codes row so links they've already shared keep working
-- and show up in the new "Generate Join Code" list.
INSERT INTO public.join_codes (code, owner_id, owner_role, is_active)
SELECT join_code, id, role, true
FROM public.profiles
WHERE role IN ('teacher', 'studio') AND join_code IS NOT NULL
ON CONFLICT (code) DO NOTHING;


-- ────────────────────────────────────────────────────────────
-- 2. create_join_code()
--    Called by teachers/studios from profile.html. Generates a
--    6-char alphanumeric code, retrying on the rare collision.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_join_code()
RETURNS public.join_codes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role     text;
  v_code     text;
  v_row      public.join_codes;
  v_attempts int := 0;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role NOT IN ('teacher', 'studio') THEN
    RAISE EXCEPTION 'only_teacher_or_studio_can_create_join_codes';
  END IF;

  LOOP
    v_code := upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 6));
    BEGIN
      INSERT INTO public.join_codes (code, owner_id, owner_role, is_active)
      VALUES (v_code, auth.uid(), v_role, true)
      RETURNING * INTO v_row;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempts := v_attempts + 1;
      IF v_attempts > 5 THEN
        RAISE EXCEPTION 'could_not_generate_unique_code';
      END IF;
    END;
  END LOOP;

  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_join_code() TO authenticated;


-- ────────────────────────────────────────────────────────────
-- 3. redeem_join_code(p_code)
--    Called by students from profile.html after entering a code and
--    checking the consent box. Validates the code, then inserts (or
--    reactivates) the studio_linkages row. SECURITY DEFINER so it can
--    look up another user's join_codes row despite RLS.
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
  IF v_role IS DISTINCT FROM 'student' THEN
    RAISE EXCEPTION 'only_students_can_redeem_join_codes';
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

  INSERT INTO public.studio_linkages (student_id, entity_id, entity_type, join_code_used, consent_given, status)
  VALUES (auth.uid(), v_jc.owner_id, v_jc.owner_role, v_jc.code, true, 'active')
  ON CONFLICT (student_id, entity_id) DO UPDATE
    SET status = 'active', consent_given = true, join_code_used = v_jc.code;

  SELECT display_name INTO v_name FROM public.profiles WHERE id = v_jc.owner_id;

  RETURN jsonb_build_object('entity_id', v_jc.owner_id, 'entity_type', v_jc.owner_role, 'display_name', v_name);
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_join_code(text) TO authenticated;
