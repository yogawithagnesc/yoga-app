const { capsulePath, spindle, teardrop,
        fiberSet, spindleFibers, teardropFibers, capsuleFibers } = require('./gen2.js');
const { write, writeLabeled } = require('./render.js');
const { front: frontTaxonomy } = require('./taxonomy.js');
const OUT = __dirname;

// Torso base filler (non-interactive) hides seams between torso muscles.
const base = 'M92,102 C74,106 66,124 66,150 C66,192 72,242 84,272 C92,288 104,294 120,294 C136,294 148,288 156,272 C168,242 174,192 174,150 C174,124 166,106 148,102 C136,98 104,98 92,102 Z';

// M3b fascia/tendon layer — silvery, non-interactive, drawn UNDER muscle
// zones so muscles read as inserting into them. "L "-prefixed mirror to R.
const fascia = [
  // Linea alba: midline tendinous seam between the rectus columns
  { name:'Linea Alba', d:'M118.6,158 L121.4,158 L121.2,266 L118.8,266 Z' },
  // Tendinous intersections across the rectus (the "six-pack" seams)
  { name:'Tendinous Intersection 1', d:'M106,178 L134,178 L134,180.2 L106,180.2 Z' },
  { name:'Tendinous Intersection 2', d:'M105,196 L135,196 L135,198.2 L105,198.2 Z' },
  { name:'Tendinous Intersection 3', d:'M106,214 L134,214 L134,216.2 L106,216.2 Z' },
  // Patellar tendon: quad convergence into the knee
  { name:'L Patellar Tendon', d:'M94,394 L100,394 L100,406 L94,406 Z' },
  // Inguinal ligament: V from the hip crest to the pubis
  { name:'L Inguinal Ligament', d:'M93,264 L117,290 L115,293 L90,267 Z' },
];

// Non-interactive tendon-fiber bursts at major joints.
const joints = [
  { name:'L Elbow', cx:54, cy:203, r:7 },
  { name:'L Wrist', cx:44, cy:288, r:5 },
  { name:'L Knee', cx:97, cy:406, r:8 },
  { name:'L Ankle', cx:90, cy:530, r:6 },
];

// Order = draw order (underlying first, small/detail/joints last so they stay tappable)
const zones = [
  { name:'Head', ellipse:[120,42,26,32], region:'shoulders' },

  // Neck (drawn before SCM so the strap stays on top)
  { name:'Neck', d:'M111,68 L108,90 A13,13 0 0 0 132,90 L129,68 A11,11 0 0 0 111,68 Z',
    fib: fiberSet(120,70,120,89, 7,9, 3, 0), region:'shoulders' },
  { name:'L Sternocleidomastoid', d:'M112,70 C110,80 110,90 116,97 C119,95 119,89 116,82 C114,76 113,72 113,70 C113,69 112,69 112,70 Z', region:'shoulders' },
  { name:'Trapezius', d:'M120,90 C108,90 98,95 86,104 C96,110 108,113 120,113 C132,113 144,110 154,104 C142,95 132,90 120,90 Z',
    fib: fiberSet(114,95,90,105, 5,4, 3, 0) + ' ' + fiberSet(126,95,150,105, 5,4, 3, 0), region:'shoulders' },

  // Chest — split into clavicular (upper) and sternal (lower) heads.
  // Sternal drawn first (underneath, main mass), clavicular on top (thin
  // upper band toward the collarbone/shoulder).
  { name:'L Pectoralis Major Sternal Head',
    d:'M118,118 L100,116 C88,118 76,124 72,132 C71,144 78,155 92,160 C104,164 114,161 118,151 Z',
    fib: fiberSet(115,133, 78,136, 16,8, 4, 0), region:'chest' },
  { name:'L Pectoralis Major Clavicular Head',
    d:'M118,106 L96,105 C86,106 78,110 73,118 C82,113 94,110 106,111 C113,112 117,114 118,117 Z',
    fib: fiberSet(116,108, 78,116, 6,5, 3, 0), region:'chest' },

  // Upper arm — biceps split into short (medial) and long (lateral) heads
  { name:'L Biceps Brachii Long Head', d: spindle(60,128, 42,202, 7, 0.45), fib: spindleFibers(60,128, 42,202, 7, 0.45, 3), region:'arms' },
  { name:'L Biceps Brachii Short Head', d: spindle(71,128, 55,202, 7, 0.45), fib: spindleFibers(71,128, 55,202, 7, 0.45, 3), region:'arms' },
  { name:'L Brachialis', d: spindle(74,150, 60,200, 6, 0.6), fib: spindleFibers(74,150, 60,200, 6, 0.6, 2), region:'arms' },

  // Shoulder cap — split into anterior (forward-facing) and middle
  // (lateral) heads; posterior head only renders in the back view.
  { name:'L Deltoid Anterior Head', d: teardrop(73,109, 10, 60,144), fib: teardropFibers(73,109, 10, 60,144, 3), region:'shoulders' },
  { name:'L Deltoid Middle Head', d: teardrop(65,113, 10, 51,151), fib: teardropFibers(65,113, 10, 51,151, 3), region:'shoulders' },

  // Forearm (flexors underneath, brachioradialis on top on the thumb side).
  // Palmaris Longus / Flexor Carpi Radialis / Extensor Carpi Ulnaris /
  // Abductor Pollicis Longus / Extensor Pollicis Brevis+Longus are called
  // out as text-only sub-labels of these two grouped zones — see taxonomy.js.
  { name:'L Forearm Flexors', d: capsulePath(48,206,12, 41,290,8), fib: capsuleFibers(48,206,12, 41,290,8, 4), region:'arms' },
  { name:'L Brachioradialis', d: spindle(52,200, 44,262, 7, 0.4), fib: spindleFibers(52,200, 44,262, 7, 0.4, 2), region:'arms' },
  { name:'L Hand', d:'M42,290 C35,294 33,312 38,328 C42,338 51,340 56,332 C59,321 57,304 53,292 C50,288 45,287 42,290 Z', region:'arms' },

  // Trunk
  { name:'L Serratus Anterior', d:'M90,150 C84,152 80,162 81,174 C82,184 88,190 94,186 C98,182 98,170 96,158 C95,153 93,150 90,150 Z',
    fib: fiberSet(88,155, 95,183, 4,4, 2, 0), region:'abs' },
  { name:'L External Oblique', d:'M92,162 C86,176 85,200 90,222 C93,234 100,240 104,234 C102,210 102,182 104,160 C99,158 95,159 92,162 Z',
    fib: fiberSet(93,167, 102,231, 5,5, 3, 2), region:'abs' },
  { name:'Upper Abs', d:'M106,160 L134,160 C137,174 137,192 134,206 C131,214 128,216 120,216 C112,216 109,214 106,206 C103,192 103,174 106,160 Z',
    fib: fiberSet(120,163, 120,213, 11,10, 3, 0), region:'abs' },
  { name:'Lower Abs', d:'M107,218 L133,218 C135,232 134,250 129,262 C125,270 115,270 111,262 C106,250 105,232 107,218 Z',
    fib: fiberSet(120,221, 120,261, 10,7, 3, 0), region:'abs' },

  // Thigh — vastus lateralis (outer) & medialis (inner) underneath,
  // rectus femoris central on top, sartorius thin diagonal on top of all.
  // Adductor Magnus drawn first (deep, peeks at the edges), Adductors
  // (Longus) and the new small Pectineus/Gracilis strips on top.
  { name:'L Vastus Lateralis', d: spindle(83,293, 92,398, 14, 0.42), fib: spindleFibers(83,293, 92,398, 14, 0.42, 4), region:'thighs' },
  { name:'L Vastus Medialis', d: teardrop(110,394, 12, 105,338), fib: teardropFibers(110,394, 12, 105,338, 3), region:'thighs' },
  { name:'L Adductor Magnus', d: spindle(124,298, 125,385, 6, 0.45), fib: spindleFibers(124,298, 125,385, 6, 0.45, 2), region:'thighs' },
  { name:'L Adductors', d: spindle(113,292, 115,392, 8, 0.45), fib: spindleFibers(113,292, 115,392, 8, 0.45, 3), region:'thighs' },
  { name:'L Pectineus', d: spindle(111,290, 112,314, 5, 0.5), fib: spindleFibers(111,290, 112,314, 5, 0.5, 2), region:'thighs' },
  { name:'L Gracilis', d: spindle(120,300, 122,393, 4, 0.5), fib: fiberSet(120,300, 122,393, 1.6,1.6, 1, 0), region:'thighs' },
  { name:'L Rectus Femoris', d: spindle(99,290, 96,400, 9, 0.5), fib: spindleFibers(99,290, 96,400, 9, 0.5, 3), region:'thighs' },
  { name:'L Sartorius', d: spindle(89,288, 110,398, 5, 0.5), fib: fiberSet(89,288, 110,398, 1.6,1.6, 1, 0), region:'thighs' },
  { name:'L Tensor Fasciae Latae', d:'M86,262 C79,268 76,282 80,294 C84,302 92,302 96,294 C98,282 97,270 93,262 C91,258 88,259 86,262 Z', region:'thighs' },

  // Knee
  { name:'L Knee', ellipse:[97,406,15,12], region:'thighs' },

  // Lower leg
  { name:'L Tibialis Anterior', d: spindle(90,416, 86,520, 9, 0.4), fib: spindleFibers(90,416, 86,520, 9, 0.4, 3), region:'calves' },
  { name:'L Gastrocnemius', d: teardrop(104,420, 12, 100,500), fib: teardropFibers(104,420, 12, 100,500, 3), region:'calves' },
  { name:'L Soleus', d: spindle(96,470, 92,524, 8, 0.5), fib: spindleFibers(96,470, 92,524, 8, 0.5, 2), region:'calves' },
  { name:'L Peroneus Longus', d: spindle(79,422, 76,496, 3, 0.5), fib: fiberSet(79,422, 76,496, 1.3,1.3, 1, 0), region:'calves' },
  { name:'L Ankle', ellipse:[90,530,11,9], region:'calves' },
  { name:'L Foot', d:'M78,534 C72,538 68,550 74,558 C82,564 100,564 106,558 C110,552 106,542 98,536 C92,532 84,532 78,534 Z', region:'calves' },
];

write('front2', base, zones, OUT, fascia, joints);
writeLabeled('front2', base, zones, OUT, fascia, joints, frontTaxonomy);
