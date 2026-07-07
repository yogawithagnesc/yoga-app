-- ============================================================
-- LUMEN — Database Schema Migration v1.0
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. PROFILES
--    One row per auth user. Created automatically by trigger.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.profiles (
  id                    uuid        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email                 text        NOT NULL,
  display_name          text,
  role                  text        CHECK (role IN ('student', 'teacher', 'studio')),

  -- Global stats (all activity types)
  global_total_minutes  integer     NOT NULL DEFAULT 0,
  global_total_sessions integer     NOT NULL DEFAULT 0,
  global_streak_count   integer     NOT NULL DEFAULT 0,

  -- Yoga-only stats
  yoga_total_minutes    integer     NOT NULL DEFAULT 0,
  yoga_total_sessions   integer     NOT NULL DEFAULT 0,
  yoga_streak_count     integer     NOT NULL DEFAULT 0,

  -- Streak continuity helpers (stored as user-local date)
  last_activity_date    date,
  last_yoga_date        date,

  -- Unique join code; auto-generated for teacher/studio roles by trigger
  join_code             text        UNIQUE,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);


-- ────────────────────────────────────────────────────────────
-- 2. PRACTICE CATEGORIES
--    System defaults live here alongside user/teacher customs.
--    visibility:
--      'system'  → visible to all authenticated users
--      'private' → visible only to creator (student custom)
--      'linked'  → visible to creator + linked students
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.practice_categories (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text        NOT NULL,
  category_type text        NOT NULL,   -- 'yoga' | 'movement' | 'breathwork'
  icon          text,
  is_system     boolean     NOT NULL DEFAULT false,
  created_by    uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  visibility    text        NOT NULL DEFAULT 'private'
                            CHECK (visibility IN ('system', 'private', 'linked')),
  is_active     boolean     NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);


-- ────────────────────────────────────────────────────────────
-- 3. PRACTICE LOGS
--    One row per logged session. muscle_feelings is a JSONB
--    array of { zone: string, feeling: string } objects.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.practice_logs (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category_id      uuid        REFERENCES public.practice_categories(id),
  style_name       text        NOT NULL,
  is_custom        boolean     NOT NULL DEFAULT false,
  duration_minutes integer     NOT NULL CHECK (duration_minutes > 0),
  practice_date    date        NOT NULL DEFAULT CURRENT_DATE,
  start_time       time,
  mood             text,
  notes            text,
  intensity        integer     CHECK (intensity BETWEEN 1 AND 5),
  muscle_feelings  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  is_private       boolean     NOT NULL DEFAULT true,
  media_urls       text[]      DEFAULT '{}',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);


-- ────────────────────────────────────────────────────────────
-- 4. STUDIO LINKAGES
--    Consent-driven student ↔ teacher/studio connections.
--    A student enters a join code; both sides must agree.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.studio_linkages (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id     uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entity_id      uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  entity_type    text        NOT NULL CHECK (entity_type IN ('teacher', 'studio')),
  join_code_used text        NOT NULL,
  consent_given  boolean     NOT NULL DEFAULT false,
  status         text        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active', 'revoked')),
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE(student_id, entity_id)
);


-- ============================================================
-- TRIGGERS
-- ============================================================

-- ── Auto-create a profiles row when a new auth.users row appears ──
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
    NEW.raw_user_meta_data->>'display_name'
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── Auto-generate a join code when role is set to teacher/studio ──
CREATE OR REPLACE FUNCTION public.generate_join_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.role IN ('teacher', 'studio') AND NEW.join_code IS NULL THEN
    NEW.join_code :=
      upper(substring(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER set_join_code
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.generate_join_code();


-- ── Keep updated_at current on profiles and practice_logs ──
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER practice_logs_updated_at
  BEFORE UPDATE ON public.practice_logs
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- ── profiles ─────────────────────────────────────────────────
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read and update only their own row
CREATE POLICY "profiles_own_select" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_own_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Teachers/studios can read basic info for students they are linked to
CREATE POLICY "profiles_linked_select" ON public.profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id  = profiles.id
        AND sl.entity_id   = auth.uid()
        AND sl.status      = 'active'
        AND sl.consent_given = true
    )
  );


-- ── practice_categories ──────────────────────────────────────
ALTER TABLE public.practice_categories ENABLE ROW LEVEL SECURITY;

-- System categories are readable by all authenticated users
CREATE POLICY "categories_system_select" ON public.practice_categories
  FOR SELECT USING (is_system = true AND is_active = true);

-- Creators have full CRUD over their own categories
CREATE POLICY "categories_own_all" ON public.practice_categories
  FOR ALL USING (created_by = auth.uid());

-- Students can read 'linked' categories from teachers/studios they follow
CREATE POLICY "categories_linked_select" ON public.practice_categories
  FOR SELECT USING (
    visibility = 'linked'
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id = auth.uid()
        AND sl.entity_id  = practice_categories.created_by
        AND sl.status     = 'active'
        AND sl.consent_given = true
    )
  );


-- ── practice_logs ────────────────────────────────────────────
ALTER TABLE public.practice_logs ENABLE ROW LEVEL SECURITY;

-- Users have full CRUD over their own logs
CREATE POLICY "logs_own_all" ON public.practice_logs
  FOR ALL USING (user_id = auth.uid());

-- Teachers/studios can read non-private logs of students they are linked to.
-- is_private = true logs are completely invisible regardless of linkage.
CREATE POLICY "logs_linked_select" ON public.practice_logs
  FOR SELECT USING (
    is_private = false
    AND EXISTS (
      SELECT 1 FROM public.studio_linkages sl
      WHERE sl.student_id  = practice_logs.user_id
        AND sl.entity_id   = auth.uid()
        AND sl.status      = 'active'
        AND sl.consent_given = true
    )
  );


-- ── studio_linkages ──────────────────────────────────────────
ALTER TABLE public.studio_linkages ENABLE ROW LEVEL SECURITY;

-- Students control their own linkages (create, read, revoke)
CREATE POLICY "linkages_student_all" ON public.studio_linkages
  FOR ALL USING (student_id = auth.uid());

-- Teachers/studios can read the linkages directed at them
CREATE POLICY "linkages_entity_select" ON public.studio_linkages
  FOR SELECT USING (entity_id = auth.uid());


-- ============================================================
-- SEED DATA — System practice categories
-- ============================================================
INSERT INTO public.practice_categories
  (name, category_type, icon, is_system, created_by, visibility)
VALUES
  ('Vinyasa',     'yoga',       '🌊', true, NULL, 'system'),
  ('Hatha',       'yoga',       '☀️',  true, NULL, 'system'),
  ('Yin',         'yoga',       '🌿', true, NULL, 'system'),
  ('Yang',        'yoga',       '⚡', true, NULL, 'system'),
  ('Ashtanga',    'yoga',       '🔥', true, NULL, 'system'),
  ('Restorative', 'yoga',       '🌙', true, NULL, 'system'),
  ('Pilates',     'movement',   '💎', true, NULL, 'system'),
  ('Strength',    'movement',   '💪', true, NULL, 'system'),
  ('Mobility',    'movement',   '🔄', true, NULL, 'system'),
  ('Pranayama',   'breathwork', '🌬️', true, NULL, 'system'),
  ('Meditation',  'breathwork', '✨', true, NULL, 'system');


-- ============================================================
-- PHASE 2 — Streak Engine & Profile Stats Triggers
-- Append this block after Phase 1 tables are created.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- sync_profile_stats(p_user_id)
--
-- Recomputes all 6 profile counters from scratch:
--   global_total_minutes / sessions / streak_count
--   yoga_total_minutes   / sessions / streak_count
--
-- Called by the AFTER INSERT/UPDATE/DELETE trigger below.
-- From-scratch calculation is always authoritative and handles
-- retroactive edits/deletes without drift.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_profile_stats(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_global_minutes  integer := 0;
  v_global_sessions integer := 0;
  v_yoga_minutes    integer := 0;
  v_yoga_sessions   integer := 0;
  v_global_streak   integer := 0;
  v_yoga_streak     integer := 0;
  v_prev_global     date;
  v_prev_yoga       date;
  v_global_done     boolean := false;
  v_yoga_done       boolean := false;
  r                 RECORD;
BEGIN
  -- ── Recompute lifetime totals ──────────────────────────
  SELECT
    COALESCE(SUM(pl.duration_minutes), 0),
    COUNT(*),
    COALESCE(SUM(CASE WHEN pc.category_type = 'yoga' THEN pl.duration_minutes ELSE 0 END), 0),
    COUNT(CASE WHEN pc.category_type = 'yoga' THEN 1 END)
  INTO
    v_global_minutes,
    v_global_sessions,
    v_yoga_minutes,
    v_yoga_sessions
  FROM public.practice_logs pl
  LEFT JOIN public.practice_categories pc ON pc.id = pl.category_id
  WHERE pl.user_id = p_user_id;

  -- ── Streak recalculation ───────────────────────────────
  -- Walk distinct practice dates DESC.
  -- Global streak counts every day with any log.
  -- Yoga streak counts consecutive days that had ≥1 yoga log;
  -- a non-yoga calendar day breaks the yoga streak.
  FOR r IN
    SELECT
      pl.practice_date,
      bool_or(pc.category_type = 'yoga') AS has_yoga
    FROM public.practice_logs pl
    LEFT JOIN public.practice_categories pc ON pc.id = pl.category_id
    WHERE pl.user_id = p_user_id
    GROUP BY pl.practice_date
    ORDER BY pl.practice_date DESC
  LOOP
    -- Global streak
    IF NOT v_global_done THEN
      IF v_prev_global IS NULL THEN
        -- Streak is live only if most recent log is today or yesterday
        IF r.practice_date >= CURRENT_DATE - 1 THEN
          v_global_streak := 1;
          v_prev_global   := r.practice_date;
        ELSE
          v_global_done := true;   -- stale; streak stays 0
        END IF;
      ELSIF v_prev_global - r.practice_date = 1 THEN
        v_global_streak := v_global_streak + 1;
        v_prev_global   := r.practice_date;
      ELSE
        v_global_done := true;     -- gap ≥2 days
      END IF;
    END IF;

    -- Yoga streak
    IF NOT v_yoga_done THEN
      IF r.has_yoga THEN
        IF v_prev_yoga IS NULL THEN
          IF r.practice_date >= CURRENT_DATE - 1 THEN
            v_yoga_streak := 1;
            v_prev_yoga   := r.practice_date;
          ELSE
            v_yoga_done := true;
          END IF;
        ELSIF v_prev_yoga - r.practice_date = 1 THEN
          v_yoga_streak := v_yoga_streak + 1;
          v_prev_yoga   := r.practice_date;
        ELSE
          v_yoga_done := true;
        END IF;
      ELSE
        -- Non-yoga day after streak has begun breaks it
        IF v_prev_yoga IS NOT NULL THEN
          v_yoga_done := true;
        END IF;
        -- Before yoga streak starts: keep scanning backward
      END IF;
    END IF;

    EXIT WHEN v_global_done AND v_yoga_done;
  END LOOP;

  -- ── Write results ──────────────────────────────────────
  UPDATE public.profiles SET
    global_total_minutes  = v_global_minutes,
    global_total_sessions = v_global_sessions,
    yoga_total_minutes    = v_yoga_minutes,
    yoga_total_sessions   = v_yoga_sessions,
    global_streak_count   = v_global_streak,
    yoga_streak_count     = v_yoga_streak,
    updated_at            = now()
  WHERE id = p_user_id;
END;
$$;


-- ────────────────────────────────────────────────────────────
-- on_practice_log_change()
-- Single dispatcher for INSERT / UPDATE / DELETE on practice_logs.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.on_practice_log_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  PERFORM public.sync_profile_stats(
    CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END
  );
  RETURN NULL;   -- AFTER trigger; return value is ignored for row-level
END;
$$;

CREATE TRIGGER practice_log_stats_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.practice_logs
  FOR EACH ROW EXECUTE FUNCTION public.on_practice_log_change();


-- ============================================================
-- PHASE 3 — Community Feed & Join-Code Linkage Hardening
-- Append after Phase 2 block.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 5. COMMUNITY FEEDS
--    One row per public practice log. Populated automatically
--    by broadcast_public_log() trigger; never inserted by the
--    client directly.
--    Deleted automatically when the source practice_log is
--    deleted (ON DELETE CASCADE on practice_log_id).
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.community_feeds (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  practice_log_id  uuid        REFERENCES public.practice_logs(id)    ON DELETE CASCADE,
  display_name     text,           -- denormalized from profiles at insert time
  action_text      text        NOT NULL,
  style_name       text,
  duration_minutes integer,
  mood             text,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Index for the dashboard query (newest first)
CREATE INDEX community_feeds_created_at_idx ON public.community_feeds (created_at DESC);

ALTER TABLE public.community_feeds ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read the community feed
CREATE POLICY "feed_authenticated_select" ON public.community_feeds
  FOR SELECT USING (auth.role() = 'authenticated');

-- Users can delete their own feed entries (e.g. if they later make a log private)
-- Cascade on practice_log_id also handles this automatically on log delete.
CREATE POLICY "feed_own_delete" ON public.community_feeds
  FOR DELETE USING (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- broadcast_public_log()
-- Fires AFTER INSERT or UPDATE on practice_logs.
-- INSERT  → if is_private = false, publish to community_feeds
-- UPDATE  → if privacy toggled off,  remove from feed
--           if privacy toggled on,   add to feed
-- DELETE  → handled automatically by ON DELETE CASCADE
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.broadcast_public_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_display_name text;
BEGIN
  -- Resolve display_name once
  SELECT display_name INTO v_display_name
  FROM public.profiles
  WHERE id = CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;

  IF TG_OP = 'INSERT' THEN
    IF NEW.is_private = false THEN
      INSERT INTO public.community_feeds
        (user_id, practice_log_id, display_name, action_text, style_name, duration_minutes, mood)
      VALUES (
        NEW.user_id,
        NEW.id,
        v_display_name,
        'Completed ' || NEW.style_name || ' · ' || NEW.duration_minutes || ' min',
        NEW.style_name,
        NEW.duration_minutes,
        NEW.mood
      );
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.is_private = false AND NEW.is_private = true THEN
      -- Made private → remove from feed
      DELETE FROM public.community_feeds WHERE practice_log_id = NEW.id;

    ELSIF OLD.is_private = true AND NEW.is_private = false THEN
      -- Made public → publish to feed
      INSERT INTO public.community_feeds
        (user_id, practice_log_id, display_name, action_text, style_name, duration_minutes, mood)
      VALUES (
        NEW.user_id,
        NEW.id,
        v_display_name,
        'Completed ' || NEW.style_name || ' · ' || NEW.duration_minutes || ' min',
        NEW.style_name,
        NEW.duration_minutes,
        NEW.mood
      )
      ON CONFLICT (practice_log_id) DO NOTHING;
    END IF;
  END IF;

  RETURN NULL;
END;
$$;

CREATE TRIGGER broadcast_log_to_feed
  AFTER INSERT OR UPDATE ON public.practice_logs
  FOR EACH ROW EXECUTE FUNCTION public.broadcast_public_log();


-- ────────────────────────────────────────────────────────────
-- RLS HARDENING
-- ────────────────────────────────────────────────────────────

-- Allow any authenticated user to read teacher/studio profiles
-- so that join-code lookup works from the student client.
-- Teachers and studios are "public" entities whose basic info
-- is discoverable; personal student profiles remain private.
CREATE POLICY "profiles_entity_public_select" ON public.profiles
  FOR SELECT USING (
    role IN ('teacher', 'studio')
  );

-- Tighten studio_linkages INSERT: drop the broad FOR ALL policy
-- and replace it with separate per-operation policies so that
-- the INSERT is validated at the DB level against the join code.
DROP POLICY IF EXISTS "linkages_student_all" ON public.studio_linkages;

-- Students can read and manage (update/delete) their own linkages
CREATE POLICY "linkages_student_read_manage" ON public.studio_linkages
  FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "linkages_student_update" ON public.studio_linkages
  FOR UPDATE USING (student_id = auth.uid());

CREATE POLICY "linkages_student_delete" ON public.studio_linkages
  FOR DELETE USING (student_id = auth.uid());

-- Validated INSERT: the submitted join_code_used must match the
-- entity's actual join_code in profiles, and entity_type must
-- match their role. This makes the join code the authoritative
-- gate rather than relying solely on client-side validation.
CREATE POLICY "linkages_student_insert" ON public.studio_linkages
  FOR INSERT WITH CHECK (
    student_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id          = entity_id
        AND p.role        = entity_type
        AND p.join_code   = join_code_used
        AND p.role       IN ('teacher', 'studio')
    )
  );

-- Add UNIQUE constraint on practice_log_id in community_feeds
-- so the ON CONFLICT clause in the UPDATE branch works.
ALTER TABLE public.community_feeds
  ADD CONSTRAINT community_feeds_practice_log_id_key UNIQUE (practice_log_id);


-- ============================================================
-- PHASE 4 — Live Class & Booking
-- Run this block after Phase 3 is applied.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 6. CLASSES
--    One row per class session. Teachers and studios create
--    classes; students discover and book them.
--
--    All timestamps are TIMESTAMPTZ (UTC) so the stored value
--    is timezone-unambiguous. Clients convert to local time for
--    display; the DB never shifts the value.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.classes (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id       uuid        NOT NULL REFERENCES public.profiles(id)           ON DELETE CASCADE,
  category_id      uuid                 REFERENCES public.practice_categories(id) ON DELETE SET NULL,
  title            text        NOT NULL,
  description      text,
  style_name       text        NOT NULL,
  start_time       timestamptz NOT NULL,
  end_time         timestamptz NOT NULL,
  capacity         integer     CHECK (capacity > 0),   -- NULL = unlimited
  location         text,
  is_online        boolean     NOT NULL DEFAULT false,
  meeting_url      text,
  status           text        NOT NULL DEFAULT 'published'
                               CHECK (status IN ('draft', 'published', 'cancelled')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT classes_end_after_start CHECK (end_time > start_time)
);

CREATE INDEX classes_teacher_id_idx ON public.classes (teacher_id);
CREATE INDEX classes_start_time_idx ON public.classes (start_time);
CREATE INDEX classes_status_idx     ON public.classes (status, start_time);

-- Reuse the existing touch_updated_at() from Phase 1
CREATE TRIGGER classes_updated_at
  BEFORE UPDATE ON public.classes
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


-- ────────────────────────────────────────────────────────────
-- 7. BOOKINGS
--    One row per (student, class) pair.
--    Capacity is enforced by the before_booking_capacity trigger.
--    Cancelling a booking sets status = 'cancelled'; the row is
--    kept for audit and the slot is freed for another student.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.bookings (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  class_id     uuid        NOT NULL REFERENCES public.classes(id)  ON DELETE CASCADE,
  status       text        NOT NULL DEFAULT 'confirmed'
                           CHECK (status IN ('confirmed', 'cancelled', 'waitlisted')),
  booked_at    timestamptz NOT NULL DEFAULT now(),
  cancelled_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (student_id, class_id)
);

CREATE INDEX bookings_student_id_idx ON public.bookings (student_id);
CREATE INDEX bookings_class_id_idx   ON public.bookings (class_id);


-- ────────────────────────────────────────────────────────────
-- TRIGGER: capacity gate on bookings
--
-- Fires BEFORE INSERT OR UPDATE. Counts confirmed bookings
-- for the class (excluding the current row on UPDATE) and
-- raises 'class_full' if the class is at capacity.
-- Skipped when status != 'confirmed' (e.g. waitlisted rows).
-- NULL capacity = unlimited; no check performed.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.before_booking_capacity()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_capacity  integer;
  v_confirmed integer;
BEGIN
  IF NEW.status <> 'confirmed' THEN
    RETURN NEW;
  END IF;

  SELECT capacity INTO v_capacity
  FROM public.classes
  WHERE id = NEW.class_id;

  IF v_capacity IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*) INTO v_confirmed
  FROM public.bookings
  WHERE class_id = NEW.class_id
    AND status   = 'confirmed'
    AND id      <> NEW.id;   -- exclude self on UPDATE

  IF v_confirmed >= v_capacity THEN
    RAISE EXCEPTION 'class_full'
      USING DETAIL = 'This class has reached its maximum capacity.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER enforce_booking_capacity
  BEFORE INSERT OR UPDATE ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.before_booking_capacity();


-- ────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY — classes
--
-- SELECT: all authenticated users see published classes;
--         teachers/studios also see their own drafts/cancelled.
-- INSERT: only teachers and studios, and only for their own row.
-- UPDATE/DELETE: only the teacher/studio that owns the class.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

-- Published classes are visible to every authenticated user
CREATE POLICY "classes_published_select" ON public.classes
  FOR SELECT USING (
    auth.role() = 'authenticated'
    AND status = 'published'
  );

-- Teachers/studios can also read their own unpublished/cancelled classes
CREATE POLICY "classes_own_select" ON public.classes
  FOR SELECT USING (teacher_id = auth.uid());

-- Only teachers and studios may create classes, and only under their own id
CREATE POLICY "classes_teacher_insert" ON public.classes
  FOR INSERT WITH CHECK (
    teacher_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id   = auth.uid()
        AND role IN ('teacher', 'studio')
    )
  );

-- Only the owning teacher/studio may update their class
CREATE POLICY "classes_teacher_update" ON public.classes
  FOR UPDATE
  USING     (teacher_id = auth.uid())
  WITH CHECK (teacher_id = auth.uid());

-- Only the owning teacher/studio may delete their class
CREATE POLICY "classes_teacher_delete" ON public.classes
  FOR DELETE USING (teacher_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- ROW LEVEL SECURITY — bookings
--
-- SELECT: students see only their own bookings;
--         teachers/studios see all bookings for classes they own.
-- INSERT: students only; class must be published.
-- UPDATE/DELETE: the student who made the booking.
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Students read their own bookings
CREATE POLICY "bookings_student_select" ON public.bookings
  FOR SELECT USING (student_id = auth.uid());

-- Teachers/studios read their class roster
CREATE POLICY "bookings_teacher_select" ON public.bookings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id         = bookings.class_id
        AND c.teacher_id = auth.uid()
    )
  );

-- Students can book a published class
CREATE POLICY "bookings_student_insert" ON public.bookings
  FOR INSERT WITH CHECK (
    student_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id   = auth.uid()
        AND role = 'student'
    )
    AND EXISTS (
      SELECT 1 FROM public.classes c
      WHERE c.id     = class_id
        AND c.status = 'published'
    )
  );

-- Students can update (e.g. cancel) their own bookings
CREATE POLICY "bookings_student_update" ON public.bookings
  FOR UPDATE
  USING     (student_id = auth.uid())
  WITH CHECK (student_id = auth.uid());

-- Students can delete their own bookings
CREATE POLICY "bookings_student_delete" ON public.bookings
  FOR DELETE USING (student_id = auth.uid());


-- ============================================================
-- PHASE 4b — Video Progress Tracking
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 8. VIDEO_PROGRESS
--    One row per (user, video) pair; upserted on every seek /
--    pause event so the client can resume from where the user
--    left off.
--
--    video_id is text (e.g. a CMS slug or external video ID)
--    rather than a UUID FK — decoupled from any specific videos
--    catalogue so a videos table can be added later without
--    migrating this table.
--
--    current_time and total_duration are stored in whole seconds.
--    updated_at is TIMESTAMPTZ and refreshed automatically by
--    the touch_updated_at() trigger reused from Phase 1.
-- ────────────────────────────────────────────────────────────
CREATE TABLE public.video_progress (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  video_id         text        NOT NULL,
  current_time     integer     NOT NULL DEFAULT 0 CHECK (current_time >= 0),
  total_duration   integer     CHECK (total_duration > 0),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, video_id)
);

CREATE INDEX video_progress_user_id_idx ON public.video_progress (user_id);

CREATE TRIGGER video_progress_updated_at
  BEFORE UPDATE ON public.video_progress
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER TABLE public.video_progress ENABLE ROW LEVEL SECURITY;

-- Users can only read their own progress
CREATE POLICY "video_progress_own_select" ON public.video_progress
  FOR SELECT USING (user_id = auth.uid());

-- Users can insert their own progress rows
CREATE POLICY "video_progress_own_insert" ON public.video_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- Users can update their own progress rows
CREATE POLICY "video_progress_own_update" ON public.video_progress
  FOR UPDATE
  USING     (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Users can delete their own progress rows (e.g. "reset progress")
CREATE POLICY "video_progress_own_delete" ON public.video_progress
  FOR DELETE USING (user_id = auth.uid());
