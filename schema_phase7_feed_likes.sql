-- ============================================================
-- LUMEN — Phase 7 Gap-Fill Migration
-- Run this in Supabase Dashboard → SQL Editor, after the earlier
-- schema files.
--
-- Community feed "likes" were local-only (index.html STATE.likes) —
-- refreshing the page lost every like and no one else ever saw a
-- count. This adds a feed_likes join table plus a like_count column
-- on community_feeds kept in sync by trigger, so likes persist and
-- are shared across users.
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. LIKE COUNT COLUMN
-- ────────────────────────────────────────────────────────────
ALTER TABLE public.community_feeds
  ADD COLUMN IF NOT EXISTS like_count integer NOT NULL DEFAULT 0;


-- ────────────────────────────────────────────────────────────
-- 2. FEED LIKES
--    One row per (feed item, user) — the PK doubles as the
--    "did I already like this" guard.
-- ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.feed_likes (
  feed_id    uuid        NOT NULL REFERENCES public.community_feeds(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES public.profiles(id)        ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (feed_id, user_id)
);

CREATE INDEX IF NOT EXISTS feed_likes_feed_id_idx ON public.feed_likes (feed_id);

ALTER TABLE public.feed_likes ENABLE ROW LEVEL SECURITY;

-- Every authenticated user can see who liked what (needed to render
-- "already liked" state and counts client-side if not using like_count)
DROP POLICY IF EXISTS "feed_likes_authenticated_select" ON public.feed_likes;
CREATE POLICY "feed_likes_authenticated_select" ON public.feed_likes
  FOR SELECT USING (auth.role() = 'authenticated');

-- Users can only like/unlike as themselves
DROP POLICY IF EXISTS "feed_likes_own_insert" ON public.feed_likes;
CREATE POLICY "feed_likes_own_insert" ON public.feed_likes
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "feed_likes_own_delete" ON public.feed_likes;
CREATE POLICY "feed_likes_own_delete" ON public.feed_likes
  FOR DELETE USING (user_id = auth.uid());


-- ────────────────────────────────────────────────────────────
-- 3. KEEP community_feeds.like_count IN SYNC
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_feed_like_count()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.community_feeds
      SET like_count = like_count + 1
      WHERE id = NEW.feed_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.community_feeds
      SET like_count = GREATEST(like_count - 1, 0)
      WHERE id = OLD.feed_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS feed_likes_count_sync ON public.feed_likes;
CREATE TRIGGER feed_likes_count_sync
  AFTER INSERT OR DELETE ON public.feed_likes
  FOR EACH ROW EXECUTE FUNCTION public.sync_feed_like_count();
