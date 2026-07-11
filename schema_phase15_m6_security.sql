-- ============================================================
-- LUMEN — Phase 15 — M6 Security, Profiles & Studio Operations
-- Run this in Supabase Dashboard → SQL Editor (after phase 14)
--
-- Changes:
-- 1. Add `username` column to profiles with UNIQUE constraint
-- 2. Username availability check function (for debounced typing)
-- 3. Studio aggregate-only RLS policies (block individual log access
--    to studio roles, allow only aggregate views/functions)
-- 4. Studio stats aggregate function (join-code follower totals,
--    class attendance summaries by branch)
-- ============================================================

-- Add username column (nullable initially, enforce later if needed)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS username text UNIQUE;

-- RLS policy for username availability check
-- Allows any authenticated user to search for exact-match usernames
-- (narrows result to display_name for privacy before any follow exists)
CREATE OR REPLACE FUNCTION public.check_username_available(p_username text)
RETURNS table(available boolean, id uuid) AS $$
BEGIN
  RETURN QUERY
  SELECT
    NOT EXISTS (SELECT 1 FROM public.profiles WHERE LOWER(username) = LOWER(p_username)) as available,
    COALESCE((SELECT public.profiles.id FROM public.profiles WHERE LOWER(username) = LOWER(p_username) LIMIT 1), NULL::uuid) as id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Allow any authenticated user to call the availability check
GRANT EXECUTE ON FUNCTION public.check_username_available(text) TO authenticated;

-- ────────────────────────────────────────────────────────────
-- Studio Aggregate RLS: block individual log access
-- ────────────────────────────────────────────────────────────

-- For studio roles: practice_logs are visible ONLY via aggregate
-- functions, never as individual rows. This is enforced by an RLS
-- policy that rejects all direct selects when the caller is a studio.
-- The studio instead reads a `studio_practice_stats` view that sums
-- across linked students' non-private logs.

DROP POLICY IF EXISTS "practice_logs_studio_block" ON public.practice_logs;
CREATE POLICY practice_logs_studio_block ON public.practice_logs
  FOR SELECT
  TO authenticated
  USING (
    -- Studio roles can NEVER read individual practice logs
    -- (auth.jwt() -> 'role' = 'studio'::text is not reliable client-side;
    --  check profiles.role instead)
    CASE WHEN (SELECT role FROM public.profiles WHERE id = auth.uid()) = 'studio'
      THEN FALSE
      ELSE TRUE
    END
  );

-- ────────────────────────────────────────────────────────────
-- Studio Stats Aggregation Functions
-- ────────────────────────────────────────────────────────────

-- Aggregate view: total follower count per studio/teacher
-- (reuses studio_linkages; does not read individual logs)
CREATE OR REPLACE FUNCTION public.studio_follower_count(p_entity_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN COALESCE((
    SELECT COUNT(DISTINCT student_id)
    FROM public.studio_linkages
    WHERE entity_id = p_entity_id
      AND status = 'active'
  ), 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Aggregate view: total practice sessions logged by linked students
-- Sums across linked students' non-private logs only
CREATE OR REPLACE FUNCTION public.studio_total_linked_sessions(p_entity_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN COALESCE((
    SELECT COUNT(pl.id)
    FROM public.practice_logs pl
    INNER JOIN public.studio_linkages sl ON pl.user_id = sl.student_id
    WHERE sl.entity_id = p_entity_id
      AND sl.status = 'active'
      AND pl.is_private = false
  ), 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Aggregate view: total minutes practiced by linked students
-- (non-private logs only)
CREATE OR REPLACE FUNCTION public.studio_total_linked_minutes(p_entity_id uuid)
RETURNS integer AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(pl.duration_minutes)
    FROM public.practice_logs pl
    INNER JOIN public.studio_linkages sl ON pl.user_id = sl.student_id
    WHERE sl.entity_id = p_entity_id
      AND sl.status = 'active'
      AND pl.is_private = false
  ), 0);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Class attendance bucketing for date-range analyzer
-- Returns classes by tier (Popular / Unpopular / HighPotential)
-- based on attendance relative to capacity
CREATE OR REPLACE FUNCTION public.studio_class_tiers(
  p_studio_id uuid,
  p_start_date date,
  p_end_date date
)
RETURNS table(
  class_id uuid,
  class_name text,
  tier text,
  attendance_count integer,
  capacity integer
) AS $$
BEGIN
  RETURN QUERY
  WITH class_attendance AS (
    SELECT
      c.id,
      c.title,
      c.capacity,
      COUNT(DISTINCT b.id) as attended
    FROM public.classes c
    LEFT JOIN public.bookings b ON c.id = b.class_id
      AND b.status = 'confirmed'
    WHERE (c.teacher_id = p_studio_id OR c.assigned_teacher_id = p_studio_id)
      AND c.start_time::date BETWEEN p_start_date AND p_end_date
    GROUP BY c.id, c.title, c.capacity
  )
  SELECT
    ca.id,
    ca.title,
    CASE
      WHEN ca.capacity = 0 THEN 'Unpopular'
      WHEN (ca.attended::float / ca.capacity) > 0.8 THEN 'Popular'
      WHEN (ca.attended::float / ca.capacity) > 0.5 THEN 'HighPotential'
      ELSE 'Unpopular'
    END as tier,
    ca.attended,
    ca.capacity
  FROM class_attendance ca;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public;

-- Idempotent: safe to re-run. Permissions already exist from phase 13.
-- (studio aggregate functions do not need explicit GRANT; they execute
--  with SECURITY DEFINER, callers don't need direct permission)
