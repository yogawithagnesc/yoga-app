# Join Codes System — Quick Start Testing (P0)

**Objective:** Validate Phase 1 join codes functionality end-to-end
**Time:** ~20 minutes
**Status:** Ready to execute

## Test Setup

### Prerequisites
- ✅ Supabase project active (vuodmnhebsjmwdeazdtc.supabase.co)
- ✅ schema_phase31.sql applied (join_codes table + RLS)
- ✅ admin/join-codes.html ready
- ✅ register.html + role-select.html support join code input
- ✅ Vercel preview deployed

### Test Codes to Create
Create these via Supabase SQL Editor (INSERT into join_codes table):

```sql
INSERT INTO join_codes (code, display_name, tier, max_participants, created_by, organization_id, feature_flags)
VALUES 
  ('TESTFREE01', 'Test Free Tier', 'free', 5, auth.uid(), NULL, '{"video":false,"recovery_log":false,"media_upload":false}'::jsonb),
  ('TESTPRO02', 'Test Pro Tier', 'pro', 20, auth.uid(), NULL, '{"video":true,"recovery_log":true,"media_upload":true}'::jsonb),
  ('TESTMAX01', 'Test Max Tier', 'pro', 2, auth.uid(), NULL, '{"video":true,"recovery_log":true,"media_upload":true}'::jsonb),
  ('TESTINACTIVE', 'Test Inactive (should reject)', 'free', 10, auth.uid(), NULL, '{"video":false}'::jsonb);

-- Then set TESTINACTIVE to inactive:
UPDATE join_codes SET is_active = false WHERE code = 'TESTINACTIVE';
```

**Note:** Replace `auth.uid()` with your actual user ID (retrieve via `SELECT auth.uid();`)

## Test Scenarios (Run in Order)

### Scenario 1: Free Tier Signup
**Flow:** Register → use TESTFREE01 → verify tier assignment → check feature flags
- [ ] Register new student account with join code `TESTFREE01`
- [ ] Verify profile shows tier = 'free' (via `/profile.html` badge)
- [ ] Verify video feature hidden (index.html should not show video continue-watching section)
- [ ] Check Supabase: `join_codes.current_participants` = 1

**Expected:** Student sees limited features, join code participant count incremented

---

### Scenario 2: Pro Tier + Feature Gating
**Flow:** Register → use TESTPRO02 → verify all features available
- [ ] Register new student account with join code `TESTPRO02`
- [ ] Verify profile shows tier = 'pro'
- [ ] Verify video feature present (continue-watching visible if videos exist)
- [ ] Verify recovery log button shows (index.html `Log Recovery / Treatment`)
- [ ] Verify media upload available in lumen-log-practice-3d.html
- [ ] Check Supabase: `join_codes.current_participants` = 1

**Expected:** Student sees all features; profile badge shows "Pro"

---

### Scenario 3: Participant Cap Enforcement
**Flow:** Use TESTMAX01 (max 2) → register 3 users → 3rd should be rejected
- [ ] Register user 1 with `TESTMAX01` → success
- [ ] Register user 2 with `TESTMAX01` → success
- [ ] Attempt register user 3 with `TESTMAX01` → **should reject with error**
- [ ] Check Supabase: `join_codes.current_participants` = 2 (capped)

**Expected:** RPC validation blocks 3rd signup; error message displayed; database enforces cap

---

### Scenario 4: Inactive Code Rejection
**Flow:** Try signup with TESTINACTIVE
- [ ] Attempt register with join code `TESTINACTIVE`
- [ ] **Should be rejected** with error "This join code is no longer active"
- [ ] Verify signup still allows optional code (clear code field and proceed)

**Expected:** Validation rejects inactive codes; signup continues without code

---

### Scenario 5: Disconnect & Re-link
**Flow:** Link student → verify access → disconnect → verify revoked
- [ ] Create a Teacher account manually (via role-select after signup)
- [ ] Student account (from Scenario 1) links to Teacher via join code
- [ ] Teacher can see student's shared sessions
- [ ] Student disconnects in app
- [ ] Teacher can no longer see student data (RLS enforces)
- [ ] Verify Supabase: `studio_linkages` record marked inactive

**Expected:** Linking & unlinking works; RLS properly filters after disconnect

---

## Verification Checklist

- [ ] All 4 test codes created and active (except TESTINACTIVE)
- [ ] Scenario 1 (free) complete — features gated
- [ ] Scenario 2 (pro) complete — all features available
- [ ] Scenario 3 (cap) complete — 3rd user rejected
- [ ] Scenario 4 (inactive) complete — rejected with message
- [ ] Scenario 5 (link/unlink) complete — RLS enforced
- [ ] No console errors in browser DevTools
- [ ] Supabase logs show no RLS permission errors
- [ ] All participant counts match expected values

## Notes

- **Feature flags:** Currently cached in `code?.feature_flags` on profile page. Implement gating in each feature page (index.html, lumen-log-practice-3d.html, profile.html).
- **Participant triggers:** `decrement_join_code_participant_count` RPC fires on profile delete; test deletion separately if needed.
- **Browser cache:** Hard refresh (Ctrl+Shift+R) after signup to load fresh feature flag state.
