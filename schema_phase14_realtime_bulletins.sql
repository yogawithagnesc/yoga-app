-- ============================================================
-- LUMEN — Phase 14 — Enable Realtime for group_bulletins
-- Run this in Supabase Dashboard → SQL Editor (after phase 13)
--
-- Root cause of "My Groups: live realtime updates failed":
-- index.html subscribes to postgres_changes INSERT events on
-- group_bulletins (tools/community's flash-in animation), but a
-- newly created table is NOT automatically part of Supabase's
-- `supabase_realtime` publication — that has to be granted
-- explicitly per table (via SQL or Database → Replication in the
-- dashboard). Unlike `classes`/`community_feeds`, which already
-- had this toggled on from earlier milestones, `group_bulletins`
-- never got it, so postgres_changes events for it were silently
-- never sent to any subscriber — the initial bulletin *list*
-- loads fine (a normal SELECT), but a bulletin posted afterward
-- never live-pushes to already-open member dashboards.
--
-- Idempotent: safe to re-run (skips if already a publication member).
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'group_bulletins'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.group_bulletins;
  END IF;
END $$;

-- Optional but recommended: also cover the other M5 tables that could
-- plausibly grow a realtime consumer later (follows request/accept
-- badges, group membership changes). Cheap to enable now; not currently
-- required by any shipped M5 UI, but avoids a repeat of this exact bug
-- if a future milestone adds a live subscription without remembering
-- this step.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'follows'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.follows;
  END IF;
END $$;
