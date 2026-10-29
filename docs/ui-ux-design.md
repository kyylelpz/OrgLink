# OrgLink — Implemented UI/UX Baseline

**Updated:** 29 October 2026. **Status:** current implemented design, following the manual redesign and regression audit.

This document describes the application in the repository. The current UI is the approved visual baseline. Earlier PDF/wireframe proposals, Open Sans guidance, bright-blue primary-action recommendations, old navigation descriptions and migration plans do not override it. Historical migration records remain useful change history, not instructions to redesign these screens again.

## Theme, branding and shared presentation

- Light Material 3, bundled **Inter** variable font and centralized `AppTheme` / `AppColors` / spacing, radius, elevation and typography tokens.
- Primary blue **#152D97**, midnight **#000246**, navy **#1E2A78**, purple **#8E75F7**, mist **#F0F2FA**, ink **#0A0A0A**, white surfaces. Bright blue in existing decorative artwork is not the primary action color.
- Success **#16704A**, warning **#825900**, error **#B42335**, muted text **#60677C** and border **#DDE2F0**, with their existing pale status surfaces. Labels/icons accompany statuses; color is not their only meaning.
- Mist page bodies, rounded midnight headers, white cards, blue primary actions, tonal/outlined/text secondary actions and destructive confirmations. Individual manually styled screens use the existing field/action radii rather than one universal shape.
- Shared token radii: field 12dp, card 16dp, button 14dp, action 20dp and feature 24dp. Common spacing is 4/8/12/16/24/32/48dp. Base type roles include 15dp body, 13dp supporting text, 12dp labels and 14dp buttons; headings scale through the existing theme.
- Official PNG assets: `assets/icons/1.png` (wordmark on midnight), `2.png` (wordmark on light) and `3.png` (transparent symbol). `AppLogo` preserves aspect ratio and embedded safe space. The wordmarks have opaque square canvases and must not be stretched or casually cropped.
- Existing local icons/illustrations are reused. Organization logos and event posters remain data supplied, with missing/error fallbacks. Production cards do not use sample event names, invented totals or demo QR patterns.
- `AppPageBody`, `AppSurfaceCard`, headings, action buttons, filter/status chips, search fields, feedback panels and optional capitalization suggestions remain shared. Feature-specific cards compose these components.

## Navigation and Android Back

The **actual approved bottom bar is Home | Events | QR | Organizations | Profile**. The manual redesign replaced the former Calendar tab with Events; this audit preserves that decision. It does not silently change the second tab back.

| Destination | Implemented behavior |
|---|---|
| Home | Personalized dashboard and real-data search; repeated tab selection does not stack duplicate roots. |
| Events | Event discovery and My Events; time/organization filters and existing registration/management routes. |
| QR | Raised rounded-square action. Authorized attendance operators enter the scanner only after permission data is ready. Other users receive the personal QR Hub without camera startup. |
| Organizations | Discovery with All/Joined/Discover filters, local Discover/My Organizations/Requests navigation and existing organization details. |
| Profile | Existing profile overview, edit form, community/history links and sign-out. |
| Calendar (`/calendar`) | Existing Coming Soon screen restored as a guarded compatibility deep link. It is **not a bottom tab** and no calendar functionality was implemented. |
| Notifications | Coming Soon destination; no invented notification feed or unread count. |

Organization-scoped event/detail/management pages retain their existing URL classification and selected-tab behavior. Root QR/personal attendance routes select QR; profile selects Profile; organization descendants select Organizations; event discovery/My Events select Events. Utility routes can retain the default Home selection.

`go_router` and the authenticated shell preserve account-scoped presentation history. Back dismisses an open dialog/pushed page first, uses valid history or parent destinations for deep links, and returns non-Home root tabs to Home. Root Home asks **Exit OrgLink?**, with Stay/Exit; the system exit occurs only after explicit confirmation. Sign-out/account redirects remove protected pages and dialogs. My Organizations/Requests custom-header Back uses the same safe handler even when opened with `go()` and no pushed page exists.

## Implemented screens and workflows

| Area | Current presentation and behavior |
|---|---|
| Authentication | Existing animated splash with a minimum two-second visible duration on cold startup and successful Google/email-password login, overlapping initialization/profile resolution; finalized Sign In/Sign Up, Google and Firebase email/password, verification/resend, forgot/reset/success and invalid-link states. Email actions use Firebase validation; verification does not bypass pending approval. See Module 1 for manual setup and linking acceptance. |
| Profile | Change Photo/Remove Photo with interactive square crop (drag, pinch, Reset, Cancel, Confirm, Keep Original); identity/photo fallback, academic information and editable Full Name, Student Number, Year Level, Section, required controlled College/Program dropdowns on save; identity remains controlled by Firebase Authentication. Existing legacy academics stay readable. Verified Google users can explicitly Link Password after fresh Google reauthentication. Existing serialization/backward compatibility is unchanged. Stored spelling/case is preserved; suggestions are opt-in. |
| Home | Midnight personalized greeting/search header, four shortcuts, live **Happening Now** cards when data permits, one featured upcoming event, additional upcoming preview, organization previews and role-aware organization management cards. Search navigates actual accessible event/organization records. No Your Activity section, fake statistics or mock production content. |
| Organizations | Midnight identity/search header; white cards with dynamic logos, actual description/visibility/status and current membership labels. Join/View navigates to existing details; it does not bypass membership requests. |
| Organization Details | Authorized managers can Change Logo/Remove Logo using the shared interactive square crop; organization identity, published description/mission/vision/goals, structure, requirements and public officers; events, request/status feedback and authorized management/roster links. |
| Memberships | My Organizations and Membership Requests retain their existing record selection, assigned-manager entries and unavailable-record retry. Request queue and roster show real names, roles, statuses and dates. Approve/Reject requires confirmation and successful completion before feedback. |
| Event Discovery/My Events | Dark headers, existing search/filters, shared poster/date/registration cards and local navigation. Personal registrations retain name refresh, unavailable-event retry and eligible withdrawal. |
| Event Details/Registration | Actual organizer, schedule, venue, capacity/deadline/visibility/status, registration status and confirmation review. Existing draft/submission/approval/publication/lifecycle and attendance/participant actions appear only under their existing guards. |
| Event Management/Editor | Search/status filtering, lifecycle/approval cards and Create Event action. Single draft form with existing validators/date pickers, optional Event Poster section above Event Details in the same card, separate normal-weight (Optional) text, local selection/landscape crop preview/change/removal, and Save Draft. Poster upload starts automatically after draft creation; failure shows Retry Upload for the same draft. Edit Draft retains immediate poster saving and shares landscape drag/pinch cropping, Reset, Cancel, Confirm, Keep Original, and a Home trim preview. Creation does not publish automatically. |
| Participants | Event-scoped identities and registration timestamps, real reserved/capacity totals, loading/error/empty feedback. Attendance entry remains separately permission controlled. |
| QR Hub/Pass | Personal QR and attendance actions; organizer tools are hidden unless relevant. A registered-event selector drives the existing short-lived server credential, window restrictions, regeneration, expiry and already-verified states. Actual QR pixels are responsive and retain the existing payload. |
| Scanner | Midnight page with live native camera, framing overlay, permission/error retry, server verification/duplicate feedback, next-participant action and manual lookup. No static camera photograph or sample pass substitutes for live input. |
| Attendance | Organization/event selection, actual summary tiles, name/status filtering, per-participant results, permitted manual verification and separate correction action. Report/history views show real records. |
| Correction | Modal organization/event/participant context, before/after status, required reason, confirmation, busy/back guards and visible conflicts. Existing correction/audit calls remain authoritative. |

## Image Editing and Upload Boundaries

Profiles and organization logos use the same Material 3 fixed-square live crop
preview, with draggable positioning, pinch zoom, Reset, Cancel, Confirm, and
Keep Original. Platform Admin organization cards reuse the logo editor. No new
cropping package is required. Create Event and Edit Draft posters reuse the
interactive cropper with a landscape frame derived from the Details content
width/184 dp slot, rather than assuming 16:9. At 393 dp without horizontal insets,
this is 345:184 (15:8). A live Home Preview mirrors its content-width/174 dp
center-cover trim. Cards/details retain `contain`; Home retains `cover`. Keep
Original preserves selected bytes without cropping.

Gallery resizing/compression, the 5 MiB limit, post-crop validation, progress,
retry/error feedback, and fallback imagery remain. Confirm renders the chosen
crop before upload; Cancel uploads nothing. Keep Original skips cropping of the
selected bytes. Profile/logo and Edit Draft image saves are immediate and separate from text forms. Create Event holds its optional poster locally until draft creation succeeds, then uploads it automatically; failed uploads retain the draft and selection for retry. Busy submissions block navigation; leaving a pending selection requires confirmation. No image bytes are persisted across app termination.

The Worker authorizes and verifies every saved reference. New uploads sign the
resource's dynamic `asset_folder`, while existing public IDs and image references
remain intact. The approved splash animation is unaffected. See
[Cloudinary setup and acceptance](cloudinary-setup.md) for permissions, schema,
folder paths, configuration, cleanup, and test evidence.

## Role visibility and data boundaries

- Signed-out, incomplete-profile and ineligible accounts retain their existing redirect states. Protected routes do not become available through tab selection or direct links alone.
- Membership review remains assigned-manager controlled; roster access uses the existing manager or active-member roster permission. Self-review remains blocked.
- Event management requires assigned manager access or active officer `manageEvents` permission. Officer access remains constrained to existing event ownership/creator rules; managers retain review/publication/lifecycle controls.
- Scanner, manual marking and corrections require the existing organization-scoped attendance permission. Event-editing access alone does not grant attendance access. Permission failures/revocation do not keep the camera running.
- Registration eligibility, deadlines, capacity, duplicates, withdrawal and event lifecycle remain checked by the existing models/backend transactions. Display labels never replace canonical role/status values in comparisons or writes.
- No attendance record means **Not Marked**, not Absent. Ordinary verification does not replace an existing result; authorized correction is separate and auditable. Pending correction removes the active result using the existing workflow.
- Server-issued QR credentials, Worker redemption, duplicate detection and correction revision checks remain unchanged. Busy/stale responses and account switches retain their existing safeguards.
- Architecture stays View → ChangeNotifier ViewModel → Repository → Service → Model, with Provider and go_router. The audit did not modify repositories, services, models, Firebase initialization/configuration, schemas, Firestore Rules, Worker code or profile persistence.

## Splash Presentation Timing

The existing animated splash design is unchanged. Its two-second minimum starts
on the first visible frame and overlaps Firebase/auth/profile/account resolution.
Startup bootstrap and initial session loading share the same interval. Slow
loading exits immediately when resolved; failed/cancelled login does not create
an unnecessary second splash. All verification, account-status, and authorization
redirects are preserved. Timing is lifecycle-bound in the presentation/router
layer, with no added repository or backend delay. See
[Module 1 timing and validation](module1.md#splash-and-loading-timing).

## Responsiveness and accessibility

The current layout is checked at **320, 360, 393 and 412dp**, including **200% text**, long titles/names, keyboard insets, safe areas, missing imagery and loading/error/empty/success states.

Confirmed regressions fixed in this audit:

1. Restored the removed Calendar compatibility route/constant under the existing eligibility guard, preserving the approved Events tab.
2. Replaced unsafe custom-header `context.pop()` on direct membership pages with the shared Back handler and an accessible 48dp target/white icon on midnight.
3. Constrained editor date text and membership/attendance status rows to available width; let schedule/registration metadata wrap instead of overflowing.
4. Made organization discovery's header/content scroll together when the keyboard and large text leave insufficient height. Normal visual composition is retained.
5. Preserved three-column attendance summaries at ordinary text sizes and stacked metrics at enlarged text sizes so labels remain readable.
6. Removed an unused pass-screen variable and replaced deprecated opacity calls with equivalent alpha values. Updated stale tests to verify current labels/components without restoring the previous design.

Navigation and status controls retain semantic labels and current theme contrast. Large-text navigation labels can wrap across lines; no destination is renamed or hidden to force a fixed height. Physical TalkBack/focus order and hardware QR readability still require device acceptance.

## Historical redesign audit evidence — before email authentication

- `flutter analyze --no-pub`: **no issues**.
- Full Flutter suite: **170 tests passed**, including auth/account redirects, membership request/approval/rejection, event create/review/publish/register/withdraw, private access, QR windows/issuance/invalidation, scanner lifecycle/retry/revocation, manual verification and correction/conflict handling.
- New direct membership-page regression test covers `go()` without a pushed entry, safe Back, touch-target size and icon contrast. Existing responsive suites cover the repaired narrow/large-text layouts.
- Local attendance Worker tests: **48 passed**, including authentication and transaction/rollback checks. Worker source was not changed.
- Rendered widget previews were reviewed for retained visual styling and enlarged-text readability. Synthetic accounts/events/camera frames exist only in test fixtures.
- Formatting and diff checks cover changed files. No deployment, live-data writes, configuration changes or credential changes occurred. The initial concurrent pub step hit a generated macOS ephemeral-file lock; analysis was rerun successfully with resolved dependencies and `--no-pub`.

## Unresolved limitations and manual acceptance

- Calendar and Notifications remain intentionally Coming Soon. Calendar is available by its compatibility route, not a visible tab. Future ratings, badges, announcements, manager transfer, platform administration and unsupported analytics/export were not implemented.
- Automated platform fakes do not certify real Google account sign-in, Android camera drivers/settings recovery, predictive Back, screen-reader focus, or two-device Worker QR scanning/expiry. Verify these on the target Android device using the configured development backend.
- During the historical redesign audit, Firestore Rules/deployed backend authorization were not changed or newly certified against a live deployment; the Flutter permission/transport tests and local Worker suite are regression evidence, not a production security certification.
- Device-level landscape behavior, offline network image quality and daylight QR readability remain manual checks. Current large-font navigation labels may wrap; the approved five-item bar is preserved.

See `docs/ui-migration-phase1.md`, `ui-migration-phase3.md`, `ui-migration-phase4.md` and `ui-migration-phase5-6.md` for historical migration details. This implemented baseline supersedes their older visual plans where the manual redesign differs.

## Email authentication addition — 29 October 2026

The finalized auth frames were read through Figma MCP and implemented within the
existing theme; the loading screen and authenticated dashboard/navigation remain
unchanged. New profiles are pending, existing statuses and UIDs stay intact, and
College/Program use the controlled Engineering options. Auth utilities handle
Back and real Firebase email action codes. Responsive auth tests cover all four
phone widths at 200% text scaling. Fixed expiry and immediate universal-logout
claims from Figma were replaced with accurate Firebase wording.

See [Module 1](module1.md) for current test evidence, manual provider/templates/
App Links setup, undeployed Rules/Worker verification guards and the explicit
Google-link emulator limitation. Earlier audit counts above describe the prior
redesign audit, not validation of this authentication addition.

## Platform Administration MVP

Eligible platform admins have a Profile → Platform Administration entry. New
utility routes provide real saved-profile/organization counts, paginated account
search and confirmed account decisions, organization creation/editing and explicit
manager assignment. The existing bottom navigation and Modules 1–4 styling remain
unchanged. Inter, midnight headers, shared surfaces/actions/status feedback and
OrganizationLogo are reused; pages/dialogs adapt to narrow screens and 200% text.

UI visibility is only a presentation guard. The Worker checks the authoritative
active platformAdmin profile for every call; ordinary users and managers are
denied. See [Platform Administration](platform-admin.md) for current policies,
audit/concurrency behavior, provisioning and manual acceptance. This supersedes
earlier future-only administration notes; no deployment/provisioning occurred.
