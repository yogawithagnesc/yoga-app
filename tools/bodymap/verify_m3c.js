const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

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
  console.log('JS errors on load:', errors.length ? errors : 'none');

  // Compact widget: photo present, correct src
  const compactState = await page.evaluate(() => ({
    photoSrc: document.getElementById('bodymap-photo').getAttribute('src'),
    photoNaturalWidth: document.getElementById('bodymap-photo').complete,
  }));
  console.log('compact widget:', JSON.stringify(compactState));

  // Open modal
  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(300);
  const modalState = await page.evaluate(() => ({
    shown: document.getElementById('anatomy-modal').classList.contains('show'),
    photoSrc: document.getElementById('bodymap-photo-full').getAttribute('src'),
    groupCount: document.querySelectorAll('#muscle-list .ml-group').length,
    rowCount: document.querySelectorAll('#muscle-list .ml-row').length,
  }));
  console.log('modal state:', JSON.stringify(modalState));

  // Click a bilateral muscle's L side
  await page.evaluate(() => {
    const rows = [...document.querySelectorAll('#muscle-list .ml-row')];
    const pecRow = rows.find(r => r.querySelector('.ml-name')?.textContent.includes('Pectoralis Major (Sternal Head)'));
    pecRow.querySelector('.ml-side').click(); // L side
  });
  await page.waitForTimeout(200);
  const afterClick = await page.evaluate(() => ({
    fpName: document.getElementById('fp-muscle-name-full').textContent,
    pickerShown: document.getElementById('feel-pick-full').classList.contains('show'),
  }));
  console.log('after click L Pectoralis Major Sternal:', JSON.stringify(afterClick));

  await page.evaluate(() => {
    const btns = [...document.querySelectorAll('#fp-row-full .fp-btn')];
    btns.find(b => b.textContent.includes('Sweet Pain')).click();
  });
  await page.waitForTimeout(200);

  // Mark a second, midline muscle (Trapezius) — multi-select check
  await page.evaluate(() => {
    const rows = [...document.querySelectorAll('#muscle-list .ml-row')];
    const trapRow = rows.find(r => r.querySelector('.ml-name')?.textContent === 'Trapezius');
    trapRow.querySelector('.ml-name').click();
  });
  await page.waitForTimeout(200);
  await page.evaluate(() => {
    const btns = [...document.querySelectorAll('#fp-row-full .fp-btn')];
    btns.find(b => b.textContent.includes('Sore') && !b.textContent.includes('Sweet')).click();
  });
  await page.waitForTimeout(200);

  const multiState = await page.evaluate(() => ({
    feelings: window.getMuscleFeelings(),
    areaTags: document.getElementById('area-tags').textContent,
  }));
  console.log('multi-select state:', JSON.stringify(multiState));

  // Toggle to back view inside modal, confirm list rebuilds with back headers
  await page.click('#svg-view-toggle-full [data-view="back"]');
  await page.waitForTimeout(200);
  const backState = await page.evaluate(() => ({
    photoSrc: document.getElementById('bodymap-photo-full').getAttribute('src'),
    firstHeader: document.querySelector('#muscle-list .ml-header')?.textContent,
  }));
  console.log('back view state:', JSON.stringify(backState));

  // Close modal, confirm compact photo synced to back
  await page.click('.am-close');
  await page.waitForTimeout(200);
  const closedState = await page.evaluate(() => document.getElementById('bodymap-photo').getAttribute('src'));
  console.log('compact photo after close:', closedState);

  await page.screenshot({ path: 'm3c_compact.png' });
  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(300);
  await page.screenshot({ path: 'm3c_modal.png', fullPage: true });

  console.log('Final JS errors:', errors.length ? errors : 'none');
  await browser.close();
})();
