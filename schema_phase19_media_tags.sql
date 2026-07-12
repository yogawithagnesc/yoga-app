-- ============================================================
-- LUMEN — Phase 19 — Session Media Tags (M6b Practice Gallery)
-- Run this in Supabase Dashboard → SQL Editor (after phase 18)
--
-- Adds free-form, per-file tags to uploaded practice media so the
-- Home "Practice Gallery" can filter a practitioner's own photos/
-- videos by tag (alongside date, media type, and practice type).
-- ============================================================

-- 1. Per-file tag array (defaults to empty; legacy rows read as untagged)
ALTER TABLE public.session_media
  ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';

-- 2. GIN index for fast array containment/overlap filtering.
--    (Client-side filtering is used at beta scale; this future-proofs
--    a server-side move without a further migration.)
CREATE INDEX IF NOT EXISTS session_media_tags_gin
  ON public.session_media USING gin (tags);

-- No RLS change: session_media_own_all already scopes rows to the
-- owner, and the Practice Gallery reads only the caller's own media.

-- Idempotent: safe to re-run.
