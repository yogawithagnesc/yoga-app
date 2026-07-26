// ============================================================
// LUMEN M7-4/M7-5 — Interactive 3D Anatomy Viewer
//
// A reusable THREE.js body-map component shared by
// lumen-log-practice-3d.html and lumen-log-recovery.html (mirrors
// how those two pages already share the M3c 2D reference-photo +
// click-list component).
//
// Loaded as an ES module (needed for GLTFLoader/OrbitControls, which
// three.js only ships as ES modules) alongside the host pages' classic
// <script> blocks. Since module scope doesn't share globals with
// classic scripts, this file exposes a small bridge API on
// `window.LumenAnatomyViewer` — the host page's classic script calls
// into that, and this module calls back into host-provided callbacks
// (onZoneTap, getFeelingColor) so the SAME feeling-picker UI, save/edit
// logic, and per-page color palette (practice's 7-state FEELINGS vs.
// recovery's 4-state RELIEF) keep working untouched. The 3D viewer is
// purely an alternate INPUT method — it never duplicates that logic.
//
// Assets: muscles.glb (135 individually-named muscle meshes) +
// skeleton.glb (201 named bones, M7-5), both pruned/Draco-compressed
// from BodyExplorer/Z-Anatomy/BodyParts3D — see ATTRIBUTION.md.
// mesh-zone-map.js resolves each muscle mesh name to the exact
// canonical `zone` key used everywhere else in the app, and classifies
// each zone as 'superficial' or 'deep' (MUSCLE_LAYER) so the viewer can
// offer a real anatomical layering — peel back the superficial muscles
// to reveal what's underneath, same as an anatomy atlas.
//
// Lazy-loaded: nothing downloads until mount() is called (muscles) or a
// layer is actually toggled on (skeleton) — the old retired 3D model
// was pulled from the default path for loading 16 MB unconditionally.
// ============================================================
// Bare specifiers ('three', 'three/addons/…') — GLTFLoader/OrbitControls
// internally import 'three' the same way, so resolution depends on an
// <script type="importmap"> in the HOST PAGE mapping those specifiers to
// the CDN (see the importmap block added alongside this script's
// script-src tag in lumen-log-practice-3d.html / lumen-log-recovery.html).
// This file does not (and cannot) define its own import map — that has
// to live in the document that loads it.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const ASSET_BASE = 'assets/anatomy3d/';
const GLB_URL = ASSET_BASE + 'muscles.glb';
const SKELETON_URL = ASSET_BASE + 'skeleton.glb';
const DRACO_DECODER_URL = 'https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/libs/draco/';

// Superficial vs. deep get distinct base tones (independent of the
// feeling/relief color overlay) so the two layers read as anatomically
// different tissue even before any toggle is touched — deep muscles
// look like the more vascular, deeper-red tissue they anatomically are.
const SUPERFICIAL_COLOR = 0xc9a98a; // warm neutral tan
const DEEP_COLOR = 0xa8594f;        // deeper red-brown ("raw muscle" tone)
const HOVER_EMISSIVE = 0x332211;
const BONE_COLOR = 0xe8dfc8;        // ivory/bone tone
const MUSCLE_OPACITY_WITH_SKELETON = 0.4; // see-through so bones show underneath

// Loaded once per page (not per mount) — GLTFLoader result is reused if the
// viewer is closed and reopened in the same session. Muscles and skeleton
// are cached independently since skeleton is opt-in (layer toggle).
let _cachedMuscleScene = null;
let _muscleLoadPromise = null;
let _cachedSkeletonScene = null;
let _skeletonLoadPromise = null;

function makeLoader() {
  const dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath(DRACO_DECODER_URL);
  const loader = new GLTFLoader();
  loader.setDRACOLoader(dracoLoader);
  return loader;
}

function loadModel() {
  if (_cachedMuscleScene) return Promise.resolve(_cachedMuscleScene);
  if (_muscleLoadPromise) return _muscleLoadPromise;
  _muscleLoadPromise = new Promise((resolve, reject) => {
    makeLoader().load(
      GLB_URL,
      (gltf) => { _cachedMuscleScene = gltf.scene; resolve(gltf.scene); },
      undefined,
      (err) => reject(err)
    );
  });
  return _muscleLoadPromise;
}

// M7-5: skeleton is only fetched the first time a viewer instance actually
// enables the skeleton layer — most sessions never touch it.
function loadSkeleton() {
  if (_cachedSkeletonScene) return Promise.resolve(_cachedSkeletonScene);
  if (_skeletonLoadPromise) return _skeletonLoadPromise;
  _skeletonLoadPromise = new Promise((resolve, reject) => {
    makeLoader().load(
      SKELETON_URL,
      (gltf) => { _cachedSkeletonScene = gltf.scene; resolve(gltf.scene); },
      undefined,
      (err) => reject(err)
    );
  });
  return _skeletonLoadPromise;
}

// mesh-zone-map.js sets window.MESH_TO_ZONE / ANATOMY3D_GAPS / MUSCLE_LAYER
// as a classic (non-module) script; fetch+eval it here as a one-time side
// effect so both this module and the host page's classic script can read it.
let _mapLoaded = false;
function ensureMapLoaded() {
  if (_mapLoaded || window.MESH_TO_ZONE) { _mapLoaded = true; return Promise.resolve(); }
  return fetch(ASSET_BASE + 'mesh-zone-map.js')
    .then((r) => r.text())
    .then((src) => { (0, eval)(src); _mapLoaded = true; }); // runs in global scope
}

/**
 * Mount a 3D anatomy viewer into `container`.
 * @param {HTMLElement} container - element to render into (should have explicit size via CSS)
 * @param {object} callbacks
 * @param {(zone: string, label: string) => void} callbacks.onZoneTap - called when a mapped mesh is clicked
 * @param {(feeling: string) => string|null} callbacks.getFeelingColor - hex color string (e.g. '#C77B4A') for a feeling key, or null
 * @param {() => Record<string,string>} callbacks.getMuscleStates - returns the host's current { zone: feeling } map
 * @returns {Promise<{
 *   setView(view:'front'|'back'):void, refresh():void, resize():void, dispose():void,
 *   setSkeletonVisible(show:boolean):Promise<void>, setDeepLayerOnly(show:boolean):void
 * }>}
 */
function mount(container, callbacks) {
  return Promise.all([loadModel(), ensureMapLoaded()]).then(([sourceScene]) => {
    const scene = new THREE.Scene();
    scene.background = null; // transparent — inherits the host page's dark background

    const width = container.clientWidth || 320;
    const height = container.clientHeight || 420;

    const camera = new THREE.PerspectiveCamera(35, width / height, 1, 5000);

    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(width, height);
    container.innerHTML = '';
    container.appendChild(renderer.domElement);

    // Lighting: key + fill + a subtle back rim light. The rim light is what
    // actually reads as "anatomical form" rather than a flat plastic blob —
    // it catches the edges of muscle bellies and separates overlapping
    // structures visually, similar to how anatomy-atlas photography is lit.
    scene.add(new THREE.AmbientLight(0xffffff, 0.55));
    const key = new THREE.DirectionalLight(0xffffff, 0.95);
    key.position.set(2, 3, 4);
    scene.add(key);
    const fill = new THREE.DirectionalLight(0xffffff, 0.35);
    fill.position.set(-3, 1, -2);
    scene.add(fill);
    const rim = new THREE.DirectionalLight(0xfff0e0, 0.55);
    rim.position.set(-1, 2, -4);
    scene.add(rim);

    // Clone the cached scene per mount so multiple opens don't share mutated
    // materials, and so disposing one viewer instance never breaks another.
    const model = sourceScene.clone(true);

    // Source data (BodyParts3D/Z-Anatomy) is authored Z-up (a common medical/
    // CAD convention); three.js is Y-up by default. Without this correction
    // the body renders lying "on its side" relative to the camera. Rotating
    // -90° about X maps the tall Z axis onto Y (verified against the raw
    // mesh bounding box: ~1577 units tall vs ~639 wide — a plausible human
    // height:width ratio only once Z becomes the vertical axis).
    model.rotation.x = -Math.PI / 2;

    const meshByName = new Map();
    model.traverse((node) => {
      if (!node.isMesh) return;
      // Give every mesh its own material instance — required since each
      // mesh's color/opacity is independently driven by its feeling state
      // and layer (superficial/deep).
      node.material = new THREE.MeshStandardMaterial({
        color: SUPERFICIAL_COLOR, roughness: 0.6, metalness: 0.05,
      });
      meshByName.set(node.name, node);
    });
    scene.add(model);

    // Frame the camera on the model's bounding box.
    const box = new THREE.Box3().setFromObject(model);
    const size = box.getSize(new THREE.Vector3());
    const center = box.getCenter(new THREE.Vector3());
    const maxDim = Math.max(size.x, size.y, size.z);
    const dist = maxDim * 1.6;
    camera.position.set(center.x, center.y, center.z + dist);
    camera.near = dist / 100;
    camera.far = dist * 10;
    camera.updateProjectionMatrix();

    const controls = new OrbitControls(camera, renderer.domElement);
    controls.target.copy(center);
    controls.enableDamping = true;
    controls.dampingFactor = 0.08;
    controls.minDistance = dist * 0.4;
    controls.maxDistance = dist * 2.5;
    controls.update();

    // ── M7-5: SKELETON LAYER (lazy-loaded on first toggle-on) ──
    // Mounted as a sibling of `model` under the same rotation so it shares
    // the muscle mesh's coordinate frame (verified: both assets come from
    // the same source pipeline and share bounding-box origin/scale/axes).
    let skeletonGroup = null;
    let skeletonVisible = false;

    function setSkeletonVisible(show) {
      skeletonVisible = show;
      if (!show) {
        if (skeletonGroup) skeletonGroup.visible = false;
        setMusclesTranslucent(false);
        return Promise.resolve();
      }
      setMusclesTranslucent(true);
      if (skeletonGroup) { skeletonGroup.visible = true; return Promise.resolve(); }
      return loadSkeleton().then((skeletonSource) => {
        skeletonGroup = skeletonSource.clone(true);
        skeletonGroup.rotation.x = -Math.PI / 2;
        skeletonGroup.traverse((node) => {
          if (!node.isMesh) return;
          node.material = new THREE.MeshStandardMaterial({
            color: BONE_COLOR, roughness: 0.5, metalness: 0.1,
          });
        });
        scene.add(skeletonGroup);
      }).catch((err) => {
        console.error('Skeleton layer failed to load:', err);
        skeletonVisible = false;
        setMusclesTranslucent(false);
      });
    }

    function setMusclesTranslucent(translucent) {
      meshByName.forEach((mesh) => {
        mesh.material.transparent = translucent;
        mesh.material.opacity = translucent ? MUSCLE_OPACITY_WITH_SKELETON : 1;
      });
    }

    // ── M7-5: SUPERFICIAL / DEEP LAYER TOGGLE ──
    // Hiding (not just fading) superficial meshes means the raycaster
    // naturally skips them too (three.js's Raycaster respects .visible),
    // so click-to-select automatically re-targets the now-exposed deep
    // muscles with no extra filtering logic needed.
    let deepLayerOnly = false;
    function setDeepLayerOnly(show) {
      deepLayerOnly = show;
      meshByName.forEach((mesh, name) => {
        const zone = window.MESH_TO_ZONE[name];
        const layer = zone && window.MUSCLE_LAYER ? window.MUSCLE_LAYER[zone] : 'superficial';
        mesh.visible = !show || layer === 'deep';
      });
    }

    // ── Click-to-select (movement-threshold click-vs-drag, matching the
    // codebase's existing pointer-capture discipline — see CLAUDE.md's
    // note on deferring pointer capture until real dragging is confirmed) ──
    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    let downPos = null;

    function setPointerFromEvent(ev) {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((ev.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((ev.clientY - rect.top) / rect.height) * 2 + 1;
    }

    function onPointerDown(ev) { downPos = { x: ev.clientX, y: ev.clientY }; }

    function onPointerUp(ev) {
      if (!downPos) return;
      const moved = Math.hypot(ev.clientX - downPos.x, ev.clientY - downPos.y);
      downPos = null;
      if (moved > 6) return; // treated as an orbit drag, not a tap

      setPointerFromEvent(ev);
      raycaster.setFromCamera(pointer, camera);
      // Only the muscle mesh is clickable — the skeleton is visual context.
      // NOTE: three.js's Raycaster only checks object.layers, never
      // .visible (a real, easy-to-miss API characteristic — see
      // three.js's core/Raycaster.js intersectObject()). Meshes hidden by
      // setDeepLayerOnly() would otherwise still register hits, so we must
      // filter by .visible ourselves to make hiding actually exclude a mesh
      // from click-selection, not just from rendering.
      const hits = raycaster.intersectObjects(model.children, true).filter((h) => h.object.visible);
      if (!hits.length) return;

      const mesh = hits[0].object;
      const zone = window.MESH_TO_ZONE && window.MESH_TO_ZONE[mesh.name];
      if (!zone) return; // shouldn't happen post-pruning, but stay defensive

      // mesh.name is sanitized by GLTFLoader (spaces -> underscores); undo
      // that for a human-readable label in the feeling-picker UI.
      const displayLabel = mesh.name.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
      callbacks.onZoneTap(zone, displayLabel);
    }

    renderer.domElement.addEventListener('pointerdown', onPointerDown);
    renderer.domElement.addEventListener('pointerup', onPointerUp);

    // ── Recolor meshes from the host's current muscleStates + layer tone ──
    function refresh() {
      const states = callbacks.getMuscleStates() || {};
      meshByName.forEach((mesh, name) => {
        const zone = window.MESH_TO_ZONE[name];
        const feeling = zone ? states[zone] : null;
        const hex = feeling ? callbacks.getFeelingColor(feeling) : null;
        const layer = zone && window.MUSCLE_LAYER ? window.MUSCLE_LAYER[zone] : 'superficial';
        const baseColor = layer === 'deep' ? DEEP_COLOR : SUPERFICIAL_COLOR;
        mesh.material.color.set(hex || baseColor);
        mesh.material.emissive.set(hex ? HOVER_EMISSIVE : 0x000000);
      });
    }
    refresh();

    // ── Front/back quick-look presets (parity with the 2D toggle; users can
    // still freely orbit — these are just camera shortcuts, not separate assets) ──
    function setView(view) {
      const z = view === 'back' ? -dist : dist;
      const targetPos = new THREE.Vector3(center.x, center.y, center.z + z);
      camera.position.copy(targetPos);
      controls.update();
    }

    let rafId = null;
    function animate() {
      rafId = requestAnimationFrame(animate);
      controls.update();
      renderer.render(scene, camera);
    }
    animate();

    function resize() {
      const w = container.clientWidth || width;
      const h = container.clientHeight || height;
      camera.aspect = w / h;
      camera.updateProjectionMatrix();
      renderer.setSize(w, h);
    }

    function dispose() {
      cancelAnimationFrame(rafId);
      renderer.domElement.removeEventListener('pointerdown', onPointerDown);
      renderer.domElement.removeEventListener('pointerup', onPointerUp);
      controls.dispose();
      meshByName.forEach((mesh) => {
        mesh.geometry && mesh.geometry.dispose();
        mesh.material && mesh.material.dispose();
      });
      if (skeletonGroup) {
        skeletonGroup.traverse((node) => {
          if (!node.isMesh) return;
          node.geometry && node.geometry.dispose();
          node.material && node.material.dispose();
        });
      }
      renderer.dispose();
      container.innerHTML = '';
    }

    return { setView, refresh, resize, dispose, setSkeletonVisible, setDeepLayerOnly };
  });
}

window.LumenAnatomyViewer = { mount };
