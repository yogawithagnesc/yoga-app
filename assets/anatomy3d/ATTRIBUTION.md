# Attribution — 3D Anatomy Model (M7-4/M7-5)

`muscles.glb` and `skeleton.glb` are derived from open-source anatomical
data, reprocessed by the
[BodyExplorer](https://github.com/JohanBellander/BodyExplorer) project
(MIT-licensed source code) from two upstream datasets. Per the terms of
those datasets, this attribution must be preserved wherever the model is
displayed or redistributed.

## Required credits

> **BodyParts3D**, © The Database Center for Life Science, licensed under
> [CC Attribution-Share Alike 2.1 Japan](https://creativecommons.org/licenses/by-sa/2.1/jp/)

> **Z-Anatomy** by Gauthier Kervyn, licensed under
> [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## What this means for Lumen

- The 3D mesh data (`muscles.glb`) is a **derivative work** under CC BY-SA —
  attribution is required (satisfied by this file + the in-app credit, see
  the anatomy modal's footer), and if the mesh file itself is redistributed
  it must remain under a compatible share-alike license.
- This does **not** affect Lumen's own application code, database schema, or
  unrelated assets — CC BY-SA's copyleft applies to the derivative mesh
  asset, not the surrounding codebase.
- Source processing pipeline: `tools/anatomy3d/build_anatomy_glb.sh`
  (fetches BodyExplorer's `public/anatomy.glb` + `public/skeleton.glb` and
  Draco-compresses both, preserving all individually-named meshes/bones).

## Provenance chain

1. **BodyParts3D** (401 meshes) + **Z-Anatomy** (66 meshes) — raw anatomical
   source data.
2. **BodyExplorer** (`JohanBellander/BodyExplorer`, MIT) — reprocessed,
   decimated (~4000 faces/mesh), and assembled into `anatomy.glb` (muscles)
   and `skeleton.glb` (201 named bones, M7-5).
3. **Lumen** (`tools/anatomy3d/build_anatomy_glb.sh`) — pruned to only
   Lumen-tracked meshes (muscles only; skeleton kept in full) and
   Draco-compressed for web delivery: muscles 25 MB → ~1.6 MB, skeleton
   9.8 MB → ~1.8 MB. No mesh merging or renaming.
