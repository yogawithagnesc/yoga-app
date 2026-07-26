// ============================================================
// LUMEN M7-4 — Interactive 3D Anatomy Viewer
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
// Asset: muscles.glb (135 individually-named muscle meshes, pruned +
// Draco-compressed from BodyExplorer/Z-Anatomy/BodyParts3D — see
// ATTRIBUTION.md). mesh-zone-map.js resolves each mesh name to the
// exact canonical `zone` key used everywhere else in the app.
//
// Lazy-loaded: nothing in this file downloads anything until mount()
// is called, which only happens when the user opens the 3D view — the
// old retired 3D model was pulled from the DEFAULT path for exactly
// this reason (16 MB loading unconditionally on page load).
// ============================================================
// Bare specifiers ('three', 'three/addons/…') — GLTFLoader/OrbitControls
// internally import 'three' the same way, so resolution depends on an
// <script type="importmap"> in the HOST PAGE mapping those specifiers to
// the CDN (see the importmap block added alongside this script's <script
// type="module" src="..."> tag in lumen-log-practice-3d.html /
// lumen-log-recovery.html). This file does not (and cannot) define its own
// import map — that has to live in the document that loads it.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const ASSET_BASE = 'assets/anatomy3d/';
const GLB_URL = ASSET_BASE + 'muscles.glb';
const DRACO_DECODER_URL = 'https://cdn.jsdelivr.net/npm/three@0.170.0/examples/jsm/libs/draco/';

const NEUTRAL_COLOR = 0xc9a98a; // unmarked-muscle tone (warm neutral, reads clearly on both light/dark UI)
const HOVER_EMISSIVE = 0x332211;

// Loaded once per page (not per mount) — GLTFLoader result is reused if the
// viewer is closed and reopened in the same session.
let _cachedGltfScene = null;
let _loadPromise = null;

function loadModel() {
  if (_cachedGltfScene) return Promise.resolve(_cachedGltfScene);
  if (_loadPromise) return _loadPromise;

  const dracoLoader = new DRACOLoader();
  dracoLoader.setDecoderPath(DRACO_DECODER_URL);

  const loader = new GLTFLoader();
  loader.setDRACOLoader(dracoLoader);

  _loadPromise = new Promise((resolve, reject) => {
    loader.load(
      GLB_URL,
      (gltf) => { _cachedGltfScene = gltf.scene; resolve(gltf.scene); },
      undefined,
      (err) => reject(err)
    );
  });
  return _loadPromise;
}

// mesh-zone-map.js sets window.MESH_TO_ZONE + window.ANATOMY3D_GAPS as a
// classic (non-module) script; fetch+eval it here as a one-time side effect
// so both this module and the host page's classic script can read it.
let _mapLoaded = false;
function ensureMapLoaded() {
  if (_mapLoaded || window.MESH_TO_ZONE) { _mapLoaded = true; return Promise.resolve(); }
  return fetch(ASSET_BASE + 'mesh-zone-map.js')
    .then((r) => r.text())
    .then((src) => { (0, eval)(src); _mapLoaded = true; }); // runs in global scope, sets window.MESH_TO_ZONE
}

/**
 * Mount a 3D anatomy viewer into `container`.
 * @param {HTMLElement} container - element to render into (should have explicit size via CSS)
 * @param {object} callbacks
 * @param {(zone: string, label: string) => void} callbacks.onZoneTap - called when a mapped mesh is clicked
 * @param {(feeling: string) => string|null} callbacks.getFeelingColor - hex color string (e.g. '#C77B4A') for a feeling key, or null
 * @param {() => Record<string,string>} callbacks.getMuscleStates - returns the host's current { zone: feeling } map
 * @returns {Promise<{ setView(view:'front'|'back'):void, refresh():void, resize():void, dispose():void }>}
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

    scene.add(new THREE.AmbientLight(0xffffff, 0.7));
    const key = new THREE.DirectionalLight(0xffffff, 0.9);
    key.position.set(2, 3, 4);
    scene.add(key);
    const fill = new THREE.DirectionalLight(0xffffff, 0.4);
    fill.position.set(-3, 1, -2);
    scene.add(fill);

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
      // mesh's color is independently driven by its own feeling state.
      node.material = new THREE.MeshStandardMaterial({
        color: NEUTRAL_COLOR, roughness: 0.65, metalness: 0.05,
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
      const hits = raycaster.intersectObjects(model.children, true);
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

    // ── Recolor meshes from the host's current muscleStates ──
    function refresh() {
      const states = callbacks.getMuscleStates() || {};
      meshByName.forEach((mesh, name) => {
        const zone = window.MESH_TO_ZONE[name];
        const feeling = zone ? states[zone] : null;
        const hex = feeling ? callbacks.getFeelingColor(feeling) : null;
        mesh.material.color.set(hex || NEUTRAL_COLOR);
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
      renderer.dispose();
      container.innerHTML = '';
    }

    return { setView, refresh, resize, dispose };
  });
}

window.LumenAnatomyViewer = { mount };
