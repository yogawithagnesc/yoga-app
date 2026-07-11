// Anatomical shape toolkit for the Lumen body map.
// All coords in the 240x580 viewBox, midline x=120.

// Tapered capsule (blunt rounded ends) — for whole-limb segments.
function capsulePath(x1, y1, r1, x2, y2, r2) {
  const dx = x2 - x1, dy = y2 - y1;
  const d = Math.sqrt(dx*dx + dy*dy);
  const theta = Math.atan2(dy, dx);
  let ratio = (r1 - r2) / d;
  ratio = Math.max(-1, Math.min(1, ratio));
  const beta = Math.asin(ratio);
  const a1 = theta + Math.PI/2 - beta;
  const a2 = theta - Math.PI/2 + beta;
  const p1a = [x1 + r1*Math.cos(a1), y1 + r1*Math.sin(a1)];
  const p1b = [x1 + r1*Math.cos(a2), y1 + r1*Math.sin(a2)];
  const p2a = [x2 + r2*Math.cos(a1), y2 + r2*Math.sin(a1)];
  const p2b = [x2 + r2*Math.cos(a2), y2 + r2*Math.sin(a2)];
  return `M${p1a[0].toFixed(1)},${p1a[1].toFixed(1)} L${p2a[0].toFixed(1)},${p2a[1].toFixed(1)} A${r2},${r2} 0 0 0 ${p2b[0].toFixed(1)},${p2b[1].toFixed(1)} L${p1b[0].toFixed(1)},${p1b[1].toFixed(1)} A${r1},${r1} 0 0 0 ${p1a[0].toFixed(1)},${p1a[1].toFixed(1)} Z`;
}

// Muscle belly / spindle — bulges to half-width `wm` at the midpoint,
// tapers to (optionally rounded) points at each end. Great for
// sartorius, biceps, vastus, hamstring heads, etc.
// bulge=0.5 centers the belly; <0.5 pushes it toward the start.
function spindle(x1, y1, x2, y2, wm, bulge = 0.5, endTaper = 1) {
  const dx = x2 - x1, dy = y2 - y1;
  const len = Math.sqrt(dx*dx + dy*dy);
  const ux = dx/len, uy = dy/len;      // axis unit
  const px = -uy, py = ux;             // perpendicular unit
  const b = bulge;
  // control points at 1/3 and 2/3 along, offset by wm (belly skewed by bulge)
  const cAf = Math.max(0.15, b - 0.18), cBf = Math.min(0.85, b + 0.18);
  const cAx = x1 + ux*len*cAf, cAy = y1 + uy*len*cAf;
  const cBx = x1 + ux*len*cBf, cBy = y1 + uy*len*cBf;
  const f = (n) => n.toFixed(1);
  // left side start->end, right side end->start
  return `M${f(x1)},${f(y1)} `
       + `C${f(cAx+px*wm)},${f(cAy+py*wm)} ${f(cBx+px*wm)},${f(cBy+py*wm)} ${f(x2)},${f(y2)} `
       + `C${f(cBx-px*wm)},${f(cBy-py*wm)} ${f(cAx-px*wm)},${f(cAy-py*wm)} ${f(x1)},${f(y1)} Z`;
}

// Teardrop — one blunt (rounded) end at (x1,y1) radius r, tapering to a
// point at (x2,y2). For deltoids, glute max, gastro heads.
function teardrop(x1, y1, r, x2, y2) {
  const dx = x2 - x1, dy = y2 - y1;
  const len = Math.sqrt(dx*dx + dy*dy);
  const ux = dx/len, uy = dy/len;
  const px = -uy, py = ux;
  const f = (n) => n.toFixed(1);
  const sL = [x1 + px*r, y1 + py*r];
  const sR = [x1 - px*r, y1 - py*r];
  const cL = [x1 + ux*len*0.4 + px*r*1.05, y1 + uy*len*0.4 + py*r*1.05];
  const cR = [x1 + ux*len*0.4 - px*r*1.05, y1 + uy*len*0.4 - py*r*1.05];
  // round cap behind start
  const capL = [x1 + px*r - ux*r*0.9, y1 + py*r - uy*r*0.9];
  const capR = [x1 - px*r - ux*r*0.9, y1 - py*r - uy*r*0.9];
  return `M${f(sL[0])},${f(sL[1])} `
       + `C${f(cL[0])},${f(cL[1])} ${f(x2)},${f(y2)} ${f(x2)},${f(y2)} `
       + `C${f(x2)},${f(y2)} ${f(cR[0])},${f(cR[1])} ${f(sR[0])},${f(sR[1])} `
       + `C${f(capR[0])},${f(capR[1])} ${f(capL[0])},${f(capL[1])} ${f(sL[0])},${f(sL[1])} Z`;
}

// ── STRIATION FIBERS ─────────────────────────────────────────
// A set of interior fiber lines running along a muscle's axis, for the
// M3a anatomical texture layer. Returns ONE path string containing n
// open subpaths (M + C, no Z) — render as stroke-only, fill:none.
//   (x1,y1)->(x2,y2): the muscle axis (same endpoints you gave the
//   shape generator). w1/w2: half-widths at start/end. bow: extra
//   sideways bulge at the midpoint (mimics spindle belly; 0 = straight).
//   inset: fraction of length to pull fibers in from each end.
function fiberSet(x1, y1, x2, y2, w1, w2, n = 4, bow = 0, inset = 0.08) {
  const dx = x2 - x1, dy = y2 - y1;
  const len = Math.sqrt(dx*dx + dy*dy);
  const ux = dx/len, uy = dy/len;
  const px = -uy, py = ux;
  const f = (v) => v.toFixed(1);
  const subs = [];
  for (let i = 0; i < n; i++) {
    const t = n === 1 ? 0 : (i/(n-1))*1.6 - 0.8;   // spread in [-0.8, 0.8]
    const sx = x1 + ux*len*inset + px*t*w1, sy = y1 + uy*len*inset + py*t*w1;
    const ex = x2 - ux*len*inset + px*t*w2, ey = y2 - uy*len*inset + py*t*w2;
    const mw = t*(w1+w2)/2 + (t >= 0 ? 1 : -1)*Math.abs(t)*bow;
    const c1x = x1 + ux*len*0.35 + px*mw, c1y = y1 + uy*len*0.35 + py*mw;
    const c2x = x1 + ux*len*0.65 + px*mw, c2y = y1 + uy*len*0.65 + py*mw;
    subs.push(`M${f(sx)},${f(sy)} C${f(c1x)},${f(c1y)} ${f(c2x)},${f(c2y)} ${f(ex)},${f(ey)}`);
  }
  return subs.join(' ');
}

// Fibers matched to each shape generator (same params → interior lines).
function spindleFibers(x1, y1, x2, y2, wm, bulge = 0.5, n = 4) {
  return fiberSet(x1, y1, x2, y2, wm*0.55, wm*0.55, n, wm*0.28);
}
function teardropFibers(x1, y1, r, x2, y2, n = 4) {
  return fiberSet(x1, y1, x2, y2, r*0.7, r*0.12, n, 0, 0.1);
}
function capsuleFibers(x1, y1, r1, x2, y2, r2, n = 4) {
  return fiberSet(x1, y1, x2, y2, r1*0.65, r2*0.65, n, 0);
}

// Radiating tendon-fiber burst at a joint (knee/ankle/wrist/elbow) — a
// small ring of short radial lines mimicking fibrous tendon attachment.
// Returns ONE path string of n open subpaths, stroke-only.
function jointTendon(cx, cy, r, n = 8, innerR = 0.35) {
  const f = (v) => v.toFixed(1);
  const subs = [];
  for (let i = 0; i < n; i++) {
    const a = (i / n) * Math.PI * 2;
    const ix = cx + Math.cos(a) * r * innerR, iy = cy + Math.sin(a) * r * innerR;
    const ox = cx + Math.cos(a) * r, oy = cy + Math.sin(a) * r;
    subs.push(`M${f(ix)},${f(iy)} L${f(ox)},${f(oy)}`);
  }
  return subs.join(' ');
}

// Mirror a path across the vertical axis x=CX. Handles M/L/C (coordinate
// pairs) and A (elliptical arc: flip endpoint x, negate rotation, flip the
// sweep flag). Only absolute commands are used by our generators.
function mirrorPathD(d, CX = 120) {
  const fx = (x) => (CX*2 - x).toFixed(1);
  const tokens = d.match(/[MLCAZ]|-?\d*\.?\d+/g) || [];
  const out = [];
  let i = 0;
  while (i < tokens.length) {
    const cmd = tokens[i++];
    if (cmd === 'Z') { out.push('Z'); continue; }
    if (cmd === 'M' || cmd === 'L') {
      const x = +tokens[i++], y = +tokens[i++];
      out.push(`${cmd}${fx(x)},${y}`);
    } else if (cmd === 'C') {
      const c = [];
      for (let k=0;k<3;k++){ const x=+tokens[i++], y=+tokens[i++]; c.push(`${fx(x)},${y}`); }
      out.push('C' + c.join(' '));
    } else if (cmd === 'A') {
      const rx=tokens[i++], ry=tokens[i++], rot=+tokens[i++], large=tokens[i++], sweep=tokens[i++];
      const x=+tokens[i++], y=+tokens[i++];
      out.push(`A${rx},${ry} ${(-rot)} ${large} ${sweep==='1'?'0':'1'} ${fx(x)},${y}`);
    }
  }
  return out.join(' ');
}

module.exports = { capsulePath, spindle, teardrop, mirrorPathD,
                   fiberSet, spindleFibers, teardropFibers, capsuleFibers, jointTendon };
