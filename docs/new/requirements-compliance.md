# Original Specification Compliance

Baseline: local `docs/Elective3_FinalProject.pdf`, 26 pages, especially sections 3–15. The document calls itself an initial design blueprint, while this audit evaluates the implemented application and retained design deliverables. A design artifact is not proof of executable functionality. Text was extracted from all PDF pages using bundled pypdf; existing wireframe images/companion UI PDF were inventoried, not visually recertified for all 36 screens.

Date: 30 October 2026. **Complete** means the applicable source behavior exists and is covered by relevant local checks; it never means deployed/device-accepted. **Partial** means only some required behavior exists. **Missing** means no implementation was found. **Deferred** means an existing guide explicitly defers it; it remains an original requirement. **Not verified** means evidence was unavailable or acceptance was not exercised. Recommendations to defer work do not change original scope.

## Evidence Key

Paths below are repository-relative, not live-resource claims.

| Key | Source | Executed evidence |
| --- | --- | --- |
| A | `lib/features/auth/`, `lib/app/{startup.dart,splash_gate.dart,router.dart}` | `test/{firebase_auth_service,email_auth,email_auth_service,email_auth_ui,auth_view_model,splash_timing,router}_test.dart`; `firebase/tests/email-auth.integration.test.mjs` (one linking TODO) |
| P | `lib/features/profile/`, `workers/attendance/src/student_ids.js` | `test/{student_profile,profile_repository,student_id,phase3_profile_ui,text_formatting}_test.dart`; `firebase/tests/profile.rules.test.mjs`; Worker Student ID tests/integration |
| O | `lib/features/organizations/`, `lib/features/memberships/`, Worker `memberships.js` | `test/{organization_workflow,organization_view_models,member_management,phase4_organizations_ui}_test.dart`; organization Rules and Worker membership unit/emulator tests |
| E | `lib/features/events/`, `firebase/firebase.rules` | `test/{event_workflow,event_view_models,event_creation_poster,participants,event_poster_crop}_test.dart`; `firebase/tests/event.rules.test.mjs` |
| T | `lib/features/attendance/`, Worker `attendance.js` | `test/{attendance,attendance_transport,attendance_correction,qr_window,manual_attendance_access}_test.dart`; attendance Rules and Worker attendance emulator tests |
| D | `lib/features/admin/`, Worker `admin.js`, `admin_search.js`, operator bootstrap | `test/platform_admin_test.dart`; Worker admin/search tests and integration; `tools/admin/provision-platform-admin.test.mjs` |
| I | `lib/core/services/image_upload_service.dart`, cropper/editor, Worker `images.js` | image/crop Flutter tests; image Rules and Worker unit/emulator tests |
| U | `lib/core/widgets/`, `lib/core/theme/`, `lib/app/router.dart` | `test/{design_system,phase1_components,phase2_navigation,phase5_6_ui}_test.dart` |

## All 36 Required Screens (Specification Section 5)

| Screen | Classification | Implemented or missing acceptance | Evidence |
| --- | --- | --- | --- |
| 1 Splash | Complete | Branding/loading, Firebase/auth resolution and visible-frame timing | A |
| 2 Onboarding | Partial | Intro route exists; gamification value cannot be demonstrated | A; no badge feature |
| 3 Google Sign-In | Partial | Real Google flow/loading/error; Terms/Privacy links are plain text; live OAuth unverified | A; `_TermsNote` in auth_screens.dart |
| 4 Complete Student Profile | Complete | UID-backed required fields, optional existing-profile photo, trusted user/pending creation | P, I |
| 5 Account Status | Partial | Status/eligibility gate; contact is instructional text, no dedicated actionable help/contact option | A; AccountStatusScreen |
| 6 Home Dashboard | Partial | Real events/org context and shortcuts; no recent announcement or badge feeds; not all requested engagement summaries | `lib/features/home/`, U |
| 7 Organization Discovery | Complete | Search/cards/logos/status/details | O |
| 8 Organization Details | Complete | Mission/vision/goals/positions/published officers/events/join state | O; publicOfficers is separate publication data |
| 9 My Organizations | Complete | Own histories/roles/assigned orgs and navigation | O |
| 10 Membership Requests | Complete | Own request states plus manager review in organization context; no separate duplicate implementation | O |
| 11 Event Discovery | Complete | Search, organization and time filters, schedule/venue/poster cards | E, U |
| 12 Event Details | Complete | Required event data, eligibility/status and registration actions | E |
| 13 Registration Confirmation | Complete | Confirmation, paired counter/UID/identity writes, capacity and errors | E |
| 14 My Events | Partial | Personal registration/attendance context; calendar shortcut leads to Coming Soon | E, `lib/app/router.dart` |
| 15 Event Management | Complete | Lifecycle list/actions restricted by manager/officer authority | E |
| 16 Create/Edit Event | Complete | Validated drafts, posters, separate review/publication, retry without duplicate draft | E, I |
| 17 Member Roster | Partial | Scoped names, role/status/search and management; no Student Number/private full-profile view | O; deliberate privacy narrowing |
| 18 Membership Review | Complete | Pending applicants, time, confirmations, approve/reject and concurrent cancellation safety | O |
| 19 Member Profile/Engagement | Partial | Manager member-details dialog/actions; no joined-event/badge engagement screen | O, absence of badge module |
| 20 Officers/Committees | Partial | Role/title/three capability assignment and revocation; no committee-member structure editor | O |
| 21 Organization Settings | Partial | Platform Admin core editor and manager logo; no full assigned-manager settings/hierarchy/event-approval editor | O, D; admin allowed fields |
| 22 Attendance Verification | Complete | QR/manual, permission/registration/window checks, duplicates/time | T |
| 23 Attendance Report | Partial | Counts/rate/roster/status/search/event selection; separate date-range filters/export absent | T |
| 24 My Attendance | Complete | Own records, event/date/status/time/summary and unavailable metadata handling | T |
| 25 Badge Collection | Deferred | No earned badges UI, award model or pipeline | Original module guides/requirements defer badges; no lib badge feature |
| 26 Badge Management | Deferred | No catalog/criteria editor or trusted awarding | Same absence; no Worker award endpoint |
| 27 Event Ratings | Deferred | No attendance-eligible single-rating submission/summary/moderation | No rating feature/Rules allowlist/Worker endpoint |
| 28 Organization Calendar | Deferred | Explicit Coming Soon; no month/week/event calendar | `lib/app/router.dart`, ComingSoonScreen |
| 29 Notifications | Deferred | Explicit Coming Soon; no delivery/feed/read state/preferences | `lib/app/router.dart`; no notification backend |
| 30 Announcements | Missing | No audience/priority/read-state publication or feed | Route/feature/Worker inventory; Home lacks announcement source |
| 31 Platform Dashboard | Partial | Users/pending/org counts; missing transfer count, active breakdown, activity and announcement feed | D; `adminBackend.stats` |
| 32 Organization Administration | Complete | Directory/core edit/status/validated manager assignment | D |
| 33 Manager Transfer Requests | Deferred | Direct audited manager replacement exists; request/propose/review state machine absent | D; original admin guide explicitly excludes requests |
| 34 Personal Profile | Complete | Own required fields/photo, editable permitted values, My Organizations shortcut | P, I; profile_overview.dart |
| 35 Account Settings | Partial | Profile, password link/sign-out; no notification preferences/removal request | P, A |
| 36 Account Removal | Deferred | No request/reauth/removal workflow or related retention implementation | Original Module 3 deferral; auth/profile/Worker inventories |

Complete screen classifications cover core behavior rather than exact reproduction of every suggested wireframe arrangement. Partial rows explicitly preserve material omissions, even where a privacy decision or current module scope explains them.

## Fourteen Business Rules (Section 8)

| Rule | Classification | Enforcement/evidence |
| --- | --- | --- |
| 1 Own permitted profile updates | Complete | Narrow Rules allowlist and validated Worker saves; P |
| 2 No self platform-role change | Complete | Direct role writes denied, trusted bootstrap; P/D |
| 3 Authorized membership state/roles | Complete | Pending/review Rules plus versioned membership backend; O |
| 4 Managers restricted to assigned org | Complete | organization.managerUid reread by Rules/Worker; O/E/T |
| 5 Officers only assigned tasks | Complete | manageEvents/manageAttendance/viewRoster independent; O/E/T |
| 6 Own private membership/attendance/badges | Partial | Own membership/attendance implemented; badges absent | 
| 7 Capacity/deadline/eligibility/duplicates | Complete | Atomic client transaction/batch plus Rules getAfter/delta checks; E |
| 8 No fabricated ordinary attendance | Complete | Manual operator/server schema; server-only QR/corrections; T |
| 9 Trusted conditional badge awards | Deferred | No award implementation; fail-closed denial is not functionality |
| 10 Attended-event single rating | Deferred | No rating implementation |
| 11 Retention-aware account removal | Deferred | No removal/retention state machine |
| 12 Authorized validated logged manager transfers | Partial | Admin reassignment is versioned/audited; request workflow missing; D |
| 13 No public admin self-provisioning | Complete | New user/pending defaults, protected fields, operator bootstrap; P/D |
| 14 Server authorization survives UI bypass | Complete | Existing adversarial Rules/Worker unit/emulator cases; no claim of exhaustive penetration testing |

## Technology, Schema, Roles and Navigation (Sections 1–4, 6–10)

| Requirement | Classification | Evidence/qualification |
| --- | --- | --- |
| Android Flutter/Dart, Auth/Firestore, Provider/ChangeNotifier/go_router/lints | Complete | pubspec, DI/router, feature folders; APK build passed |
| VS Code/Android Studio as team workflow | Not verified | Project files/tooling do not establish every developer's editor usage |
| Git/GitHub collaboration | Partial | Git checkout and workflow guide exist; remote team workflow/CI not exercised |
| Separate dev/prod Firebase | Partial | orglink-dev consistent; no validated orglink-prod configuration; user instruction restricts this task to development |
| No real students in development fixtures | Partial | Executed synthetic fixtures; live database/operator datasets not inspected |
| Optional Firebase Storage | Complete | Not selected; Cloudinary implements optional imagery; no need to enable Storage |
| Rules, composite indexes, emulator setup | Complete | root firebase.json and declared indexes, executed suites; deployed indexes not verified |
| Platform vs org roles, multi-org memberships | Complete | Separate fields, authoritative managerUid, contextual permissions; O/D |
| All suggested officer types | Partial | Title options/configured values separated from three capabilities; no finance, committee or announcement task subsystem; financial functionality was conditional |
| Customizable hierarchy/committee assignments | Partial | positions model and title assignment exist; no full structure/committee editor; O |
| Suggested users/orgs/memberships/events/registration/attendance schema | Complete | Implemented canonical paths/timestamps; architecture schema |
| Badge/award/rating/notification/announcement/transfer collections | Partial | activityLogs implemented; other required behaviors/collections absent |
| No indefinitely growing participation arrays on user | Complete | Own collection-group registrations/memberships and scoped attendance reads |
| Feature layers/models | Partial | Layers exist for implemented modules; absent features have no working models/repositories |
| Bottom navigation Home/Organizations/Events/Badges/Profile | Partial | Actual Home/Events/QR/Organizations/Profile; Badges replaced by QR in current MVP |
| Protected routing, org selector, role-dependent entries | Complete | router, scopes, management hubs and access-denied views; backend remains authoritative |
| Loading/empty/success/error, duplicate/conflict flows | Complete | Existing ViewModels/screens and named UI/workflow tests; actual network/device acceptance remains outstanding |
| Responsive Android and accessible design | Partial | Local widths/large-text/semantics tested; physical TalkBack, camera, keyboard and predictive Back not accepted |
| Credential-safe trusted backend | Complete | Runtime Worker credentials kept out of Flutter; no live secret values inspected or certified |

## Design Deliverables (Sections 11–15)

| Required deliverable | Classification | Local evidence/remaining gap |
| --- | --- | --- |
| 1 Overview/assumptions | Complete | Existing requirements/README plus this consolidated set |
| 2 Roles/permissions matrix | Complete | security.md with current manager membership capabilities |
| 3 Complete sitemap/route map | Partial | Actual router source and original UI/module docs; absent screens have no working routes |
| 4 Low-fidelity wireframes for all 36 | Not verified | `docs/wireframes-orglink.png`, `docs/figma/`, UI companion PDF exist; all-screen coverage/layout not recertified |
| 5 Shared design system | Complete | Material 3 theme/tokens/components; U |
| 6 Complete asset inventory | Partial | Asset directories/provenance and existing UI docs; no verified full required table, gamification assets absent |
| 7 Sixteen-column page-by-page specification | Partial | Existing guides plus screen matrix; no recertified complete original-format table for all 36 |
| 8 Firestore structure/examples | Complete | Existing database-schema guide reused/corrected in architecture.md; absent proposed collections explicitly identified |
| 9 Auth/security architecture | Complete | security.md and underlying source/tests |
| 10 All 12 Mermaid workflow diagrams | Partial | Existing module/design diagrams retained; absent badge/rating/transfer/removal flows are not executable workflows; full diagram inventory not recertified |
| 11 Layered Flutter directory structure | Complete | Source tree and architecture guide |
| 12 Testing checklist for all specified workflows | Partial | Core suites/checklists exist; missing features have no executed acceptance suites |
| 13 MVP/future roadmap | Complete | Existing scope boundaries and explicit V1/V1.1 recommendations in audit report; original gaps remain visible |

## Essential V1 Versus Recommended Deferrals

For a **core demonstration**, authentication/approval, membership and permissions, event registration/capacity, attendance and administrator workflows are essential. Their source and local tests exist, but deployed service compatibility, prepared authorized fictional accounts and physical-device acceptance are gates. Complete these without bypassing authorization.

Badges and attendance-eligible ratings are central to the original gamification/engagement objective. They remain P1 specification gaps even if the presentation scope explicitly defers them. Calendar/notifications/announcements, manager-transfer requests and account removal are also original requirements, not optional simply because the current app lacks them.

A supervised V1 demonstration can reasonably disclose these as V1.1 work alongside committee/settings depth, report export/date filters and audit browsing. Broader student rollout requires an account-removal/retention policy and operational abuse/privacy review first. No feature was implemented or original requirement silently waived during this audit.
