-- ============================================================
-- LUMEN — Phase 13 (M5) Community Architecture
-- Run this in Supabase Dashboard → SQL Editor
--
-- PREREQUISITE: schema.sql + phases 1–12 must already be applied.
--
-- This migration is additive and safe to re-run (all statements use
-- IF NOT EXISTS, DROP-then-CREATE, or ON CONFLICT guards).
--
-- Adds infrastructure for M5's cross-role community features:
--   1. follows           — bidirectional follow invitations (pending/accepted states)
--   2. groups            — teacher-owned private sub-communities
--   3. group_members     — membership records
--   4. group_bulletins   — text bulletins posted to groups (realtime broadcasts)
--   5. feedback extensions — direction field + target_entity_id, INSERT policies
--   6. practice_logs extensions — route_feedback_to flag
--
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- SECURITY DEFINER HELPER: is_group_member
--    Prevents RLS recursion when group_members and group_bulletins
--    policies cross-reference each other.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_group_member(p_group_id uuid, p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.group_members gm
    WHERE gm.group_id = p_group_id
      AND gm.student_id = p_user_id
  );
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 1. FOLLOWS
--    Bidirectional follow invitations. A follow record
--    represents a one-way relationship: follower_id follows
--    followee_id. The followee must accept for activity
--    to be visible.
--
--    state: 'pending' (awaiting target acceptance),
--           'accepted' (follow is approved),
--           'revoked' (rejected or unfollowed)
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.follows (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  follower_id  uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  followee_id  uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status       text        NOT NULL DEFAULT 'pending'
                           CHECK (status IN ('pending', 'accepted', 'revoked')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  responded_at timestamptz,
  CONSTRAINT followers_not_self CHECK (follower_id <> followee_id),
  UNIQUE (follower_id, followee_id)
);

CREATE INDEX IF NOT EXISTS follows_followee_status_idx ON public.follows (followee_id, status);
CREATE INDEX IF NOT EXISTS follows_follower_status_idx ON public.follows (follower_id, status);

ALTER TABLE public.follows ENABLE ROW LEVEL SECURITY;

-- Both endpoints see the follow record (follower sees their pending request,
-- followee sees who requested)
DROP POLICY IF EXISTS "follows_involved_select" ON public.follows;
CREATE POLICY "follows_involved_select" ON public.follows
  FOR SELECT USING (follower_id = auth.uid() OR followee_id = auth.uid());

-- Follower initiates a follow request (always starts as pending)
DROP POLICY IF EXISTS "follows_follower_insert" ON public.follows;
CREATE POLICY "follows_follower_insert" ON public.follows
  FOR INSERT WITH CHECK (
    follower_id = auth.uid()
    AND status = 'pending'
  );

-- Either endpoint can update (followee accepts/revokes, follower can withdraw)
-- App enforces which status transitions each side may make
DROP POLICY IF EXISTS "follows_endpoint_update" ON public.follows;
CREATE POLICY "follows_endpoint_update" ON public.follows
  FOR UPDATE USING (followee_id = auth.uid() OR follower_id = auth.uid())
  WITH CHECK (followee_id = auth.uid() OR follower_id = auth.uid());

-- Either party can delete (unfollow / reject)
DROP POLICY IF EXISTS "follows_endpoint_delete" ON public.follows;
CREATE POLICY "follows_endpoint_delete" ON public.follows
  FOR DELETE USING (follower_id = auth.uid() OR followee_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- PROFILES: follow-related visibility
--    The base schema only exposes profiles to: self, linked
--    teachers/studios (of their students), and publicly for
--    teacher/studio roles. Peer students have no visibility into
--    each other's profiles by default, which would leave a
--    follower/followee's display_name unreadable in the follows
--    UI. Grant read access to any profile with which the caller
--    has a follows row (either direction, any status — a pending
--    request must still show the requester's name).
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "profiles_follow_related_select" ON public.profiles;
CREATE POLICY "profiles_follow_related_select" ON public.profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.follows f
      WHERE (f.follower_id = auth.uid() AND f.followee_id = profiles.id)
         OR (f.followee_id = auth.uid() AND f.follower_id = profiles.id)
    )
  );

-- ────────────────────────────────────────────────────────────
-- HELPER: lookup_profile_by_email(p_email)
--    The "follow by email" flow needs to resolve an email to a
--    profile id *before* any follows relationship exists — which
--    the RLS policy above can't cover (chicken-and-egg). This
--    SECURITY DEFINER function exposes only id + display_name for
--    an exact (case-insensitive) email match, mirroring the
--    narrow-disclosure pattern already used by join-code lookup.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.lookup_profile_by_email(p_email text)
RETURNS TABLE (id uuid, display_name text, role text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT p.id, p.display_name, p.role
    FROM public.profiles p
    WHERE lower(p.email) = lower(p_email)
    LIMIT 1;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 2. GROUPS
--    Teacher-owned private sub-communities (e.g., "Private
--    Coaching Circle", "Intermediate Flow Cohort").
--    Groups are created by teachers; they segment their roster
--    of linked students into cohorts for targeted bulletins
--    and schedule alerts.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.groups (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name          text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 80),
  description   text,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS groups_owner_idx ON public.groups (owner_id);

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

-- Teacher/studio owners have full CRUD over their own groups.
-- WITH CHECK additionally requires a teacher/studio role on INSERT/UPDATE
-- (students cannot create groups).
DROP POLICY IF EXISTS "groups_owner_all" ON public.groups;
CREATE POLICY "groups_owner_all" ON public.groups
  FOR ALL USING (owner_id = auth.uid())
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('teacher', 'studio')
    )
  );

-- Group members can read groups they belong to
DROP POLICY IF EXISTS "groups_member_select" ON public.groups;
CREATE POLICY "groups_member_select" ON public.groups
  FOR SELECT USING (is_group_member(id, auth.uid()));


-- ────────────────────────────────────────────────────────────
-- 3. GROUP MEMBERS
--    Membership records. A student belongs to a group only if
--    they have a membership row. Teachers can add linked students
--    to their groups. Members can see co-members in their groups.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_members (
  group_id   uuid        NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  student_id uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  added_by   uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, student_id)
);

CREATE INDEX IF NOT EXISTS group_members_student_idx ON public.group_members (student_id);

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

-- Teachers can read and manage members of their own groups
DROP POLICY IF EXISTS "group_members_owner_all" ON public.group_members;
CREATE POLICY "group_members_owner_all" ON public.group_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_members.group_id
        AND g.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_members.group_id
        AND g.owner_id = auth.uid()
    )
    -- On INSERT, verify student is linked to the teacher
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id = group_members.student_id
        AND sl.entity_id = auth.uid()
        AND sl.status = 'active'
        AND sl.consent_given = true
    )
  );

-- Members can see co-members in their own groups (used for roster visibility)
DROP POLICY IF EXISTS "group_members_member_select" ON public.group_members;
CREATE POLICY "group_members_member_select" ON public.group_members
  FOR SELECT USING (is_group_member(group_id, auth.uid()));


-- ────────────────────────────────────────────────────────────
-- 4. GROUP BULLETINS
--    Text messages posted by teachers to a group.
--    Each bulletin is broadcast realtime to all active members'
--    dashboards. In M5, only the teacher (group owner) may post.
--    Member-authored posts are deferred.
--
--    Bulletins are immutable (no UPDATE/DELETE after posting);
--    if a mistake occurs, a new corrective bulletin is posted.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.group_bulletins (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   uuid        NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  author_id  uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  body       text        NOT NULL CHECK (char_length(body) BETWEEN 1 AND 2000),
  kind       text        NOT NULL DEFAULT 'text'
                         CHECK (kind IN ('text', 'schedule', 'material')),
  media_urls text[]      DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS group_bulletins_group_created_idx
  ON public.group_bulletins (group_id, created_at DESC);

ALTER TABLE public.group_bulletins ENABLE ROW LEVEL SECURITY;

-- Members of a group can read bulletins posted to that group
DROP POLICY IF EXISTS "group_bulletins_member_select" ON public.group_bulletins;
CREATE POLICY "group_bulletins_member_select" ON public.group_bulletins
  FOR SELECT USING (is_group_member(group_id, auth.uid()));

-- Teachers can insert bulletins into their own groups
-- (member-authored posts deferred to a future phase)
DROP POLICY IF EXISTS "group_bulletins_teacher_insert" ON public.group_bulletins;
CREATE POLICY "group_bulletins_teacher_insert" ON public.group_bulletins
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.groups g
      WHERE g.id = group_bulletins.group_id
        AND g.owner_id = auth.uid()
    )
    AND author_id = auth.uid()
  );

-- Bulletins are immutable: no UPDATE or DELETE
-- (handled via the absence of UPDATE/DELETE policies)


-- ────────────────────────────────────────────────────────────
-- CRITICAL: Tighten community_feeds visibility (breaking change)
--
-- DECISION (confirmed by user): peer activity hidden until follow accepted.
-- This drops the global "feed_authenticated_select" policy that granted
-- every authenticated user read of the entire feed. Going forward:
--   - Accepted follows: can see peer activity
--   - Linked teachers/studios: can see roster activity (existing policy)
--   - No global visibility
--
-- Run this AFTER the current schema.sql and phases 1–12 are applied,
-- but substitute the community_feeds RLS policies below for the existing ones.
-- ────────────────────────────────────────────────────────────

-- Drop the old global visibility policy
DROP POLICY IF EXISTS "feed_authenticated_select" ON public.community_feeds;

-- Accepted follows: follower can see followee's activity
DROP POLICY IF EXISTS "feed_accepted_follow_select" ON public.community_feeds;
CREATE POLICY "feed_accepted_follow_select" ON public.community_feeds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.follows f
      WHERE f.follower_id = auth.uid()
        AND f.followee_id = community_feeds.user_id
        AND f.status = 'accepted'
    )
  );

-- Linked teachers/studios: can read non-private logs of linked students
-- (this already exists as "logs_linked_select" on practice_logs;
--  community_feeds is a denormalized copy, so grant the same visibility)
DROP POLICY IF EXISTS "feed_linked_teacher_select" ON public.community_feeds;
CREATE POLICY "feed_linked_teacher_select" ON public.community_feeds
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id = community_feeds.user_id
        AND sl.entity_id = auth.uid()
        AND sl.status = 'active'
        AND sl.consent_given = true
    )
  );

-- Keep existing delete policy (users can delete their own feed entries)
-- Drop-then-recreate for idempotency (Postgres has no CREATE POLICY IF NOT EXISTS)
DROP POLICY IF EXISTS "feed_own_delete" ON public.community_feeds;
CREATE POLICY "feed_own_delete" ON public.community_feeds
  FOR DELETE USING (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- 5. FEEDBACK EXTENSIONS
--    The feedback table exists from Phase 1 (schema_phase1_gaps.sql).
--    This migration extends it with direction and target fields,
--    adds character length constraints, and creates INSERT policies
--    for both teacher→student and student→teacher directions.
--
--    session_id was originally NOT NULL (feedback was scoped to a
--    specific practice log). The student→teacher portal (PRD §3.6.2)
--    is general feedback not tied to any one session, so session_id
--    is relaxed to nullable here; a CHECK enforces that
--    teacher_to_student feedback (which comments on a specific log)
--    still requires it.
-- ────────────────────────────────────────────────────────────

-- Relax session_id to nullable for general student→teacher feedback
ALTER TABLE public.feedback
  ALTER COLUMN session_id DROP NOT NULL;

-- Add direction field (teacher_to_student or student_to_teacher)
ALTER TABLE public.feedback
  ADD COLUMN IF NOT EXISTS direction text NOT NULL DEFAULT 'teacher_to_student'
    CHECK (direction IN ('teacher_to_student', 'student_to_teacher'));

-- Add target_entity_id (the recipient of feedback)
ALTER TABLE public.feedback
  ADD COLUMN IF NOT EXISTS target_entity_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Enforce: teacher_to_student feedback must reference a specific session;
-- student_to_teacher feedback must target a specific entity.
-- (Postgres has no ADD CONSTRAINT IF NOT EXISTS — drop-then-add instead.)
ALTER TABLE public.feedback
  DROP CONSTRAINT IF EXISTS feedback_direction_shape;
ALTER TABLE public.feedback
  ADD CONSTRAINT feedback_direction_shape CHECK (
    (direction = 'teacher_to_student' AND session_id IS NOT NULL)
    OR (direction = 'student_to_teacher' AND target_entity_id IS NOT NULL)
  );

-- Add text length constraint (1–2000 chars, enforced at DB level)
ALTER TABLE public.feedback
  DROP CONSTRAINT IF EXISTS feedback_body_len;
ALTER TABLE public.feedback
  ADD CONSTRAINT feedback_body_len CHECK (char_length(body) BETWEEN 1 AND 2000);

-- Teacher→Student: teacher submits feedback on a non-private student log
-- (Enforces the "never comment on private data" rule at the DB level)
DROP POLICY IF EXISTS "feedback_teacher_insert" ON public.feedback;
CREATE POLICY "feedback_teacher_insert" ON public.feedback
  FOR INSERT WITH CHECK (
    -- Author is a teacher/studio
    auth.uid() = author_id
    AND direction = 'teacher_to_student'
    -- The log exists, is not private, and is from a linked student
    AND EXISTS (
      SELECT 1 FROM public.practice_logs pl
      JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
      WHERE pl.id = feedback.session_id
        AND pl.is_private = false
        AND sl.entity_id = auth.uid()
        AND sl.status = 'active'
        AND sl.consent_given = true
    )
  );

-- Student→Teacher: student submits feedback to a linked teacher/studio
DROP POLICY IF EXISTS "feedback_student_insert" ON public.feedback;
CREATE POLICY "feedback_student_insert" ON public.feedback
  FOR INSERT WITH CHECK (
    -- Author is the current user
    auth.uid() = author_id
    AND direction = 'student_to_teacher'
    -- The target is a linked teacher/studio
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id = auth.uid()
        AND sl.entity_id = feedback.target_entity_id
        AND sl.status = 'active'
        AND sl.consent_given = true
    )
  );

-- Replace the existing SELECT policy to include target_entity_id visibility
DROP POLICY IF EXISTS "feedback_session_owner_select" ON public.feedback;
DROP POLICY IF EXISTS "feedback_view" ON public.feedback;
CREATE POLICY "feedback_view" ON public.feedback
  FOR SELECT USING (
    author_id = auth.uid()
    OR target_entity_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.practice_logs pl
      WHERE pl.id = feedback.session_id AND pl.user_id = auth.uid()
    )
  );


-- ────────────────────────────────────────────────────────────
-- 6. PRACTICE_LOGS EXTENSIONS
--    Add a student-controlled feedback routing flag and
--    optional teacher assignment for red-flag routing.
-- ────────────────────────────────────────────────────────────

-- Flag to indicate this log's author has requested feedback routing
ALTER TABLE public.practice_logs
  ADD COLUMN IF NOT EXISTS route_feedback_to uuid REFERENCES public.profiles(id) ON DELETE SET NULL;


-- ────────────────────────────────────────────────────────────
-- 7. HELPER: compute_red_flags(p_teacher_id)
--    Returns a set of (student_id, flag_type, detail) rows
--    for all linked students with active red flags.
--
--    Flag types:
--      'severe_pain' — any non-private log in past 14 days
--                      with Pain or Injured feelings
--      'routed_feedback' — student has set route_feedback_to = p_teacher
--
--    Called by the teacher dashboard to highlight roster rows.
--    SECURITY DEFINER so the teacher can scan their linked
--    students' logs in one call while respecting is_private.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.compute_red_flags(p_teacher_id uuid)
RETURNS TABLE (student_id uuid, flag_type text, detail text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Assert the caller is requesting their own flags
  IF p_teacher_id <> auth.uid() THEN
    RAISE EXCEPTION 'Unauthorized: can only compute red flags for yourself';
  END IF;

  -- Severe Pain: non-private logs in the past 14 days with Pain/Injured feelings
  RETURN QUERY
    SELECT DISTINCT
      pl.user_id,
      'severe_pain'::text AS flag_type,
      'Logged Pain or Injury in the past 14 days'::text AS detail
    FROM public.practice_logs pl
    JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
    WHERE sl.entity_id = p_teacher_id
      AND sl.status = 'active'
      AND sl.consent_given = true
      AND pl.is_private = false
      AND pl.practice_date >= CURRENT_DATE - 13
      AND (
        pl.muscle_feelings @> '[{"feeling":"Pain"}]'::jsonb
        OR pl.muscle_feelings @> '[{"feeling":"Injured"}]'::jsonb
      );

  -- Routed Feedback: student has explicitly routed feedback to this teacher
  RETURN QUERY
    SELECT DISTINCT
      pl.user_id,
      'routed_feedback'::text AS flag_type,
      'Student requested feedback routing'::text AS detail
    FROM public.practice_logs pl
    JOIN public.studio_linkages sl ON sl.student_id = pl.user_id
    WHERE sl.entity_id = p_teacher_id
      AND sl.status = 'active'
      AND sl.consent_given = true
      AND pl.route_feedback_to = p_teacher_id;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- 8. HELPER: body_fatigue_30day(p_user_id)
--    Returns a JSON array of 30-day rolling fatigue counts:
--    [{ date, serious_count }, ...]
--
--    serious_count = number of muscle_feelings with
--    feeling in {Sore, Pain, Injured} on that date.
--
--    Used by the 30-day progress dashboard to plot
--    body map fatigue trend over time. Client-side aggregation
--    of the user's own logs (no privacy concerns).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.body_fatigue_30day(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_result jsonb := '[]'::jsonb;
  r RECORD;
BEGIN
  -- For each of the last 30 days, count serious feelings on that date
  FOR r IN
    SELECT
      pl.practice_date AS date,
      COALESCE(
        SUM(
          CASE WHEN mf->>'feeling' IN ('Sore', 'Pain', 'Injured')
            THEN 1 ELSE 0 END
        ),
        0
      ) AS serious_count
    FROM public.practice_logs pl
    CROSS JOIN LATERAL jsonb_array_elements(pl.muscle_feelings) AS mf
    WHERE pl.user_id = p_user_id
      AND pl.practice_date >= CURRENT_DATE - 29
    GROUP BY pl.practice_date
    ORDER BY pl.practice_date ASC
  LOOP
    v_result := v_result || jsonb_build_object(
      'date', r.date,
      'serious_count', r.serious_count
    );
  END LOOP;

  RETURN v_result;
END;
$$;
