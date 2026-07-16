# M7-1 — Legal Framework Engineering Brief

**Purpose:** the drafting specification for Lumen's Terms of Service, Privacy Policy, and
Data Sharing Agreement. This is the *source of truth* the three documents are engineered
against. Every clause must be consistent with the **Product-Fact Data Map** below — no claim
may promise more (or less) than the code actually enforces.

**Model:** Opus 4.8. **Owner:** AgnesC. **Companion to:** `WORKPLAN.md` M7-1, `Lumen_PRD.md` v2.0.

---

## 0. ⚠️ Attorney-Review Disclaimer (must appear in every output document)

These documents are AI-drafted starting points, engineered for factual accuracy against the
product and for coverage of common privacy-law requirements. **They are not legal advice and
are not a substitute for review by a qualified attorney licensed in the governing
jurisdiction.** They must be reviewed (and the bracketed placeholders completed) by counsel
before being published or relied upon.

---

## 1. Drafting Principles (the user's three requirements, operationalized)

1. **Legally compliant.** Cover the mandatory disclosures of the *primary* jurisdiction's
   privacy law, plus a GDPR/CCPA best-practice baseline (these are the strictest common
   denominators; drafting to them satisfies most others). Flag every jurisdiction-dependent
   choice with a `[BRACKETED PLACEHOLDER]` rather than guessing.
2. **Consistent with the product.** Each factual assertion in the documents must trace to a
   row in §3 (Product-Fact Data Map) or §4 (Consistency Matrix). If the product doesn't do it,
   don't claim it. If the product does it, don't omit it. No aspirational or boilerplate claims
   that the code contradicts (e.g. do **not** claim end-to-end encryption, SOC-2, or that "we
   never share your data" — none are true as built).
3. **Fit for purpose.** Plain language, short sentences, tables over prose where it aids
   scanning. Include what's *necessary* (mandatory disclosures) and *best practice* (data-subject
   rights, retention, subprocessors, breach), and nothing padded. Target reading level: general
   adult. Avoid US-only or EU-only idioms unless the jurisdiction is fixed.

---

## 2. Open Inputs (block final drafting — resolve before completing bracketed clauses)

| # | Input needed | Why it changes the documents |
|---|---|---|
| A | Legal operator name + jurisdiction of establishment | Governing-law clause; primary privacy regime; data-controller identity |
| B | Primary user geography | Whether GDPR (EU/EEA/UK) and/or CCPA (California) attach extraterritorially |
| C | Minimum age / minors allowed? | Parental-consent regime, children's-data provisions, age-gate at signup |
| D | Contact address + DPO/privacy contact email | Mandatory in every privacy law's "how to reach us" section |
| E | Cookie/analytics use beyond auth session | Cookie disclosure + consent banner scope (currently: auth session only) |

> **Signal from the codebase:** Traditional-Chinese localization (Noto Serif/Sans TC, M8) and
> the `yogawithagnesc` studio suggest a **Hong Kong / Greater China** primary audience → **HK
> PDPO** likely primary, with **GDPR/CCPA** as the extraterritorial baseline. Treat as a
> hypothesis to confirm, not a fact.

---

## 3. Product-Fact Data Map (VERIFIED — the consistency source of truth)

Verified against `schema.sql`, `schema_phase15_m6_security.sql`, `schema_phase17_rls_studio_fix.sql`,
`schema_phase19_m7_rls_fix.sql`, `schema_phase20_media_notes_consent.sql`, `profile.html`,
`teacher.html`, `lumen-log-practice-3d.html`, `index.html`.

### 3.1 Data collected

| Category | Fields | Table | Sensitivity |
|---|---|---|---|
| Account identity | email, display_name, role, username, join_code | `profiles` | Personal |
| Practice records | style/type, date, start_time, duration, mood, intensity, notes | `practice_logs` | Personal + wellness |
| **Body/muscle state** | `muscle_feelings` JSONB (per-zone: relax…pain/injured) | `practice_logs` | **Health-adjacent — elevated** |
| Media | photos/videos of practice, tags | `session_media` + Storage | Personal (may show face/home) |
| Derived stats | minutes, sessions, streaks (global + yoga) | `profiles` | Personal |
| Relationships | student↔teacher/studio links, follows, group membership | `studio_linkages`, `follows`, `group_members` | Personal (social graph) |
| Scheduling | class bookings, saved filters | `bookings`, `profiles.saved_filters` | Personal |
| Video viewing | resume position per on-demand video | `video_progress` | Personal (behavioral) |
| Feedback | student↔teacher messages | `feedback` | Personal |

### 3.2 Consent & sharing mechanics (the crux — must be described exactly)

- **Private by default.** `practice_logs.is_private` defaults to **TRUE**. A log is invisible to
  anyone but its owner unless the owner shares it. (schema.sql:79)
- **Linkage requires a join code + explicit consent.** A student enters a teacher/studio join
  code and must tick a consent box; `studio_linkages.consent_given` is stored. Either side can
  revoke (`status='active'|'revoked'`). (profile.html:154-156, schema.sql studio_linkages)
- **Minimal default payload to a linked teacher.** Even for a shared (non-private) log, a linked
  **teacher** sees only: date, practice type, duration, mood, and **pain/injured** muscle entries
  — *not* tight/sore/other feelings. Delivered solely via the `get_linked_practice_logs()` RPC.
  (schema_phase20 lines 81-133)
- **Notes are a separate opt-in.** Written reflections are redacted unless `notes_shared=true`.
- **Media is a separate opt-in.** Photos/videos are shared only per-file when
  `shared_with_teacher=true`.
- **Studios are aggregate-only.** A studio account can read counts/totals but is **RLS-blocked
  from every individual practice_log row** (schema_phase17, schema_phase20 dropped the leaky
  policy). Only role `'teacher'` can invoke the log-reading RPC.
- **On-demand videos are linkage-gated.** Published videos are visible only to the creator and
  to students with an active, consented linkage (schema_phase19). Unlinked users see nothing.
- **Peer feed requires an accepted follow.** Peer activity is hidden until a follow request is
  accepted (schema_phase13).

### 3.3 Subprocessors (third parties data flows to — mandatory Privacy Policy disclosure)

| Processor | Role | Data it touches |
|---|---|---|
| **Supabase** | Database, Auth, Storage, Realtime | All account + practice data, media files, credentials |
| **Vercel** | Application hosting + serverless (Mux token broker) | Request metadata, IP, JWT in transit |
| **Mux** | Video upload/encode/streaming | Uploaded class videos, playback + basic viewing telemetry |

### 3.4 What the product does NOT do (guardrails — do not accidentally claim these)

- No end-to-end encryption (data is encrypted in transit/at rest by Supabase/Vercel, not E2EE).
- No advertising, ad-targeting, or sale of personal data (nothing in code does this — so the
  policy can affirmatively state "we do not sell your data," which is truthful).
- No third-party analytics/tracking SDKs presently wired in (confirm before claiming).
- No payment processing yet (booking is gated/"Next Stage"; no card data collected).

---

## 4. Consistency Matrix (doc claim → code enforcement)

Each row is a promise the documents WILL make and the exact mechanism that makes it true.
If a mechanism ever changes, the corresponding clause must change.

| Document claim | Enforced by |
|---|---|
| "Your practice logs are private by default." | `practice_logs.is_private DEFAULT true` |
| "Teachers see only what you choose to share, and never your private logs." | `get_linked_practice_logs()` filters `is_private=false`; RLS `logs_own_all` |
| "A linked teacher sees a minimal summary; your notes and media stay hidden unless you opt in separately." | RPC redacts notes unless `notes_shared`; media gated on `shared_with_teacher` |
| "Only pain/injured body markers are shared, not your full body map." | RPC filters `muscle_feelings` to `feeling IN ('pain','injured')` |
| "Studios only ever see aggregate statistics, never your individual sessions." | schema_phase17 + phase20 RLS; RPC role-gated to `'teacher'` |
| "You can disconnect from a teacher/studio at any time." | `studio_linkages.status='revoked'` path |
| "On-demand class videos are visible only to linked members." | schema_phase19 `videos_published_read` linkage check |
| "We do not sell your personal data." | No such code path exists (truthful negative) |

---

## 5. Document Specifications

### 5.1 Terms of Service (`legal/terms-of-service.md`)

Audience: all account holders. Sections (keep tight):
1. Acceptance & eligibility (age gate → input C).
2. Accounts & roles — define student / teacher / studio; join-code linkage; accuracy of info.
3. Acceptable use — no harassment via feedback/groups; no uploading others' media without
   consent; no misuse of linked-student data by teachers/studios (ties to the DSA).
4. User content & IP — **users own their media and logs**; grant Lumen a limited licence to
   store/process/display it *solely to operate the service* (mirrors what the code does).
5. Teacher/studio obligations — may use shared student data only for instruction/feedback,
   not for marketing or resale (cross-reference DSA).
6. **Wellness disclaimer** — Lumen is a self-tracking tool, **not medical advice**; body/pain
   tracking is informational; consult a professional for injuries. (Material given health-adjacent data.)
7. Service availability, changes, beta features (booking engine gated).
8. Termination & suspension.
9. Disclaimers of warranty; limitation of liability `[jurisdiction limits]`.
10. Governing law & disputes `[input A]`.
11. Changes to terms + notice mechanism.
12. Contact `[input D]`.

### 5.2 Privacy Policy (`legal/privacy-policy.md`)

Structure to the strict baseline (GDPR Art. 13/14 + CCPA + PDPO DPP-1/5 all satisfied by this shape):
1. Who we are / data controller `[input A, D]`.
2. **What we collect** — reproduce §3.1 in user-friendly form; call out health-adjacent body data.
3. **Why / legal basis** — contract performance (run the service), consent (data sharing to
   teachers, media), legitimate interests (security, product function). Map each purpose.
4. **How we share** — the layered consent model (§3.2) in plain words; subprocessors table (§3.3);
   affirmative "we do not sell your data."
5. **International transfers** — data hosted via Supabase/Vercel/Mux (name regions once known)
   `[transfer mechanism placeholder]`.
6. **Retention** — how long logs/media/account persist; deletion on account closure (cascade).
7. **Your rights** — access, rectification, erasure, portability, withdraw consent, object,
   complain to a regulator `[name the regulator per input A]`. How to exercise (contact).
8. **Security** — encryption in transit/at rest via infrastructure providers; RLS access control;
   *no* overclaiming (no E2EE, no certifications unless obtained).
9. **Minors** `[input C]`.
10. Cookies/local storage — auth session token only `[confirm input E]`.
11. Changes + contact.

### 5.3 Data Sharing Agreement (`legal/data-sharing-agreement.md`)

This is the artifact behind the join-code consent checkbox. Two linkage directions:
- **Student → Teacher/Studio** (the primary one; consent box text: *"I agree to share my
  practice data with this Teacher / Studio in accordance with the Data Sharing Agreement."*)
- **Teacher → Studio** (consent text: *"I confirm I teach at this Studio and agree to appear on
  its schedule."*)

Contents (short, scannable — this is read at the moment of linking):
1. Plain statement of what linking does.
2. **Exactly what the linked party CAN see** — the minimal default payload (date, type, duration,
   mood, pain/injured markers); notes only if separately shared; media only if separately shared
   per file. A clear table.
3. **What they CANNOT see** — private logs, non-pain body markers, unshared notes/media; and for
   **studios**, nothing individual at all (aggregates only).
4. Permitted use by the recipient (instruction/feedback) and prohibited use (marketing, resale,
   re-disclosure) — ties to ToS §5.
5. **Revocation** — how to disconnect and what happens to previously shared data after.
6. Reference to the Privacy Policy for full detail.

The DSA must match the consent-box wording verbatim where quoted, and the "CAN see" table must
match §3.2 exactly.

---

## 6. Output Conventions

- Markdown, one file per document under `legal/`.
- Every jurisdiction/entity-specific value as `[BRACKETED PLACEHOLDER]` so counsel completes it.
- Each document: `Last updated: [DATE]` + `Version: 0.1 (draft — pending legal review)` header,
  and the §0 disclaimer.
- Cross-reference sibling documents by name (they'll become terms.html / privacy.html).
- Keep total length lean: ToS ~1,500–2,500 words, Privacy ~1,500–2,500, DSA ~600–1,000.

---

## 7. Downstream Wiring (after drafting; likely folded into M8)

- Render `.md` → `terms.html` / `privacy.html` / (DSA inline in the linkage modal).
- Add "I agree to the Terms & Privacy Policy" checkbox to `register.html`.
- Link the DSA from the existing consent row in `profile.html` (replace the bare reference with
  an actual link/modal).
- Version-stamp consent: consider storing the accepted document version at
  `studio_linkages` / signup time for auditability (schema follow-up).
