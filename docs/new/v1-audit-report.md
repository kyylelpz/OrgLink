# OrgLink V1 Release-Readiness Audit

**Verdict: Conditionally Ready for the implemented core V1 demonstration. Not ready to claim full original-specification compliance or production release readiness.** No confirmed P0 exploit or core integrity/workflow failure was demonstrated by the executed checks. Deployment compatibility and physical-device acceptance remain release gates, and multiple original mandatory features are absent.

Audited 30 October 2026 (Asia/Manila), commit `9b1e0536b98b5325fc90d189eb1327c08fc1dfef`, initially clean working tree. Scope: source, navigation, original local specification PDF, existing docs, Rules/indexes, Worker, Cloudinary integration, tests and Android build/configuration. Source inspection and existing tests provide bounded evidence, not comprehensive proof that every workflow or malicious input is safe.

Toolchain: Flutter 3.44.6 / Dart 3.12.2, Node 24.11.1, Firebase CLI 15.34.1, Java 24.0.2 (emulator runtime), Wrangler 4.153.0; Android project compilation targets JVM 17. Existing local installations were reused.

While documentation was being written, an external edit appeared in `lib/features/auth/presentation/screens/auth_screens.dart`, removing the Account Status Refresh Status button and inserting spacing (file modification time 16:01 Asia/Manila). This audit did not make or revert that change. The full Flutter suite and release APK build were repeated after detecting it; current logs contain the reruns. Backend source was unchanged. Treat the final audited workspace as the stated commit plus this concurrent UI edit, rather than an exact pristine commit certification.

## Method and Boundaries

Reviewed feature services/models/ViewModels/views, router/DI, Firestore Rules/index declarations, Worker routing/auth/transactions/admin/membership/Student ID/attendance/images, Android manifests/signing and existing test scripts. Extracted original PDF text across all pages and mapped all 36 screens, 14 business rules and 13 deliverables in [compliance](requirements-compliance.md). Existing wireframe assets/UI companion were inventoried; their full visual-design compliance was not recertified.

No app/backend/Rules/test behavior was changed. No dependencies were installed/upgraded, remote resources deployed, live endpoint/database read performed, or accounts provisioned. Emulator fixtures use synthetic local data. Build/test tools produced ordinary ignored local caches/build outputs; requested documentation and retained validation evidence are under `docs/new/`. Existing documentation was preserved.

## Executed Validation

Commands run from repository root unless noted. Logs alongside this report are the evidence. Counted suites are separate invocations, not a claim of distinct end-to-end scenarios.

| Check | Actual outcome | Evidence |
| --- | --- | --- |
| `flutter analyze` | **Nonzero exit 1**: 4 warnings, 1 info, 0 analyzer errors; not clean | [Log](flutter-analyze.log) |
| `flutter test --reporter expanded` | **296 passed**, exit 0 | [Log](flutter-test.log) |
| `npm.cmd test --prefix workers/attendance` | **104 passed**, 0 failed/skipped/TODO | [Log](worker-tests.log) |
| `npm.cmd test --prefix tools/admin` | **38 passed**, 0 failed/skipped/TODO | [Log](operator-tests.log) |
| `firebase.cmd emulators:exec --project orglink-dev --only firestore,auth "npm.cmd --prefix firebase/tests test"` | **163 passed, 0 failed, 1 TODO**, process exit 0; 164 reported tests | [Log](firebase-tests.log) |
| Combined backend emulator command below | **50 passed**, 0 failed/skipped/TODO, exit 0 | [Log](backend-emulator-tests.log) |
| `npx.cmd --no-install wrangler deploy --dry-run --outdir ../../docs/new/worker-bundle` (Worker directory) | **Passed**, local bundle only, no remote bindings certified | [Log](worker-build.log) |
| `flutter build apk --release --no-pub` | **Passed**, 76.9 MB release-mode APK; debug signing config | [Log](android-release-build.log) |
| `dart format --output=none --set-exit-if-changed .` | **Nonzero exit 1**: 132 files checked, 16 would change; source intentionally not rewritten | [Log](dart-format.log) |

Total executed test results: **651 passed, 0 counted failures, 1 TODO** across Flutter, Worker, operator, Rules/Auth and backend emulator suites. Node prints the TODO as a failing subtest diagnostic but excludes it from fail count; it is **not** a pass. The installed Auth emulator rejects Google-to-password linking with the same email (`auth/email-already-in-use`). Verify UID-preserving linking manually on Android. No required suite remains blocked by missing local tooling.

Combined emulator command:

```powershell
firebase.cmd emulators:exec --project orglink-dev --only firestore,auth "node --test --test-concurrency=1 workers/attendance/test/attendance.emulator.test.cjs workers/attendance/test/admin.emulator.test.js workers/attendance/test/student_ids.emulator.test.js workers/attendance/test/images.emulator.test.js workers/attendance/test/memberships.emulator.test.js tools/admin/provision-demo.emulator.test.mjs"
```

Initial backend-emulator startup failed because port 8080 was retained by the first run's Firestore Java child. Its PID, creation time, project and exact repository Rules path were verified before stopping only that test-owned process. The clean retry passed. Emulator PERMISSION_DENIED/evaluation diagnostics occur in intentional rejection cases; the final suite result, not the presence of an error-looking line, determines pass/fail. Rules expression-limit messages appeared on denied malformed writes; no tested allowed workflow failed from that limit.

The second test-owned Java child was also identified and stopped after completion to release port 8080. Disposable Worker bundle files were removed; its successful dry-run log is retained.

The first PDF extraction attempt lacked PyMuPDF; bundled pypdf succeeded after UTF-8 output was selected. No dependency installation was needed. An initial Worker dry-run invocation had an incorrect relative log path and did not run; the corrected Worker-directory command above passed. Neither setup retry is represented as a passing test.

## Verification by Module

| Module | Implementation/local evidence | Deployment/device status |
| --- | --- | --- |
| Auth/profile | Google/email SDK flows, verification gate, linking/reset UI, profile validation, atomic unique Student ID registry | Real OAuth/email/action-link association and linking TODO unverified |
| Account approval | Trusted pending→active/rejected and active↔disabled decisions, live app-status checks | Actual admin identity/provider/live account acceptance unverified |
| Organizations/memberships | Discovery/apply/cancel/review, manager roster, officer role/capability changes, termination/reapply, immutable management audits | Compatible deployed Worker/Rules and multi-session revocation unverified |
| Events/registration | Lifecycle approval/publication, posters/retry, eligibility/deadline/capacity, withdrawal, identity privacy | Live indexes and actual-device network behavior unverified |
| Attendance | QR hash/expiry/binding, concurrent redemption/manual races, current permissions, correction revision/audit/reset, reporting/history | Physical camera and two-phone flow unverified |
| Platform admin | Authoritative role checks, counts, directory/search, exact-ID manager resolution, audited versioned changes | Bootstrap/current deployment not inspected |
| Cloudinary | Authorization, proxy upload tickets, verified revisioned references, folder mappings/cleanup tested locally | Real upload/folder/lookup/delete and cron/secrets/IAM unverified |
| UI/navigation | Auth/eligibility redirects, role denial, loading/empty/error/success, narrow/large-text local tests | TalkBack, predictive Back, real keyboard/gallery/camera/resume unverified |
| Calendar/notifications | Explicit Coming Soon only | No working feature/deployment claimed |
| Badges/ratings/announcements/transfers/removal | Missing executable workflows (some explicitly deferred in existing guides) | Cannot be certified by unrelated core tests |

## Prioritized Unaddressed Issue Register

Counts: **P0 0; P1 6; P2 7; P3 2 (15 total)**. The register separates confirmed defects, verification risks and requirement gaps. P1 requirement gaps are blockers to claiming the full original specification, not proven failures in the existing core demo. “V1 blocker” identifies that distinction explicitly; it is not a waiver of scope.

### Deployment and Acceptance Risks

| ID / title | Severity / module | Description, impact and evidence | Recommended resolution | V1 blocker | Status |
| --- | --- | --- | --- | --- | --- |
| V1-01 Deployed stack and device acceptance absent | P1 / cross-system | Defaults/config/local results cannot establish live compatibility, provider setup, IAM/bindings, index readiness or two-phone QR. `firebase.json`, `wrangler.jsonc`, transport defaults; no remote/device acceptance executed. Linking has one emulator TODO. Demo can fail at onboarding or QR even with passing tests. | Record authorized existing deployments/config and run the minimum acceptance checklist with the exact APK. Resolve the TODO on Android. | Yes, until acceptance evidence exists | Needs verification |
| V1-11 Abuse, QR relay and retention controls | P2 / security/operations | `attendance.js`, `auth.js`, image cron and `wrangler.jsonc`: no App Check/distributed scanner abuse control/general QR-audit retention; valid forwarded QR remains usable within its window; observability disabled. No attack/quota outage demonstrated. | Supervise identity checks for demo; define retention, logging/monitoring and endpoint abuse policy before wider use. | No for supervised demo; broader rollout review needed | Needs verification |
| V1-13 Distribution signing is unfinished | P2 / Android | `android/app/build.gradle.kts` uses debug signing for release and `com.example.orglink`. APK builds, but production identity/signing and its OAuth certificate are not established. | Accept and label a development demo APK; configure approved release signing/certificate registration before distribution. | No for accepted development demo; yes for production distribution | Open |

### Confirmed Defects and Quality Failures

| ID / title | Severity / module | Description, impact and evidence | Recommended resolution | V1 blocker | Status |
| --- | --- | --- | --- | --- | --- |
| V1-09 Policy names are not links | P2 / authentication | `_TermsNote` in `lib/features/auth/presentation/screens/auth_screens.dart` renders plain Text while PDF screen 3 requires Terms/Privacy links. Users cannot open policies from sign-in. | Supply approved policy destinations and accessible actions in a separate implementation task. | No core demo; required before public onboarding | Open |
| V1-10 Static analysis is not clean | P2 / code quality | Actual analyzer exit 1: unused `_CropCoverPreview` (profile_photo_crop_dialog.dart:314), unused event import (event_discovery_screen.dart:10), unused profile imports (complete_profile_screen.dart:3,12), closure style info (my_events_screen.dart:173). Existing historical clean claims are inaccurate. | Remove unused code/imports and apply the style correction in an authorized implementation pass; rerun checks. | No; no analyzer errors/build failure | Open |
| V1-14 Formatting check fails | P3 / maintainability | Nonmutating whole-tree format reports 16 files needing formatting; dart-format.log lists paths. No files were reformatted during the audit. | Apply scoped formatting in a separate change and rerun validation. | No | Open |
| V1-15 Crop instruction references absent preview | P3 / image UI | `profile_photo_crop_dialog.dart:263–265` tells poster users Home trim is “shown below”; build tree renders only the main preview. `_CropCoverPreview` is unused. | Correct instruction to match the approved single-preview UI; update exact-text coverage where needed. | No | Open |

### Original Requirement Gaps and Explicit Deferrals

| ID / title | Severity / module | Description, impact and evidence | Recommended resolution | V1 blocker | Status |
| --- | --- | --- | --- | --- | --- |
| V1-02 Badge collection/management/awarding absent | P1 / gamification | PDF screens 25–26, business rule 9 and badge flow require trusted awards, collection/catalog. No feature models/routes/backend; existing scope docs defer badges. Core participation does not satisfy gamification. | Disclose original gap; separately plan criteria, idempotent trusted awards, collection and tests. | Yes for full specification; no for explicitly limited core demo | Deferred |
| V1-03 Attendance-eligible ratings absent | P1 / engagement | PDF screen 27 and rule 10 require one rating/comment per attended event and summary/moderation. No working rating feature or trusted validation. | Preserve gap and implement/test eligibility/uniqueness in a future scope. | Yes for full specification; no for explicitly limited core demo | Deferred |
| V1-04 Calendar, notifications and announcements incomplete | P1 / communication | PDF screens 6,28–31; router exposes Coming Soon calendar/notifications; no announcement publishing/feed/audience/read-state backend. Local snackbars are not notifications. | Present placeholders honestly; plan calendar and durable audience-aware communication workflows. | Yes for full specification; no for explicitly limited core demo | Open |
| V1-05 Manager-transfer requests absent | P1 / administration | PDF screen 33 and rule 12 require request/proposed-manager/review workflow. `admin.js` permits direct audited replacement only. | Retain administrator replacement as current behavior; plan validated request/review lifecycle separately. | Yes for full specification; no for explicitly limited core demo | Deferred |
| V1-06 Account removal and retention workflow absent | P1 / account/privacy | PDF screens 35–36 and rule 11; no request/reauth/removal endpoint or retained-history policy implementation. Deactivation is not removal. | Define policy and trusted removal request/process before broad rollout. | Yes for full specification; no for supervised limited demo | Deferred |
| V1-07 Organization settings and committees partial | P2 / organizations | PDF screens 20–21/section 6: manager has roster/capability and logo controls, admin core configuration; no full manager settings/committee editor. Admin patches omit positions/publicOfficers hierarchy editing. | Disclose permission/editor boundaries; plan authorized manager settings/structure management. | No core demo; original requirement remains partial | Open |
| V1-08 Attendance date filters/export absent | P2 / reports | PDF screen 23 requires date filters and authorized export. Report has event/name/status filters and statistics; no CSV/export/date-range implementation. | Demonstrate actual event-scoped report; add privacy-aware export/date filtering separately. | No core demo | Deferred |
| V1-12 Activity/engagement visibility partial | P2 / admin/membership/events | PDF screens 19/31 require member engagement and recent platform activity. Current details show membership metadata, logs have no browser; initial reviews/events/registrations retain state metadata rather than comprehensive append-only history. | Define scoped engagement/log views and audit coverage; preserve existing immutable logs. | No core demo | Open |

No security exploit is inferred solely from a missing optional hardening feature. Conversely, passing unrelated tests does not complete any missing requirement above.

## Documentation Reconciliation

Original documents are retained. The earlier QA report's “Ready for Deployment,” no-defect/clean-analysis statements and older 212/259 counts do not represent this audit. Its `WORKER_SERVICE_ACCOUNT_KEY` binding name is incorrect for current source; use `FIREBASE_SERVICE_ACCOUNT`. Older module text describing only `/issue` and `/redeem`, absence of a default API origin, same-card posters/Home crop preview and operator-only officer assignment is superseded by source and this set. The original platform-admin bootstrap procedure contains a personal operator identity; the reusable new guide intentionally omits it.

Accurate architecture/schema/permissions/setup content was copied and targeted corrections applied. Module guides preserve useful existing workflow, security, recovery and setup decisions without carrying obsolete implementation-phase totals. Current source/test paths and the requirement matrix ground the new claims. No missing feature was added to make documentation look complete.

## Minimum Actions Before Presentation

1. Agree and clearly state that V1 demonstrates the implemented core, while the original requirements in V1-02–08/V1-12 remain incomplete. Do not present Coming Soon screens as working features or claim full compliance.
2. An authorized operator must privately record compatible deployed Worker/Rules/index versions and configuration, confirm the existing administrator and prepared fictional manager/officer/member accounts, and verify any required Student ID registry adoption. No new accounts/live changes are authorized by this audit.
3. Install the exact accepted development APK on two Android phones. Verify Google sign-in, password verification/reset email/action links, UID-preserving Google/password linking, profile pending→approval, sign-out/restart and live deactivation/revocation. Confirm OAuth matches that APK's certificate and action-link domain association works.
4. Exercise organization request/cancel/review, officer permission grant/revocation with a second session, draft→submit→approve→publish, private/public eligibility, capacity conflict and withdrawal. Verify actual deployed queries/indexes and empty/network error recovery.
5. During a correctly scheduled published event, register students, perform manual and two-phone QR marking, reject duplicate/expired/regenerated passes, verify correction/reset and report totals, and ensure revoked officers cannot mutate. Visually verify participant identity.
6. Upload a harmless public-use profile/logo/poster and confirm live verification, dynamic folder mapping, removal and scheduled cleanup. Verify camera denial, background/resume, gallery crop, keyboard, narrow layout, large text and TalkBack.
7. Resolve or explicitly record acceptance of analyzer/formatting and minor text/policy gaps. Preserve the known-good demo build and a non-destructive fallback demonstration using disclosed local test evidence; do not weaken security or fabricate deployment success.

These are unexecuted manual acceptance instructions, not passed checks. Deployment/provisioning/migration steps require separate existing authorization and were not run here.

## Recommended V1.1 Work and Final Assessment

For a supervised core demo, badges, ratings, full calendar/notification/announcement delivery, transfer requests, committee/settings depth, report export and log browsing can be scheduled after V1 **only with an explicit presentation scope disclosure**. They remain requirements of the original document. Account removal/retention and abuse/privacy controls should precede unsupervised broader student rollout rather than be indefinitely postponed.

The verified local core is substantial: source-backed identity/profile/approval, organization and officer management, event lifecycle/registration, attendance/corrections and administrator operations passed the existing test suites, and an Android release-mode build succeeded. Outstanding acceptance gate V1-01 prevents an unconditional Ready verdict. There is no confirmed P0 blocker from this audit, but missing original requirements and unverified remote/hardware behavior prevent full-system release certification.
