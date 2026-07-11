const { capsulePath, spindle, teardrop,
        fiberSet, spindleFibers, teardropFibers, capsuleFibers } = require('./gen2.js');
const { write } = require('./render.js');
const OUT = __dirname;

// Torso base filler (non-interactive) hides seams between torso muscles.
const base = 'M92,102 C74,106 66,124 66,150 C66,192 72,242 84,272 C92,288 104,294 120,294 C136,294 148,288 156,272 C168,242 174,192 174,150 C174,124 166,106 148,102 C136,98 104,98 92,102 Z';

// M3a fascia/tendon layer — silvery, non-interactive, drawn UNDER muscle
// zones so muscles read as inserting into them. "L "-prefixed mirror to R.
const fascia = [
  // Linea alba: midline tendinous seam between the rectus columns
  { name:'Linea Alba', d:'M118.6,158 L121.4,158 L121.2,266 L118.8,266 Z' },
  // Tendinous intersections across the rectus (the "six-pack" seams)
  { name:'Tendinous Intersection 1', d:'M106,178 L134,178 L134,180.2 L106,180.2 Z' },
  { name:'Tendinous Intersection 2', d:'M105,196 L135,196 L135,198.2 L105,198.2 Z' },
  // Patellar tendon: quad convergence into the knee
  { name:'L Patellar Tendon', d:'M94,394 L100,394 L100,406 L94,406 Z' },
  // Inguinal ligament: V from the hip crest to the pubis (fills the
  // pelvic gap below the lower abs)
  { name:'L Inguinal Ligament', d:'M93,264 L117,290 L115,293 L90,267 Z' },
];

// Order = draw order (underlying first, small/detail/joints last so they stay tappable)
const zones = [
  { name:'Head', ellipse:[120,42,26,32] },

  // Neck (drawn before SCM so the strap stays on top)
  { name:'Neck', d:'M111,68 L108,90 A13,13 0 0 0 132,90 L129,68 A11,11 0 0 0 111,68 Z',
    fib: fiberSet(120,70,120,89, 7,9, 3, 0) },
  { name:'L Sternocleidomastoid', d:'M112,70 C110,80 110,90 116,97 C119,95 119,89 116,82 C114,76 113,72 113,70 C113,69 112,69 112,70 Z' },
  { name:'Trapezius', d:'M120,90 C108,90 98,95 86,104 C96,110 108,113 120,113 C132,113 144,110 154,104 C142,95 132,90 120,90 Z',
    fib: fiberSet(114,95,90,105, 5,4, 3, 0) + ' ' + fiberSet(126,95,150,105, 5,4, 3, 0) },

  // Chest — fibers fan from the sternum toward the humerus insertion
  { name:'L Pectoralis Major', d:'M118,106 L96,105 C84,107 74,116 72,129 C71,142 78,154 92,159 C104,163 114,160 118,150 L118,106 Z',
    fib: fiberSet(115,130, 78,132, 19,9, 5, 0) },

  // Upper arm
  { name:'L Biceps', d: spindle(66,128, 48,202, 13, 0.45), fib: spindleFibers(66,128, 48,202, 13, 0.45, 4) },
  { name:'L Brachialis', d: spindle(74,150, 60,200, 6, 0.6), fib: spindleFibers(74,150, 60,200, 6, 0.6, 2) },

  // Shoulder cap (on top of pec/biceps origins)
  { name:'L Deltoid', d: teardrop(70,110, 15, 56,150), fib: teardropFibers(70,110, 15, 56,150, 4) },

  // Forearm (flexors underneath, brachioradialis on top on the thumb side)
  { name:'L Forearm Flexors', d: capsulePath(48,206,12, 41,290,8), fib: capsuleFibers(48,206,12, 41,290,8, 4) },
  { name:'L Brachioradialis', d: spindle(52,200, 44,262, 7, 0.4), fib: spindleFibers(52,200, 44,262, 7, 0.4, 2) },
  { name:'L Hand', d:'M42,290 C35,294 33,312 38,328 C42,338 51,340 56,332 C59,321 57,304 53,292 C50,288 45,287 42,290 Z' },

  // Trunk
  { name:'L Serratus Anterior', d:'M90,150 C84,152 80,162 81,174 C82,184 88,190 94,186 C98,182 98,170 96,158 C95,153 93,150 90,150 Z',
    fib: fiberSet(88,155, 95,183, 4,4, 2, 0) },
  { name:'L External Oblique', d:'M92,162 C86,176 85,200 90,222 C93,234 100,240 104,234 C102,210 102,182 104,160 C99,158 95,159 92,162 Z',
    fib: fiberSet(93,167, 102,231, 5,5, 3, 2) },
  { name:'Upper Abs', d:'M106,160 L134,160 C137,174 137,192 134,206 C131,214 128,216 120,216 C112,216 109,214 106,206 C103,192 103,174 106,160 Z',
    fib: fiberSet(120,163, 120,213, 11,10, 3, 0) },
  { name:'Lower Abs', d:'M107,218 L133,218 C135,232 134,250 129,262 C125,270 115,270 111,262 C106,250 105,232 107,218 Z',
    fib: fiberSet(120,221, 120,261, 10,7, 3, 0) },

  // Thigh — vastus lateralis (outer) & medialis (inner) underneath,
  // rectus femoris central on top, sartorius thin diagonal on top of all
  { name:'L Vastus Lateralis', d: spindle(83,293, 92,398, 14, 0.42), fib: spindleFibers(83,293, 92,398, 14, 0.42, 4) },
  { name:'L Vastus Medialis', d: teardrop(110,394, 12, 105,338), fib: teardropFibers(110,394, 12, 105,338, 3) },
  { name:'L Adductors', d: spindle(115,292, 117,392, 8, 0.45), fib: spindleFibers(115,292, 117,392, 8, 0.45, 3) },
  { name:'L Rectus Femoris', d: spindle(99,290, 96,400, 9, 0.5), fib: spindleFibers(99,290, 96,400, 9, 0.5, 3) },
  { name:'L Sartorius', d: spindle(89,288, 110,398, 5, 0.5), fib: fiberSet(89,288, 110,398, 1.6,1.6, 1, 0) },
  { name:'L Tensor Fasciae Latae', d:'M86,262 C79,268 76,282 80,294 C84,302 92,302 96,294 C98,282 97,270 93,262 C91,258 88,259 86,262 Z' },

  // Knee
  { name:'L Knee', ellipse:[97,406,15,12] },

  // Lower leg
  { name:'L Tibialis Anterior', d: spindle(90,416, 86,520, 9, 0.4), fib: spindleFibers(90,416, 86,520, 9, 0.4, 3) },
  { name:'L Gastrocnemius', d: teardrop(104,420, 12, 100,500), fib: teardropFibers(104,420, 12, 100,500, 3) },
  { name:'L Soleus', d: spindle(96,470, 92,524, 8, 0.5), fib: spindleFibers(96,470, 92,524, 8, 0.5, 2) },
  { name:'L Ankle', ellipse:[90,530,11,9] },
  { name:'L Foot', d:'M78,534 C72,538 68,550 74,558 C82,564 100,564 106,558 C110,552 106,542 98,536 C92,532 84,532 78,534 Z' },
];

write('front2', base, zones, OUT, fascia);
