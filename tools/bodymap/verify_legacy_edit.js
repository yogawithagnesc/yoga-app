const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

  await page.addInitScript(() => {
    const legacyRow = {
      id: 'legacy-log-1', category_id: 'cat-1', practice_date: '2026-06-01',
      start_time: '07:00', mood: 'Calm', notes: 'old session',
      intensity: 3, duration_minutes: 45, is_private: true,
      focus_area_ids: [],
      // Retired M3a-era zone names no longer rendered by M3b's split geometry.
      muscle_feelings: [
        { zone: 'L Biceps', feeling: 'sore' },
        { zone: 'L Deltoid', feeling: 'tight' },
        { zone: 'L Pectoralis Major', feeling: 'pain' },
      ],
    };
    const genericResult = { data: [], error: null };
    const builder = (table) => {
      const b = {};
      ['select','eq','gte','lte','order','insert','update','delete','upsert'].forEach(m => b[m] = () => b);
      b.maybeSingle = async () => table === 'practice_logs' ? { data: legacyRow, error: null } : { data: null, error: null };
      b.single = async () => table === 'profiles' ? { data: { role: 'student' }, error: null } : { data: null, error: null };
      b.then = (res) => res({ ...genericResult });
      return b;
    };
    window.supabase = {
      createClient: () => ({
        auth: { getSession: async () => ({ data: { session: { user: { id: 'test-user' } } } }) },
        from: (t) => builder(t),
        storage: { from: () => ({}) },
      }),
    };
  });

  await page.goto('file:///home/user/yoga-app/lumen-log-practice-3d.html?edit=legacy-log-1');
  await page.waitForTimeout(1200);

  console.log('JS errors:', errors.length ? errors : 'none');

  const state = await page.evaluate(() => ({
    feelings: window.getMuscleFeelings(),
    ctaText: document.querySelector('.cta-btn[onclick="savePractice()"]')?.textContent,
    otherZonesStillTappable: !!document.querySelector('#svg-body [data-z="L Deltoid Anterior Head"]'),
  }));
  console.log('legacy edit state:', JSON.stringify(state, null, 1));

  // Confirm a re-save still includes the orphaned legacy entries (no data loss)
  await browser.close();
})();
