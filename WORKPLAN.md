# LUMEN — Workplan (PRD v2.0 Ecosystem Expansion)

**Status:** Living document · Owner: AgnesC · Updated: 2026-07-10
**Companion to:** `Lumen_PRD.md` v2.0

This workplan sequences all remaining work to fulfill PRD v2.0. Milestones are ordered by dependency; each lists scope, key tables/files, acceptance criteria, and the recommended Claude model for the implementation session (cost-effectiveness rationale at the bottom).

---

## Milestone Overview

| # | Milestone | PRD Sections | Status | Model |
|---|-----------|--------------|--------|-------|
| M0 | Feed-likes fix + housekeeping | §3.6 (feed) | ✅ This session | Haiku 4.5 |
| M1 | Finish P1 verification | §3.1–3.4 | Pending | Haiku 4.5 |
| M2 | Dynamic categorization engine | §3.2.1–3.2.2 | Not started | Sonnet 5 |
| M3 | SVG Body Map + 14-day rest engine | §3.2.3 | Not started | Sonnet 5 |
| M4 | Class scheduling & booking framework | §3.5, §8 | Not started | Sonnet 5 (+ Opus 4.8 design pass) |
| M5 | Cross-role community architecture | §3.6 | Not started | Sonnet 5 (+ Opus 4.8 RLS review) |
| M6 | Security, profiles & studio operations | §3.7 | Not started | Sonnet 5 |
| M7 | On-demand video catalog | P4 | Not started | Haiku 4.5 / Sonnet 5 |
| M8 | Polish: theme, localization, OAuth | §2, §6 | Not started | Haiku 4.5 (+ Sonnet 5 for OAuth) |

---

## M0 — Feed-Likes Fix + Housekeeping ✅ (this session)

**Problem:** Unlike appeared broken; like counts reset to 0/−1 after refresh (P2 blocker).

**Root cause:** `sync_feed_like_count()` lacked `SECURITY DEFINER`, and `community_feeds` has no UPDATE RLS policy, so the trigger's count update was silently filtered to zero rows for every user.

**Delivered:**
- `schema_phase8_fix_like_count.sql` — recreates the trigger function as `SECURITY DEFINER` and backfills `like_count` from actual `feed_likes` rows. **Action required: run in Supabase SQL Editor.**
- `Lumen_PRD.md` rewritten to v2.0; this `WORKPLAN.md` created.

**Acceptance:** like → refresh → count persists; unlike → refresh → count decrements correctly, never −1; counts visible across users.

---

## M1 — Finish P1 Verification

Close out the remaining P1 checklist items. Mostly manual QA plus small fixes.

**Scope:**
- Studio role: register/select → dashboard pass (verify `teacher.html` works for `role = 'studio'`).
- Join code redemption, student side (`profile.html` → `redeem_join_code` RPC): live test end-to-end including consent checkbox and connection display.
- Password reset flow: configure the redirect URL in Supabase Auth settings (`reset-password.html`), then live test the full email → reset loop.
- Custom categories, dual-perspective toggle, Body Status widget: live verification passes.

**Key files:** `profile.html`, `teacher.html`, `reset-password.html`, `login.html`, `index.html`.

**Acceptance:** every unchecked P1 item in PRD §4 checklist verified live on yoga-app-ten.vercel.app.

---

## M2 — Dynamic Categorization Engine (PRD §3.2.1–3.2.2)

**Scope:**
- Seed exactly two default categories (Yoga, Fitness) per profile on account creation (extend `handle_new_user` trigger or a seeding function).
- Inline rename of categories; `+ Add Category` UI.
- Drag-and-drop practice-type chips between category containers on the Log Practice page — vanilla JS `dragstart`/`drop` plus touch-event fallback for mobile (no library; keep the single-file page pattern).
- `+ Add New Practice Type` inside any category box.
- Persist the category↔type mapping: extend `practice_categories` with a parent/group linkage (linking table or JSONB layout column) with realtime save on drop.
- Global `focus_areas` dictionary (already seeded — 15 chips exist in `schema_phase1_gaps.sql`); add custom focus creation for all roles.
- Ecosystem promotion: teacher/studio custom focuses surface as "Recommended Focus" badges for join-code-linked students.

**Builds on:** `practice_categories` + `focus_areas` tables, `buildTypes()`/`submitCustomCategory()` in `lumen-log-practice-3d.html`, linked-category visibility already implemented in `teacher.html`.

**Acceptance:** new account sees Yoga + Fitness; chips drag between containers on desktop and mobile and persist across reload; teacher's custom focus appears as a recommended badge on a linked student's log screen.

---

## M3 — SVG Body Map + 14-Day Rest Engine (PRD §3.2.3)

**Decision made:** SVG-primary (the existing 2D fallback is promoted; the 16MB GLTF 3D model is retired from the default path — optionally kept behind a toggle).

**Scope:**
- Upgrade `buildSVGFallback()`/`svgTap()` in `lumen-log-practice-3d.html` into the primary interface: front/back anatomical views, richer muscle paths (Quadriceps, Hamstrings, Lower Back, Shoulders, Triceps, etc.).
- Tap → context popover: mark Sore (amber) or Pain (red); multi-select supported; states color the SVG paths live.
- 14-day rolling analytics: extend `loadBodyStatus()`/`computeBodyStatus()` in `index.html` to count practice types over `[today − 14d]`.
- Rest Suggestion Card: any muscle flagged Sore/Pain ≥ 3 times in 14 days surfaces a prioritized restoration card ("…Consider a Yin or Mindfulness focus today.").

**Acceptance:** log screen loads instantly with no 16MB download; marking 3+ sore states on a muscle across 14 days produces the rest card on the dashboard.

---

## M4 — Class Scheduling & Booking Framework (PRD §3.5 + §8)

The largest milestone. The `classes` and `bookings` tables plus capacity trigger already exist in `schema.sql` — this is primarily frontend plus a few schema additions.

**Scope (suggested split into two sessions):**

*Session A — provisioning + federated view:*
- Studio/teacher schedule ingestion form (§8.1): date, description, teacher assignment, room, capacity, prerequisites (new columns: `room`, `prerequisites`, `is_featured` on `classes`).
- Teacher multi-studio binding: teachers redeem studio join codes in `profile.html` (reuse `redeem_join_code`).
- Federated student calendar: Classes tab merges published classes from all linked studios, 14-day forward horizon, studio-branded cards (name + color-coded border).
- Role-adaptive header: student sees today's bookings; teacher sees today's teaching schedule.
- Booking modal with the Book button disabled and tagged `[Next Stage Development — Gated Booking Engine]`.
- Featured/promo classes render in a hero banner atop linked students' feeds.

*Session B — filters + DnD mutator:*
- Filter overlay: date / class type / teacher name; "star" a filter setup to save it as a quick-access chip (new `saved_filters` table or JSONB on profiles).
- §8.2 drag-and-drop weekly/monthly calendar grid for studio managers: drag a class block to another cell → async `UPDATE` of `start_time`/`teacher_id`/`room` → linked views refresh via Supabase Realtime.

**Model note:** run an Opus 4.8 (or stronger) planning pass first for the DnD calendar architecture and the federated query/RLS design, then implement with Sonnet 5.

**Acceptance:** studio creates a class; linked student sees it within the 14-day window with studio branding; dragging the class to a new slot updates every viewer without reload.

---

## M5 — Cross-Role Community Architecture (PRD §3.6)

**Scope:**
- Linked Students Portfolio for teachers: roster table querying shared practice logs of joined students (respecting `is_private`).
- Red Flag Alerts: severe Pain body-status flags, or a student-set "route feedback to teacher" flag, highlight the roster row.
- Sub-communities: `+ Create Group` → private groups (`groups`, `group_members` tables) with text bulletins, reference-material uploads, schedule alerts; "Send" fires a Supabase Realtime broadcast to members' dashboards.
- Bidirectional follow approval: peer feed visibility requires accepted follow invitations (`follows` table with pending/accepted states).
- Feedback portal: students send reviews to linked teachers/studios (the `feedback` table from `schema_phase1_gaps.sql` exists but needs an INSERT policy and UI); character check + respectful-tone placeholder.
- 30-day holistic progress dashboard: body-map fatigue trend vs mood scores over a rolling 30 days.

**Model note:** have Opus 4.8 review the RLS/privacy model before shipping — this milestone crosses the most trust boundaries.

**Acceptance:** teacher sees red flag when a linked student logs severe pain; group broadcast arrives on member dashboards in realtime; peer activity hidden until follow accepted.

---

## M6 — Security, Profiles & Studio Operations (PRD §3.7)

**Scope:**
- Per-log privacy toggle in the practice history ledger (`is_private` already exists — add the per-row toggle UI and re-broadcast handling, which `broadcast_public_log` already supports).
- Join-code descriptive lookup: connections list shows real Studio/Teacher names, not code strings (mostly done in `profile.html` — verify + polish).
- Unique global usernames: `username` column with DB-level UNIQUE constraint + debounced availability check while typing.
- Peer invitations by exact username → notification queue for approval (pairs with M5 `follows`).
- Studio aggregate-only dashboard: join-code follower totals and class stats; individual raw logs are structurally excluded (RLS-enforced, not just UI).
- Motivational quote header; central feedback pipeline view.
- Date-range attendance analyzer: range picker → check-in tallies bucketed into Popular / Unpopular / High-Potential class tiers.
- Studio brand channel: broadcast updates to all linked users' home screens.
- Directory tabs: Contracted Teachers vs Linked Students.
- Multi-branch hierarchy: sub-branches each with an independent join code; per-branch stats aggregated under the main studio profile.

**Acceptance:** duplicate username rejected in realtime; studio dashboard shows only aggregates; branch codes track separately and roll up.

---

## M7 — On-Demand Video Catalog (P4)

**Scope:**
- `videos` table (title, Mux playback ID, duration, thumbnail, teacher/studio owner, published flag) replacing the hardcoded single-entry `VIDEO_CATALOG` in `index.html` (~line 859).
- Upload/registration workflow for teachers/studios (Mux asset creation is manual in the Mux dashboard for beta; the app stores playback IDs).
- Catalog UI on the Classes tab; `video_progress` resume already works via `MuxVideoPlayer.js`.

**Acceptance:** multiple videos listed from the DB; continue-watching works across them.

---

## M8 — Polish: Theme, Localization, OAuth

**Decision made:** dark + gold is the app-wide standard.

**Scope:**
- Theme unification: apply the dark+gold token set (`#C8A96E` accent family, `#080807`/`#111110` surfaces) to `index.html`'s home screen and any warm-variant remnants; extract a shared token block (copied consistently into each single-file page, or a small shared CSS file).
- Chinese/Cantonese localization: extend the `STRINGS` pattern in `index.html` to all pages, add a language switcher, provide zh-TC translations (Noto Serif/Sans TC already specified).
- Enable Google/Apple OAuth: re-enable the disabled buttons in `login.html`, configure providers in Supabase Auth, verify the `handle_new_user` OAuth metadata path (`schema_phase4_oauth_display_name.sql`) end-to-end. Apple requires an Apple Developer account ($99/yr) — confirm before scheduling.

**Acceptance:** all pages visually consistent in dark+gold; full zh-TC UI switch; OAuth sign-up lands on role-select correctly.

---

## Model Recommendations & Cost Rationale

The codebase is deliberately simple — single-file vanilla JS pages, direct Supabase calls, no build step. That keeps per-milestone model needs modest:

- **Haiku 4.5** — cheapest; ideal for mechanical work: QA passes, small bug fixes (like M0), theme token sweeps, string-table localization, boilerplate catalog CRUD. Roughly 1/3 the cost of Sonnet.
- **Sonnet 5** — the default for feature milestones (M2–M7). Best cost/capability balance for multi-file feature work, new schema + RLS + UI in one pass.
- **Opus 4.8** — reserve for short, high-leverage design/review passes only: the M4 DnD calendar + federated query architecture, and the M5 privacy/RLS review. Using it as a planning pass (with Sonnet implementing) captures most of the value at a fraction of the cost.

No milestone requires more than this mix. General pattern: **plan with the strongest model when the design crosses trust boundaries or realtime state; implement with Sonnet; sweep with Haiku.**

---

## Dependency Notes

- M2 and M3 are independent of each other; both extend the Log Practice page — coordinate to avoid merge conflicts.
- M5 follow/invite tables are shared with M6 peer invitations — build the `follows` schema once in whichever ships first.
- M4 Session B's saved filters and M6's studio analytics both read `bookings`; no ordering constraint.
- M8 (theme) touches every page — schedule last to avoid repeated restyling of pages still under construction.
