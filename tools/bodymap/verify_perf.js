const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
  await page.addInitScript(() => {
    const result = { data: [], error: null };
    const builder = () => { const b = {}; ['select','eq','gte','lte','order','insert','update','delete','upsert','single','maybeSingle'].forEach(m => b[m] = () => b); b.then = (res) => res({ ...result }); return b; };
    window.supabase = { createClient: () => ({
      auth: { getSession: async () => ({ data: { session: { user: { id: 'test-user' } } } }) },
      from: (t) => { const b = builder(); if (t === 'profiles') b.single = async () => ({ data: { role: 'student' }, error: null }); return b; },
      storage: { from: () => ({}) },
    })};
  });
  await page.goto('file:///home/user/yoga-app/lumen-log-practice-3d.html');
  await page.waitForTimeout(1000);

  const compactToggle = await page.evaluate(async () => {
    const t0 = performance.now();
    document.querySelector('#svg-view-toggle [data-view="back"]').click();
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    return Math.round(performance.now() - t0);
  });
  console.log('compact view-toggle render ms (63->60 zones):', compactToggle);

  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(200);
  const fullOpen = await page.evaluate(async () => {
    const t0 = performance.now();
    document.getElementById('anatomy-modal').classList.add('show');
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    return Math.round(performance.now() - t0);
  });
  console.log('modal already-open reflow ms:', fullOpen);

  const fullToggle = await page.evaluate(async () => {
    const t0 = performance.now();
    document.querySelector('#svg-view-toggle-full [data-view="back"]').click();
    await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));
    return Math.round(performance.now() - t0);
  });
  console.log('full-view toggle render ms (123 zones + labels):', fullToggle);

  await browser.close();
})();
