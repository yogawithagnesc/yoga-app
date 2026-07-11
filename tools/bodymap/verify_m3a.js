const { chromium } = require('playwright');

// Sample interior points of each zone's bbox; a zone passes if at least one
// sampled point's topmost element IS that zone (i.e. it has exposed,
// tappable surface despite anatomical overlaps + the new overlay layers).
async function checkView(page, file) {
  await page.goto('file://' + __dirname + '/' + file);
  await page.waitForTimeout(200);
  return page.evaluate(() => {
    const svg = document.querySelector('svg');
    const zones = [...svg.querySelectorAll('.svgm')];
    const failures = [];
    for (const z of zones) {
      const bb = z.getBoundingClientRect();
      let hits = 0, samples = 0;
      for (let fx = 0.15; fx <= 0.85; fx += 0.1) {
        for (let fy = 0.1; fy <= 0.9; fy += 0.08) {
          const x = bb.x + bb.width * fx, y = bb.y + bb.height * fy;
          const el = document.elementFromPoint(x, y);
          samples++;
          if (el === z) hits++;
        }
      }
      if (hits === 0) failures.push(z.getAttribute('data-z'));
    }
    return { total: zones.length, failures };
  });
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 520, height: 1100 } });

  for (const [file, label] of [['front2.html','FRONT'], ['back2.html','BACK']]) {
    const r = await checkView(page, file);
    console.log(`${label}: ${r.total} zones, ${r.failures.length} untappable${r.failures.length ? ' → ' + r.failures.join(', ') : ' ✓'}`);
  }

  // Feeling override + clear on both a muscle and a tendon zone
  await page.goto('file://' + __dirname + '/back2.html');
  const paint = await page.evaluate(() => {
    const FEEL = '#C47070';
    const results = {};
    for (const sel of ['[data-z="L Gluteus Maximus"]', '[data-z="L Iliotibial Band"]']) {
      const el = document.querySelector(sel);
      el.style.fill = FEEL;                       // applyFeeling
      const withFeeling = getComputedStyle(el).fill;
      el.style.fill = el.classList.contains('svgm-t') ? 'url(#fasciaGrad)' : 'url(#muscleGrad)'; // clear
      const cleared = getComputedStyle(el).fill;
      results[sel] = { withFeeling, cleared };
    }
    return results;
  });
  console.log('paint check:', JSON.stringify(paint, null, 1));
  await browser.close();
})();
