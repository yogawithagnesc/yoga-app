const { capsulePath, spindle, teardrop,
        fiberSet, spindleFibers, teardropFibers, capsuleFibers } = require('./gen2.js');
const { write } = require('./render.js');
const OUT = __dirname;

const base = 'M92,102 C74,106 66,124 66,150 C66,192 72,242 84,272 C92,288 104,294 120,294 C136,294 148,288 156,272 C168,242 174,192 174,150 C174,124 166,106 148,102 C136,98 104,98 92,102 Z';

// M3a fascia/tendon layer (drawn under muscle zones).
const fascia = [
  // Thoracolumbar fascia — the diamond over the sacrum/lower spine the
  // erector spinae and glutes insert into (named in the M3a spec).
  { name:'Thoracolumbar Fascia', d:'M120,246 L131,258 L120,280 L109,258 Z' },
  // Triceps tendon flat above the elbow
  { name:'L Triceps Tendon', d:'M52,196 L58,198 L56,209 L50,206 Z' },
];

const zones = [
  { name:'Head', ellipse:[120,42,26,32] },
  { name:'Neck', d:'M111,68 L108,90 A13,13 0 0 0 132,90 L129,68 A11,11 0 0 0 111,68 Z',
    fib: fiberSet(120,70,120,89, 7,9, 3, 0) },

  // Trapezius — large kite from neck across shoulders down the spine;
  // fibers fan from the neck outward and down toward the spine
  { name:'Trapezius', d:'M120,90 C104,92 90,99 80,112 C98,120 92,148 108,172 L120,186 L132,172 C148,148 142,120 160,112 C150,99 136,92 120,90 Z',
    fib: fiberSet(118,96, 100,150, 6,10, 3, 3) + ' ' + fiberSet(122,96, 140,150, 6,10, 3, 3) },

  // Upper arm / shoulder
  { name:'L Triceps Long Head', d: spindle(66,132, 52,204, 9, 0.5), fib: spindleFibers(66,132, 52,204, 9, 0.5, 3) },
  { name:'L Triceps Lateral Head', d: spindle(74,138, 62,200, 7, 0.45), fib: spindleFibers(74,138, 62,200, 7, 0.45, 2) },
  { name:'L Forearm Extensors', d: capsulePath(50,206,12, 41,290,8), fib: capsuleFibers(50,206,12, 41,290,8, 4) },
  { name:'L Hand', d:'M42,290 C35,294 33,312 38,328 C42,338 51,340 56,332 C59,321 57,304 53,292 C50,288 45,287 42,290 Z' },

  // Back — lat fibers converge from the lumbar spine up toward the armpit
  { name:'L Latissimus Dorsi', d:'M110,138 C94,142 80,158 78,184 C77,208 85,228 101,238 C109,242 115,236 115,224 C115,196 113,162 112,142 C112,139 111,138 110,138 Z',
    fib: fiberSet(110,230, 90,150, 12,6, 4, 0) },
  { name:'Erector Spinae', d:'M110,180 L130,180 C133,200 133,226 128,246 C124,256 116,256 112,246 C107,226 107,200 110,180 Z',
    fib: fiberSet(120,184, 120,250, 8,6, 3, 0) },
  { name:'L External Oblique', d:'M92,196 C87,208 87,224 92,238 C96,246 102,246 104,238 C103,222 103,206 104,192 C99,191 95,193 92,196 Z',
    fib: fiberSet(94,199, 100,238, 5,5, 2, 2) },

  // Shoulder detail (drawn after arm/lat so they stay tappable)
  { name:'L Deltoid', d: teardrop(70,110, 15, 56,150), fib: teardropFibers(70,110, 15, 56,150, 4) },
  { name:'L Infraspinatus', d:'M98,120 C88,122 82,132 82,144 C82,154 90,160 98,158 C104,156 106,144 104,132 C102,124 101,120 98,120 Z',
    fib: fiberSet(102,132, 84,146, 10,5, 3, 0) },
  { name:'L Teres Major', d:'M96,158 C90,160 86,168 88,176 C90,182 96,184 100,180 C102,174 101,164 99,158 C98,157 97,157 96,158 Z',
    fib: fiberSet(98,161, 90,178, 4,3, 2, 0) },

  // Glutes (maximus underneath, medius on top at upper-outer hip);
  // glute max fibers run diagonally down-and-out
  { name:'L Gluteus Maximus', d:'M92,258 C78,262 70,278 70,296 C70,314 82,326 100,324 C110,322 118,314 118,298 L118,262 C110,258 100,256 92,258 Z',
    fib: fiberSet(112,266, 80,308, 14,10, 4, 0) },
  { name:'L Gluteus Medius', d:'M90,250 C82,252 77,262 79,274 C81,284 90,288 96,282 C100,274 99,262 96,252 C94,249 92,249 90,250 Z',
    fib: fiberSet(88,254, 92,282, 6,5, 2, 0) },

  // Hamstrings (biceps femoris + semitendinosus, IT band thin strip on top —
  // the IT band is fascia, so it renders with the tendon material)
  { name:'L Biceps Femoris', d: spindle(92,300, 97,402, 12, 0.45), fib: spindleFibers(92,300, 97,402, 12, 0.45, 3) },
  { name:'L Semitendinosus', d: spindle(110,300, 113,402, 10, 0.5), fib: spindleFibers(110,300, 113,402, 10, 0.5, 3) },
  { name:'L Iliotibial Band', d: spindle(82,292, 88,404, 5, 0.5), tendon: true },

  // Knee
  { name:'L Knee', ellipse:[97,406,15,12] },

  // Lower leg
  { name:'L Gastrocnemius', d: teardrop(98,418, 14, 92,498), fib: teardropFibers(98,418, 14, 92,498, 3) },
  { name:'L Soleus', d: spindle(95,470, 90,524, 9, 0.5), fib: spindleFibers(95,470, 90,524, 9, 0.5, 2) },
  { name:'L Achilles', ellipse:[90,530,9,9], tendon: true },
  { name:'L Foot', d:'M78,534 C72,538 68,550 74,558 C82,564 100,564 106,558 C110,552 106,542 98,536 C92,532 84,532 78,534 Z' },
];

write('back2', base, zones, OUT, fascia);
