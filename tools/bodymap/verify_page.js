const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

  await page.addInitScript(() => {
    const result = { data: [], error: null };
    const builder = () => {
      const b = {};
      ['select','eq','gte','lte','order','insert','update','delete','upsert','single','maybeSingle'].forEach(m => b[m] = () => b);
      b.then = (res) => res({ ...result });
      return b;
    };
    window.supabase = {
      createClient: () => ({
        auth: { getSession: async () => ({ data: { session: { user: { id: 'test-user' } } } }) },
        from: (t) => { const b = builder(); if (t === 'profiles') b.single = async () => ({ data: { role: 'student' }, error: null }); return b; },
        storage: { from: () => ({}) },
      }),
    };
  });

  await page.goto('file:///home/user/yoga-app/lumen-log-practice-3d.html');
  await page.waitForTimeout(1000);
  console.log('JS errors:', errors.length ? errors : 'none');

  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(300);
  await page.click('#svg-view-toggle-full [data-view="back"]');
  await page.waitForTimeout(300);

  await page.click('#svg-body-full [data-z="L Gluteus Maximus"]');
  await page.waitForTimeout(200);
  const afterTap = await page.evaluate(() => ({
    picking: !!document.querySelector('#svg-body-full .svgm.picking'),
    name: document.getElementById('fp-muscle-name-full')?.textContent,
    pickerShown: document.getElementById('feel-pick-full')?.classList.contains('show'),
  }));
  console.log('full-view after tap:', JSON.stringify(afterTap));

  await page.evaluate(() => {
    const btns = [...document.querySelectorAll('#fp-row-full .fp-btn')];
    btns.find(b => b.textContent.includes('Sore')).click();
  });
  await page.waitForTimeout(200);
  const afterPick = await page.evaluate(() => document.querySelector('#svg-body-full [data-z="L Gluteus Maximus"]').style.fill);
  console.log('full-view fill after pick:', afterPick);

  await page.click('.am-close');
  await page.waitForTimeout(200);
  await page.click('#svg-view-toggle [data-view="back"]');
  await page.waitForTimeout(200);
  const compactSynced = await page.evaluate(() => document.querySelector('#svg-body [data-z="L Gluteus Maximus"]').style.fill);
  console.log('compact view synced fill:', compactSynced);

  const areaTags = await page.evaluate(() => document.getElementById('area-tags').textContent);
  console.log('area tags:', areaTags);

  await page.screenshot({ path: 'page_compact_m3b.png' });
  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'page_full_modal_m3b.png' });

  // Legacy log edit check: simulate an old zone name in svgBodyStates
  const legacyCheck = await page.evaluate(() => {
    window.svgBodyStatesTestOnly = null;
    // svgBodyStates isn't exported globally; verify via getMuscleFeelings after manual inject is not directly possible,
    // so just confirm getMuscleFeelings() round-trips whatever is currently marked.
    return typeof window.getMuscleFeelings === 'function' ? window.getMuscleFeelings() : null;
  });
  console.log('getMuscleFeelings():', JSON.stringify(legacyCheck));

  await browser.close();
})();
