const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

  let insertedPayload = null;
  await page.addInitScript(() => {
    const cats = [{ id: 'cat-1', name: 'Vinyasa', category_type: 'yoga', icon: '🧘', subtitle: '', sort_order: 0, is_system: true, visibility: 'system', created_by: null }];
    const groups = [{ id: 'grp-1', name: 'Yoga', sort_order: 0, default_key: 'yoga' }];
    const genericResult = { data: [], error: null };
    const builder = (table) => {
      const b = {};
      ['select','eq','gte','lte','order'].forEach(m => b[m] = () => b);
      b.insert = (payload) => { window.__lastInsert = payload; return { then: (res) => res({ error: null }) }; };
      b.update = () => b; b.delete = () => b; b.upsert = () => b;
      b.single = async () => {
        if (table === 'profiles') return { data: { role: 'student' }, error: null };
        return { data: null, error: null };
      };
      b.maybeSingle = async () => ({ data: null, error: null });
      b.then = (res) => {
        if (table === 'practice_categories') return res({ data: cats, error: null });
        if (table === 'practice_groups') return res({ data: groups, error: null });
        return res({ ...genericResult });
      };
      return b;
    };
    window.supabase = {
      createClient: () => ({
        auth: { getSession: async () => ({ data: { session: { user: { id: 'test-user' } } } }) },
        from: (t) => builder(t),
        storage: { from: () => ({ upload: async () => ({ error: null }) }) },
      }),
    };
  });

  await page.goto('file:///home/user/yoga-app/lumen-log-practice-3d.html');
  await page.waitForTimeout(1000);

  // Select a practice type (required by savePractice validation). Use a
  // programmatic click rather than Playwright's coordinate-based click:
  // the card's own onclick sits behind the type-name text, which has its
  // own click listener that calls stopPropagation() (to protect the
  // double-click-to-rename feature) — a real click landing on that text
  // would never reach the card handler. Pre-existing UI behavior, not
  // specific to M3c.
  await page.evaluate(() => document.querySelector('.type-card[data-category-id="cat-1"]').click());

  // Mark two muscles via the click-list
  await page.click('button[onclick="openFullAnatomy()"]');
  await page.waitForTimeout(300);
  await page.evaluate(() => {
    const rows = [...document.querySelectorAll('#muscle-list .ml-row')];
    rows.find(r => r.querySelector('.ml-name')?.textContent === 'Trapezius').querySelector('.ml-name').click();
  });
  await page.waitForTimeout(150);
  await page.evaluate(() => document.querySelector('#fp-row-full .fp-btn').click()); // first = Relax
  await page.waitForTimeout(150);
  await page.evaluate(() => {
    const rows = [...document.querySelectorAll('#muscle-list .ml-row')];
    const row = rows.find(r => r.querySelector('.ml-name')?.textContent === 'Sternocleidomastoid');
    row.querySelector('.ml-side').click(); // bilateral — only the L/R chips are clickable, not the name
  });
  await page.waitForTimeout(150);
  await page.evaluate(() => {
    const btns = [...document.querySelectorAll('#fp-row-full .fp-btn')];
    btns.find(b => b.textContent.includes('Sore')).click();
  });
  await page.waitForTimeout(150);
  await page.click('.am-close');

  await page.evaluate(() => window.savePractice());
  await page.waitForTimeout(500);

  const insert = await page.evaluate(() => window.__lastInsert);
  console.log('savePractice insert payload muscle_feelings:', JSON.stringify(insert?.muscle_feelings));
  console.log('JS errors:', errors.length ? errors : 'none');

  await browser.close();
})();
