-- ============================================================
-- LUMEN — Phase 8 Repair Migration
-- Run this in Supabase Dashboard → SQL Editor, after
-- schema_phase7_feed_likes.sql.
--
-- BUG: feed like counts reset to 0 (or -1) after page refresh.
--
-- ROOT CAUSE: sync_feed_like_count() was created WITHOUT
-- SECURITY DEFINER, so its UPDATE on community_feeds runs as the
-- liking user. community_feeds has no UPDATE RLS policy (only
-- SELECT and own-DELETE), so the UPDATE is silently filtered to
-- zero rows for every user — the feed_likes row is written (the
-- ❤️ state persists) but like_count never changes in the DB.
-- On reload the client reads the stale like_count of 0; unliking
-- then renders -1.
--
-- FIX: recreate the trigger function as SECURITY DEFINER (it runs
-- as the function owner, bypassing RLS for the count column sync),
-- then backfill like_count from the actual feed_likes rows.
--
-- Idempotent — safe to re-run.
-- ============================================================


-- ────────────────────────────────────────────────────────────
-- 1. RECREATE TRIGGER FUNCTION AS SECURITY DEFINER
--    (CREATE OR REPLACE keeps the existing trigger binding —
--    feed_likes_count_sync does not need to be recreated.)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.sync_feed_like_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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


-- ────────────────────────────────────────────────────────────
-- 2. BACKFILL — repair counts drifted while the trigger was
--    silently failing.
-- ────────────────────────────────────────────────────────────
UPDATE public.community_feeds cf
SET like_count = (
  SELECT count(*)
  FROM public.feed_likes fl
  WHERE fl.feed_id = cf.id
);


-- ────────────────────────────────────────────────────────────
-- 3. VERIFY (optional) — both columns should match per row.
-- ────────────────────────────────────────────────────────────
-- SELECT cf.id, cf.like_count,
--        (SELECT count(*) FROM public.feed_likes fl WHERE fl.feed_id = cf.id) AS actual
-- FROM public.community_feeds cf
-- ORDER BY cf.created_at DESC;
