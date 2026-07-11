// M5 verification (peer follows, groups/bulletins, feedback portal,
// 30-day fatigue dashboard, teacher roster red flags).
// Stubs the Supabase client with an in-memory, mutating dataset so
// multi-step CRUD flows (create group -> add member -> post bulletin)
// reflect correctly across reloads within a scenario. Run with:
//   /opt/node22/bin/node tools/community/verify_m5.js
const { chromium } = require('/opt/node22/lib/node_modules/playwright');

// Embed resolution: which select-string fragment maps to which FK column
// on the base row, and which table the embed pulls from.
const EMBEDS = [
  { needle: 'profiles!follows_follower_id_fkey', col: 'follower_id', table: 'profiles', key: 'profiles' },
  { needle: 'profiles!follows_followee_id_fkey', col: 'followee_id', table: 'profiles', key: 'profiles' },
  { needle: 'profiles!group_members_student_id_fkey', col: 'student_id', table: 'profiles', key: 'profiles' },
  { needle: 'profiles!feedback_author_id_fkey', col: 'author_id', table: 'profiles', key: 'profiles' },
  { needle: 'profiles!studio_linkages_entity_id_fkey', col: 'entity_id', table: 'profiles', key: 'profiles' },
  { needle: 'profiles!studio_linkages_student_id_fkey', col: 'student_id', table: 'profiles', key: 'profiles' },
  { needle: 'groups(', col: 'group_id', table: 'groups', key: 'groups' },
];

function buildInitScript(profile, dataset, rpcResults) {
  return `
    (function(){
      const PROFILE = ${JSON.stringify(profile)};
      const DATA = ${JSON.stringify(dataset)};
      const RPC = ${JSON.stringify(rpcResults)};
      const EMBEDS = ${JSON.stringify(EMBEDS)};
      let idCounter = 1000;
      function genId() { return 'gen-' + (idCounter++); }

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
          return true;
        });
      }
      function rowsFor(table) { return (DATA[table] || []).map(r => Object.assign({}, r)); }
      function applyEmbeds(rows, selectStr) {
        return rows.map(row => {
          const out = Object.assign({}, row);
          EMBEDS.forEach(e => {
            if (selectStr.indexOf(e.needle) === -1) return;
            const fk = row[e.col];
            const match = (DATA[e.table] || []).find(r => r.id === fk);
            out[e.key] = match ? Object.assign({}, match) : null;
          });
          return out;
        });
      }
      function builder(table) {
        const filters = [];
        let selectStr = '';
        let orderCol = null, orderAsc = true;
        let limitN = null;
        const b = {
          select(s){ selectStr = s || ''; return b; },
          eq(col,val){ filters.push({op:'eq',col,val}); return b; },
          neq(col,val){ filters.push({op:'neq',col,val}); return b; },
          gte(col,val){ filters.push({op:'gte',col,val}); return b; },
          gt(col,val){ filters.push({op:'gt',col,val}); return b; },
          lte(col,val){ filters.push({op:'lte',col,val}); return b; },
          lt(col,val){ filters.push({op:'lt',col,val}); return b; },
          in(col,val){ filters.push({op:'in',col,val}); return b; },
          order(col, opts){ orderCol = col; orderAsc = !(opts && opts.ascending === false); return b; },
          limit(n){ limitN = n; return b; },
          insert(payload){
            const rows = Array.isArray(payload) ? payload : [payload];
            const inserted = rows.map(r => {
              const row = Object.assign({ id: genId(), created_at: new Date().toISOString() }, r);
              DATA[table] = DATA[table] || [];
              DATA[table].push(row);
              return row;
            });
            window.__lastInsert = { table, payload };
            return { then:(res)=>res({ data: inserted, error: null }), select(){ return this; }, single(){ return Promise.resolve({ data: inserted[0], error: null }); } };
          },
          update(payload){
            window.__lastUpdate = { table, payload };
            return Object.assign({}, b, {
              eq(col, val){ filters.push({op:'eq',col,val}); return this; },
              then(res){
                DATA[table] = (DATA[table]||[]).map(r => matchesFilters(r, filters) ? Object.assign({}, r, payload) : r);
                return res({ data: null, error: null });
              },
            });
          },
          delete(){
            return Object.assign({}, b, {
              eq(col, val){ filters.push({op:'eq',col,val}); return this; },
              then(res){
                DATA[table] = (DATA[table]||[]).filter(r => !matchesFilters(r, filters));
                return res({ data: null, error: null });
              },
            });
          },
          _run(){
            let rows = rowsFor(table).filter(r => matchesFilters(r, filters));
            rows = applyEmbeds(rows, selectStr);
            if (orderCol) {
              rows.sort((a,b2) => {
                if (a[orderCol] < b2[orderCol]) return orderAsc ? -1 : 1;
                if (a[orderCol] > b2[orderCol]) return orderAsc ? 1 : -1;
                return 0;
              });
            }
            if (limitN != null) rows = rows.slice(0, limitN);
            return { data: rows, error: null };
          },
          single(){
            if (table === 'profiles' && filters.length === 1 && filters[0].col === 'id' && filters[0].val === PROFILE.id) {
              return Promise.resolve({ data: PROFILE, error: null });
            }
            const r = b._run(); return Promise.resolve({ data: r.data[0] || null, error: null });
          },
          maybeSingle(){ const r = b._run(); return Promise.resolve({ data: r.data[0] || null, error: null }); },
          then(res){ return res(b._run()); },
        };
        return b;
      }
      function makeChannelStub(name) {
        const stub = {
          on(event, cfg, cb) { window.__rtCallbacks = window.__rtCallbacks || {}; window.__rtCallbacks[name] = cb; return stub; },
          subscribe() { return stub; },
        };
        return stub;
      }
      window.supabase = {
        createClient: () => ({
          auth: { getSession: async () => ({ data: { session: { user: { id: PROFILE.id, email: PROFILE.email } } } }), signOut: async () => ({}) },
          from: (t) => builder(t),
          rpc: async (name, args) => {
            window.__lastRpc = { name, args };
            if (RPC[name]) return { data: RPC[name], error: null };
            return { data: [], error: null };
          },
          channel: (name) => makeChannelStub(name),
          removeChannel: () => {},
          storage: { from: () => ({ upload: async () => ({ error: null }) }) },
        }),
      };
    })();
  `;
}

(async () => {
  const browser = await chromium.launch();
  let pass = 0, fail = 0;
  const check = (name, cond) => { (cond ? pass++ : fail++); console.log((cond ? 'PASS ' : 'FAIL ') + name); };

  // ── Scenario 1: Student — peer follows (search, pending requests, accept) ──
  {
    const studentProfile = { id: 'stu-1', email: 's1@x.com', role: 'student', display_name: 'Amy', saved_filters: [] };
    const dataset = {
      profiles: [
        { id: 'stu-1', email: 's1@x.com', display_name: 'Amy', role: 'student' },
        { id: 'stu-2', email: 's2@x.com', display_name: 'Ben', role: 'student' },
        { id: 'stu-3', email: 's3@x.com', display_name: 'Cara', role: 'student' },
      ],
      follows: [
        // Ben has sent Amy a pending follow request
        { id: 'f1', follower_id: 'stu-2', followee_id: 'stu-1', status: 'pending', created_at: new Date().toISOString() },
      ],
      studio_linkages: [], practice_logs: [], community_feeds: [], groups: [], group_members: [], group_bulletins: [], feedback: [],
    };
    const rpcResults = {
      lookup_profile_by_email: [{ id: 'stu-3', display_name: 'Cara', role: 'student' }],
      body_fatigue_30day: [],
    };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(studentProfile, dataset, rpcResults));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(500);
    await page.evaluate(() => switchTab('community'));
    await page.waitForTimeout(500);

    const pendingText = await page.$eval('#follow-section', el => el.textContent);
    check('follows: pending request from Ben shown', pendingText.includes('Ben') && pendingText.includes('wants to follow you'));

    // Accept the pending request
    await page.evaluate(() => {
      const btn = document.querySelector('.follow-btn.accept');
      if (btn) btn.click();
    });
    await page.waitForTimeout(400);
    const afterAcceptText = await page.$eval('#follow-section', el => el.textContent);
    check('follows: accepted request moves Ben to Following', afterAcceptText.includes('Following') && afterAcceptText.includes('connected'));

    // Send a new follow request by email (Cara)
    await page.fill('#follow-email-input', 'S3@x.com');
    await page.evaluate(() => sendFollowRequest());
    await page.waitForTimeout(400);
    const msgText = await page.$eval('#follow-search-msg', el => el.textContent);
    check('follows: send request success message shown', msgText.includes('sent'));

    check('follows: no page errors', errors.length === 0); if(errors.length) console.log('ERRS:', errors);
    await page.close();
  }

  // ── Scenario 2: Student — My Groups + bulletin realtime ──
  {
    const studentProfile = { id: 'stu-1', email: 's1@x.com', role: 'student', display_name: 'Amy', saved_filters: [] };
    const dataset = {
      profiles: [{ id: 'stu-1', email: 's1@x.com', display_name: 'Amy', role: 'student' }],
      groups: [{ id: 'g1', owner_id: 'tea-1', name: 'Morning Flow Cohort', description: 'Early risers', created_at: new Date().toISOString() }],
      group_members: [{ group_id: 'g1', student_id: 'stu-1', added_by: 'tea-1', created_at: new Date().toISOString() }],
      group_bulletins: [{ id: 'b1', group_id: 'g1', author_id: 'tea-1', body: 'Welcome to the cohort!', created_at: new Date().toISOString() }],
      follows: [], studio_linkages: [], practice_logs: [], community_feeds: [], feedback: [],
    };
    const rpcResults = { body_fatigue_30day: [] };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(studentProfile, dataset, rpcResults));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(500);
    await page.evaluate(() => switchTab('community'));
    await page.waitForTimeout(500);

    const groupsWrapVisible = await page.$eval('#groups-section-wrap', el => getComputedStyle(el).display !== 'none');
    check('groups: My Groups section visible for member', groupsWrapVisible);
    const groupText = await page.$eval('#groups-section', el => el.textContent);
    check('groups: group name + bulletin rendered', groupText.includes('Morning Flow Cohort') && groupText.includes('Welcome to the cohort'));

    // Simulate a realtime bulletin insert
    await page.evaluate(() => {
      const cb = window.__rtCallbacks && window.__rtCallbacks['group-bulletins-g1'];
      if (cb) cb({ new: { id: 'b2', group_id: 'g1', author_id: 'tea-1', body: 'Class moved to 8am tomorrow', created_at: new Date().toISOString() } });
    });
    await page.waitForTimeout(300);
    const afterRt = await page.$eval('#groups-section', el => el.textContent);
    check('groups: realtime bulletin appears without reload', afterRt.includes('Class moved to 8am tomorrow'));

    check('groups: no page errors', errors.length === 0); if(errors.length) console.log('ERRS:', errors);
    await page.close();
  }

  // ── Scenario 3: Student — Feedback portal ──
  {
    const studentProfile = { id: 'stu-1', email: 's1@x.com', role: 'student', display_name: 'Amy', saved_filters: [] };
    const dataset = {
      profiles: [
        { id: 'stu-1', email: 's1@x.com', display_name: 'Amy', role: 'student' },
        { id: 'tea-1', email: 't@x.com', display_name: 'Agnes', role: 'teacher' },
      ],
      studio_linkages: [{ student_id: 'stu-1', entity_id: 'tea-1', entity_type: 'teacher', status: 'active', consent_given: true }],
      follows: [], practice_logs: [], community_feeds: [], groups: [], group_members: [], group_bulletins: [], feedback: [],
    };
    const rpcResults = { body_fatigue_30day: [] };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(studentProfile, dataset, rpcResults));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(500);
    await page.evaluate(() => switchTab('community'));
    await page.waitForTimeout(500);

    const portalVisible = await page.$eval('#feedback-portal-wrap', el => getComputedStyle(el).display !== 'none');
    check('feedback: portal button visible for linked student', portalVisible);

    await page.evaluate(() => openFeedbackModal());
    await page.waitForTimeout(300);
    const modalVisible = await page.$eval('#feedback-modal', el => getComputedStyle(el).display !== 'none');
    check('feedback: modal opens with target chip', modalVisible);
    const chipText = await page.$eval('#feedback-target-chips', el => el.textContent);
    check('feedback: target chip shows teacher name', chipText.includes('Agnes'));

    await page.fill('#feedback-body', 'Thank you for a wonderful class this week!');
    await page.evaluate(() => updateFeedbackCharCount());
    await page.evaluate(() => submitFeedback());
    await page.waitForTimeout(300);

    const inserted = await page.evaluate(() => window.__lastInsert);
    check('feedback: insert payload has correct direction + target', inserted && inserted.table === 'feedback' && inserted.payload.direction === 'student_to_teacher' && inserted.payload.target_entity_id === 'tea-1');
    const modalClosedAfterSubmit = await page.$eval('#feedback-modal', el => getComputedStyle(el).display === 'none');
    check('feedback: modal closes after submit', modalClosedAfterSubmit);

    check('feedback: no page errors', errors.length === 0); if(errors.length) console.log('ERRS:', errors);
    await page.close();
  }

  // ── Scenario 4: Student — 30-day fatigue trend widget ──
  {
    const studentProfile = { id: 'stu-1', email: 's1@x.com', role: 'student', display_name: 'Amy', saved_filters: [] };
    const dataset = {
      profiles: [{ id: 'stu-1', email: 's1@x.com', display_name: 'Amy', role: 'student', global_streak_count: 1, global_total_sessions: 1, global_total_minutes: 30, yoga_streak_count: 1, yoga_total_sessions: 1, yoga_total_minutes: 30 }],
      follows: [], studio_linkages: [], practice_logs: [], community_feeds: [], groups: [], group_members: [], group_bulletins: [], feedback: [],
    };
    const today = new Date().toISOString().split('T')[0];
    const rpcResults = { body_fatigue_30day: [{ date: today, serious_count: 4 }] };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(studentProfile, dataset, rpcResults));
    await page.goto('file:///home/user/yoga-app/index.html');
    await page.waitForTimeout(700);

    const sectionVisible = await page.$eval('#fatigue-section', el => getComputedStyle(el).display !== 'none');
    check('fatigue: 30-day section visible when data present', sectionVisible);
    const barCount = await page.$$eval('#fatigue-chart .fatigue-bar', els => els.length);
    check('fatigue: 30 bars rendered', barCount === 30);
    const highBarCount = await page.$$eval('#fatigue-chart .fatigue-bar.high', els => els.length);
    check('fatigue: high-fatigue day (>=3) flagged with .high class', highBarCount === 1);

    check('fatigue: no page errors', errors.length === 0); if(errors.length) console.log('ERRS:', errors);
    await page.close();
  }

  // ── Scenario 5: Teacher — red flags + groups + feedback received ──
  {
    const teacherProfile = { id: 'tea-1', email: 't@x.com', role: 'teacher', display_name: 'Agnes' };
    const dataset = {
      profiles: [
        { id: 'tea-1', email: 't@x.com', display_name: 'Agnes', role: 'teacher' },
        { id: 'stu-1', email: 's1@x.com', display_name: 'Amy', role: 'student' },
        { id: 'stu-2', email: 's2@x.com', display_name: 'Ben', role: 'student' },
      ],
      studio_linkages: [
        { student_id: 'stu-1', entity_id: 'tea-1', entity_type: 'teacher', status: 'active', consent_given: true },
        { student_id: 'stu-2', entity_id: 'tea-1', entity_type: 'teacher', status: 'active', consent_given: true },
      ],
      practice_categories: [], practice_logs: [], groups: [], group_members: [], group_bulletins: [],
      feedback: [{ id: 'fb1', author_id: 'stu-1', target_entity_id: 'tea-1', direction: 'student_to_teacher', body: 'Loved the class today!', created_at: new Date().toISOString() }],
      focus_areas: [],
    };
    const rpcResults = {
      compute_red_flags: [
        { student_id: 'stu-1', flag_type: 'severe_pain', detail: 'Logged Pain or Injury in the past 14 days' },
      ],
    };
    const page = await browser.newPage({ viewport: { width: 430, height: 950 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.addInitScript(buildInitScript(teacherProfile, dataset, rpcResults));
    await page.goto('file:///home/user/yoga-app/teacher.html');
    await page.waitForTimeout(600);

    const rosterText = await page.$eval('#students-list', el => el.innerHTML);
    check('teacher: red flag badge rendered on flagged student', rosterText.includes('flag-badge') && rosterText.includes('🚩'));
    check('teacher: no flag badge for unflagged student', (rosterText.match(/flag-badge/g) || []).length === 1);

    // Groups tab: create a group
    await page.evaluate(() => switchTeacherTab('groups'));
    await page.waitForTimeout(300);
    await page.evaluate(() => toggleGroupForm());
    await page.fill('#new-group-name', 'Evening Restorative Circle');
    await page.evaluate(() => createGroup());
    await page.waitForTimeout(400);
    const groupsListText = await page.$eval('#groups-list', el => el.textContent);
    check('teacher: created group appears in list', groupsListText.includes('Evening Restorative Circle'));

    // Add a member and post a bulletin
    const realGroupId = await page.evaluate(() => document.querySelector('.group-card').id.replace('group-card-', ''));
    await page.selectOption('#add-member-' + realGroupId, 'stu-1');
    await page.evaluate((gid) => addMember(gid), realGroupId);
    await page.waitForTimeout(400);
    const membersText = await page.$eval('#groups-list', el => el.textContent);
    check('teacher: added member appears as chip', membersText.includes('Amy'));

    await page.fill('#bulletin-input-' + realGroupId, 'Reminder: bring your own mat this week.');
    await page.evaluate((gid) => sendBulletin(gid), realGroupId);
    await page.waitForTimeout(400);
    const bulletinText = await page.$eval('#groups-list', el => el.textContent);
    check('teacher: sent bulletin appears in group card', bulletinText.includes('bring your own mat'));

    // Feedback tab
    await page.evaluate(() => switchTeacherTab('feedback'));
    await page.waitForTimeout(300);
    const feedbackText = await page.$eval('#feedback-list', el => el.textContent);
    check('teacher: feedback received from student shown', feedbackText.includes('Amy') && feedbackText.includes('Loved the class today'));

    check('teacher: no page errors', errors.length === 0);
    await page.close();
  }

  console.log('\n' + pass + ' passed, ' + fail + ' failed');
  await browser.close();
  process.exit(fail > 0 ? 1 : 0);
})();
