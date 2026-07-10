LUMEN
—  ILLUMINATE YOUR PRACTICE  —

Product Requirement Document
A practice-tracking & learning companion for experienced yoga practitioners, teachers and studios

Version 2.0  ·  Ecosystem Expansion
Document owner: AgnesC  ·  Status: Living Document
Companion workplan: WORKPLAN.md

Table of Contents
1. Product Overview
2. Design System — FINALIZED
3. Core Functional Specifications (v2.0 Expanded)
4. Implementation Status & Delivery Checklist
5. Technical Architecture
6. Non-Functional Requirements
7. Decisions Log & Open Items
8. Studio Classes Control Module

---

# 1. Product Overview

## 1.1 Vision
Lumen is a mobile-first web app that helps experienced yoga practitioners, teachers and studios track practice, understand progress, and stay connected. Where most yoga apps are class-streaming catalogues, Lumen is positioned as a learning and progress-tracking instrument — a private journal of the body and the practice.

The name Lumen (Latin for "light," and the SI unit of luminous flux) ties into a Catholic "salt and light" theme (Matthew 5:13–14). The subtitle "Illuminate Your Practice" frames the product promise: making the invisible progress of a personal practice visible.

v2.0 expands the vision from a personal journal into a three-role ecosystem: Students track and share on their terms; Teachers monitor, group and guide their students; Studios schedule, promote and analyze at an aggregate level.

## 1.2 Target Users

| User Type | Profile | Primary Need |
|---|---|---|
| Intermediate Practitioner | 1–3 years of practice | Track progress, build consistency |
| Advanced Practitioner | Established self-led practice | Log detail, monitor injury patterns |
| Teacher | Independent teachers | Follow students, give feedback, manage groups & schedules |
| Studio | Schools & facilities | Schedule classes, promote, analyze attendance at macro level |

## 1.3 Positioning & Feature Priority
The product scope is deliberately ordered. Tracking comes first; community and content are layered on once the core journaling loop is solid.

| Priority | Pillar | Description |
|---|---|---|
| P1 | Practice Tracking & Progress | Log sessions, body map, mood, streak, history, categories |
| P2 | Teacher–Student Community | Feedback, shared activity, groups, broadcasts |
| P3 | Live Class / Booking | Federated schedules, booking framework, studio scheduling |
| P4 | On-Demand Video | Recorded class library (Mux) |

Guiding principle — "Fastest working method first." Ship a working version, then refine. The team consistently prioritises a deployable result over architectural purity — e.g. static HTML pages and a GitHub-web upload workflow rather than a framework build.

---

# 2. Design System — FINALIZED

Status: Phase 1 design system is locked and in use. Logo, colour palette, typography, spacing, and the base component library are finalized and implemented in the live product.

## 2.1 Brand & Logo · FINALIZED
Direction D was selected: a Tenor Sans wordmark "LUMEN" framed by gold ruling lines, with the subtitle "ILLUMINATE YOUR PRACTICE" set in spaced caps beneath.

## 2.2 Colour Palette · FINALIZED
A restrained monochrome base with a single gold accent, in a six-layer token system.

**DECIDED (v2.0): the dark + gold token set is the system-wide standard.** The warm cream/bark/sage variant currently on the live home screen will be migrated to dark + gold in the polish milestone (WORKPLAN M8). The warm palette's semantic colors (sage = success, etc.) are retained as semantic tokens only.

Core Accent & Neutrals

| Hex | Token | Usage |
|---|---|---|
| #C8A96E | Gold Accent | Primary accent, CTAs, highlights |
| #D8BA80 | Gold Hover | Hover state |
| #A88848 | Gold Pressed | Pressed state |
| #080807 | BG Base (dark) | App background |
| #111110 | BG Elevated | Cards, sheets |
| #E8E0D0 | Text Primary | Primary text on dark |

Semantic (retained from warm variant)

| Hex | Token | Usage |
|---|---|---|
| #5C7A55 | Sage | Success / log actions |
| #D4956A | Warning | Tight / Sore (amber) states |
| #C47070 | Error | Pain / error states |

## 2.3 Typography · FINALIZED

| Role | Typeface | Use |
|---|---|---|
| Display | Cormorant Garamond | Large titles, quotes, hero numerals |
| Headings | Tenor Sans | Section labels, logo wordmark |
| Body | DM Sans | Paragraphs, UI text, buttons |
| Chinese | Noto Serif / Sans TC | Cantonese / Chinese content |

## 2.4 Spacing, Radius & Components · FINALIZED
Spacing: 4px base grid, 8 tokens (4 / 8 / 12 / 16 / 24 / 32 / 48 / 64).
Border radius: 5 tokens (6 / 10 / 14 / 20 / full).
Component library: 8 base interactive components — Button, Card, Input, Badge, Progress (Ring / Bar / Heatmap), Avatar, Bottom Navigation, Modal Sheet.

---

# 3. Core Functional Specifications (v2.0 Expanded)

## 3.1 Feature: User Authentication, Role Selection & Onboarding

### 3.1.1 Authentication Interface & OAuth Options
- Native credentials portal (Email + Password) with an integrated "Forgot Password?" email recovery workflow. **Implemented** (`login.html`, `reset-password.html`); redirect-URL configuration and live testing pending.
- Third-party OAuth (Google Sign-In, Apple Sign-In). **Deferred to final phase** — buttons present but disabled in `login.html`; provider configuration scheduled in WORKPLAN M8.
- Unified account provisioning: regardless of identity provider, all first-time registrants route to a mandatory, non-skippable Role Selection screen before accessing the app. **Implemented** (`role-select.html`, with profile upsert self-heal).

### 3.1.2 Tri-Role System Architecture
Every user session belongs to exactly one role:
- **Student** — default consumer persona. Full access to personal tracking, private custom category building, aggregated analytics, and multi-entity studio/teacher linkages.
- **Teacher** — independent professional. Provisions custom practice templates, views authorized data streams of linked students, broadcasts teaching schedules, manages sub-groups.
- **Studio** — institutional persona. Administrative hub overseeing contracted Teacher profiles, macro attendance analytics, branch hierarchies, and institutional communications. Operates at aggregate tier only (see §3.7.2).

### 3.1.3 Secure Join-Code Linkage & Data Privacy Engine
Connectivity between user tiers relies strictly on mutual transactional consent.
- **Join-Code Mechanism:** Studios and Teachers generate unique alphanumeric Join Codes via profile settings. **Implemented** as a multi-code system (`join_codes` table; `create_join_code` / `redeem_join_code` SECURITY DEFINER RPCs) — codes can be created, listed and deactivated per owner.
- **Consent-Driven Onboarding:** a Student manually inputs a Join Code and explicitly checks: "I agree to share my localized practice data with this Studio/Teacher in accordance with the Data Sharing Agreement." **Implemented** (`profile.html`).
- **Data Privacy Boundary:** RLS restricts Studio/Teacher access exclusively to non-private logs of consenting linked students. Personal self-practice metrics and private logs remain hidden. **Implemented** (linked-teacher read policies gated on `is_private = false` + active consent).
- This infrastructure is the foundation for the v2.0 ecosystem: teacher multi-studio binding (§3.5.1), studio branches (§3.7.2), and group segmentation (§3.6.1).

## 3.2 Feature: Main Dashboard, Personalization & Log Practice (Student / Teacher)

### 3.2.1 Dynamic Practice Categorization Engine
Users dynamically manage how their fitness and yoga journeys are categorized instead of relying on hardcoded types.
- **Seed Defaults:** on account creation, a seeding function provisions exactly two default categories per profile: **Yoga** and **Fitness**.
- **CRUD Actions:** inline rename of default categories; create custom categories via a `+ Add Category` trigger. *(Custom category creation from the log form is already implemented; per-profile default seeding and rename are WORKPLAN M2.)*
- **Drag-and-Drop Interface:** on the Log Practice page, practice types (Vinyasa, Hatha, Running, Gym, Pilates…) render as draggable chips. Users drag chips between category containers to reorder or re-classify them.
- **Custom Practice Types:** a `+ Add New Practice Type` trigger inside any category box.
- **Data constraints:** `practice_categories` links to `profiles.id` via `user_id` (exists). Category/chip mapping changes persist to a JSONB layout or linking table in Supabase in real time.

### 3.2.2 Hierarchical Practice Focus & Ecosystem Recommendation
- **System Defaults:** a permanent global dictionary of practice focuses: Full body, Upper body, Lower body, Core, Strength, Flexibility, Balance, Mindfulness. *(A 15-chip `focus_areas` dictionary is already seeded; reconcile the list in M2.)*
- **Custom Extension:** Students, Teachers and Studios can append new focus strings via text input.
- **Ecosystem Promotion:** a custom focus created by a Teacher or Studio is pushed downstream as a "Recommended Focus" badge visible to any Student linked via Join Code.

### 3.2.3 Interactive Body Map Visualizer & 14-Day Rolling Rest Engine
**DECIDED (v2.0): SVG-based body model is the primary interface.** The 16MB 3D GLTF model is retired from the default path (the existing SVG fallback in the log screen is promoted and enriched — WORKPLAN M3).
- **Anatomical Selection:** the Log Practice UI embeds an interactive front/back vector human anatomical graphic (SVG).
- **Multi-Select Muscle Nodes:** tapping a muscle path (Quadriceps, Hamstrings, Lower Back, Shoulders, Triceps…) toggles a context popover to mark the muscle **Sore** or **Pain**.
- **Visual States:** Amber for Sore, Red for Pain; multiple nodes active simultaneously.
- **14-Day Rolling Analytics:** the "Your Body Status" widget aggregates practice logs within `[today − 14 days]` and displays a numeric count of completed practice types. *(14-day aggregation is implemented in `index.html`; rest suggestions are M3.)*
- **Rest Suggestion Logic:** if any muscle node is flagged Sore/Pain ≥ 3 times within the 14-day window, surface a prioritized Rest & Restoration Suggestion Card (e.g., "Your Quadriceps have been logged as Sore/Pain 4 times in the past 2 weeks. We highlight this area as requiring rest. Consider a Yin or Mindfulness focus today.").

### 3.2.4 Core Gamification Stats Bar (v1.0, implemented)
The dashboard grid renders three parameters from the profile schema: Current Streak (🔥 X day streak), Sessions counter, Total Time tracker.

### 3.2.5 Dual-Perspective Filter Toggle (v1.0, implemented)
- **Yoga Journey Only:** dashboard, widgets and history ignore non-yoga activities; streak reads `yoga_streak_count`.
- **All-Round Fitness Journey:** aggregates all cross-functional metrics; streak reads `global_streak_count`.

## 3.3 Feature: Dynamic Log Practice & Custom Category System (v1.0, implemented)
- **Dynamic System Configurations:** default practice styles live in the `practice_categories` table (12 system styles seeded), decoupled from client code; the frontend fetches active categories on load. Admin CRUD works without code deployments.
- **Cross-Functional Customization:** users append personalized categories (Running, Pilates, Weight Training…) directly from the log form.
- **Hierarchical Visibility:** Student-created categories are private-scoped to their `user_id`. Teacher/Studio categories propagate to all linked Students (`linked` visibility).
- **Structured Biometric Input:** the logging wizard captures muscle locations with qualitative states, saved as a structured `muscle_feelings` JSONB object driving the Body Status pipeline. Focus chips, mood, intensity, duration, notes, media upload (Supabase Storage `practice-media` bucket) and a privacy toggle complete the form.

## 3.4 Data Flow & Mutation System Logic (v1.0, implemented)

### 3.4.1 Transactional Create Flow
On log submission, database triggers process atomically:
1. **Payload Insertion** into `practice_logs` (style, duration, mood, user ID, muscle feelings map, `is_private` boolean defaulting to true).
2. **Incremental Aggregation** on `profiles`: increment `global_total_minutes` / `global_total_sessions`; if the category is Yoga-typed, also `yoga_total_minutes` / `yoga_total_sessions`.
3. **Timezone-Aware Dual-Streak Evaluation** (`global_streak_count` and `yoga_streak_count`): consecutive day → +1; same-day entry → unchanged; gap ≥ 2 days → reset to 1. *(Implemented as a from-scratch recompute in `sync_profile_stats`.)*
4. **Privacy-Gated Broadcast:** if `is_private = false`, the `broadcast_public_log` trigger injects an activity story into `community_feeds`; if true, no broadcast. The client refreshes dashboard metrics without reload.

### 3.4.2 Transactional Mutation & Compensation (Edit/Delete)
Handled natively via PostgreSQL triggers on `practice_logs` UPDATE/DELETE:
- **On Delete:** totals and session counters decremented.
- **On Edit:** delta applied to lifetime fields.
- **Streak Correction:** the trigger recomputes streaks across the affected timeline so chains broken by edits/deletes stay consistent. Privacy toggles add/remove the corresponding feed story.

## 3.5 Feature: Centralized Class Scheduling & Booking Framework (Studio / Teacher / Student)

### 3.5.1 Multi-Studio Federated Schedule View
- **Federated Compilation:** the Classes tab queries and merges upcoming schedules from all Studios where the Student holds an active Join Code connection, into one unified calendar.
- **Visual Distinction:** class cards carry explicit Studio branding (name, color-coded borders) to distinguish sources.
- **Teacher Matrix Binding:** Teachers can bind multiple Studio Join Codes in their profile, representing every facility where they teach.
- **Forward Horizon Limit:** the schedule renders exactly 14 calendar days forward from the current date.

### 3.5.2 Schedule Filtering, Pinning & Adaptive Headers
- **Multi-Criteria Filter Engine:** overlay filtering the 14-day view by Date, Class Type, and Teacher Name.
- **Favorite Filter Sticky Tagging:** starring a filter setup (e.g., Teacher: Agnes) saves it as a quick-access shortcut chip at the top of the interface.
- **Role-Adaptive Header:**
  - Student view: horizontal row of the current day's booked schedule, chronological.
  - Teacher view: the current day's teaching schedule (assigned classes).
- **Booking Transaction Placeholder:** a reservation modal exists, but the "Book Class" button is visually disabled and tagged `[Next Stage Development — Gated Booking Engine]` to isolate the booking engine as a later phase.
- **Studio Merchandising Placement:** Studios can flag class instances or workshops as Featured / Promotional; these bypass chronological flow and render in a hero promotion banner atop linked Students' feeds.

*(Schema foundation — `classes`, `bookings` tables with capacity trigger and RLS — already exists. All §3.5 UI is WORKPLAN M4.)*

## 3.6 Feature: Cross-Role Community Architecture

### 3.6.1 Teacher Gated Insights & Micro-Community Segmentation
- **Student Roster Health Monitor:** a "Linked Students Portfolio" table querying practice logs of all students bound via active Join Codes (respecting per-log privacy).
- **Automated Red Flag Alerts:** if a linked student registers a rolling body-status warning (e.g., severe Pain), or explicitly routes feedback to that teacher, the roster row flashes an urgent Red Flag Alert icon.
- **Sub-Community Micro-Segmentation:** a `+ Create Group` button segments the roster into private sub-communities (e.g., Private Coaching Circle, Intermediate Flow Cohort).
- **Supabase Realtime Blast Broadcasts:** within sub-groups, teachers write text bulletins, upload reference materials, or send last-minute schedule alerts; "Send" triggers a high-priority realtime broadcast to all targeted members' dashboard notifications.

### 3.6.2 Student Social Feed & Mutual Respect Feedback Portals
- **Bidirectional Privacy Gating:** students see updates from connected teachers and peers, but peer-to-peer visibility requires an explicit two-way approval — a follow invitation must be accepted before any activity stream renders.
- **Feed Likes:** persistent, cross-user like counts on feed items (`feed_likes` table + count-sync trigger). **Implemented; count-persistence defect fixed in Phase 8** (see §4).
- **Ecosystem Feedback Portal:** a dedicated field transmitting performance reviews and textual logs to linked Teachers or Studios. The submission CTA enforces a character check and a placeholder emphasizing professional, mutual-respect guidelines.
- **30-Day Holistic Progress Metrics:** a visual dashboard comparing physical logs (Body Map fatigue trend counts) and mental scores (mood tracking) across a rolling 30-day window.

## 3.7 Feature: Security Settings, Profile Matrices & Studio Configurations

### 3.7.1 Student Privacy Enforcer & Global Identity Constraints
- **Granular Ingestion Log Toggle:** every practice log row in the confirmation ledger carries an independent visibility toggle `[Share with Teachers/Studios: True/False]`. Unshared records remain hidden from external roster views — total student data sovereignty. *(The `is_private` flag and RLS gating exist; the per-row ledger toggle UI is WORKPLAN M6.)*
- **Join Code Descriptive Lookup:** the connections dashboard maps Join Codes to relational records, showing the human Studio/Teacher name instead of alphanumeric strings.
- **Unique Global Username Constraints:** profile editing provides Name and Email inputs; the system enforces a database-level UNIQUE constraint on `username` with a realtime availability check while typing.
- **Peer Invitation System:** users add fitness companions by exact unique username, dropping a Follow Request into the target's notification queue for authorization.

### 3.7.2 Studio Operational Analytics Dashboard
- **Aggregate-Only Data Rule:** the Studio Home view operates exclusively at Aggregate/Macro tier — total Join Code follower metrics and general class statistics. Individual student raw practice details are structurally blocked (RLS-enforced) to guarantee zero data contamination.
- **Brand Anchoring:** a prominent motivational quote component heads the UI.
- **Central Feedback Pipeline View:** compiles all direct feedback submitted to the studio or its contracted teachers.
- **Date Range Attendance Analyzer:** a calendar range picker `[Start Date – End Date]` parses check-in tallies and buckets class configurations into three tiers:
  - **Popular:** highest attendance relative to room capacity.
  - **Unpopular:** lowest capacity utilization.
  - **High Potential:** high week-over-week acceleration despite lower absolute slots.
- **Studio Brand Community Domain:** an independent brand channel; updates broadcast immediately to the main screens of all users linked to the studio's code.
- **Bi-Categorized Directory:** the studio profile separates its network into two tabs — Contracted Teachers and Linked Students.
- **Multi-Branch Hierarchy Engine:** studios create sub-branches, each with an independent Link Code (Branch A Code, Branch B Code…). Performance aggregates separately per branch while consolidating under the main studio profile. All studio managers follow the unique-username / unique-email schema rule.

---

# 4. Implementation Status & Delivery Checklist

Reconciled as of 2026-07-10. Full milestone detail in WORKPLAN.md.

## P0 — Role-Select Loop Fix ✅ DONE
- [x] Profiles backfill + trigger repair + insert policy (`schema_phase6_repair.sql`)
- [x] role-select.html upsert + 0-row validation
- [x] OAuth buttons disabled in login.html (coming soon)
- [x] Merged to main via PR #1, Vercel deployed

## P1 — Core Tracking Loop ✅ DONE
- [x] Student: register → role select → dashboard — live tested
- [x] Log practice + stats trigger updates — live tested
- [x] Media upload (video + images) — live tested
- [x] Teacher role: register/select → dashboard, generate join codes — live tested
- [x] Studio role: register/select → dashboard — verified (teacher.html serves both teacher and studio roles)
- [x] Custom categories, dual-perspective toggle, Body Status widget verification — verified
- [x] Join code redemption, student side — verified
- [x] Password reset flow — verified live end-to-end; required fixing the Supabase **Site URL** (was `localhost:3000`) and switching Email Provider off unconfigured Custom SMTP back to the Supabase default

## P2 — Community Features
- [x] Feed likes schema deployed (`schema_phase7_feed_likes.sql`)
- [x] Feed likes persistence bug **root-caused and fixed**: the count-sync trigger lacked SECURITY DEFINER and `community_feeds` has no UPDATE RLS policy, so count updates were silently filtered to zero rows. Fix: `schema_phase8_fix_like_count.sql` — **run and verified live** (like/unlike now persists correctly).
- [x] Dynamic Practice Categorization Engine (§3.2.1) + Hierarchical Practice Focus & Ecosystem Recommendation (§3.2.2) — implemented via `schema_phase9_categorization_engine.sql` (pending migration run + live test)
- [ ] Remaining §3.6 scope (roster monitor, groups, broadcasts, follows, feedback portal, 30-day metrics) — WORKPLAN M5

## P3 — Live Classes & Booking
- [ ] Studio/teacher class creation UI — not started (M4)
- [ ] Federated student calendar, filters, adaptive headers, gated booking, featured classes — not started (M4)
- [ ] Drag-and-drop schedule mutator (§8.2) — not started (M4)

## P4 — On-Demand Video
- [ ] Videos catalog table + upload workflow — not started (M7)
- [ ] Multi-video support (currently 1 hardcoded Mux video) — not started (M7)

## Polish / Non-Functional
- [x] Theme decision made: **dark + gold app-wide** (migration in M8)
- [x] Body Map decision made: **SVG primary** (build in M3)
- [ ] Chinese/Cantonese localization — M8
- [ ] Google/Apple OAuth providers — M8 (final phase)

---

# 5. Technical Architecture

## 5.1 Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Static HTML / CSS / JS | Mobile-first, single-file pages, no build tooling |
| Body Map | SVG (primary) | 3D Three.js/GLTF retired from default path per v2.0 decision |
| Video | Mux (@mux/mux-player) | `MuxVideoPlayer.js` wrapper, resume via `video_progress` |
| Hosting | Vercel | Auto-deploy on push to main → yoga-app-ten.vercel.app |
| Source Control | GitHub (web upload) | yogawithagnesc/yoga-app |
| Backend | Supabase | Auth + Postgres + Storage + Realtime, Tokyo region |

Deployment workflow (agreed, no-terminal): edit/upload in the GitHub web UI → commit to main → Vercel auto-deploys.

## 5.2 Database Schema (as implemented)

Applied migrations, in order: `schema.sql` (base + Phases 2–4 inline), `schema_phase1_gaps.sql`, `schema_phase2_category_meta.sql`, `schema_phase4_oauth_display_name.sql`, `schema_phase5_join_codes.sql`, `schema_phase6_repair.sql`, `schema_phase7_feed_likes.sql`, `schema_phase8_fix_like_count.sql`, `schema_phase9_categorization_engine.sql`.

| Table | Purpose |
|---|---|
| `profiles` | Role, display name, 6 stat counters (`global_/yoga_` × `total_minutes/total_sessions/streak_count`), `last_activity_date`, `last_yoga_date`, legacy `join_code` |
| `practice_categories` | System / private / linked practice **types** (Vinyasa, Running…); `subtitle`, `sort_order` |
| `practice_groups` | User-owned practice **categories** (Yoga, Fitness, custom); seeded 2 rows per profile |
| `practice_group_items` | Per-user placement override mapping a practice type to a category, written on drag-and-drop |
| `practice_logs` | Sessions: category, duration, mood, intensity, `muscle_feelings` JSONB, `focus_area_ids`, `media_urls`, `is_private` |
| `focus_areas` | Global focus chip dictionary (15 seeded) |
| `session_media` | Uploaded media metadata (Storage bucket `practice-media`) |
| `studio_linkages` | Consent-driven student ↔ teacher/studio connections |
| `join_codes` | Multi-code system per owner; create/deactivate; RPCs `create_join_code`, `redeem_join_code` |
| `community_feeds` | Denormalized public-log feed; `like_count` |
| `feed_likes` | One row per (feed, user); count synced by SECURITY DEFINER trigger |
| `feedback` | Student → teacher/studio feedback (UI pending, M5) |
| `classes` | Teacher/studio class scheduling: time, capacity, status |
| `bookings` | Student ↔ class, capacity-gated by trigger |
| `video_progress` | Per-user resume position |

Key triggers: `handle_new_user` (auto profile), `sync_profile_stats` (full streak/total recompute on log insert/update/delete), `broadcast_public_log` (privacy-gated feed publishing), `sync_feed_like_count` (SECURITY DEFINER), `before_booking_capacity` (raises `class_full`).

Planned v2.0 additions (see WORKPLAN): rest-suggestion queries (M3), `saved_filters`, class `room`/`prerequisites`/`is_featured` (M4), `groups`/`group_members`/`follows`/notifications (M5), `username` unique constraint, studio branches (M6), `videos` catalog (M7).

Security model: RLS on every table keyed on `auth.uid()`; linked-entity reads gated on `is_private = false` plus an active consent record; SECURITY DEFINER used only for narrow, audited RPCs and count-sync triggers.

## 5.3 Cost (Beta)
Supabase free tier + Vercel free tier remain sufficient for beta: ~$0/month (optional custom domain ~$12/yr). Scale-up to ~1,000 active users estimated at roughly $110/month including paid Supabase, Vercel and Mux video delivery. v2.0 realtime broadcasts and storage usage fit within the same envelope at beta scale.

---

# 6. Non-Functional Requirements

| Area | Requirement |
|---|---|
| Platform | Mobile-first; usable in any mobile browser, max content width 430px |
| Language | English UI; Cantonese / Chinese via Noto TC fonts (full zh-TC localization in M8, using the `STRINGS` table pattern) |
| Privacy | Row-level security; students control per-log sharing; studios see aggregates only |
| Performance | SVG body map loads instantly (16MB 3D model retired from default path) |
| Accessibility | Sufficient contrast; legible type scale; ≥44px touch targets |
| Reliability | Static hosting + managed backend; auto-deploy on commit |

---

# 7. Decisions Log & Open Items

## Decided
- **Theme:** dark + gold token set is the app-wide standard; warm cream/bark/sage retired except as semantic tokens. (2026-07-10)
- **Body Map:** SVG-primary interaction; 3D GLTF retired from the default path. (2026-07-10)
- **OAuth:** Google/Apple providers deferred to the final polish phase (M8).
- **Booking engine:** the actual reservation transaction is gated behind a later phase; v2.0 ships the disabled placeholder (§3.5.2).
- Save Practice → database, media storage, dashboard read-side: **done** (previously open in v1.0).

## Open
- Localization scope: full zh-TC translation vs. progressive per-page rollout.
- Apple Sign-In requires an Apple Developer account ($99/yr) — confirm before M8.
- Payments/monetization for booking: explicitly out of scope for v2.0.
- Whether to keep the 3D body model behind an optional toggle or remove the assets entirely.

---

# 8. Studio Classes Control Module

## 8.1 Schedule Provisioning & Rule Infrastructure
Enables Studio managers to configure upcoming scheduling frameworks.
- **Schedule Ingestion Interface:** a form for administrators to input future calendar dates, class descriptions, assigned teacher profiles, room allocations, maximum attendance capacity, and mandatory booking prerequisites.

## 8.2 Interactive Canvas Drag-and-Drop Schedule Mutator
Allows studio managers to adjust schedules directly on a visual calendar.
- **Visual Grid Operations:** a weekly/monthly calendar planning grid.
- **Direct Mutation Interaction:** click, hold and drag an existing class block to a different calendar cell (changing day or time).
- **Automatic Relational Updates:** releasing the block fires an asynchronous UPDATE mutation changing the record's `start_time`, `teacher_id`, or room instantly, propagating to all linked students' and teachers' views in real time via Supabase Realtime — no page refresh.

*(Both delivered in WORKPLAN M4; an Opus-class design pass is recommended before implementing §8.2.)*
