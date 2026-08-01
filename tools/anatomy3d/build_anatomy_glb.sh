#!/usr/bin/env bash
# ============================================================
# LUMEN M7-4/M7-5 — Anatomy 3D Asset Build Pipeline
#
# Reproduces assets/anatomy3d/{muscles,skeleton}.glb + mesh-zone-map.js
# from BodyExplorer's open-source anatomy meshes (MIT code, CC BY-SA
# data — see assets/anatomy3d/ATTRIBUTION.md).
#
# Source: https://github.com/JohanBellander/BodyExplorer
#   public/anatomy.glb   — 467 individually-named muscle/tendon meshes,
#     built from BodyParts3D + Z-Anatomy data, already decimated to
#     ~4000 faces/mesh by the upstream project.
#   public/skeleton.glb  — 201 individually-named bones (M7-5). Kept in
#     full (not pruned to a Lumen taxonomy — bones are a visual-context
#     layer only, not individually clickable/feeling-trackable).
#
# Pipeline (muscles):
#   1. Fetch the raw anatomy.glb (~25 MB).
#   2. Generate mesh-zone-map.js — maps mesh names -> Lumen's canonical
#      `zone` keys (reads MUSCLE_LIST from lumen-log-practice-3d.html).
#   3. Prune the raw GLB down to only the meshes the map actually uses
#      (135 of 467 — the rest are untracked structures like face
#      muscles/hand-foot intrinsics/organs that have no Lumen zone and
#      would just be dead clicks).
#   4. Draco-compress the pruned GLB (mesh-name-preserving — NOT the
#      full gltf-transform "optimize" preset, whose `join` step merges
#      meshes and destroys the per-muscle names click-select depends on).
#
# Pipeline (skeleton, M7-5):
#   5. Fetch the raw skeleton.glb (~9.8 MB) and Draco-compress directly
#      (no pruning needed — no click resolution required for bones).
#
# Result: muscles ~25 MB -> ~1.6 MB, skeleton ~9.8 MB -> ~1.8 MB — both
# comfortably under the 16 MB ceiling that got the old Sketchfab 3D
# model retired (see WORKPLAN.md M3 / Lumen_PRD.md), and both lazy-
# loaded independently so the default 3D-view cost stays ~1.6 MB unless
# the user explicitly toggles the skeleton layer on.
#
# Requirements: node + npx.
# Usage: bash tools/anatomy3d/build_anatomy_glb.sh
# ============================================================
set -euo pipefail

SRC_URL="https://raw.githubusercontent.com/JohanBellander/BodyExplorer/main/public/anatomy.glb"
SKELETON_SRC_URL="https://raw.githubusercontent.com/JohanBellander/BodyExplorer/main/public/skeleton.glb"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$(cd "$TOOLS_DIR/../.." && pwd)/assets/anatomy3d"
RAW_GLB="/tmp/lumen_anatomy_raw.glb"
PRUNED_RAW_GLB="/tmp/lumen_anatomy_pruned_raw.glb"
OUT_GLB="$OUT_DIR/muscles.glb"
SKELETON_RAW_GLB="/tmp/lumen_skeleton_raw.glb"
SKELETON_OUT_GLB="$OUT_DIR/skeleton.glb"

mkdir -p "$OUT_DIR"

echo "[1/5] Fetching upstream anatomy.glb (~25 MB)…"
curl -sSL -o "$RAW_GLB" "$SRC_URL"
ls -lh "$RAW_GLB"

echo "[2/5] Generating mesh-zone-map.js from raw mesh names + MUSCLE_LIST…"
node "$TOOLS_DIR/generate_mesh_zone_map.cjs" "$RAW_GLB"
cp "$TOOLS_DIR/mesh-zone-map.js" "$OUT_DIR/mesh-zone-map.js"

if [ ! -d "$TOOLS_DIR/node_modules" ]; then
  echo "Installing build-time-only dependencies (tools/anatomy3d/package.json)…"
  (cd "$TOOLS_DIR" && npm install)
fi

echo "[3/5] Pruning to only Lumen-mapped meshes…"
(cd "$TOOLS_DIR" && node prune_to_mapped_meshes.mjs "$RAW_GLB" "$PRUNED_RAW_GLB")
ls -lh "$PRUNED_RAW_GLB"

echo "[4/5] Draco-compressing muscles (mesh-name-preserving; no join/simplify)…"
(cd "$TOOLS_DIR" && npx --no-install @gltf-transform/cli draco "$PRUNED_RAW_GLB" "$OUT_GLB")
ls -lh "$OUT_GLB"

echo "[5/5] Fetching + compressing skeleton.glb (~9.8 MB, kept in full — 201 bones)…"
curl -sSL -o "$SKELETON_RAW_GLB" "$SKELETON_SRC_URL"
(cd "$TOOLS_DIR" && npx --no-install @gltf-transform/cli draco "$SKELETON_RAW_GLB" "$SKELETON_OUT_GLB")
ls -lh "$SKELETON_OUT_GLB"

echo "→ Verifying final mesh count matches the map…"
node -e '
  const fs = require("fs");
  const buf = fs.readFileSync(process.argv[1]);
  const len = buf.readUInt32LE(12);
  const g = JSON.parse(buf.slice(20, 20 + len).toString("utf8"));
  const mapJs = fs.readFileSync(process.argv[2], "utf8");
  const mapCount = Object.keys(JSON.parse(mapJs.match(/window\.MESH_TO_ZONE = (\{[\s\S]*?\n\});/)[1])).length;
  console.log("GLB meshes:", (g.meshes || []).length, "| Map entries:", mapCount);
  if ((g.meshes || []).length !== mapCount) {
    console.error("MISMATCH — investigate before committing.");
    process.exit(1);
  }
  console.log("OK — counts match.");
' "$OUT_GLB" "$OUT_DIR/mesh-zone-map.js"

echo "Done. Commit assets/anatomy3d/{muscles,skeleton}.glb + mesh-zone-map.js."
