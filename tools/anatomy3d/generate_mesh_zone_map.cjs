#!/usr/bin/env node
// ============================================================
// LUMEN M7-4 — Mesh-to-Zone Taxonomy Mapper (generator)
//
// Produces `mesh-zone-map.js`, a data module mapping every
// clickable mesh name in assets/anatomy3d/muscles.glb to the
// exact canonical `zone` key Lumen already uses in
// practice_logs.muscle_feelings / recovery_logs.areas_treated
// (defined by MUSCLE_LIST in lumen-log-practice-3d.html).
//
// Run: node tools/anatomy3d/generate_mesh_zone_map.js
// (re-run whenever MUSCLE_LIST or the GLB source changes)
// ============================================================
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../..');
const LOG_PAGE = path.join(ROOT, 'lumen-log-practice-3d.html');
// Accepts an optional CLI arg for the source GLB (used by the build script
// to point at the *unpruned* raw download, since mesh names are identical
// pre/post-prune but pruning depends on this map already existing).
// Defaults to the committed asset for convenience when just refreshing the
// map against an unchanged mesh set.
const GLB_PATH = process.argv[2]
  ? path.resolve(process.argv[2])
  : path.join(ROOT, 'assets/anatomy3d/muscles.glb');
const OUT_PATH = path.join(__dirname, 'mesh-zone-map.js');
const REPORT_PATH = path.join(__dirname, 'mapping_coverage_report.txt');

// ── 1. Extract the authoritative MUSCLE_LIST from the live page ──
// (avoids hand-copied drift between this generator and the source of truth)
function extractMuscleList() {
  const html = fs.readFileSync(LOG_PAGE, 'utf8');
  const start = html.indexOf('const MUSCLE_LIST = {');
  if (start === -1) throw new Error('MUSCLE_LIST not found in ' + LOG_PAGE);
  // Find the matching closing brace for the object literal by bracket counting.
  let depth = 0, i = start + 'const MUSCLE_LIST = '.length, end = -1;
  for (; i < html.length; i++) {
    if (html[i] === '{') depth++;
    else if (html[i] === '}') { depth--; if (depth === 0) { end = i + 1; break; } }
  }
  const objLiteral = html.slice(start + 'const MUSCLE_LIST = '.length, end);
  // eslint-disable-next-line no-eval
  return eval('(' + objLiteral + ')');
}

const MUSCLE_LIST = extractMuscleList();

// Flatten to unique { zone, bilateral, label } entries (front/back share many).
const zoneEntries = new Map();
['front', 'back'].forEach(view => {
  MUSCLE_LIST[view].forEach(group => {
    group.items.forEach(item => {
      if (!zoneEntries.has(item.zone)) {
        zoneEntries.set(item.zone, { zone: item.zone, bilateral: item.bilateral, label: item.label });
      }
    });
  });
});
console.log(`Extracted ${zoneEntries.size} canonical zones from MUSCLE_LIST.`);

// ── 2. Read mesh names from the GLB ──
function readMeshNames(glbPath) {
  const buf = fs.readFileSync(glbPath);
  const jsonLen = buf.readUInt32LE(12);
  const g = JSON.parse(buf.slice(20, 20 + jsonLen).toString('utf8'));
  return (g.meshes || []).map(m => m.name).filter(Boolean);
}
const meshNames = readMeshNames(GLB_PATH);
console.log(`Read ${meshNames.length} mesh names from ${path.relative(ROOT, GLB_PATH)}.`);

// ── 3. Normalization + synonym handling ──
const SYNONYMS = {
  peroneus: 'fibularis', peroneal: 'fibularis',
  hallux: 'hallucis',
};
const FILLER_WORDS = new Set(['of', 'part', 'head', 'muscle', 'the']);

function tokenize(s) {
  return s
    .toLowerCase()
    .replace(/\(\d+\)/g, '')            // strip "(2)", "(3)" duplicate-instance suffixes
    .replace(/[^a-z ]/g, ' ')
    .split(/\s+/)
    .filter(Boolean)
    .map(t => SYNONYMS[t] || t);
}

function sideOf(tokens) {
  if (tokens.includes('left')) return 'L';
  if (tokens.includes('right')) return 'R';
  return null;
}

// Canonical signature: side-stripped, filler-stripped, sorted tokens.
function signature(tokens) {
  return tokens
    .filter(t => t !== 'left' && t !== 'right' && !FILLER_WORDS.has(t))
    .sort()
    .join(' ');
}

const meshRecords = meshNames.map(name => {
  const tokens = tokenize(name);
  return { name, tokens, side: sideOf(tokens), sig: signature(tokens) };
});

// ── 4. Match each zone against mesh records ──
// A zone's own tokens (from its label, which is closer to natural English
// than the sometimes-terse `zone` key, e.g. "Pectoralis Major (Sternal Head)")
// are compared against each mesh's normalized signature. A mesh matches if
// its signature's token set is a superset of the zone's core token set
// (handles "long head of biceps brachii" vs "Biceps Brachii Long Head" —
// same tokens, different order/filler words).
function zoneTokens(entry) {
  return tokenize(entry.label.replace(/[()]/g, ' '));
}

function matchesZone(meshSig, zoneToks) {
  const meshToks = new Set(meshSig.split(' ').filter(Boolean));
  return zoneToks.every(t => meshToks.has(t));
}

const meshToZone = {};   // mesh name -> canonical Lumen zone key (with L/R baked in if bilateral)
const coverage = [];     // report rows

// ── 4a. Explicit overrides ──
// A handful of Lumen zones use different terminology or are compound groups
// relative to the BodyParts3D/Z-Anatomy mesh names — anatomically real
// correspondences that plain token-matching can't discover automatically:
//   - Deltoid: Lumen tracks Anterior/Middle/Posterior heads; the mesh set
//     uses the standard anatomical part names Clavicular/Acromial/Spinal,
//     which correspond 1:1 to Anterior/Middle/Posterior respectively.
//   - Pectoralis Major "Sternal Head": the mesh's closest equivalent part
//     is "sternocostal" (its third part, "abdominal", isn't tracked by Lumen).
//   - Erector Spinae: a single Lumen zone standing in for the whole spinal
//     extensor group, which the mesh set names as separate constituent
//     muscles (iliocostalis/longissimus/spinalis, each per spinal region).
//   - Forearm Extensors: a generic Lumen catch-all for wrist/finger
//     extensors not already tracked as their own zone (Extensor Carpi
//     Ulnaris, Extensor Pollicis Brevis/Longus are separate Lumen zones —
//     excluded here to avoid one mesh feeding two zones).
const OVERRIDES = [
  { zone: 'Deltoid Anterior Head',  bilateral: true,  meshSigContains: ['clavicular', 'deltoid'] },
  { zone: 'Deltoid Middle Head',    bilateral: true,  meshSigContains: ['acromial', 'deltoid'] },
  { zone: 'Deltoid Posterior Head', bilateral: true,  meshSigContains: ['spinal', 'deltoid'] },
  { zone: 'Pectoralis Major Sternal Head', bilateral: true, meshSigContains: ['sternocostal', 'pectoralis', 'major'] },
  { zone: 'Erector Spinae', bilateral: false, meshSigContainsAny: [
    ['iliocostalis'], ['longissimus'], ['spinalis'],
  ] },
  { zone: 'Forearm Extensors', bilateral: true, meshSigContainsAny: [
    ['extensor', 'carpi', 'radialis', 'brevis'],
    ['extensor', 'carpi', 'radialis', 'longus'],
    ['extensor', 'digitorum'],   // NB: excludes "extensor digitorum longus" (foot) via exact-set check below
    ['extensor', 'indicis'],
  ] },
];

const overriddenMeshes = new Set(); // meshes claimed by an override, skipped by the automatic pass
const overrideZoneNames = new Set(OVERRIDES.map(o => o.zone));

function meshTokenSet(m) { return new Set(m.sig.split(' ').filter(Boolean)); }

OVERRIDES.forEach(ov => {
  const patterns = ov.meshSigContainsAny || [ov.meshSigContains];
  const hits = meshRecords.filter(m => {
    const toks = meshTokenSet(m);
    return patterns.some(pat => pat.every(t => toks.has(t)));
  });
  // Guard: "extensor digitorum" pattern must not accidentally catch
  // "extensor digitorum longus" (a separately-tracked foot muscle).
  const filtered = ov.zone === 'Forearm Extensors'
    ? hits.filter(m => !(meshTokenSet(m).has('longus') && meshTokenSet(m).has('digitorum')))
    : hits;

  filtered.forEach(h => overriddenMeshes.add(h.name));

  if (!filtered.length) {
    console.warn(`OVERRIDE MISS: no meshes matched for "${ov.zone}" — check anatomy.glb naming.`);
    coverage.push({ zone: ov.zone, bilateral: ov.bilateral, status: 'GAP', meshes: [] });
    return;
  }
  if (ov.bilateral) {
    filtered.filter(h => h.side === 'L').forEach(h => { meshToZone[h.name] = 'L ' + ov.zone; });
    filtered.filter(h => h.side === 'R').forEach(h => { meshToZone[h.name] = 'R ' + ov.zone; });
  } else {
    filtered.forEach(h => { meshToZone[h.name] = ov.zone; });
  }
  coverage.push({ zone: ov.zone, bilateral: ov.bilateral, status: 'OK (override)', meshes: filtered.map(h => h.name) });
});

zoneEntries.forEach(entry => {
  if (overrideZoneNames.has(entry.zone)) return; // handled by the override pass above
  const zToks = zoneTokens(entry).filter(t => !FILLER_WORDS.has(t));
  const hits = meshRecords.filter(m => matchesZone(m.sig, zToks));

  if (!hits.length) {
    coverage.push({ zone: entry.zone, bilateral: entry.bilateral, status: 'GAP', meshes: [] });
    return;
  }

  if (entry.bilateral) {
    const left = hits.filter(h => h.side === 'L');
    const right = hits.filter(h => h.side === 'R');
    left.forEach(h => { meshToZone[h.name] = 'L ' + entry.zone; });
    right.forEach(h => { meshToZone[h.name] = 'R ' + entry.zone; });
    const unsided = hits.filter(h => !h.side);
    coverage.push({
      zone: entry.zone, bilateral: true,
      status: (left.length && right.length) ? 'OK' : 'PARTIAL',
      meshes: hits.map(h => h.name),
      note: unsided.length ? `${unsided.length} unsided hit(s) ignored` : '',
    });
  } else {
    hits.forEach(h => { meshToZone[h.name] = entry.zone; });
    coverage.push({ zone: entry.zone, bilateral: false, status: 'OK', meshes: hits.map(h => h.name) });
  }
});

// ── 4b. Sanitize mesh names for the OUTPUT keys ──
// CRITICAL: three.js's GLTFLoader renames every loaded mesh/node via
// PropertyBinding.sanitizeNodeName() (createUniqueName(), called
// unconditionally during scene-graph construction — not just for animated
// models), converting whitespace to underscores and stripping [ ] . : /
// (source: three.js AnimationUtils — exact algorithm:
// `name.replace(/\s/g, '_').replace(/[\[\].:\/]/g, '')`). The raw glTF JSON
// mesh names (used above for matching, and by prune_to_mapped_meshes.mjs,
// which reads/writes the untouched glTF JSON) are NOT sanitized — only the
// live THREE.Mesh.name a raycaster hit-tests against. Without this step,
// every runtime raycast lookup into MESH_TO_ZONE would silently miss
// (mesh.name = "left_brachioradialis" but the map key would be
// "left brachioradialis" — no match, feature completely non-functional).
function sanitizeNodeName(name) {
  return name.replace(/\s/g, '_').replace(/[[\].:/]/g, '');
}
const sanitizedMeshToZone = {};
Object.entries(meshToZone).forEach(([rawName, zone]) => {
  sanitizedMeshToZone[sanitizeNodeName(rawName)] = zone;
});

// ── 5. Write outputs ──
const gapZones = coverage.filter(c => c.status === 'GAP').map(c => c.zone);
const partialZones = coverage.filter(c => c.status === 'PARTIAL').map(c => c.zone);

const header = `// ============================================================
// LUMEN M7-4 — Mesh-to-Zone Taxonomy Map (GENERATED — do not hand-edit)
//
// Generated by tools/anatomy3d/generate_mesh_zone_map.js from
// MUSCLE_LIST (lumen-log-practice-3d.html) + assets/anatomy3d/muscles.glb.
// Maps each clickable 3D mesh name -> the exact canonical \`zone\` key
// used throughout Lumen (practice_logs.muscle_feelings,
// recovery_logs.areas_treated, index.html's BODY_ZONE_MAP + rest engine).
//
// Known gaps (zones with no corresponding 3D mesh — tendon/fascia
// structures not present in this muscle-only mesh set; the 2D click-list
// remains the entry path for these): ${gapZones.join(', ') || 'none'}
${partialZones.length ? `//
// Partially-sided zones (matched on one side only — verify before
// treating as fully bilateral): ${partialZones.join(', ')}` : ''}
//
// Regenerate with: node tools/anatomy3d/generate_mesh_zone_map.js
// ============================================================
// Keys are sanitized (spaces -> underscores, [ ] . : / stripped) to match
// THREE.js GLTFLoader's PropertyBinding.sanitizeNodeName() transform applied
// to every loaded mesh's live .name at runtime. See note above for why.
window.MESH_TO_ZONE = ${JSON.stringify(sanitizedMeshToZone, null, 2)};

window.ANATOMY3D_GAPS = ${JSON.stringify(gapZones, null, 2)};
`;
fs.writeFileSync(OUT_PATH, header);

const reportLines = [
  `Mesh-to-Zone Mapping Coverage Report`,
  `Generated: ${new Date().toISOString()}`,
  `Zones: ${zoneEntries.size} | Mapped mesh entries: ${Object.keys(meshToZone).length} / ${meshNames.length} total meshes`,
  '',
  ...coverage.map(c => `[${c.status}]${c.note ? ' (' + c.note + ')' : ''} ${c.zone}${c.bilateral ? ' (bilateral)' : ''} <- ${c.meshes.length} mesh(es)${c.meshes.length ? ': ' + c.meshes.slice(0, 3).join(' | ') + (c.meshes.length > 3 ? ' | …' : '') : ''}`),
];
fs.writeFileSync(REPORT_PATH, reportLines.join('\n'));

console.log(`\nOK: ${coverage.filter(c => c.status === 'OK').length} / ${coverage.length} zones fully mapped.`);
console.log(`PARTIAL: ${partialZones.length ? partialZones.join(', ') : 'none'}`);
console.log(`GAP (no 3D mesh — 2D fallback only): ${gapZones.length ? gapZones.join(', ') : 'none'}`);
console.log(`\nWrote ${path.relative(ROOT, OUT_PATH)} and ${path.relative(ROOT, REPORT_PATH)}`);
