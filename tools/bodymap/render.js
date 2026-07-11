const fs = require('fs');
const { mirrorPathD } = require('./gen2.js');

// Shared defs for the M3a anatomical material system. Kept here so the
// preview pages and the integration snippet stay in lockstep.
// - muscleGrad: crimson/burgundy muscle belly (objectBoundingBox → each
//   path gets its own volume highlight)
// - fasciaGrad: silver-gray tendon/fascia
// - chisel: specular rim-lighting emboss (light from top-left)
const DEFS = `<defs>
<radialGradient id="muscleGrad" cx="40%" cy="30%" r="75%">
  <stop offset="0%" stop-color="#8E332C"/>
  <stop offset="50%" stop-color="#68201E"/>
  <stop offset="100%" stop-color="#380D0D"/>
</radialGradient>
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
// Each entry: { name, d, fib? } (path) or { name, ellipse:[cx,cy,rx,ry], fib? }.
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

function zoneToSvg(z, attrs) {
  // Tendon-like zones (IT band, Achilles) stay tappable but render with
  // the silvery fascia material via the extra svgm-t class.
  if (!attrs) attrs = `class="${z.tendon ? 'svgm svgm-t' : 'svgm'}"`;
  if (z.ellipse) {
    const [cx,cy,rx,ry] = z.ellipse;
    return `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" ${attrs} data-z="${z.name}"/>`;
  }
  return `<path d="${z.d}" ${attrs} data-z="${z.name}"/>`;
}

// Assemble body markup: base silhouette → zones → fascia seams over the
// muscles (tendinous insertions read on top; pointer-events:none keeps
// every zone tappable) → striation fibers on top.
function bodyMarkup(base, zones, fascia) {
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
  return parts.join('\n');
}

// CSS matching the live page's material treatment, for previews.
const PREVIEW_CSS = `
  body{background:#080807;margin:0;padding:20px}
  svg{width:460px;height:auto;background:#111110}
  .svgm-bg{fill:#3A1210}
  .svgm{fill:url(#muscleGrad);stroke:#2A0A0B;stroke-width:0.7;cursor:pointer;filter:url(#chisel)}
  .svgm.svgm-t{fill:url(#fasciaGrad);stroke:#6E6A60}
  .svgm:hover{filter:url(#chisel) brightness(1.3)}
  .svgm-fascia path{fill:url(#fasciaGrad);stroke:#6E6A60;stroke-width:0.3;opacity:0.85}
  .svgm-fibers path{fill:none;stroke:#1E0708;stroke-width:0.5;opacity:0.4}
`;

function write(name, base, zonesRaw, outDir, fasciaRaw) {
  const zones  = expand(zonesRaw);
  const fascia = expandFascia(fasciaRaw);
  const body   = bodyMarkup(base, zones, fascia);

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

  console.log(`${name}: ${zones.length} zones, ${fascia.length} fascia, ${zones.filter(z=>z.fib).length} fibered`);
  return zones;
}

module.exports = { expand, zoneToSvg, write, DEFS };
