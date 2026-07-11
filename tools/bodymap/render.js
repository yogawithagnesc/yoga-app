const fs = require('fs');
const { mirrorPathD, jointTendon } = require('./gen2.js');

// Region palette (M3b) — six body-region gradients replacing the single
// M3a muscleGrad, each dark enough at the rim that fiber striations still
// read through the fill. Region key -> gradient id.
const REGIONS = {
  chest:     'regChest',
  abs:       'regAbs',
  shoulders: 'regShoulders',
  arms:      'regArms',
  thighs:    'regThighs',
  calves:    'regCalves',
};

const REGION_GRADIENTS = `
<radialGradient id="regChest" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#42B586"/>
  <stop offset="50%" stop-color="#2A7A58"/>
  <stop offset="100%" stop-color="#123D2C"/>
</radialGradient>
<radialGradient id="regAbs" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#D6699F"/>
  <stop offset="50%" stop-color="#A8406F"/>
  <stop offset="100%" stop-color="#571F39"/>
</radialGradient>
<radialGradient id="regShoulders" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#E37A5C"/>
  <stop offset="50%" stop-color="#B84E34"/>
  <stop offset="100%" stop-color="#5E2517"/>
</radialGradient>
<radialGradient id="regArms" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#D9B84A"/>
  <stop offset="50%" stop-color="#A88824"/>
  <stop offset="100%" stop-color="#544310"/>
</radialGradient>
<radialGradient id="regThighs" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#B4433C"/>
  <stop offset="50%" stop-color="#872F2A"/>
  <stop offset="100%" stop-color="#451815"/>
</radialGradient>
<radialGradient id="regCalves" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#4C8F72"/>
  <stop offset="50%" stop-color="#335F6E"/>
  <stop offset="100%" stop-color="#182E36"/>
</radialGradient>`;

// Shared defs for the anatomical material system. Kept here so the
// preview pages and the integration snippet stay in lockstep.
// - regionGradients: 6 body-region palettes (M3b)
// - fasciaGrad: silver-gray tendon/fascia
// - chisel: specular rim-lighting emboss (light from top-left)
const DEFS = `<defs>${REGION_GRADIENTS}
<linearGradient id="fasciaGrad" x1="0%" y1="0%" x2="0%" y2="100%">
  <stop offset="0%" stop-color="#D8D4C8"/>
  <stop offset="55%" stop-color="#BEBAB0"/>
  <stop offset="100%" stop-color="#98948A"/>
</linearGradient>
<filter id="chisel" x="-20%" y="-20%" width="140%" height="140%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="0.9" result="blur"/>
  <feSpecularLighting in="blur" surfaceScale="1.6" specularConstant="0.55" specularExponent="20" lighting-color="#FFD9BC" result="spec">
    <feDistantLight azimuth="225" elevation="48"/>
  </feSpecularLighting>
  <feComposite in="spec" in2="SourceAlpha" operator="in" result="specClip"/>
  <feComposite in="SourceGraphic" in2="specClip" operator="arithmetic" k1="0" k2="1" k3="0.65" k4="0"/>
</filter>
</defs>`;

// Expand a zone list: entries whose name starts with "L " are mirrored to "R ".
// Each entry: { name, d, fib?, region?, tendon? } (path) or
// { name, ellipse:[cx,cy,rx,ry], ... }.
function expand(zones) {
  const out = [];
  zones.forEach(z => {
    out.push(z);
    if (z.name.startsWith('L ')) {
      const m = { name: z.name.replace('L ','R ') };
      if (z.d) m.d = mirrorPathD(z.d);
      else if (z.ellipse) {
        const [cx,cy,rx,ry] = z.ellipse;
        m.ellipse = [240-cx,cy,rx,ry];
      }
      if (z.fib) m.fib = mirrorPathD(z.fib);
      if (z.tendon) m.tendon = true;
      if (z.region) m.region = z.region;
      out.push(m);
    }
  });
  return out;
}

// Mirror-expand fascia shapes the same way (name is only for bookkeeping).
function expandFascia(shapes) {
  const out = [];
  (shapes || []).forEach(s => {
    out.push(s);
    if (s.name.startsWith('L ')) out.push({ name: s.name.replace('L ','R '), d: mirrorPathD(s.d) });
  });
  return out;
}

// Mirror-expand joint tendon bursts (center-point based, not path-based).
function expandJoints(joints) {
  const out = [];
  (joints || []).forEach(j => {
    out.push(j);
    if (j.name.startsWith('L ')) out.push({ name: j.name.replace('L ','R '), cx: 240-j.cx, cy: j.cy, r: j.r });
  });
  return out;
}

function zoneToSvg(z, attrs) {
  if (!attrs) {
    // Tendon-like zones (IT band, Achilles) stay tappable but render with
    // the silvery fascia material via the extra svgm-t class. Everything
    // else gets its body-region palette class + a data-region attribute
    // the page JS reads to restore the correct fill after a feeling is cleared.
    const cls = z.tendon ? 'svgm svgm-t' : `svgm svgm-${z.region || 'shoulders'}`;
    const regionAttr = z.tendon ? '' : ` data-region="${REGIONS[z.region || 'shoulders']}"`;
    attrs = `class="${cls}"${regionAttr}`;
  }
  if (z.ellipse) {
    const [cx,cy,rx,ry] = z.ellipse;
    return `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" ${attrs} data-z="${z.name}"/>`;
  }
  return `<path d="${z.d}" ${attrs} data-z="${z.name}"/>`;
}

// Assemble body markup: base silhouette → zones → fascia seams over the
// muscles (tendinous insertions read on top; pointer-events:none keeps
// every zone tappable) → striation fibers → joint tendon bursts on top.
function bodyMarkup(base, zones, fascia, joints) {
  const parts = [];
  if (base) parts.push(`<path d="${base}" class="svgm-bg"/>`);
  zones.forEach(z => parts.push(zoneToSvg(z)));
  if (fascia.length) {
    parts.push('<g class="svgm-fascia" pointer-events="none">');
    fascia.forEach(s => parts.push(`<path d="${s.d}"/>`));
    parts.push('</g>');
  }
  const fibs = zones.filter(z => z.fib);
  if (fibs.length) {
    parts.push('<g class="svgm-fibers" pointer-events="none">');
    fibs.forEach(z => parts.push(`<path d="${z.fib}"/>`));
    parts.push('</g>');
  }
  if (joints && joints.length) {
    parts.push('<g class="svgm-joints" pointer-events="none">');
    joints.forEach(j => parts.push(`<path d="${jointTendon(j.cx, j.cy, j.r)}"/>`));
    parts.push('</g>');
  }
  return parts.join('\n');
}

// ── LABEL OVERLAY (full-screen modal only) ──────────────────────────
// taxonomy: [{ view, header, side: 'L'|'R'|'mid', items: [{label, tapped}],
//             anchor: [x,y] in the original 0-240/0-580 body space }]
// Body group is translated by (dx,dy) in the expanded canvas; left-column
// headers render right-aligned ending at LEFT_X, right-column left-aligned
// starting at RIGHT_X, each with one leader line + dot to its anchor.
const LABEL_LAYOUT = { dx: 200, dy: 20, leftX: 188, rightX: 452, canvasW: 640, canvasH: 620 };

function labelBlock(entry, colX, align, startY) {
  const { dx, dy } = LABEL_LAYOUT;
  const ax = entry.anchor[0] + dx, ay = entry.anchor[1] + dy;
  const anchorX = align === 'end' ? colX + 14 : colX - 14; // small gap before the leader line starts
  const lines = [];
  let y = startY;
  lines.push(`<text x="${colX}" y="${y}" text-anchor="${align}" class="lbl-h">${entry.header}</text>`);
  y += 13;
  entry.items.forEach(it => {
    lines.push(`<text x="${colX}" y="${y}" text-anchor="${align}" class="lbl-s">${it}</text>`);
    y += 11;
  });
  lines.push(`<line x1="${anchorX}" y1="${startY - 4}" x2="${ax}" y2="${ay}" class="lbl-line"/>`);
  lines.push(`<circle cx="${ax}" cy="${ay}" r="2.2" class="lbl-dot"/>`);
  return { markup: lines.join('\n'), nextY: y + 14 };
}

function labels(taxonomyForView) {
  const { leftX, rightX } = LABEL_LAYOUT;
  const left = taxonomyForView.filter(e => e.side === 'L');
  const right = taxonomyForView.filter(e => e.side === 'R');
  const mid = taxonomyForView.filter(e => e.side === 'mid');
  // distribute midline-only headers to whichever column is currently shorter
  mid.forEach((e, i) => (left.length <= right.length ? left : right).push(e));

  const parts = ['<g class="body-labels">'];
  let y = 44;
  left.forEach(e => { const r = labelBlock(e, leftX, 'end', y); parts.push(r.markup); y = r.nextY; });
  y = 44;
  right.forEach(e => { const r = labelBlock(e, rightX, 'start', y); parts.push(r.markup); y = r.nextY; });
  parts.push('</g>');
  return parts.join('\n');
}

// CSS matching the live page's material treatment, for previews.
const REGION_CSS = Object.entries(REGIONS)
  .map(([k, id]) => `.svgm.svgm-${k}{fill:url(#${id})}`)
  .join('\n  ');

const PREVIEW_CSS = `
  body{background:#080807;margin:0;padding:20px}
  svg{width:460px;height:auto;background:#111110}
  .svgm-bg{fill:#3A1210}
  .svgm{stroke:#2A0A0B;stroke-width:0.7;cursor:pointer;filter:url(#chisel)}
  ${REGION_CSS}
  .svgm.svgm-t{fill:url(#fasciaGrad);stroke:#6E6A60}
  .svgm:hover{filter:url(#chisel) brightness(1.3)}
  .svgm-fascia path{fill:url(#fasciaGrad);stroke:#6E6A60;stroke-width:0.3;opacity:0.85}
  .svgm-fibers path{fill:none;stroke:#1E0708;stroke-width:0.5;opacity:0.4}
  .svgm-joints path{fill:none;stroke:#E8E0D0;stroke-width:0.6;opacity:0.55}
`;

const LABEL_CSS = `
  .lbl-h{font:600 8.5px 'DM Sans',system-ui,sans-serif;fill:#F0EAD8}
  .lbl-s{font:400 6.5px 'DM Sans',system-ui,sans-serif;fill:#9A9080}
  .lbl-line{stroke:#F0EAD8;stroke-width:0.5;opacity:0.55}
  .lbl-dot{fill:#F0EAD8}
`;

function write(name, base, zonesRaw, outDir, fasciaRaw, jointsRaw) {
  const zones  = expand(zonesRaw);
  const fascia = expandFascia(fasciaRaw);
  const joints = expandJoints(jointsRaw);
  const body   = bodyMarkup(base, zones, fascia, joints);

  fs.writeFileSync(`${outDir}/${name}_zones.json`, JSON.stringify(zones, null, 2));
  fs.writeFileSync(`${outDir}/${name}_markup.txt`, DEFS + '\n' + body);

  // preview with final material system
  const plain = `<!DOCTYPE html><html><head><style>${PREVIEW_CSS}</style></head><body><svg viewBox="0 0 240 580">${DEFS}\n${body}</svg></body></html>`;
  fs.writeFileSync(`${outDir}/${name}.html`, plain);

  // colored debug (zone boundaries / tap areas)
  const palette = ['#e6194b','#3cb44b','#ffe119','#4363d8','#f58231','#911eb4','#42d4f4','#f032e6','#bfef45','#fabed4','#469990','#dcbeff','#9A6324','#fffac8','#800000','#aaffc3','#808000','#ffd8b1','#000075','#a9a9a9'];
  let dbg = base?`<path d="${base}" fill="#333"/>\n`:'';
  zones.forEach((z,i) => { dbg += zoneToSvg(z, `fill="${palette[i%palette.length]}" stroke="#000" stroke-width="0.5" opacity="0.85"`) + '\n'; });
  const dbgHtml = `<!DOCTYPE html><html><head><style>body{background:#111;margin:0;padding:20px}svg{width:460px;background:#000}</style></head><body><svg viewBox="0 0 240 580">${dbg}</svg></body></html>`;
  fs.writeFileSync(`${outDir}/${name}_debug.html`, dbgHtml);

  console.log(`${name}: ${zones.length} zones, ${fascia.length} fascia, ${joints.length} joints, ${zones.filter(z=>z.fib).length} fibered`);
  return zones;
}

// Full-screen labeled render: body group translated into the expanded
// canvas + the label overlay on top. `taxonomyForView` entries reference
// anchors in the ORIGINAL 0-240/0-580 body space (same as zone authoring).
function writeLabeled(name, base, zonesRaw, outDir, fasciaRaw, jointsRaw, taxonomyForView) {
  const zones  = expand(zonesRaw);
  const fascia = expandFascia(fasciaRaw);
  const joints = expandJoints(jointsRaw);
  const body   = bodyMarkup(base, zones, fascia, joints);
  const { dx, dy, canvasW, canvasH } = LABEL_LAYOUT;

  const full = `<g transform="translate(${dx},${dy})">\n${body}\n</g>\n${labels(taxonomyForView)}`;
  fs.writeFileSync(`${outDir}/${name}_full_markup.txt`, DEFS + '\n' + full);

  const plain = `<!DOCTYPE html><html><head><style>${PREVIEW_CSS}${LABEL_CSS}svg{width:640px}</style></head><body><svg viewBox="0 0 ${canvasW} ${canvasH}">${DEFS}\n${full}</svg></body></html>`;
  fs.writeFileSync(`${outDir}/${name}_full.html`, plain);

  console.log(`${name}_full: ${zones.length} zones, ${taxonomyForView.length} label groups`);
}

module.exports = { expand, zoneToSvg, write, writeLabeled, labels, DEFS, REGIONS, LABEL_LAYOUT };
