# LUMEN — Workplan (PRD v2.0 Ecosystem Expansion)

**Status:** Living document · Owner: AgnesC · Updated: 2026-07-10
**Companion to:** `Lumen_PRD.md` v2.0

This workplan sequences all remaining work to fulfill PRD v2.0. Milestones are ordered by dependency; each lists scope, key tables/files, acceptance criteria, and the recommended Claude model for the implementation session (cost-effectiveness rationale at the bottom).

---

## Milestone Overview

| # | Milestone | PRD Sections | Status | Model |
|---|-----------|--------------|--------|-------|
| M0 | Feed-likes fix + housekeeping | §3.6 (feed) | ✅ Done | Haiku 4.5 |
| M1 | Finish P1 verification | §3.1–3.4 | ✅ Done | Haiku 4.5 |
| M2 | Dynamic categorization engine | §3.2.1–3.2.2 | ✅ Done (pending migration run + live test) | Sonnet 5 |
| M3 | SVG Body Map + 14-day rest engine | §3.2.3 | ✅ Done (verified live) | Sonnet 5 |
| M3a | Advanced anatomical illustration redesign | §3.2.3 | ✅ Done | Sonnet 5 |
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

## M0/M1 — Verified Live ✅

Both closed out: password reset required correcting the Supabase **Site URL** (was `localhost:3000`, now the production Vercel URL) and switching **Email Provider** off Custom SMTP back to the Supabase default (Custom SMTP had no host configured, so the recovery link's own send silently 429'd during retries — resolved by waiting out the rate limit and testing with a fresh email). Studio dashboard, join-code redemption, custom categories, dual-perspective toggle and Body Status widget were confirmed already working from the P1 code.

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

## M2 — Dynamic Categorization Engine (PRD §3.2.1–3.2.2) ✅ Implemented

**Delivered:** `schema_phase9_categorization_engine.sql` (new `practice_groups` + `practice_group_items` tables, seed trigger + backfill for existing profiles, `focus_areas` extended with `created_by`/`visibility`) plus a rewrite of the category/focus section of `lumen-log-practice-3d.html` (dynamic group tabs replacing the hardcoded Yoga/Movement/Breathwork tabs, inline rename, `+ Category` add, pointer-events drag-and-drop of practice-type chips between groups, custom focus creation, "Recommended" badges for teacher/studio-promoted focuses) and a new "Shared Focus Areas" card in `teacher.html`.

**Action required:** run `schema_phase9_categorization_engine.sql` in the Supabase SQL Editor, then live-test: new account shows Yoga + Fitness tabs; drag a type between tabs on both desktop and mobile and confirm it persists on reload; rename a category; add a custom category and a custom focus; confirm a teacher's shared focus shows "Recommended" on a linked student's log screen.

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

## M3 — SVG Body Map + 14-Day Rest Engine (PRD §3.2.3) ✅ Done

**Decision made:** SVG-primary (the existing 2D fallback is promoted; the 16MB GLTF 3D model is retired from the default path — optionally kept behind a toggle).

**Delivered:**
- SVG body map with 49 front-view and 42 back-view anatomical zones (front/back toggle, tap-to-highlight interaction, 7-state feeling system: Relax/Feel Good/Sweet Pain/Tight/Sore/Pain/Injured)
- BODY_ZONE_MAP expanded in `index.html` to include all anatomical zones mapping to 6 broad categories (Shoulders, Lower Back, Hamstrings, Hips, Knees, Core)
- `computeRestNeeds()` function counts serious feelings (sore/pain/injured) per muscle in 14 days
- `getRestSuggestion()` recommends Yin/Mindfulness based on affected body areas
- Rest Suggestion Card renders in dashboard body status when 3+ serious feelings detected in any muscle over 14 days
- Perspective toggle support (yoga-only or global view) integrated with rest engine

**Acceptance:** log screen loads instantly; marking 3+ sore/pain/injured states on a muscle across 14 days produces the rest suggestion card on the dashboard with contextual restoration practice recommendations.

**Post-M3 enhancements (verified live):** Body Status scoring updated to the 7-state feeling weights (single Sore/Pain now correctly reads Watch/Fatigued); historic practice log editing via `?edit=<id>` on the log page with Edit links in the dashboard day-log modal.

---

## M3a — Advanced Anatomical Illustration Redesign ✅ Done

Visual-only upgrade of the M3 body map from flat terracotta capsules to a medically-styled anatomical illustration. Zero behavioral change: same 91 zones, `data-z` names, tap/pick flow, and front/back toggle.

**Delivered:**
- **Material:** crimson/burgundy muscle bellies via per-muscle radial gradient (`#muscleGrad`); silver-gray fascia/tendon material (`#fasciaGrad`)
- **Fascia layer** (non-interactive, `pointer-events:none`): thoracolumbar fascia diamond, linea alba + tendinous intersections (six-pack seams), inguinal ligaments, patellar tendons, triceps tendon flats; IT band and Achilles zones re-materialed as tendon (`svgm-t` class) while staying tappable
- **Striation texture:** 67 fiber-line overlays running along each muscle's contraction axis (fanning pec/trap/lat/glute fibers, vertical rectus/erector fibers, spindle-bowed limb fibers)
- **Rim lighting:** shared `#chisel` specular-lighting filter (top-left light) chisels every muscle's contour; hover/picking brightness composes with it
- **Toolkit** checked into `tools/bodymap/` (generators, build scripts, integration splicer, Playwright verification) — regenerate there, never hand-edit the inline SVG

**Verified:** all 91 zones pass multi-point tappability sampling; feeling override/clear restores the correct base material (muscle vs tendon); end-to-end tap → highlight → pick → view-toggle in the real page with stubbed auth; view-toggle render ~38ms (filter cost negligible).

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
