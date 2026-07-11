# Body Map (M3 → M3a → M3b → M3c)

## Current design (M3c) — reference photo + clickable muscle-name list

As of M3c, the body map in `lumen-log-practice-3d.html` is **not** SVG-based.
It displays the user-supplied reference photos (`assets/bodymap-front.png`,
`assets/bodymap-back.png`) as a decorative image, and interaction happens by
clicking a real, plain-text muscle name in a grouped list rendered alongside
the photo — not by tapping a region of the image. This was a deliberate pivot
away from the M3a/M3b SVG illustration approach (see below) after the user
asked for the exact reference photo look, which hand-authored SVG cannot
reproduce, and suggested the click-the-name interaction model, which also
removes the need for pixel-accurate hit-regions entirely.

**Where it lives (all inline in `lumen-log-practice-3d.html`):**
- `MUSCLE_LIST` — the data: `front`/`back` arrays of `{ header, items: [{ label, zone, bilateral }] }`. `label` mirrors the reference photo's wording; `zone` is the clean canonical key stored in `practice_logs.muscle_feelings` and read by `index.html`'s `BODY_ZONE_MAP` for the 14-day rest engine. Bilateral items render L/R chip buttons and store under `"L <zone>"`/`"R <zone>"`; non-bilateral (midline) items are a single clickable row.
- `renderMuscleList(view)` — builds the grouped list DOM, marking rows/chips whose zone has a stored feeling.
- `muscleTap()` / `applyFeeling()` — open the existing 7-state feeling picker and commit the choice into `muscleStates` (zone → feeling), shared by the compact widget's summary and the full-screen modal's list.
- Compact widget (`#svg-fallback`): front/back toggle + photo + "🔍 Tap to Mark Muscles" button. No direct interaction here — just a preview and an entry point.
- Full-screen modal (`#anatomy-modal`): the actual interactive surface — photo + the full clickable list + feeling picker + footer hint.

**To add/rename a muscle:** edit `MUSCLE_LIST` directly in the page. If it's a
genuinely new zone (not a rename), add it to `BODY_ZONE_MAP` in `index.html`
too, so it contributes to the rest engine.

**Verification:**
- `verify_m3c.js` — Playwright: page load, list render (both views), click → picker → multi-select, front/back toggle rebuilds the list, compact ↔ full-screen state sync
- `verify_legacy_edit.js` — Playwright: editing a pre-M3c log (zone names from a retired SVG-era split) doesn't crash and the current list stays fully functional
- `verify_save_roundtrip.js` — Playwright: `savePractice()` inserts the correct `muscle_feelings` payload for both bilateral and midline marks

## Retired: M3/M3a/M3b SVG illustration toolkit

Everything else in this directory (`gen2.js`, `render.js`, `taxonomy.js`,
`build_front2.js`, `build_back2.js`, `integrate.js`) generated a hand-authored
SVG anatomical illustration (91 → 123 tappable shape zones, region material
palette, striation fibers, chisel rim-lighting) that was directly tappable.
**It is no longer wired into the live page as of M3c** — kept here for
historical reference only (e.g. `taxonomy.js`'s canonical zone names/regions
were reused as the source for M3c's `MUSCLE_LIST` zone keys). Do not run
`integrate.js` — it splices markup into DOM elements (`#svg-body`,
`COMPACT_MARKUP`, etc.) that no longer exist in the page.
