# Body Map Generator Toolkit (M3/M3a/M3b)

Generates the anatomical SVG body map embedded in `lumen-log-practice-3d.html`:
- **Compact widget** (`#svg-body`, `COMPACT_MARKUP`) — small, unlabeled, in the
  log-practice form.
- **Full-screen modal** (`#svg-body-full`, `FULL_MARKUP`) — expanded canvas
  with the header/sub-muscle/leader-line label overlay (opened via
  "🔍 View Full Anatomy").

Both render the SAME ~123 tap zones (63 front + 60 back) from one geometry
definition, so a mark made in either instantly shows in the other.
**Never hand-edit the inline SVG paths in the page** — change the
zone/fascia/fiber/label definitions here and regenerate.

## Files
- `gen2.js` — shape primitives (capsule, spindle, teardrop), striation-fiber
  generators, joint-tendon radial burst generator, and vertical-axis path
  mirroring (L → R zones)
- `taxonomy.js` — label overlay source of truth: header groups, sub-muscle
  text, region tag, and leader-line anchor point per header, for front + back.
  The label *list* may be denser than the tap-zone *geometry* (e.g. seven
  named forearm muscles grouped onto 2 physical hitboxes) — see the M3b
  design note at the top of the file.
- `render.js` — shared `<defs>` (6 body-region material gradients, silver
  fascia gradient, chisel rim-light filter), zone/fascia/joint expansion,
  the `labels()` header/leader-line/dot assembly, and `write()` (compact) /
  `writeLabeled()` (full-screen) output writers
- `build_front2.js` / `build_back2.js` — the 63 front / 60 back zone
  definitions (region-tagged), fascia shapes, joint tendon points, and
  per-muscle fiber specs
- `integrate.js` — injects the regenerated `COMPACT_MARKUP`/`FULL_MARKUP`
  data objects into `lumen-log-practice-3d.html`. The surrounding CSS, modal
  HTML, and interaction JS (`buildSvg`/`attachSvgHandlers`/`svgTap`/
  `applyFeeling`/etc., which share `svgBodyStates` across both containers)
  are hand-authored in the page directly and are not touched by this script.
- `verify_m3a.js` — Playwright: multi-point interior sampling proves every
  zone keeps exposed tappable surface; paint override/clear check
- `verify_page.js` — Playwright: end-to-end in the real page with a stubbed
  Supabase session (tap → highlight → pick feeling in both containers →
  toggle views → confirm state sync between compact and full-screen)
- `verify_legacy_edit.js` — Playwright: opens the edit flow with a log
  referencing zone names retired by M3b's muscle-head splits, confirms no
  crash and the orphaned entries survive a resave (documented limitation:
  they're no longer visually re-tappable under the old name, but not lost)
- `verify_perf.js` — Playwright: render-time check for view toggles in both
  containers with the full zone count + chisel filter + label overlay

## Regenerate
```
node build_front2.js && node build_back2.js   # writes *_markup.txt + previews
node integrate.js                              # splices into the page
NODE_PATH=<path-with-playwright> node verify_m3a.js && node verify_page.js \
  && node verify_legacy_edit.js && node verify_perf.js
```
