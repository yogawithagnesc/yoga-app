// ============================================================
// LUMEN M7-4 — Prune anatomy.glb down to only Lumen-tracked meshes
//
// Removes any mesh not present in mesh-zone-map.js's MESH_TO_ZONE keys
// (the 135 of 467 meshes that correspond to a canonical Lumen `zone`).
// This both shrinks the asset substantially and avoids "dead clicks" —
// users tapping an untracked mesh (face muscles, hand/foot intrinsics,
// organs) that has no corresponding feeling-picker target.
//
// Must run BEFORE Draco compression (gltf-transform's Draco decoder
// isn't wired into this script's NodeIO instance).
//
// Usage: node tools/anatomy3d/prune_to_mapped_meshes.mjs <raw.glb> <out.glb>
// ============================================================
import { NodeIO } from '@gltf-transform/core';
import { prune } from '@gltf-transform/functions';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const [, , rawPath, outPath] = process.argv;
if (!rawPath || !outPath) {
  console.error('Usage: node prune_to_mapped_meshes.mjs <raw.glb> <out.glb>');
  process.exit(1);
}

const mapJs = fs.readFileSync(path.join(__dirname, 'mesh-zone-map.js'), 'utf8');
const match = mapJs.match(/window\.MESH_TO_ZONE = ({[\s\S]*?\n});/);
const meshToZone = JSON.parse(match[1]);
// mesh-zone-map.js keys are SANITIZED (three.js's GLTFLoader runtime
// transform — see generate_mesh_zone_map.cjs's note), but gltf-transform's
// NodeIO reads/writes the untouched glTF JSON, where mesh.getName() is still
// the RAW space-separated name. Sanitize identically here before comparing.
function sanitizeNodeName(name) {
  return name.replace(/\s/g, '_').replace(/[[\].:/]/g, '');
}
const keepNames = new Set(Object.keys(meshToZone));

const io = new NodeIO();
const doc = await io.read(rawPath);
const root = doc.getRoot();

let removed = 0;
for (const mesh of root.listMeshes()) {
  if (!keepNames.has(sanitizeNodeName(mesh.getName()))) { mesh.dispose(); removed++; }
}
await doc.transform(prune());
await io.write(outPath, doc);

console.log(`Kept ${keepNames.size} mapped meshes, removed ${removed} unmapped meshes.`);
console.log(`Wrote ${outPath}`);
