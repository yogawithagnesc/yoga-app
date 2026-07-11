// M3b label taxonomy — single source of truth for the full-screen labeled
// view's header/sub-muscle text blocks and leader-line anchors. Anchors
// are in the ORIGINAL 0-240 x 0-580 body coordinate space (same as the
// zone `d`/ellipse authoring in build_front2.js/build_back2.js) — the
// label renderer (render.js `labels()`) translates them into the expanded
// canvas. `side` picks the text column: 'L' = left column (pointing at
// the L-prefixed / viewer-left zones), 'R' = right column (mirrored,
// pointing at the R-prefixed zones, anchor x mirrored across 120), 'mid'
// = midline structures, auto-balanced into whichever column is shorter.
//
// One leader line + one dot per header (not per sub-muscle) — see M3b
// plan's design principle: the label LIST can be denser than the tap-zone
// GEOMETRY. Every item text may or may not have its own polygon; the
// grouped items (e.g. individual wrist muscles) are called out for
// anatomical completeness without needing a separately-tappable hitbox.

const mirror = (x) => 240 - x;

function pair(header, anchorL, items) {
  return [
    { header, side: 'L', anchor: anchorL, items },
    { header, side: 'R', anchor: [mirror(anchorL[0]), anchorL[1]], items },
  ];
}

const front = [
  { header: 'Neck', side: 'mid', anchor: [120, 80],
    items: ['Sternocleidomastoid', 'Trapezius', 'Omohyoid', 'Sternohyoid'] },

  ...pair('Chest', [95, 135],
    ['Pectoralis Major (Sternal Head)', 'Pectoralis Major (Clavicular Head)']),

  ...pair('Shoulders', [60, 125],
    ['Deltoid Anterior Head', 'Deltoid Middle Head']),

  ...pair('Biceps', [55, 160],
    ['Biceps Brachii Short Head', 'Biceps Brachii Long Head', 'Brachialis']),

  ...pair('Forearms', [45, 240],
    ['Brachioradialis', 'Palmaris Longus', 'Flexor Carpi Radialis',
     'Extensor Carpi Ulnaris', 'Abductor Pollicis Longus',
     'Extensor Pollicis Brevis', 'Extensor Pollicis Longus']),

  { header: 'Abs', side: 'mid', anchor: [120, 190],
    items: ['Serratus Anterior', 'External Oblique', 'Tendinous Inscriptions', 'Rectus Abdominis'] },

  ...pair('Quadriceps', [85, 340],
    ['Vastus Lateralis', 'Vastus Medialis', 'Rectus Femoris']),

  ...pair('Thighs', [100, 300],
    ['Tensor Fasciae Latae', 'Sartorius', 'Pectineus', 'Adductor Longus', 'Gracilis', 'Adductor Magnus']),

  ...pair('Calves', [85, 460],
    ['Tibialis Anterior', 'Gastrocnemius', 'Peroneus Longus']),
];

const back = [
  ...pair('Neck & Upper Back', [100, 95],
    ['Splenius Capitis', 'Sternocleidomastoid', 'Trapezius', 'Rhomboid Major']),

  ...pair('Shoulders', [60, 125],
    ['Deltoid Middle Head', 'Deltoid Posterior Head', 'Teres Minor', 'Infraspinatus']),

  ...pair('Mid-Back', [85, 180],
    ['Latissimus Dorsi', 'Teres Major']),

  ...pair('Arms (Triceps)', [60, 165],
    ['Triceps Long Head', 'Triceps Lateral Head', 'Triceps Medial Head']),

  ...pair('Forearms', [45, 240],
    ['Forearm Extensors', 'Extensor Carpi Ulnaris', 'Abductor Pollicis Longus', 'Extensor Pollicis Longus']),

  { header: 'Lower Back & Core', side: 'mid', anchor: [120, 210],
    items: ['Erector Spinae', 'Thoracolumbar Fascia'] },

  ...pair('Glutes', [85, 290],
    ['Gluteus Maximus', 'Gluteus Medius']),

  ...pair('Hamstrings', [100, 350],
    ['Biceps Femoris Long Head', 'Semitendinosus', 'Semimembranosus']),

  ...pair('Calves', [95, 460],
    ['Gastrocnemius Medial Head', 'Gastrocnemius Lateral Head', 'Soleus', 'Peroneus Brevis', 'Flexor Hallucis Longus', 'Achilles Tendon']),
];

module.exports = { front, back };
