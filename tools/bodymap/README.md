# Body Map Generator Toolkit (M3/M3a)

Generates the anatomical SVG body map embedded in `lumen-log-practice-3d.html`
(`getSVGMarkup()`). **Never hand-edit the inline SVG paths in the page** —
change the zone/fascia/fiber definitions here and regenerate.

## Files
- `gen2.js` — shape primitives (capsule, spindle, teardrop), striation-fiber
  generators, and vertical-axis path mirroring (L → R zones)
- `render.js` — shared `<defs>` (crimson muscle gradient, silver fascia
  gradient, chisel rim-light filter), zone expansion, markup/preview writers
- `build_front2.js` / `build_back2.js` — the 49 front / 42 back zone
  definitions plus fascia shapes and per-muscle fiber specs
- `integrate.js` — splices regenerated markup + CSS + JS fill-fallback into
  `lumen-log-practice-3d.html` (uses string markers; review diff after run)
- `verify_m3a.js` — Playwright: multi-point interior sampling proves every
  zone keeps exposed tappable surface; paint override/clear check
- `verify_page.js` — Playwright: end-to-end in the real page with a stubbed
  Supabase session (tap → highlight → pick feeling → toggle views)

## Regenerate
```
node build_front2.js && node build_back2.js   # writes *_markup.txt + previews
node integrate.js                              # splices into the page
NODE_PATH=<path-with-playwright> node verify_m3a.js && node verify_page.js
```
