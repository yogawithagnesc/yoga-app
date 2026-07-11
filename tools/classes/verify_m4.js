// M4 Phase A verification (federated classes tab + provisioning form).
// Stubs the Supabase client with an in-memory dataset and drives the real
// pages. Run with the global playwright:
//   /opt/node22/bin/node tools/classes/verify_m4.js
const { chromium } = require('/opt/node22/lib/node_modules/playwright');

// ── Shared in-memory dataset ──────────────────────────────
// Studio A is linked to the student; Studio B is NOT. One class is >14
// days out (must be excluded); one is featured; one is today (for the
// booked-today strip).
function buildInitScript(profile, dataset) {
  return `
    (function(){
      const PROFILE = ${JSON.stringify(profile)};
      const DATA = ${JSON.stringify(dataset)};
      function matchesFilters(row, filters) {
        return filters.every(f => {
          const v = row[f.col];
          if (f.op === 'eq')  return v === f.val;
          if (f.op === 'neq') return v !== f.val;
          if (f.op === 'gte') return v >= f.val;
          if (f.op === 'gt')  return v > f.val;
          if (f.op === 'lte') return v <= f.val;
          if (f.op === 'lt')  return v < f.val;
          if (f.op === 'in')  return f.val.includes(v);
          if (f.op === 'or')  return f.val.some(cl => row[cl.col] === cl.val);
          return true;
        });
      }
      function rowsFor(table) { return (DATA[table] || []).map(r => Object.assign({}, r)); }
      // naive join expander: turn "classes(...)" select on bookings into nested obj
      function expandBooking(b) {
        const cls = (DATA.classes || []).find(c => c.id === b.class_id);
        return Object.assign({}, b, { classes: cls ? Object.assign({}, cls) : null });
      }
      function builder(table) {
        const filters = [];
        let selectStr = '';
        const b = {
          select(s){ selectStr = s || ''; return b; },
          eq(col,val){ filters.push({op:'eq',col,val}); return b; },
          neq(col,val){ filters.push({op:'neq',col,val}); return b; },
          gte(col,val){ filters.push({op:'gte',col,val}); return b; },
          gt(col,val){ filters.push({op:'gt',col,val}); return b; },
          lte(col,val){ filters.push({op:'lte',col,val}); return b; },
          lt(col,val){ filters.push({op:'lt',col,val}); return b; },
          in(col,val){ filters.push({op:'in',col,val}); return b; },
          or(str){
            const cls = String(str).split(',').map(p => { const seg = p.split('.'); return {col:seg[0], op:seg[1], val:seg.slice(2).join('.')}; });
            filters.push({op:'or',val:cls}); return b;
          },
          order(){ return b; },
          insert(payload){ window.__lastInsert = payload; return { then:(res)=>res({error:null}) }; },
          update(){ return b; },
          _run(){
            let rows = rowsFor(table).filter(r => matchesFilters(r, filters));
            if (table === 'bookings' && /classes\\(/.test(selectStr)) rows = rows.map(expandBooking);
            return { data: rows, error: null };
          },
          single(){
            if (table === 'profiles') return Promise.resolve({ data: PROFILE, error: null });
            const r = b._run(); return Promise.resolve({ data: r.data[0] || null, error: null });
          },
          maybeSingle(){ const r = b._run(); return Promise.resolve({ data: r.data[0] || null, error: null }); },
          then(res){ return res(b._run()); },
        };
        return b;
      }
      const channelStub = { on(){ return channelStub; }, subscribe(){ return channelStub; } };
      window.supabase = {
        createClient: () => ({
          auth: {
            getSession: async () => ({ data: { session: { user: { id: PROFILE.id, email: PROFILE.email } } } }),
            signOut: async () => ({}),
          },
          from: (t) => builder(t),
          rpc: async () => ({ data: null, error: null }),
          channel: () => channelStub,
          removeChannel: () => {},
          storage: { from: () => ({ upload: async () => ({ error: null }) }) },
        }),
      };
    })();
  `;
}

const now = new Date();
const iso = (d) => d.toISOString();
const plusDays = (n, h = 9) => { const d = new Date(now); d.setDate(d.getDate() + n); d.setHours(h, 0, 0, 0); return d; };
// "today, shortly from now" — reliably >= the page's now() and (almost
// always) still the same calendar day, so it survives the gte filter and
// lands in the today strip. +30 min start, +90 min end.
const soonToday = () => new Date(now.getTime() + 30 * 60000);
const soonTodayEnd = () => new Date(now.getTime() + 90 * 60000);

const studentProfile = { id: 'stu-1', email: 's@x.com', role: 'student', display_name: 'Sam',
  global_streak_count: 0, global_total_sessions: 0, global_total_minutes: 0,
  yoga_streak_count: 0, yoga_total_sessions: 0, yoga_total_minutes: 0 };

const baseClasses = [
  { id: 'c-today', teacher_id: 'studio-a', assigned_teacher_id: 'tea-1', title: 'Noon Reset', style_name: 'Hatha', start_time: iso(soonToday()), end_time: iso(soonTodayEnd()), capacity: 10, room: 'Studio A', location: null, is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
  { id: 'c-feat',  teacher_id: 'studio-a', assigned_teacher_id: null, title: 'Sunrise Flow', style_name: 'Vinyasa', start_time: iso(plusDays(1)), end_time: iso(plusDays(1, 10)), capacity: 20, room: 'Main', location: null, is_online: false, meeting_url: null, prerequisites: 'Sun salutations', description: 'Bright start', is_featured: true, status: 'published' },
  { id: 'c-yin',   teacher_id: 'studio-a', assigned_teacher_id: null, title: 'Yin Evening', style_name: 'Yin', start_time: iso(plusDays(3, 18)), end_time: iso(plusDays(3, 19)), capacity: null, room: null, location: 'Hall', is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
  { id: 'c-far',   teacher_id: 'studio-a', assigned_teacher_id: null, title: 'Far Future', style_name: 'Power', start_time: iso(plusDays(20)), end_time: iso(plusDays(20, 10)), capacity: 10, room: null, location: null, is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
  { id: 'c-other', teacher_id: 'studio-b', assigned_teacher_id: null, title: 'Not Linked Class', style_name: 'Flow', start_time: iso(plusDays(2)), end_time: iso(plusDays(2, 10)), capacity: 10, room: null, location: null, is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
];

const studentDataset = {
  studio_linkages: [{ student_id: 'stu-1', entity_id: 'studio-a', entity_type: 'studio', status: 'active' }],
  classes: baseClasses,
  profiles: [{ id: 'studio-a', display_name: 'Studio A' }, { id: 'studio-b', display_name: 'Studio B' }, { id: 'tea-1', display_name: 'Agnes' }],
  bookings: [{ student_id: 'stu-1', class_id: 'c-today', status: 'confirmed' }],
};

(async () => {
  const browser = await chromium.launch();
  let pass = 0, fail = 0;
  const check = (name, cond) => { (cond ? pass++ : fail++); console.log((cond ? 'PASS ' : 'FAIL ') + name); };

  // ── Scenario 1: student federated view ──
  {
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(studentProfile, studentDataset));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(600);
    await page.evaluate(() => switchTab('courses'));
    await page.waitForTimeout(500);

    const titles = await page.$$eval('#cls-list .cc-title', els => els.map(e => e.textContent));
    check('student: Studio A classes shown', titles.includes('Sunrise Flow') && titles.includes('Yin Evening'));
    check('student: non-linked Studio B excluded', !titles.includes('Not Linked Class'));
    check('student: >14-day class excluded', !titles.includes('Far Future'));
    check('student: provisioning CTA hidden', await page.$eval('#cls-cta', el => el.style.display === 'none'));

    const heroTitle = await page.$eval('.fh-title', el => el.textContent).catch(() => null);
    check('student: featured hero = Sunrise Flow', heroTitle === 'Sunrise Flow');

    const todayTitles = await page.$$eval('#today-strip .tc-title', els => els.map(e => e.textContent)).catch(() => []);
    check('student: today strip shows booked class', todayTitles.includes('Noon Reset'));

    // Booking modal opens; Book button disabled + gated tag
    await page.evaluate(() => openBooking('c-feat'));
    await page.waitForTimeout(200);
    check('booking modal visible', await page.$eval('#booking-modal', el => el.style.display === 'flex'));
    const gated = await page.$eval('.book-btn-disabled .bb-tag', el => el.textContent).catch(() => '');
    check('book button gated tag present', /Gated Booking Engine/.test(gated));
    const studioName = await page.$$eval('#bm-meta .bm-v', els => els.map(e => e.textContent));
    check('booking modal shows studio name', studioName.includes('Studio A'));

    check('student: no JS errors', errors.length === 0);
    if (errors.length) console.log('   errors:', errors);
    await page.close();
  }

  // ── Scenario 2: teacher schedule view ──
  {
    const teacherProfile = Object.assign({}, studentProfile, { id: 'tea-1', role: 'teacher', display_name: 'Agnes' });
    const teacherDataset = {
      studio_linkages: [],
      classes: [
        { id: 't-today', teacher_id: 'tea-1', assigned_teacher_id: null, title: 'My Morning Class', style_name: 'Vinyasa', start_time: iso(soonToday()), end_time: iso(soonTodayEnd()), capacity: 12, room: 'A', location: null, is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
        { id: 't-assigned', teacher_id: 'studio-a', assigned_teacher_id: 'tea-1', title: 'Studio Assigned Class', style_name: 'Yin', start_time: iso(plusDays(2)), end_time: iso(plusDays(2, 10)), capacity: 10, room: 'B', location: null, is_online: false, meeting_url: null, prerequisites: null, description: null, is_featured: false, status: 'published' },
      ],
      profiles: [{ id: 'tea-1', display_name: 'Agnes' }, { id: 'studio-a', display_name: 'Studio A' }],
      bookings: [],
    };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(teacherProfile, teacherDataset));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(600);
    await page.evaluate(() => switchTab('courses'));
    await page.waitForTimeout(400);

    check('teacher: provisioning CTA visible', await page.$eval('#cls-cta', el => el.style.display === 'flex'));
    const titles = await page.$$eval('#cls-list .cc-title', els => els.map(e => e.textContent));
    check('teacher: owned + assigned classes shown', titles.includes('My Morning Class') && titles.includes('Studio Assigned Class'));
    const todayTitles = await page.$$eval('#today-strip .tc-title', els => els.map(e => e.textContent)).catch(() => []);
    check('teacher: today strip shows teaching', todayTitles.includes('My Morning Class'));
    check('teacher: no JS errors', errors.length === 0);
    if (errors.length) console.log('   errors:', errors);
    await page.close();
  }

  // ── Scenario 3: classes.html provisioning insert ──
  {
    const teacherProfile = { id: 'tea-1', email: 't@x.com', role: 'teacher', display_name: 'Agnes' };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(teacherProfile, { studio_linkages: [], classes: [], profiles: [] }));
    await page.goto('file:///home/user/yoga-app/classes.html');
    await page.waitForTimeout(500);

    await page.fill('#c-title', 'Test Flow');
    await page.fill('#c-style', 'Vinyasa');
    await page.fill('#c-date', '2026-07-15');
    await page.fill('#c-time', '08:30');
    await page.selectOption('#c-duration', '60');
    await page.fill('#c-capacity', '15');
    await page.check('#c-featured');
    await page.evaluate(() => createClass());
    await page.waitForTimeout(300);

    const ins = await page.evaluate(() => window.__lastInsert);
    check('provision: title correct', ins && ins.title === 'Test Flow');
    check('provision: style correct', ins && ins.style_name === 'Vinyasa');
    check('provision: capacity parsed', ins && ins.capacity === 15);
    check('provision: featured flag set', ins && ins.is_featured === true);
    check('provision: teacher_id = self', ins && ins.teacher_id === 'tea-1');
    check('provision: assigned defaults to self', ins && ins.assigned_teacher_id === 'tea-1');
    check('provision: end = start + 60min', ins && (new Date(ins.end_time) - new Date(ins.start_time)) === 3600000);
    check('provision: status published', ins && ins.status === 'published');
    check('provision: no JS errors', errors.length === 0);
    if (errors.length) console.log('   errors:', errors);
    await page.close();
  }

  console.log('\n' + pass + ' passed, ' + fail + ' failed');
  await browser.close();
  process.exit(fail ? 1 : 0);
})();
