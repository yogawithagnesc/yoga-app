# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Navigation

- **Product spec:** `Lumen_PRD.md` (v2.0, comprehensive)
- **Implementation plan:** `WORKPLAN.md` (milestones M0–M8, current status in summary table)
- **Database schema:** `schema.sql` + `schema_phase*.sql` (incremental migrations, all idempotent)
- **Live app:** https://yoga-app-ten.vercel.app
- **GitHub branch convention:** feature branches use pattern `claude/lumen-prd-v2-workplan-*`

## Architecture

**Lumen** is a practice-tracking companion for yoga practitioners, teachers, and studios. It's deliberately built as **zero-build single-file HTML pages** deployed on Vercel, with Supabase as the backend.

### Core Stack
- **Frontend:** Vanilla JavaScript (ES6+), single-file HTML pages, no framework
- **Backend:** Supabase (PostgreSQL, RLS, Realtime, Auth, Storage)
- **Styling:** CSS custom properties (dark + gold token system, finalized in PRD §2.2)
- **3D/SVG:** THREE.js + GLTFLoader for optional 3D body model; SVG for primary body map
- **Video:** Mux SDK + custom MuxVideoPlayer.js wrapper
- **Deployment:** Vercel (preview + production at yoga-app-ten.vercel.app)

### Page Structure

Each `.html` file is self-contained: all CSS is inline `<style>` tags, all JS is inline `<script>` tags.

| File | Role | Authenticated |
|---|---|---|
| `login.html` | Email/password auth, OAuth prep | No |
| `register.html` | Email signup with email verification | No |
| `role-select.html` | First-time role picker (student/teacher/studio) | Yes, new user |
| `reset-password.html` | Email recovery link handler | No |
| `index.html` | Dashboard: stats, body status widget, activity feed, calendar, videos | Yes |
| `profile.html` | User profile, join-code management, category customization | Yes |
| `teacher.html` | Teacher/Studio view: shared categories, focus areas, linked student roster | Yes, teacher/studio role |
| `lumen-log-practice-3d.html` | Main log form: practice date/type, muscle map, focus selection, mood, intensity, notes, media upload | Yes |
| `role-select.html` | Role selector (appears after email verification or OAuth signup) | Yes, new user |

### Key Tables & RLS

**Reference:** `schema.sql` for core schema; `schema_phase*.sql` for incremental extensions.

| Table | Owner | RLS Pattern | Purpose |
|---|---|---|---|
| `profiles` | User | Self + linked visibility | User metadata (role, display name, stats counters) |
| `practice_logs` | User | Self + linked-read (if not private) | Session records (date, category, duration, mood, muscle feelings) |
| `practice_categories` | System/User | Public (system) + private (user) + linked | Practice types (Vinyasa, Running, etc.); custom per user |
| `focus_areas` | System/User | Public (system) + private (user) + linked | Training focus chips (Upper body, Flexibility, etc.) |
| `practice_groups` | User | Self only | User-owned category containers (Yoga, Fitness, custom) |
| `practice_group_items` | User | Self only | Per-user placement overrides (type → group mapping) |
| `studio_linkages` | Mutual | Self (owner/student) | Join-code connections (teacher/studio to student) |
| `community_feeds` | System-triggered | Self + linked-read | Activity broadcast (non-private logs) |
| `classes` | Teacher/Studio | Self + linked-read | Class schedules (foundation for M4) |

**Auth:** All queries prefaced with `eq('user_id', currentUser.id)` or equivalent RLS-scoped access; never trust client-side user ID.

### Supabase Integration Points

Each page imports the Supabase SDK and initializes a client:

```javascript
const SUPABASE_URL = 'https://vuodmnhebsjmwdeazdtc.supabase.co'
const SUPABASE_KEY = 'sb_publishable_...'
const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY)
```

Session checks follow a consistent pattern:

```javascript
const { data: { session } } = await db.auth.getSession()
if (!session) { window.location.href = 'login.html'; return }
currentUser = session.user
```

**Realtime subscriptions** are used for:
- Feed refresh when new public logs broadcast
- Body status widget update (via `ON INSERT/UPDATE practice_logs`)

### Database Migrations

All migrations live in `schema_phase*.sql` and are idempotent (use `IF NOT EXISTS`, `ON CONFLICT`, etc.). **Execution:** run in Supabase Dashboard → SQL Editor, in order (1 → 2 → 3 … → 10). Do not skip phases.

Recent phases:
- **Phase 8** (M0): Feed-likes count fix (`sync_feed_like_count` trigger + SECURITY DEFINER)
- **Phase 9** (M2): Dynamic category engine (`practice_groups`, `practice_group_items`, focus_areas extensions)
- **Phase 10** (M2): Focus-areas curation (replace 15 focuses with curated 9)

## Development Workflow

### No Build Step
There is no build, bundler, or test runner. Changes to `.html` files are deployed directly.

**Workflow:**
1. Edit `.html` file locally
2. Hard refresh browser (Ctrl+Shift+R) to clear cache
3. Test in Vercel preview (auto-deployed on git push)
4. Verify with actual data from the live Supabase project

### Git Workflow

**Branch naming:** `claude/lumen-prd-v2-workplan-*` (e.g., `claude/lumen-prd-v2-workplan-7yuud7`).

**Commit message format:**
```
Feature or fix title

- Detailed bullet 1
- Detailed bullet 2

Co-Authored-By: Claude <model> <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_...
```

**PR template:** auto-populated if `.github/PULL_REQUEST_TEMPLATE.md` exists; otherwise summarize changes in the PR body.

### Testing

No automated test suite exists. **Manual testing required:**
- [ ] Hard refresh browser to clear cache
- [ ] Test golden path in desktop browser
- [ ] Test on mobile device (iOS Safari, Android Chrome)
- [ ] Verify Supabase data persists (reload page)
- [ ] Check for regressions on related features

**Debug tools:**
- Browser DevTools Console (JavaScript errors, network)
- Supabase Dashboard → Logs (auth, database, RLS errors)
- Vercel Deployments tab (preview URL environment)

## Implementation Status

From `WORKPLAN.md` (updated 2026-07-10):

| Milestone | Status | Notes |
|---|---|---|
| M0 | ✅ Done | Feed-likes persistence fix (schema_phase8) |
| M1 | ✅ Done | P1 verification (studio dashboard, join-code, password reset) |
| M2 | ✅ Done | Dynamic categorization engine (practice_groups + drag-drop) |
| M3 | 🚧 In Progress | SVG body map + 14-day rest engine |
| M4–M8 | 📋 Planned | Scheduling, community, security, video, polish |

**M2 Known Issue:** Practice type rename (double-click/double-tap) still fails despite multiple pointer-event architecture fixes; root cause warrants fresh device/browser testing. Category rename works. This does not block M3.

## Important Patterns

### State Management
Each page maintains local state (no global store):
- `currentUser` — current auth session
- `CATEGORIES`, `GROUPS`, `FOCUS_AREAS` — fetched once on page load, manually refreshed after mutations
- `STATE` (in `index.html`) — dashboard aggregates (streak, sessions, mins, body status)

### Event Handling
- **Drag-and-drop:** Pointer Events API (not native HTML5 DnD; more reliable on mobile). See `attachTypeDragHandlers()` in `lumen-log-practice-3d.html`. **Important:** `setPointerCapture()` is deferred until dragging is confirmed (movement past threshold) to avoid hijacking click/dblclick events on child elements.
- **Modal / Popover:** direct DOM manipulation (show/hide via `classList.toggle()` or `.style.display`); no library.
- **Contenteditable rename:** double-click on text element → set `contentEditable='true'` → focus + select text → commit on blur or Enter key.

### API Patterns
All Supabase queries follow this structure:

```javascript
const { data, error } = await db.from('table')
  .select('columns') // or .insert(), .update(), .delete()
  .eq('user_id', currentUser.id)
  .single() // or .maybeSingle(), or omit for arrays

if (error) { console.error('...', error); return }
// use data
```

**RLS security:** Never construct queries without a `.eq('user_id', currentUser.id)` filter; RLS will silently filter to zero rows if missing.

### CSS Tokens
Dark + gold system (PRD §2.2):

```css
:root {
  --bg: #080807;              /* main background */
  --bg-el: #111110;           /* elevated surface (cards) */
  --accent: #C8A96E;          /* gold primary */
  --accent-h: #D8BA80;        /* gold hover */
  --success: #7B9E87;         /* sage, use for positive actions */
  --warning: #D4956A;         /* amber, use for Sore / alerts */
  --error: #C47070;           /* red, use for Pain / errors */
  --tx-1: #E8E0D0;            /* text primary */
  --tx-2: #9A9080;            /* text secondary */
  --tx-3: #5A5448;            /* text tertiary */
}
```

Use these tokens consistently; hardcoded colors are discouraged (except in SVG fallback paths where dynamic theming isn't practical).

## Common Tasks

### Add a Database Column
1. Create a new `schema_phase*.sql` file with `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...`
2. Run it in Supabase SQL Editor
3. Update queries in `.html` files to fetch/use the column
4. Test reload persistence

### Add a New Feature Page
1. Copy an existing `.html` file as a template (e.g., `profile.html`)
2. Update auth check and Supabase initialization
3. Inline all CSS and JS (no external imports except the Supabase SDK)
4. Push to git; Vercel auto-deploys
5. Test on preview URL

### Fix an RLS Policy
1. Identify the failing query and table in Supabase Logs
2. Review RLS policies in the relevant `schema_phase*.sql` file
3. Create a new phase file or update an existing one with corrected `DROP POLICY` + `CREATE POLICY`
4. Run in Supabase SQL Editor
5. Re-test the query; confirm no silent filtering

### Update the Body Map (SVG)
See `buildSVGFallback()` in `lumen-log-practice-3d.html` (~line 1612). The SVG is rendered inline as a `<path>` and `<ellipse>` grid. Muscle labels are stored in `data-z` attributes (e.g., `data-z="Quadriceps"`). Tap handlers use `svgTap(el)` to map taps to the `areaStates` object.

## Glossary

- **SECURITY DEFINER:** PostgreSQL function attribute that executes with the role's privileges (admin), not the caller's. Used for triggers that must bypass RLS to update aggregate stats or broadcast feeds.
- **RLS:** Row-Level Security; PostgreSQL policies that filter rows returned to the caller based on session metadata (`auth.uid()`, `auth.role()`).
- **Idempotent migration:** a `.sql` file that can be run multiple times without error (uses `IF NOT EXISTS`, `ON CONFLICT`, etc.). All phases are idempotent.
- **Realtime broadcast:** Supabase Realtime subscriptions that push updates to clients when database rows change; used for feed refresh and collaborative updates.
- **contentEditable:** HTML attribute (`contentEditable='true'`) that makes an element's text in-place editable. Not a form input; text is mutated directly in the DOM.

## Troubleshooting

**"RLS permission denied" error:**
- Check the query includes `.eq('user_id', currentUser.id)`
- Verify `currentUser.id` is set (not null)
- Check the table's RLS policies exist and match the auth check

**Double-click/tap doesn't trigger rename:**
- Ensure the parent element's `pointerdown` listener doesn't call `setPointerCapture()` immediately; pointer capture hijacks subsequent `click` and `dblclick` events and redirects them to the capturing element.
- Test in desktop browser first (mobile touch events are harder to debug).

**Supabase queries return zero rows but no error:**
- Likely RLS filtering. Check the table's RLS policies and ensure the query includes the right `.eq()` filter.
- Confirm the logged-in user ID matches the data's `user_id` column.

**Vercel preview doesn't reflect local changes:**
- Hard refresh browser (Ctrl+Shift+R) to bust cache.
- Check that git changes were pushed to the feature branch.
- Vercel deploys on `git push`; check the Deployments tab on vercel.com.

## Related Documentation

- **Lumen_PRD.md:** complete product spec, design tokens, feature breakdown, acceptance criteria
- **WORKPLAN.md:** milestone sequencing, scope per phase, model recommendations, dependencies
- `.claude/settings.local.json`: git permissions for this session
