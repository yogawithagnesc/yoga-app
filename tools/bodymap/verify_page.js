const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });

  // Stub the Supabase SDK before page scripts run: fake session + minimal
  // thenable query builder so initPage() completes without network.
  await page.addInitScript(() => {
    const result = { data: [], error: null };
    const builder = () => {
      const b = {};
      const chain = ['select','eq','gte','lte','order','insert','update','delete','upsert','single','maybeSingle'];
      chain.forEach(m => b[m] = () => b);
      b.then = (res) => res({ ...result });
      return b;
    };
    window.supabase = {
      createClient: () => ({
        auth: { getSession: async () => ({ data: { session: { user: { id: 'test-user' } } } }) },
        from: (t) => {
          const b = builder();
          if (t === 'profiles') { b.single = async () => ({ data: { role: 'student' }, error: null }); }
          return b;
        },
        storage: { from: () => ({}) },
      }),
    };
  });

  await page.goto('file:///home/user/yoga-app/lumen-log-practice-3d.html');
  await page.waitForTimeout(1200);

  const zoneCount = await page.evaluate(() => document.querySelectorAll('#svg-body .svgm').length);
  console.log('front zones rendered:', zoneCount);

  // Tap glute-equivalent (front: L Pectoralis Major) → picking highlight + name shown
  await page.click('[data-z="L Pectoralis Major"]');
  await page.waitForTimeout(200);
  const state1 = await page.evaluate(() => ({
    picking: !!document.querySelector('.svgm.picking'),
    name: document.getElementById('fp-muscle-name')?.textContent,
    pickerShown: document.getElementById('feel-pick')?.classList.contains('show'),
  }));
  console.log('after tap:', JSON.stringify(state1));

  // Pick "Pain" feeling → fill commits, highlight clears
  await page.evaluate(() => {
    const btns = [...document.querySelectorAll('.fp-btn')];
    btns.find(b => b.textContent.includes('Pain') && !b.textContent.includes('Sweet')).click();
  });
  await page.waitForTimeout(200);
  const state2 = await page.evaluate(() => ({
    fill: document.querySelector('[data-z="L Pectoralis Major"]').style.fill,
    stillPicking: !!document.querySelector('.svgm.picking'),
  }));
  console.log('after pick:', JSON.stringify(state2));

  // Toggle to back view → state preserved? zone count?
  await page.click('.svg-toggle-btn[data-view="back"]');
  await page.waitForTimeout(400);
  const state3 = await page.evaluate(() => ({
    backZones: document.querySelectorAll('#svg-body .svgm').length,
    itbandClass: document.querySelector('[data-z="L Iliotibial Band"]')?.getAttribute('class'),
  }));
  console.log('back view:', JSON.stringify(state3));

  // Screenshots of the body map area in both views
  await page.locator('#svg-body').screenshot({ path: 'page_back_m3a.png' });
  await page.click('.svg-toggle-btn[data-view="front"]');
  await page.waitForTimeout(400);
  const frontFill = await page.evaluate(() => document.querySelector('[data-z="L Pectoralis Major"]').style.fill);
  console.log('front again, pec fill persisted:', frontFill);
  await page.locator('#svg-body').screenshot({ path: 'page_front_m3a.png' });

  // Perf sanity: time a view toggle (SVG regen + filter paint)
  const t = await page.evaluate(async () => {
    const t0 = performance.now();
    document.querySelector('.svg-toggle-btn[data-view="back"]').click();
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    return Math.round(performance.now() - t0);
  });
  console.log('view-toggle render ms:', t);

  await browser.close();
})();
