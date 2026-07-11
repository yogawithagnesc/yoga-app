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
| M4 | Class scheduling & booking framework | §3.5, §8 | ✅ Phase A + Phase B done | Sonnet 5 (+ Opus 4.8 design pass) |
| M5 | Cross-role community architecture | §3.6 | 🚧 Schema designed, awaiting feed-gating decision | Sonnet 5 (+ Opus 4.8 RLS review done) |
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

## M3b — Hyper-Detailed Anatomical Illustration + Labeled Full-Screen Viewer ✅ Done

Pushed the M3a vector illustration much further to approach a professional medical-illustration reference the user supplied: finer muscle-head separation, a region-based color palette, joint tendon detail, and a complete header/sub-muscle/leader-line label system — while keeping true photorealism explicitly out of scope (no image-generation tool exists in this environment; the reference images are photographic/3D renders, not something hand-authored SVG can match 1:1).

**Delivered:**
- **Taxonomy expansion:** 91 → 123 tap zones (63 front / 60 back). New muscle-head splits (Deltoid → Anterior/Middle/Posterior, Biceps → Short/Long Head, Pectoralis Major → Sternal/Clavicular Head, Triceps → +Medial Head, Gastrocnemius → Medial/Lateral Head, hamstrings → +Semimembranosus) plus new named muscles (Splenius Capitis, Rhomboid Major, Teres Minor, Pectineus, Gracilis, Adductor Magnus, Peroneus Longus/Brevis, Flexor Hallucis Longus). Source of truth: `tools/bodymap/taxonomy.js`.
- **Region palette:** 6 body-region material gradients replacing the single M3a crimson (Chest emerald, Abs fuchsia, Shoulders coral, Arms yellow, Thighs crimson/salmon, Calves forest/slate), each still dark enough at the rim for striations to read through.
- **Joint tendon bursts:** non-interactive radiating fiber overlay at knees, ankles, elbows, wrists.
- **Full-screen labeled viewer:** new "🔍 View Full Anatomy" modal (`#svg-body-full`) with an expanded canvas, left/right column headers + sub-muscle text + 1px leader lines + target dots, its own Front/Back pill (amber/gold active state) and a "🖐 Tap a muscle to mark" footer hint. The compact in-form widget stays small and unlabeled (not enough width to be legible) but shares the new material/texture upgrade.
- **Shared interaction state:** `svgBodyStates` is one object read/written by both containers; `buildSvg()`/`attachSvgHandlers()`/`svgTap()`/`applyFeeling()` are container-parameterized so a mark made in either view instantly syncs to the other.
- **Legacy compatibility:** `BODY_ZONE_MAP` (`index.html`) updated additively — old zone names (e.g. `Deltoid`, `Biceps`, `Pectoralis Major`) stay mapped alongside the new split names, so historical logs keep contributing correctly to the rest engine. Old logs referencing a retired split-away name still round-trip through the edit flow without data loss; they're just no longer visually re-tappable under the old name (documented, not a bug — a 1:1 migration is inherently ambiguous for a one-to-many split).

**Verified:** all 123 zones pass multi-point tappability sampling (caught and fixed one real overlap: Adductor Magnus fully hidden under Adductors); end-to-end tap → highlight → pick → sync between compact and full-screen containers; legacy log edit with retired zone names causes no crash and preserves data; view-toggle render times stayed smooth (compact ~16ms, full-screen with labels ~30ms).

---

## M3c — Reference Photo + Clickable Muscle-Name List ✅ Done (supersedes M3a/M3b's SVG illustration)

The user supplied the actual reference photos (front/back) used to spec M3b and asked for the exact photo look, plus proposed a different interaction model: click a muscle's *name* in a list next to the photo, rather than tap a region of the image. Assessed feasibility first: true pixel-for-pixel use of "these exact photos" required the actual image files (not achievable from M3b's hand-authored SVG, and pasted chat images aren't retrievable as files) — resolved once the user pushed the two PNGs to the repo (`Lumen - Body map (Front/Back) (V1).png` on `main`), now stored as `assets/bodymap-front.png` / `assets/bodymap-back.png`. The click-list model turned out to be a net simplification: it removes the need for pixel-accurate hit-regions entirely, so it was implemented directly rather than treated as a fallback.

**Delivered:**
- **Photo is the visual, list is the interaction:** the body map now displays the exact reference PNGs (decorative, non-interactive) with a grouped, real-DOM list of clickable muscle names below/alongside it — headers matching the reference (Neck, Chest, Shoulders, Biceps, Forearms, Abs, Quadriceps, Thighs, Hamstrings, Calves front; Neck & Upper Back, Shoulders, Mid-Back, Arms (Triceps), Forearms, Lower Back & Core, Glutes, Hamstrings, Calves back).
- **Full individual muscle granularity:** since rows are just text (not spatial polygons), every named muscle from the reference gets its own row — including the small forearm/wrist muscles (Palmaris Longus, Extensor Carpi Ulnaris, Abductor Pollicis Longus, etc.) that M3b had to group onto shared tap targets for touch-target-size reasons. Data source: `MUSCLE_LIST` in `lumen-log-practice-3d.html`.
- **Bilateral L/R chips:** paired muscles (most of them) render two small chip buttons; midline structures (Trapezius, Erector Spinae, Rectus Abdominis, etc.) are a single clickable row. Multi-select across as many muscles as needed, one feeling per muscle via the existing 7-state picker.
- **Compact widget + full-screen modal:** the in-form widget shows the photo + a "🔍 Tap to Mark Muscles" button (kept small — the full list doesn't fit at ~260px wide); the full-screen modal is the primary interactive surface (photo + complete clickable list + picker + footer hint), reusing the modal shell built in M3b.
- **Legacy-safe canonical zones:** display labels mirror the reference photo's wording, but each stores under a clean canonical `zone` key reused from M3b's taxonomy (typos/duplicates in the AI-generated reference text, e.g. "Sarotorius", "Biceos Femoris", "Perenous Lingus", were not carried into the data model — only into nothing, since display text was normalized to the canonical spelling throughout). `BODY_ZONE_MAP` (`index.html`) additively extended for the newly-individually-tracked muscles (Omohyoid, Sternohyoid, the wrist muscles, Rectus Abdominis, Extensor Digitorum Longus).
- **`tools/bodymap/`'s SVG generation toolkit (gen2.js/render.js/build_front2.js/build_back2.js/integrate.js) is retired** — no longer wired into the live page, kept for historical reference only (its canonical zone names seeded `MUSCLE_LIST`'s `zone` keys).

**Verified:** page loads with no JS errors; both views render the correct photo + list (10 header groups / 42 rows front, matching back); click → picker → multi-select confirmed across bilateral and midline muscles; front/back toggle rebuilds the list correctly; compact widget and full-screen modal stay in sync on open/close; `savePractice()` inserts the correct `muscle_feelings` payload; editing a pre-M3c log with retired SVG-era zone names causes no crash and the current list stays fully functional (same accepted limitation as M3b: orphaned old names survive round-trip but aren't visually re-selectable under their old name).

**UI Layout adjustment (2026-07-11):** repositioned the "Tap to Mark" instruction text from below the photo to the left and right edges of the body-map pane using a 3-column grid layout, creating visual symmetry with the reference photo's side-annotated design. The instruction is now flanked on both sides while the photo + toggle + CTA remain centered.

**Follow-up enhancement (post-M3c):** refactor the full-screen modal to display the muscle list in left and right columns flanking the central photo — organized by the reference photo's anatomical section headers (Neck, Chest, Shoulders, Biceps, etc.) in the sequence they appear in the photos (front and back). This would make the muscle names visible at all times alongside their visual locations, reducing the need for the modal footer hint and creating a more self-documenting interface. Scope: restructure `.am-body` grid layout, merge `renderMuscleList()` into a two-column render pass, verify no regression in the click → picker → save flow.

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

### M4 Phase A — ✅ Done (Opus 4.8 planning pass 2026-07-11)

Session A shipped. Two architecture decisions were confirmed with the user before implementation: (1) add `assigned_teacher_id` so a Studio can schedule a class and assign it to one of its linked Teachers; (2) extend `redeem_join_code` to allow Teacher→Studio binding rather than a separate flow.

**Delivered:**
- `schema_phase11_classes_meta.sql` (idempotent) — adds `room`, `prerequisites`, `is_featured`, `assigned_teacher_id` to `classes`; a partial `classes_featured_idx`; SELECT-only RLS so an assigned teacher can read the class + roster a Studio owns; and a relaxed `redeem_join_code` (student→teacher/studio unchanged; **teacher→studio new**; studio→nothing; no self-link). **Action required: run in Supabase SQL Editor after phases 1–10.**
- `classes.html` (new) — teacher/studio-only provisioning form (title, style, date/time + duration→end, capacity, assigned teacher, room, online/location toggle, description, prerequisites, featured flag) + upcoming-class list (owned or assigned) with cancel. Studios get a dropdown of their bound teachers; teachers default to self.
- `index.html` — hardcoded `#page-courses` replaced with the federated Classes tab: role-adaptive header strip (student = today's bookings; teacher/studio = today's teaching), Featured hero banner (soonest featured class from linked studios), 14-day forward list grouped by day with **studio-branded left borders** (deterministic colour from the owner id — a real brand colour can arrive in M6), and a **gated booking modal** (Book button disabled + `[Next Stage Development — Gated Booking Engine]` tag). Empty state links to `profile.html` when the student has no linkages. Loaded lazily on first `switchTab('courses')`.
- `profile.html` — teachers now get a "Bind to a Studio" card (reusing the join-code UI, role-adjusted copy) + a "My Studios" list with unbind. `submitJoinCode`/`unlink` are role-aware.

**Federation is a query concern, not RLS:** RLS already exposes every published class to all authenticated users, so the student view fetches its active `studio_linkages.entity_id` set and filters `classes.teacher_id IN (…)` client-side over the 14-day horizon. No new read-broadening policy was needed.

**Verified:** `tools/classes/verify_m4.js` (Playwright, stubbed Supabase) — 23/23 checks: student view shows only linked-studio classes, excludes a non-linked studio and a >14-day class, hides the provisioning CTA, renders the featured hero + booked-today strip, opens the booking modal with the gated tag and correct studio name, no JS errors; teacher view shows the CTA + owned/assigned classes + today's teaching strip; the provisioning form inserts a correct `classes` row (title/style/capacity/featured/owner/assigned/end=start+duration/status). Visual screenshot confirms the day-grouped, two-studio-branded layout.

**Deferred to Phase B:** filter overlay + saved-filter chips and the §8.2 drag-and-drop schedule mutator (the piece most warranting its own Opus pass).

### M4 Phase B — ✅ Done

An Opus 4.8 planning pass proposed a 7×15 weekly DnD grid per §8.2's literal spec. That was adapted to this app's actual constraints before implementing: the whole codebase is single-file/mobile-first (every other view, including Phase A's own list layout, is validated at a 430px viewport) and there is no desktop-only layout anywhere to fall back to. A dense weekly grid would not have been legible at that width, so the reschedule interaction became **drag-a-card-onto-a-day-group-header** (moves the date, keeps time-of-day) plus a **tap-to-edit modal** (precise date/time/duration/room) — same outcome as the grid (drag reschedules a class, propagates live) without the legibility risk, reusing the exact M2 Pointer-Events drag pattern (deferred `setPointerCapture` until movement clears a threshold, so a plain tap still opens the booking modal).

**Delivered:**
- `schema_phase12_saved_filters.sql` (idempotent) — adds `profiles.saved_filters jsonb default '[]'`. No new RLS needed (existing self-row UPDATE policy covers it). **Action required: run in Supabase SQL Editor after phase 11.**
- **Filter overlay** — a `⚙ Filters` bar above the day-grouped list (both student and teacher/studio views) opens a popover (date range, teacher, style-text) reusing the `.overlay`/`.modal` shell. Filtering runs client-side over the already-fetched 14-day window; a badge on the Filters button shows the active-filter count.
- **Saved-filter chips** — `⭐ Save this filter` names the current filter set and persists it into `profiles.saved_filters`; chips render in a horizontal-scroll row, tap-to-apply, ✕-to-delete (each mutation is a full-array `profiles` UPDATE, matching the JSONB-array design chosen for the expected low per-user cardinality).
- **Drag-to-reschedule** — a drag handle (⠿) appears only on cards the current user owns (`teacher_id = auth.uid()`, matching the `classes_teacher_update` RLS policy exactly, so a rejected UPDATE can never surprise the user). Dragging a card onto another day-group header updates its date via an optimistic-then-confirmed `classes` UPDATE (same-day drops are a no-op); a conflict check blocks the move (and reverts) if the new time window collides with another class in the same room or under the same (assigned) teacher.
- **Edit modal** — the ✎ button on owned cards opens a date/time/duration/room form with the same conflict check, for precise reschedules that a day-level drag can't express.
- **Realtime sync** — a single unfiltered `postgres_changes` subscription on `classes` per page load; each event is relevance-gated client-side (teacher: owned or assigned; student: `teacher_id` in the linked-studio set) before triggering a full re-fetch of the current view, so a reschedule by one party lands in every other linked viewer's Classes tab without a manual reload.

**Verified:** `tools/classes/verify_m4b.js` (Playwright, extended stub with a capturing `postgres_changes` channel + an `update()` payload capture) — 25/25 checks across 4 scenarios: filters narrow/reset/save/reapply/delete correctly with the badge tracking count; a real mouse-driven drag from a card's handle onto a different day header fires the correct `classes` UPDATE and the card re-renders under the new day group optimistically; the edit modal opens pre-filled, rejects a room-conflicting save with the conflicting class named in the error while staying open, and accepts + persists + closes on a valid save; a relevant realtime event triggers a clean re-fetch while an irrelevant one (unlinked studio) is ignored without error. Re-ran `verify_m4.js` (Phase A, 23 checks) afterward with no regressions. Visual screenshots confirm the filter bar/chips/drag-handle/edit-icon all read cleanly at the 430px viewport used throughout the rest of the app.

**Not built:** the literal §8.2 weekly/monthly grid — the day-group drag + edit-modal combination was judged the mobile-safe equivalent per the reasoning above; a true grid remains available as a future desktop-specific enhancement if the studio-manager persona ever gets one.

---

## M5 — Cross-Role Community Architecture (PRD §3.6) — 🚧 In Progress

**Delivered (schema phase 13):** Opus 4.8 planning pass completed. Full RLS/privacy model designed with 6 key privacy decisions:
1. **Sub-community visibility** — group name/existence visible only to owner + accepted members. Members can see co-member rosters.
2. **Group broadcasts** — teacher-only posts in M5; member-authored posts deferred. Realtime `group_bulletins` push notifications to member dashboards.
3. **Follows** — bidirectional/asymmetric-request: A requests (pending), B accepts → A sees B's peer activity.
4. **Red flags** — computed only over `is_private = false` logs + Pain/Injured feelings (reuses 14-day window). Students can set `route_feedback_to` flag.
5. **Feedback INSERT** — teacher→student only on non-private logs (enforced at DB level); student→teacher portal direction. Both directions 1–2000 char limit.
6. **30-day dashboard** — client-side aggregation of student's own logs (no privacy concerns).

**Critical decision point (requires user confirmation):**
- Current `community_feeds` policy grants all authenticated users read of the entire public feed. M5's peer-gating intent requires *dropping* this global visibility and gating all feeds behind: accepted follows (peer) + linked teacher (roster). This is a **breaking change** to the current experience. Alternative: keep public feed and treat follows as an *additional* curated tier (conflicts with PRD §3.6.2 wording: "peer activity hidden until follow accepted").
- **Recommendation:** implement option (b) — full gating behind follows/teachers, per PRD intent. Flagging for user confirmation before migration run.

**Schema migration ready:** `schema_phase13_community_architecture.sql` created with:
- `follows` table (pending/accepted/revoked states, bidirectional request model)
- `groups` + `group_members` + `group_bulletins` (teacher-owned cohorts, realtime broadcasts)
- `feedback` extensions (direction field, INSERT policies for teacher→student and student→teacher)
- `practice_logs.route_feedback_to` flag extension
- SECURITY DEFINER helpers: `is_group_member()` (RLS recursion prevention), `compute_red_flags()` (teacher roster red-flag scanning), `body_fatigue_30day()` (30-day dashboard aggregation)

**Next steps:** (1) confirm feed-gating design decision with user; (2) run schema migration in Supabase SQL Editor; (3) implement teacher.html roster + groups UI; (4) implement index.html peer feed + follows + group section; (5) feedback portal; (6) 30-day dashboard.

**Scope:**
- Linked Students Portfolio for teachers: roster table querying shared practice logs of joined students (respecting `is_private`).
- Red Flag Alerts: severe Pain body-status flags, or a student-set "route feedback to teacher" flag, highlight the roster row.
- Sub-communities: `+ Create Group` → private groups (`groups`, `group_members` tables) with text bulletins, reference-material uploads, schedule alerts; "Send" fires a Supabase Realtime broadcast to members' dashboards.
- Bidirectional follow approval: peer feed visibility requires accepted follow invitations (`follows` table with pending/accepted states).
- Feedback portal: students send reviews to linked teachers/studios (the `feedback` table from `schema_phase1_gaps.sql` exists but needs an INSERT policy and UI); character check + respectful-tone placeholder.
- 30-day holistic progress dashboard: body-map fatigue trend vs mood scores over a rolling 30 days.

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
