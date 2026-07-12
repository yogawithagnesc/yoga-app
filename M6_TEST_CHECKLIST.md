# M6 Testing Checklist — Security, Profiles & Studio Operations

**Status:** Core features shipped, validation testing in progress

---

## 📋 Pre-Test Setup
- [ ] Hard refresh browser (Ctrl+Shift+R)
- [ ] Ensure schema_phase15 and schema_phase16 are run in Supabase (if not yet applied)
- [ ] Test with 2–3 different user accounts (student, teacher, studio)
- [ ] Open DevTools Console to check for JS errors
- [ ] Open Network tab to verify RPC calls execute

---

## Test 1: Username Uniqueness & Availability Check

**Scenario A: New Username (No Existing)**
- [ ] Open Profile tab
- [ ] Username field visible with placeholder "Set your unique username"
- [ ] Field is empty (new user scenario)
- [ ] Type "testuser_alpha"
- [ ] Wait 400ms → ✓ Available (green text) appears
- [ ] Field auto-saves (no modal, no button click required)
- [ ] Reload profile page → Username persists "testuser_alpha"

**Scenario B: Existing Username (Already Set)**
- [ ] Open Profile → Username field shows current value (e.g., "testuser_alpha")
- [ ] dataset.original is set = no unnecessary save on first keystroke
- [ ] Edit to "testuser_beta"
- [ ] Wait 400ms → ✓ Available (green)
- [ ] Auto-saves
- [ ] Reload → New value persists

**Scenario C: Unavailable Username**
- [ ] Type a username you know exists
- [ ] Wait 400ms → ✗ Already taken (red text)
- [ ] Don't save (button click not required, auto-save doesn't trigger on unavailable)
- [ ] Edit field → message clears

**Scenario D: Invalid Input**
- [ ] Type <3 characters → No message shown
- [ ] Delete all text → Message hides
- [ ] Type 1 char, wait → No message
- [ ] Type 3 chars → Availability check fires

**DevTools Check:**
- [ ] Network tab shows RPC call `check_username_available` on each keystroke (after 400ms debounce)
- [ ] Response includes `available: true/false`

---

## Test 2: Per-Log Privacy Toggle

**Setup:**
- [ ] Log in as student
- [ ] Log at least 2 practice sessions (different days if possible)

**Scenario A: Toggle Privacy in Practice History**
- [ ] Open Home tab
- [ ] Tap a calendar day with practice logged
- [ ] Day modal opens, showing logged sessions
- [ ] Each session row shows:
  - [ ] Session name (e.g., "Vinyasa Flow")
  - [ ] Duration (e.g., "30 min")
  - [ ] 🔒 Private button (dark) OR 🔓 Shared button (gold)
  - [ ] Edit button
  - [ ] Delete button

**Scenario B: Click Toggle**
- [ ] Session shows 🔒 Private
- [ ] Click button → Toggles to 🔓 Shared
- [ ] Toast or subtle message: "Shared with your connections"
- [ ] Click again → Back to 🔒 Private
- [ ] Toast: "Set to private"

**Scenario C: Persistence**
- [ ] Close day modal
- [ ] Reopen same day → Session toggle state is saved
- [ ] Refresh entire page → State persists

**Scenario D: Multiple Sessions**
- [ ] Tap day with 3+ sessions
- [ ] Toggle first to Shared
- [ ] Toggle third to Shared
- [ ] Close modal
- [ ] Reopen → Both are Shared, second is Private

**DevTools Check:**
- [ ] Network tab shows UPDATE call to `practice_logs` table
- [ ] `is_private` field changed from `true` → `false` or vice versa
- [ ] No other fields altered

---

## Test 3: Peer Invitations by Username or Email

**Setup:**
- [ ] Create 2+ test accounts with usernames set (use Test 1 first)
- [ ] Log in to Account A

**Scenario A: Follow by Username**
- [ ] Go to Community tab
- [ ] See "Peer Connections" section
- [ ] Input field placeholder: "Username or email address"
- [ ] Type Account B's username (lowercase, no @)
- [ ] Click "Follow" button
- [ ] Message appears: "Follow request sent!"
- [ ] Input clears

**Scenario B: Follow by Email**
- [ ] Input field shows ready for input
- [ ] Type Account B's email (with @)
- [ ] Click "Follow"
- [ ] Message: "Follow request sent!"

**Scenario C: Invalid Query**
- [ ] Type "nonexistent_user_xyz"
- [ ] Click "Follow"
- [ ] Error message: "No user found with that username or email."

**Scenario D: Self-Follow Prevention**
- [ ] Type own username or email
- [ ] Click "Follow"
- [ ] Error: "You can't follow yourself."

**Scenario E: Duplicate Follow**
- [ ] Type Account B's username again (second time)
- [ ] Click "Follow"
- [ ] Error: "Follow request already sent."

**Scenario F: Accept Request (Cross-Account)**
- [ ] Log in to Account B
- [ ] Go to Community → Peer Connections
- [ ] "Requests" section shows pending request from Account A
- [ ] Button row: "Accept" and "Decline"
- [ ] Click "Accept"
- [ ] Request moves to "Following" section

**DevTools Check:**
- [ ] Network: `check_username_available` RPC called (if username entered)
- [ ] Network: `lookup_profile_by_email` RPC called (if email entered)
- [ ] Database: `follows` table INSERT on request send

---

## Test 4: Studio Analytics Dashboard

**Prerequisite:** Switch to teacher or studio account

**Scenario A: Navigate to Analytics**
- [ ] Open teacher.html ("My Students" button from Profile)
- [ ] See tabs: Roster, Directory, Groups, **Analytics**, Feedback
- [ ] Click Analytics tab
- [ ] Page loads with no errors

**Scenario B: View Studio Metrics**
- [ ] Three metric rows visible:
  - [ ] "Total Followers" → number or 0
  - [ ] "Sessions Logged" → number or 0
  - [ ] "Total Minutes" → number or 0
- [ ] If no linked students: all show 0
- [ ] If linked students exist with shared logs: numbers > 0

**Scenario C: Date-Range Attendance Analyzer**
- [ ] "Class Attendance (Date Range)" section visible
- [ ] Input fields: Start Date, "to", End Date
- [ ] Default range: last 30 days (pre-filled)
- [ ] Button: "Analyze"
- [ ] Click Analyze

**Scenario D: Results Display**
- [ ] If classes exist in date range:
  - [ ] Classes grouped by tier: Popular, Unpopular, HighPotential
  - [ ] Each class shows name + "X/Y attendance (Z%)"
  - [ ] Color-coded left border: green (popular), red (unpopular), gold (high potential)
- [ ] If no classes: "No classes found in this date range"

**Scenario E: Filter by Different Dates**
- [ ] Change date range (e.g., last 7 days)
- [ ] Click Analyze
- [ ] Results update accordingly

**DevTools Check:**
- [ ] Network: RPC calls to `studio_follower_count`, `studio_total_linked_sessions`, `studio_total_linked_minutes`
- [ ] Network: `studio_class_tiers` RPC with date parameters

---

## Test 5: Directory Tabs (Contracted Teachers vs Linked Students)

**Prerequisite:** Teacher or studio account

**Scenario A: Navigate to Directory**
- [ ] teacher.html → Click Directory tab
- [ ] Two card sections visible

**Scenario B: Teacher Role**
- [ ] Section 1 header: "My Studios"
- [ ] Lists studios where user teaches
- [ ] Each row: Avatar, Name, "studio" role badge
- [ ] Section 2 header: "Linked Students"
- [ ] Lists students connected to this teacher

**Scenario C: Studio Role**
- [ ] Section 1 header: "Contracted Teachers" (or "Associated Teachers")
- [ ] Lists teachers who teach at this studio
- [ ] Section 2 header: "Linked Students"
- [ ] Lists all students linked to this studio

**Scenario D: Empty State**
- [ ] If no contracted teachers: "No associated teachers."
- [ ] If no linked students: "No linked students yet."

**DevTools Check:**
- [ ] Network: `studio_linkages` query to fetch bound entities
- [ ] Filters applied: `entity_id`, `student_id`, `status='active'`

---

## Test 6: RLS Enforcement (Aggregate-Only Access)

**Prerequisite:** Studio account with linked students

**Scenario A: Student View (Control)**
- [ ] Log in as student
- [ ] Open Home → practice history visible
- [ ] Can see all own logged sessions in day modal

**Scenario B: Studio View (RLS Block)**
- [ ] Log in as studio
- [ ] Open Home
- [ ] Day modal DOES NOT appear (or shows empty) — cannot directly access student logs
- [ ] Analytics tab shows ONLY aggregates (totals), not raw logs
- [ ] Teacher.html Roster tab shows student list, but does not expose individual log details

**DevTools Check:**
- [ ] Network: Verify queries to `practice_logs` from studio account return 0 rows
- [ ] Database (Supabase Logs tab): RLS policy `practice_logs_studio_block` filters results

---

## Test 7: Cross-Browser & Mobile

**Desktop (Chrome/Firefox/Safari)**
- [ ] All UI renders correctly
- [ ] Buttons are 44px+ minimum tap target
- [ ] No horizontal scroll on 430px viewport

**Mobile (iOS Safari / Android Chrome)**
- [ ] Profile page loads without flash
- [ ] Username input accepts typing
- [ ] Privacy toggle buttons tap correctly
- [ ] Analytics metrics readable
- [ ] No layout broken at 375px width

---

## Test 8: Error Handling & Edge Cases

**Network Errors**
- [ ] Disable internet → Load Profile → Graceful error (not blank page)
- [ ] RPC call fails → "Error checking availability" message shown

**Data Integrity**
- [ ] Multiple simultaneous toggles on same session → No race condition
- [ ] Follow request sent while follower is typing → No duplicate request

**Permission Denial**
- [ ] Student tries to access teacher.html → Redirects or shows no data
- [ ] Non-owner tries to edit username of another user → DB RLS prevents it

---

## 📊 Summary Checklist

**Core Features Status:**
- [ ] ✅ Username uniqueness + availability check
- [ ] ✅ Per-log privacy toggle
- [ ] ✅ Peer invitations (username + email)
- [ ] ✅ Studio analytics dashboard
- [ ] ✅ Directory tabs
- [ ] ✅ RLS enforcement

**Known Limitations:**
- Multi-branch hierarchy: scoped for later
- Studio brand channel: scoped for later (low priority)

**Next Steps After Testing:**
- Deploy to Vercel preview
- Gather user feedback
- Begin M7 video-player implementation

---

**Last Updated:** 2026-07-11  
**Tester:** [Your Name]  
**Date Tested:** [Date]  
**Notes:** [Any issues found, environment details]
