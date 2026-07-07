LUMEN
—  ILLUMINATE YOUR PRACTICE  —

Product Requirement Document
A practice-tracking & learning companion for experienced yoga practitioners and teachers

Version 1.0  ·  Review Snapshot
Document owner: AgnesC  ·  Status: Living Document

Table of Contents

1. Product Overview
1.1 Vision
Lumen is a mobile-first web app that helps experienced yoga practitioners and teachers track their practice, understand their progress, and stay connected to their teacher. Where most yoga apps are class-streaming catalogues, Lumen is positioned as a learning and progress-tracking instrument — a private journal of the body and the practice.
The name Lumen (Latin for “light,” and the SI unit of luminous flux) ties into a Catholic “salt and light” theme (Matthew 5:13–14). The subtitle “Illuminate Your Practice” frames the product promise: making the invisible progress of a personal practice visible.
1.2 Target Users
User Type
Profile
Primary Need
Intermediate Practitioner
1–3 years of practice
Track progress, build consistency
Advanced Practitioner
Established self-led practice
Log detail, monitor injury patterns
Teacher
Teachers and Schools
Follow students, give feedback, manage content


1.3 Positioning & Feature Priority
The product scope is deliberately ordered. Tracking comes first; community and content are layered on once the core journaling loop is solid.
Priority
Pillar
Description
P1
Practice Tracking & Progress
Log sessions, body map, mood, streak, history
P2
Teacher–Student Community
Feedback, shared activity, encouragement
P3
Live Class / Booking
Schedule and reserve live sessions
P4
On-Demand Video
Recorded class library


Guiding principle
“Fastest working method first.” Ship a working version, then refine. The team consistently prioritises a deployable result over architectural purity in the early phase — e.g. starting with static HTML and a simple GitHub-web upload workflow rather than a full framework build.


2. Design System  —  FINALIZED
Status: Phase 1 design system is locked and in use.
Logo, colour palette, typography, spacing, and the base component library have all been finalized and are implemented in the live product. These are the agreed outputs.


2.1 Brand & Logo  ·  FINALIZED
Direction D was selected: a Tenor Sans wordmark “LUMEN” framed by gold ruling lines, with the subtitle “ILLUMINATE YOUR PRACTICE” set in spaced caps beneath.
LUMEN
————  ILLUMINATE YOUR PRACTICE  ————

Agreed logo lock-up (rendered approximation of the live wordmark).

2.2 Colour Palette  ·  FINALIZED
A restrained monochrome base with a single gold accent. A six-layer token system supports both dark and light surfaces. The live home screen currently uses the warm “cream/bark/sage” variant; the newer Lumen auth and logging screens use the dark + gold token set. Unifying these is a noted action (see Section 6).
Core Accent & Neutrals
Swatch
Hex
Token
Usage


#C8A96E
Gold Accent
Primary accent, CTAs, highlights


#D8BA80
Gold Hover
Hover state


#A88848
Gold Pressed
Pressed state


#080807
BG Base (dark)
App background (dark mode)


#111110
BG Elevated
Cards, sheets


#E8E0D0
Text Primary
Primary text on dark


Warm Variant (current live home) & Semantic
Swatch
Hex
Token
Usage


#F5F0E8
Cream
Warm bg (live home)


#3D3028
Bark
Warm primary text


#5C7A55
Sage
Success / log actions


#D4956A
Warning
Tight / warning


#C47070
Error
Sore / error


2.3 Typography  ·  FINALIZED
Role
Typeface
Use
Display
Cormorant Garamond
Large titles, quotes, hero numerals
Headings
Tenor Sans
Section labels, logo wordmark
Body
DM Sans
Paragraphs, UI text, buttons
Chinese
Noto Serif / Sans TC
Cantonese / Chinese content


2.4 Spacing, Radius & Components  ·  FINALIZED
Spacing: 4px base grid, 8 tokens (4 / 8 / 12 / 16 / 24 / 32 / 48 / 64).
Border radius: 5 tokens (6 / 10 / 14 / 20 / full).
Component library: 8 base interactive components — Button, Card, Input, Badge, Progress (Ring / Bar / Heatmap), Avatar, Bottom Navigation, Modal Sheet.

3. Functional Requirements
3.1 Feature: User Authentication, Role Selection & Onboarding
3.1.1 Authentication Interface & OAuth Options
Legacy Sign-In Platform: The application must support a native credentials portal (Email and Password validation) featuring an integrated "Forgot Password?" email recovery workflow, as structured visually within the template user interface layout of image_e3b002.png.
Third-Party OAuth Integration: To optimize onboarding conversion metrics, the authentication system must natively support Google Sign-In and Apple Sign-In authentication layers.
Unified Account Provisioning: Regardless of the authentication identity provider selected, all first-time registrants must be routed immediately to a mandatory, non-skippable Role Selection and profile initialization screen prior to accessing the core application landscape.
3.1.2 Tri-Role System Architecture
The application enforces a strict three-tier identity management architecture, where a user session must belong to exactly one of the following distinct system roles:
Student: The default consumer persona. Students possess full access to personal self-practice tracking, private custom category building, aggregated analytics metrics, and multi-entity studio/teacher linkages.
Teacher: An independent professional persona. Teachers can provision custom localized practice templates, view authorized data streams of linked students, and broadcast official teaching schedules.
Studio: An institutional corporate persona. Studios act as premium administrative hub configurations with advanced rights to oversee multiple assigned Teacher profiles, analyze macro consumer attendance, and govern dedicated institutional data repositories.
3.1.3 Secure Join-Code Linkage & Data Privacy Engine
To foster authentic professional relationships and completely prevent superficial tracking metrics, connectivity between user tiers relies strictly on mutual transactional consent.
The Join-Code Mechanism: Studios and Teachers can programmatically generate unique alphanumeric strings ("Join Codes") via their profile settings.
Consent-Driven Onboarding: To link their profiles, a Student must manually input the respective Join Code and explicitly toggle a mandatory legal checkbox: "I agree to share my localized practice data with this Studio/Teacher in accordance with the Data Sharing Agreement."
Data Privacy Boundary Enforcement: Upon successful activation of a link, visibility permissions are heavily restricted. The backend schema restricts Studio and Teacher access exclusively to classes attended under their specific entity and explicit feedback logs that the Student has intentionally configured to "Shared". Personal self-practice metrics, private logs, and records from independent fitness routines remain strictly hidden from connected Studios and Teachers.
Future Ecosystem Scalability: This infrastructure functions as the technical foundational layer to scale into an extensive, secure database ecosystem encompassing integrated institutional management and collaborative community networking.
3.2 Feature: Main Dashboard & Basic Analytics Screen
3.2.1 Core Gamification Stats Bar
Data Consistency: The primary user interface layer displays baseline metric aggregates synchronized with the prototype parameters established on https://yoga-app-ten.vercel.app/.
Primary Metrics Display: The top dashboard grid renders three core parameters pulled dynamically from the initialized profile schema:
Current Streak: Represented via the "🔥 [X] day streak" vector component.
Sessions Counter: Displays the total count of valid historical sessions (e.g., "21 Sessions").
Total Time Tracker: Renders cumulative duration across verified entries (e.g., "588 Minutes").
3.2.2 Dual-Perspective Filter Toggle
To support comprehensive user habits without dilution of specialized practices, the user interface features a prominent structural filter component that dynamically alters data tracking views:
Yoga Journey Only: When active, the entire dashboard view, analytics widgets, and historical graphs ignore non-yoga activities. The dashboard streak counter explicitly reads and displays the yoga_streak_count from the database, maintaining an exclusive focus on meditative and mindfulness progress.
All-Round Fitness Journey: When toggled, the application unlocks the data architecture to aggregate all cross-functional metrics—blending custom workouts, cardio sessions, and non-yoga routines. The dashboard streak counter shifts to display the global_streak_count, reflecting a singular holistic fitness ecosystem.
3.2.3 Basic Analytics Visualizer (V1 Specification)
Scope Realignment: To ensure high implementation velocity, specialized graphical charts and intricate trends are deferred to later architectural revisions. V1 relies strictly on core structural parameters.
Body Status & Fatigue Visualization: A basic diagnostic interface block that tracks localized somatic states. The system processes a rolling index of historical muscle feelings documented over the past 14 days. The UI uses simplified highlight levels or color indicators across basic structural muscle markers (e.g., Shoulders, Lower Back, Hamstrings) to inform users of persistent fatigue or optimized recovery.
3.3 Feature: Dynamic Log Practice & Custom Category System
3.3.1 Customizable Practice Categories
Dynamic System Configurations: The database stores default system yoga style templates within a managed configuration table (e.g., system_styles), decoupling them from the core application source code. Rather than hard-coding explicit classes like Morning Flow or Power Vinyasa into the client interface, the frontend dynamically fetches active system styles from the backend on application initialization.
Agile Style Iteration: To prioritize launch velocity, default styles will be initialized with simple, descriptive names. The system architecture must natively support full administrative CRUD operations (Create, Read, Update, Delete) on this table, allowing system administrators to modify, rename, or expand the default class types at any point post-production without requiring code deployments or client-side app store updates.
Cross-Functional Customization: To accurately map holistic health journeys, users can dynamically append personalized custom activity categories (e.g., Running, Pilates, Weight Training) directly from the input form interface.
Hierarchical Visibility & Partitioning Rules:
Categories initiated by a Student are assigned strict private scoping flags mapped directly to their unique identity profile (user_id). These items do not pollute external selection matrices.
Categories deployed by an authenticated Studio or Teacher propagate downstream across the data network. They automatically appear within the selection lists of all Linked Students bound to that organization, facilitating unified training parameters.
3.3.2 Structured Biometric Input Capture
The Log Interface: Beyond documenting raw time durations, the logging wizard features a structured physiological input checklist.
Muscle Feeling Checklist: Users tap and select target muscle locations alongside explicit qualitative states (e.g., Tight, Sore, Relaxed, Energetic). This metadata is captured as a structured document object and saved directly into the log database layer to drive the basic analytics visualizer pipeline.
3.4 Data Flow & Mutation System Logic Specifications
3.4.1 Transactional Create Flow (Form Submission)
When an authenticated profile submits a new entry via the dynamic log form interface, the application triggers a PostgreSQL database function via the Supabase client wrapper. The database must process and commit these operations in a single atomic transaction:
Payload Insertion: Write a new record into the central practice_sessions table. The schema commits the style, duration, mood, user ID, muscle feelings map, and an explicit visibility flag (is_private boolean, defaulted to true for Student self-practice).
Incremental Aggregation: Locate the user's corresponding record in the profiles/users table. Atomically increment global lifetime metrics (global_total_minutes and global_total_sessions by $+1$). If the session category type is categorized under system or custom Yoga styles, simultaneously increment yoga_total_minutes and yoga_total_sessions.
Timezone-Aware Dual-Streak Evaluation: Run a server-side timestamp delta comparison against the user's localized historical timeline to compute two entirely independent streak tracks (global_streak_count and yoga_streak_count):
Scenario A (Consecutive Day): If the preceding log (any workout for global / yoga-only for yoga) falls exactly on the previous calendar date relative to local user time, increment that specific streak counter by $+1$.
Scenario B (Same-Day Entry): If an entry already exists for the current calendar date, retain the current streak counter (do not alter, do not reset).
Scenario C (Broken Chain): If the gap between the current timestamp and the nearest historical entry is $\ge 2$ calendar days, reset that specific streak counter to $1$.
Privacy-Gated Broadcast Triggers: Once the database transaction successfully commits:
The frontend client dynamically fetches the updated profile row, instantly refreshing the Dashboard metrics without requiring a manual application reload.
Strict Security Rule: Evaluate the session's visibility parameter. If is_private is FALSE (e.g., a public studio class or shared teacher log), format and inject an activity story into the community feed. If is_private is TRUE, abort the broadcast routine immediately to preserve user data boundaries.
3.4.2 Transactional Mutation & Compensation Rules (Edit/Delete Logic)
Because your architecture operates without dedicated backend cron utilities, all historical timeline adjustments are handled natively via PostgreSQL Database Triggers tied directly to ON UPDATE or ON DELETE events on the practice_sessions table:
Metric Compensation:
On Delete: Subtract the target log's duration from the profile's corresponding lifetime totals and decrement the session counter by $1$.
On Edit: Calculate the mathematical delta ($\Delta = \text{New} - \text{Old}$), and apply that difference directly to the respective lifetime minute tracking fields.
Trigger-Based Streak Correction: Modifying or deleting a historical record executes a nested Postgres validation loop. The trigger scans adjacent calendar dates relative to the modified record's timestamp. If the deletion breaks an established consecutive day chain, the function automatically recalculates and overwrites the user's historical and current streak_count values to keep data synchronized.
3.5 Community  ·  PLACEHOLDER
Activity feed UI exists with mock data (likes, recent activity).
Real teacher–student interaction and feedback is a P2 item for a later sprint.
3.6 Classes / Video  ·  PLACEHOLDER
Featured + all-classes lists are present as static UI.
Live booking (P3) and on-demand video (P4) are future scopes.


5. Technical Architecture  —  FINALIZED
5.1 Stack
Layer
Technology
Notes
Frontend
Static HTML / CSS / JS
Mobile-first, single-file pages
3D
Three.js 0.160 + GLTF
Anatomy model via CDN importmap
Hosting
Vercel
Auto-deploy on push to main
Source Control
GitHub (web upload)
yogawithagnesc / yoga-app
Backend
Supabase
Auth + Postgres + Storage, Tokyo region


Deployment workflow (agreed, no-terminal)
1. Edit or upload files directly in the GitHub web interface.
2. Commit to the main branch.
3. Vercel detects the push and auto-deploys to yoga-app-ten.vercel.app.
This keeps the workflow accessible without local tooling or command line.

5.2 Database Schema 
Table: users (or profiles) 
Column Name
Data Type
Constraints / Default
Description
global_total_minutes
integer
DEFAULT 0
Lifetime minutes across all fitness categories.
global_total_sessions
integer
DEFAULT 0
Total number of all sessions logged.
global_streak_count
integer
DEFAULT 0
Current consecutive days active overall.
yoga_total_minutes
integer
DEFAULT 0
Lifetime minutes spent strictly practicing yoga.
yoga_total_sessions
integer
DEFAULT 0
Total number of yoga practices logged.
yoga_streak_count
integer
DEFAULT 0
Current consecutive days practicing yoga.


Table: practice_sessions 
Column Name
Data Type
Constraints / Default
Description
style_id
uuid
REFERENCES system_styles(id)
Foreign key mapping to the dynamic style table.
is_custom
boolean
DEFAULT false
Flags if a category was manually created by a user.
is_private
boolean
DEFAULT true
Controls visibility; true blocks community feed injection.


5.3 Cost (Beta)
Supabase free tier and Vercel free tier are sufficient for the beta phase: estimated monthly cost is $0 (an optional custom domain is ~$12/year). Scale-up to ~1,000 active users is estimated at roughly $110/month, including paid Supabase, Vercel, and video hosting.

6. Non-Functional Requirements
Area
Requirement
Platform
Mobile-first; usable in any mobile browser, max content width 430px
Language
English UI; Cantonese / Chinese supported via Noto TC fonts
Privacy
Row-level security; each user sees only their own practice data
Performance
3D model (~16MB) loads with progress indicator + 2D fallback
Accessibility
Sufficient contrast; legible type scale; tap targets sized for touch
Reliability
Static hosting + managed backend; auto-deploy on commit


7. Open Decisions & Agreed Actions
Items the founder should confirm or that are queued for upcoming work:
Unify the visual theme. Decide whether the home screen adopts the dark + gold Lumen tokens, or the warm cream/bark/sage palette becomes the system-wide standard.
Connect Save Practice to the database. Current active task — write session + body-map data to Supabase.
Fix Body Map interaction. Adopt SVG-primary interaction or resolve 3D touch handling.
Media storage. Wire photo/video upload to Supabase Storage.
Track Dashboard. Build the read-side: streak, totals, body heatmap, teacher view.