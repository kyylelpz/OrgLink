# Platform Administration MVP

Implemented for **orglink-dev** only. No administrator was provisioned, no live
roles/managers were changed, and no Worker or Rules were deployed by this task.
The intended initial operator-selected identity is **lopez.kyle922@gmail.com**.
That email appears only in this procedure; it is not an app/Rules/Worker allowlist.

## Scope and architecture

This MVP follows the specification's separation of platform and organization
roles (Elective3_FinalProject.pdf, roles, screens 31–33 and administration business
rules). The approved implemented UI and Modules 1–4 remain the baseline.
Manager replacement is an explicit administrator operation here; a manager
transfer-request workflow, announcements and other future screens are not added.

Flutter follows View → AdminViewModel (ChangeNotifier) → AdminRepository →
AdminService → existing Cloudflare Worker → Firestore, with typed models and
Provider/go_router. The service uses the existing `ATTENDANCE_API_URL` definition
and the same configured development Worker. No new package, Firebase Cloud
Function, hosting service or paid infrastructure is introduced. Direct client
privileged writes remain denied by the existing Firestore Rules.

The existing Worker verifies RS256 Firebase ID tokens against the fixed Google
key URL, issuer and orglink-dev audience, expiry and verified password identity.
Every admin read/write then reads `users/{verified-token-uid}` transactionally and
requires matching uid, `platformRole == platformAdmin`, active account and valid
existing student identity fields. Client email/role/custom claims never authorize
these operations. A stale role claim cannot override current Firestore status.
No service-account key is sent to Flutter. Existing attendance endpoints and
permissions are unchanged; the shared REST client gains bounded queries/counts.

## UI and routes

An active, complete platform admin sees **Platform Administration** in Profile.

| Route | UI |
| --- | --- |
| `/admin` | Real Users, Pending Accounts and Organizations counts; management entry points and refresh |
| `/admin/accounts` | Paginated account cards, search, approve/reject/deactivate/reactivate confirmations, errors and results |
| `/admin/organizations` | Directory, search, create/edit dialog, manager assignment and confirmation |

These utility screens do not replace the current bottom navigation. Pushed pages
pop normally; direct management links return to Admin, and direct Admin returns
to Profile. Unauthorized users see access denied and trigger no admin query.
Revoking a role hides privileged content and replaces an open confirmation with
access denied. Backend authorization remains mandatory regardless of UI state.

The screens reuse Inter, midnight headers, blue actions, surface cards, status
chips, OrganizationLogo fallbacks, loading/empty/error feedback, and the optional
capitalization suggestion widget. Stored names are preserved; suggestions require
an explicit action. Cards/forms scroll, actions wrap, dropdowns expand, and
AppBar title height adapts for large text. Tests cover 320/360/393/412dp, 200%
text, long names, keyboard insets, dialogs and native Back. Physical TalkBack and
Android predictive Back remain manual acceptance.

## Data and operation policies

Dashboard counts use Firestore aggregation queries, not sample numbers or a full
directory download. **Users counts saved `users` profile documents**, including
pending/inactive profiles; Firebase Auth identities that have not yet completed a
profile are not counted or listed. Pending means `accountStatus == pending`.
Organizations counts saved organization documents, regardless of status. Counts
are a transactionally consistent snapshot and refresh on request; not a new
analytics collection or polling feed.

Lists fetch 26 records to display **25 per page**, with Next/Previous cursors.
Queries order by name then document ID for deterministic ties. Search supports a
case-sensitive name prefix; accounts also support exact Student ID and exact email. Organization IDs remain exact-searchable. No
normalized values are written back, and no unbounded client filtering is used.
Refreshing/new searches reset or reload pages; concurrent inserts may require a
new search/refresh to appear before an existing cursor.

Account decisions:

- Approve: complete `pending` profile → `active`.
- Reject: `pending` → `rejected`.
- Deactivate: `active` → `disabled`.
- Reactivate: eligible, complete `disabled` student profile → `active`, after confirmation.
- The account's UID, email, profile fields, memberships and history are retained.
  Deactivation changes platform eligibility, not Firebase Auth identity deletion.
  Existing Rules/Worker eligibility checks deny protected data immediately after
  committed status changes, even with a still-valid Auth token.
- Self changes and changes to any non-`user` platform role are denied. There is no
  role editor, self-approval, admin promotion/demotion or administrator shutdown
  action in the public API. Rejected accounts remain excluded from reactivation.
  Pending, suspended, active, incomplete and malformed profiles cannot use Reactivate.
- The Worker derives `canReactivate` on account list responses from matching
  profile UID, `platformRole: user`, disabled status and complete existing identity
  fields (email, Full Name, Student Number, Year Level and Section). Flutter shows
  Reactivate only when that flag and its status/role/self guards permit it. This
  flag is not persisted and is never accepted as mutation authorization. The Worker
  independently revalidates the actual account in the transaction. Existing legacy
  academic values are preserved; reactivation does not impose a profile migration.
- Reactivation uses `accountStatus` / `action: reactivate`, the existing opaque
  document `version` and stable `requestId`. It updates only accountStatus and
  updatedAt; UID, role, profile, memberships, organization ownership, events and
  attendance remain intact. Its atomic audit records the action and disabled/active
  before/after states. Stale versions fail with conflict; identical retries produce
  one change and one audit. The existing ViewModel reloads the page after success.
  Email verification and Firebase Auth's separate disabled flag are unchanged;
  this action restores OrgLink platform eligibility only.

Organization creation uses the existing schema: organizationId, name,
description, logoURL, mission, vision, goals, visibility, status, managerUid,
membershipRequirements, approvalSettings, positions, publicOfficers, createdAt,
updatedAt. Creation supplies empty optional lists and manual approval defaults.
The UI can edit name, description, HTTPS logo URL, mission/vision, goals,
requirements, public/private visibility, active/inactive status, request acceptance
and manager Student ID (resolved to managerUid by the server). Other existing fields are preserved.

Manager selection uses the exact 10-digit Student ID shown in Account Management. The protected Worker resolves it through the registry to the existing UID. The server
requires an existing active account with valid student identity and a recognized
platform role; pending, disabled, missing and malformed profiles are rejected.
An update must match both the current document version and expected manager UID.
A manager may already manage other organizations, as supported by existing
Modules 2–4. An inactive manager must be replaced before saving that organization.

**Organization.managerUid remains the ownership authority.** Replacement updates
only the organization document; it does not delete or rewrite memberships,
events, registrations or attendance. A former manager's existing membership
record, even a historical `manager` label, stays intact and does not independently
grant manager powers. Any separately authorized officer permissions/membership
remain their existing scope. The new manager receives manager powers through
managerUid, without an invented platform role or blanket membership grant.

## API, concurrency and audit records

All operations use POST JSON and Firebase `Authorization: Bearer <ID token>`:

| Endpoint | Payload |
| --- | --- |
| `/admin/stats` | `{}` |
| `/admin/list` | `collection: users or organizations`, allowed `field`, `search`, optional `{id,value}` cursor |
| `/admin/mutate` | `requestId`, `operation`, `targetId`, operation-specific fields below |

Mutation operations: `accountStatus` takes `action` (`approve`, `reject`, `deactivate`, or `reactivate`) and `version`;
`createOrganization` takes `changes`; `updateOrganization` takes `changes`,
`version` and `expectedManagerUid`. Versions are opaque Firestore updateTime
strings from list responses. Changes and collections are allowlisted; field
lengths, status/visibility choices, manager identity, HTTPS logos, IDs and arrays
are validated server-side. Mutation payloads cannot modify arbitrary document
paths or privileged user fields. Requests are capped at 64KiB for admin endpoints
and responses at 256KiB in Flutter; attendance retains its existing request cap.

The Worker reads actor, target, any proposed manager and idempotency/audit record
before writing. A Firestore transaction commits the narrow change and one
`activityLogs/admin-{actorUid}-{requestId}` document atomically. Conflicts fail
with a refresh/review message; the existing REST transport retries aborted
transactions and revalidates all conditions, never blindly overwrites.

Audit fields: actorUid, operation, targetPath, requestId, normalized request,
before/after change context and server createdAt. Passwords/tokens/keys are never
included. Accounts log only status changes; organization edits record their
submitted permitted details. Audit creation failure prevents the target change.
Repeated identical requests reuse their result and do not duplicate the audit;
reusing an ID with another payload is rejected. Flutter retains request IDs for
ambiguous retries in the current screen. New-organization IDs remain stable for
that editor session. If a screen/app is closed after an uncertain response,
refresh the directory and search for the organization before creating another.

Audit documents are server-only under the existing default-deny Rules. No audit
editing/deleting API exists. Read access/audit retention and account deletion
policies are not expanded by this MVP. Service-account IAM/operator privileges
remain a trusted boundary. Sanitized Worker failure logs identify platform-admin
stages without request bodies, account emails, tokens or credentials.

## One-time initial administrator provisioning — operator only

**Do not run this automatically from Flutter, the Worker, CI or app startup.**
The account remains unprivileged until an operator explicitly applies the grant.
The helper is not a public endpoint and does not set a custom email allowlist.

1. In orglink-dev Firebase Console Authentication, independently locate
   **lopez.kyle922@gmail.com** and copy its existing Auth UID. Do not guess a UID
   or create a second account. Complete its existing student profile and email
   verification first. Pending is allowed for this explicit bootstrap approval;
   disabled/suspended/rejected accounts require separate operator review.
2. Use trusted Firebase Admin ADC credentials permitted to read Auth identities
   and read/write development Firestore. Keep key files **outside this repository**
   and never in assets, Flutter defines, logs or committed configuration. The
   script rejects in-repository GOOGLE_APPLICATION_CREDENTIALS paths. Unset both
   emulator host variables; this CLI deliberately supports only orglink-dev.
3. Install existing operator-tool dependencies if needed (`npm --prefix tools/admin
   ci`). Run the read-only verification/plan first in an operator terminal:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\Secure\orglink-dev-admin.json'
node tools/admin/provision-platform-admin.mjs --project orglink-dev --uid ACTUAL_UID --email lopez.kyle922@gmail.com
```

The tool cross-checks getUser(UID) and getUserByEmail(email), enabled/verified Auth
state, matching UID/email in the complete Firestore profile, recognized role and
pending/active status. No write occurs without confirmation.

4. Review the exact UID, email, before role/status and proposed role/status. Apply
   from an interactive terminal only:

```powershell
node tools/admin/provision-platform-admin.mjs --project orglink-dev --uid ACTUAL_UID --email lopez.kyle922@gmail.com --apply
```

Type **GRANT platformAdmin TO ACTUAL_UID AND ACTIVATE** exactly when prompted.
This explicitly authorizes both role grant and bootstrap approval to active. A
cancel/mismatch/noninteractive invocation does not grant privileges. Identity is
reverified before the transaction, and profile changes after review require a
new confirmation. Only role/status/updatedAt change, and
`activityLogs/provision-platform-admin-{uid}` is created with before/after,
operator-provisioning source and server timestamp. Repeating provisioning for an
already active platform admin is idempotent and writes no duplicate log. An
existing bootstrap log with a subsequently demoted account fails closed for
separate review rather than silently granting again.

5. Verify in Console that the same `users/{ACTUAL_UID}` now has platformAdmin /
   active, existing profile data is intact and the bootstrap audit exists. Sign
   in/reload the account and open Profile → Platform Administration. Verify a
   normal user/manager still receives HTTP 403 on admin requests. No email claim
   or cached custom role claim alone should grant access.

The tool has no unattended --confirm bypass and does not modify existing
organization managers or other user roles. It was unit tested with synthetic
test doubles only; **this provisioning procedure has not been executed**.

## Manual deployment and free-tier operation

1. Review the diff and existing Module 1–4 security/configuration. Keep project
   orglink-dev, existing Firebase configuration, backend host and Worker secret
   FIREBASE_SERVICE_ACCOUNT. The Worker uses the existing datastore OAuth scope;
   no Firebase Admin SDK/key is added to Flutter or the Worker runtime. No new
   permissions or Auth administration API access are required for runtime calls.
2. Review a local bundle using `npm --prefix workers/attendance run check`
   (existing Wrangler dry-run script). When authorized, release this extension
   through the existing Worker deployment process. The new routes must be live
   before the new Flutter admin screens can load. **No deployment was run here.**
3. Deploy the Student ID Rules cutover described in Module 1; do not add client admin write bypasses.
   Keep the existing Module 1 verification/eligibility guards reviewed and deployed
   as required by that module. Automatic single-field indexes support these
   simple searches/counts; disabled custom index configurations need review.
4. Provision the selected initial administrator only via the separate confirmed
   procedure above. Build/install Flutter using the existing ATTENDANCE_API_URL
   when customized. No new backend environment variable or paid plan is needed.
5. Counts/queries consume Firestore free-quota reads, including aggregation
   billing minima; page requests load at most 26 rows. There is no background
   full-database poll or count trigger. Keep demo data small and monitor the
   existing Spark/Workers Free quotas. Audit writes consume normal write/storage
   quota. Live load/quota behavior has not been certified by local tests.

## Validation and acceptance

Repeatable commands:

```powershell
flutter analyze
flutter test --no-pub test/platform_admin_test.dart
flutter test --no-pub
npm --prefix workers/attendance test
npm --prefix tools/admin test
firebase emulators:exec --project orglink-dev --only firestore "npm --prefix workers/attendance run test:admin:emulator"
```

The admin emulator test refuses a non-loopback or absent emulator and has no live
fallback. It seeds clearly synthetic accounts/organizations and exercises the
actual Worker Firestore REST transport against local transactions and Rules.

Automated coverage: unsigned/forged-token denial and ignored client role/email
claims; ordinary/manager/pending/disabled admin denial; pending approval/rejection,
active deactivation, disabled reactivation, self/admin protection, profile preservation; complete eligible
manager validation; create/edit/reassign and child history preservation; stale
versions/ownership and racing decisions; idempotency, audit atomicity/failure;
real aggregation, exact/prefix queries and cursor pages; direct-client profile,
manager and audit forgery denial; confirmed/declined/idempotent provisioning and
UID/email mismatches; responsive UI, confirmation cancellation, session/role
revocation, loading/error/empty components and Back behavior.

Manual acceptance after an authorized release:

- Check regular user, organization manager and inactive admin denial on every
  endpoint and direct route; revocation must deny a still-signed-in session.
- Check primary UID before/after provisioning and preserved roles/memberships.
- Approve/reject test applicants; deactivate a separate ordinary account and
  verify its existing session loses data access without losing identity/history.
  Reactivate that eligible disabled student after confirmation; verify the list
  refreshes, its active session can regain authorized access, and a single audit
  records disabled → active. Rejected/incomplete/admin/self accounts must not
  offer Reactivate; direct requests for them must also fail. Check stale-version,
  unauthorized and identical-retry behavior without changing privileged fields.
- Create/edit an organization; assign then replace an eligible manager. Verify
  the old manager loses manager powers and the new manager gains the existing
  scoped controls. Confirm memberships/events/attendance remain intact.
- Run two admin clients against the same record; stale action must be rejected.
  Inspect the resulting audit and test refresh after an uncertain network result.
- Check real Android TalkBack/focus, 200% text, long names and native/predictive
  Back. New runtime pages do not prove device or deployed IAM configuration.

Initial Platform Administration MVP validation (before reactivation):

- `flutter analyze`: **no issues**.
- Full Flutter suite: **205 passed**, including **14 focused platform-admin tests**
  and existing Modules 1–4 regression/responsive tests.
- Worker local suite: **60 passed** (existing auth/attendance/transport plus admin
  authorization, validation, idempotency, race and audit tests).
- Operator tools: **7 passed**, including existing demo-provisioning tests and
  initial-admin verification/confirmation/idempotency/concurrent-change tests.
- Real Firestore REST/emulator integration: **1 comprehensive test passed**,
  covering counts, 25-row pages, competing decisions, manager transfer ownership,
  preserved child history, audit records and direct-client Rules denial.
- Wrangler `deploy --dry-run`: **bundle succeeded**, exited without deployment.
- Touched Dart files formatted; `git diff --check` clean. Rendered admin preview
  checked; physical-device and deployed IAM acceptance remain manual.

A pre-existing validation blocker was repaired: pubspec's Dart package name was
`OrgLink` while test imports reference `package:orglink`. The canonical package
name is restored to lowercase `orglink`; the displayed application name and
Firebase Android identity are unchanged. No Flutter or Node dependency was added.

No live data, provisioning, Firebase Console settings, Rules or Worker deployment
changed. The original admin feature did not alter Rules. The later Student ID cutover below intentionally tightens profile and registry writes.

## Account reactivation validation (before Student ID cutover)

Reactivation is an extension of the existing accountStatus operation, not a new
route, schema, role, service or permission bypass. Tests cover eligibility-derived
visibility, confirmation cancellation, successful refresh, server denial, stale
versions, audit failure rollback, idempotent retry, racing reactivations and
preservation of profile/history. A signed ordinary-manager token with a forged
platformAdmin claim is rejected on the real HTTP mutate boundary. The local
Firestore integration also exercises disabled → active with real updateTime
checks, persisted audit, refreshed eligibility and preserved manager records.

Current validation results:

- `flutter analyze`: **no issues**.
- Full Flutter suite: **208 passed**, including **17 focused admin tests**.
- Worker suite: **65 passed**, including reactivation success, authorization,
  eligibility, stale versions, races, idempotency, audit rollback and history.
- Real Firestore emulator integration: **1 comprehensive test passed**, including
  reactivation with real persisted version/audit/eligibility checks.
- Touched Dart files formatted; `git diff --check` clean.

Reactivation alone needed no configuration or schema change. When its release is authorized, update
the existing Worker before expecting Reactivate in Flutter: older list responses
omit canReactivate and the client safely hides the action. Verify the confirmed
disabled → active flow on Android against the development backend after release.
No deployment, provisioning, Firebase Console change or live-account modification
was performed.

Reactivation-specific changed files:

- `workers/attendance/src/admin.js`
- `lib/features/admin/data/models/admin_models.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `workers/attendance/test/admin.test.js`
- `workers/attendance/test/admin.emulator.test.js`
- `test/platform_admin_test.dart`
- `docs/platform-admin.md`

## File manifest

- `README.md`
- `docs/module1.md`
- `docs/module2.md`
- `docs/platform-admin.md`
- `docs/ui-ux-design.md`
- `lib/app/dependency_injection.dart`
- `lib/app/router.dart`
- `lib/core/constants/app_routes.dart`
- `lib/features/admin/data/models/admin_models.dart`
- `lib/features/admin/data/repositories/admin_repository.dart`
- `lib/features/admin/data/services/admin_service.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/features/admin/presentation/viewmodels/admin_view_model.dart`
- `lib/features/auth/presentation/screens/auth_screens.dart`
- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/presentation/widgets/profile_overview.dart`
- `pubspec.yaml`
- `test/platform_admin_test.dart`
- `tools/admin/package.json`
- `tools/admin/provision-platform-admin.mjs`
- `tools/admin/provision-platform-admin.test.mjs`
- `workers/attendance/package.json`
- `workers/attendance/src/admin.js`
- `workers/attendance/src/firestore.js`
- `workers/attendance/src/index.js`
- `workers/attendance/test/admin.emulator.test.js`
- `workers/attendance/test/admin.test.js`

## Student IDs for account identification and manager assignment

Accounts show **Student ID** prominently and in the read-only Account Details
dialog. Firebase UID remains the hidden internal target for status operations,
self checks, document paths and audit actor references. No reference migration or
UID replacement occurred. Names/email/status remain visible under admin-only
access. Missing/invalid legacy Student IDs require operator correction; no display
padding or guessed value is persisted. Exact ID search uses stored studentNumber,
accepts precisely 10 numeric digits and retains existing cursor pagination.

Organization cards show manager name/Student ID instead of manager UID. The editor
uses a numeric 10-character **Manager Student ID** field and **Find Manager**.
`POST /admin/manager {studentId}` requires the same authoritative active admin
check as other operations. There is no public/student lookup endpoint. It reads
an active registry mapping, verifies exactly one matching UID-keyed profile,
checks ownership consistency and returns name, Student ID, account status,
eligibility, profile version and registry version. Disabled/pending/incomplete
accounts are shown as ineligible; missing, duplicated, retired and stale mappings
fail closed for manual review. Resolve errors are not treated as matched users.

The confirmation includes the matched name, Student ID and status. Changing the
field clears the preview; save requires a current eligible preview. The existing
mutation is extended with `changes.managerStudentId`, managerProfileVersion and
managerRegistryVersion. It **rejects a client managerUid field**. The transaction
resolves the registry again, verifies both preview versions, validates the active
candidate, and uses the resolved Firebase UID for the existing managerUid field.
Existing expectedManagerUid checks refer to the old stored owner and remain an
ownership/concurrency check, never a proof for selecting the new manager. An API
partial detail edit without assignment can retain the server's existing owner;
the UI requires explicit Student ID resolution for its editor save.

Audit entries keep actor UID and resolved managerUid before/after; normalized
request context includes the Student ID/version choices. Idempotency, account
approval/rejection/reactivation, self/admin protection and history retention are
unchanged. A stale profile or registry mapping after confirmation returns conflict
and requires Find Manager again. No owner or membership grant is inferred from a
name, email, role label or client UID. Existing organization memberships, events,
attendance and role scopes remain intact.

See [Module 1](module1.md#bulsu-student-id-enforcement) for registry ownership,
backfill/audit commands, privacy, deployment freeze/order, read compatibility,
indexes and rollback. The operator must reconcile existing data before enabling
ordinary ID-changing traffic. The new Worker and Rules must accompany Flutter;
old manager-UID clients intentionally cannot bypass the new assignment contract.
No administrator provisioning, live migration, account correction or deployment
was performed for this change.

### Student ID code audit and validation

Audited studentNumber in the profile model/repository/service/completion/overview,
Auth profile-completion routing, admin cards/search/organization editor,
Firestore profile/eligibility Rules, Worker admin/attendance eligibility and
operator demo/provisioning tools. The field name and all UID-based references
remain. Legacy-read eligibility checks in Flutter, Rules and attendance/admin
remain intentionally compatible during the migration; new profile/ID writes are
strict and can only claim IDs through the trusted registry transaction. Existing
operator provisioning tools still preserve UIDs and never manufacture Student IDs.

Validation performed locally:

- `flutter analyze`: **no issues**.
- Full Flutter suite: **212 passed**; final focused Student ID/admin rerun:
  **21 passed** (including the updated width/text-scale admin matrices).
- Worker unit/runtime suite: **73 passed**.
- Operator tooling suite: **11 passed** (audit classification, idempotency,
  identity checks, conflicts, stale plans and existing provisioning safeguards).
- Real Worker Firestore REST/Auth emulator workflows: **2 passed**, including
  racing claims, profile changes/retired mappings, real Auth-backed backfill,
  versioned manager resolution, status/reactivation and preserved history.
- Firestore Rules/Auth emulator suite: **146 passed, 0 failed, 1 existing TODO**.
  The TODO is the previously documented local Google password-linking emulator
  limitation, not a passing account-link test or a Student ID regression.
- Wrangler bundle dry run passed without deploying. Touched Dart files formatted;
  diff checks clean. No new Dart/Node packages or paid infrastructure.

Manual work remains: live read-only audit, school-verified legacy correction,
planned Rules/Worker/Flutter cutover, separately confirmed backfill and read-only
verify, followed by Android/email/IAM acceptance. No live audit/migration,
operator provisioning, deployment or live-account change ran during this task.

### Student ID changed-file manifest

- `docs/module1.md`
- `docs/platform-admin.md`
- `firebase/firebase.rules`
- `firebase/tests/email-auth.integration.test.mjs`
- `firebase/tests/profile.rules.test.mjs`
- `lib/app/dependency_injection.dart`
- `lib/core/services/worker_api_service.dart`
- `lib/features/admin/data/models/admin_models.dart`
- `lib/features/admin/data/repositories/admin_repository.dart`
- `lib/features/admin/data/services/admin_service.dart`
- `lib/features/admin/presentation/screens/admin_screen.dart`
- `lib/features/admin/presentation/viewmodels/admin_view_model.dart`
- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- `test/phase2_navigation_test.dart`
- `test/platform_admin_test.dart`
- `test/student_id_test.dart`
- `test/support/test_auth_repository.dart`
- `test/text_formatting_test.dart`
- `test/widget_test.dart`
- `tools/admin/backfill-student-ids.mjs`
- `tools/admin/backfill-student-ids.test.mjs`
- `tools/admin/package.json`
- `workers/attendance/package.json`
- `workers/attendance/src/admin.js`
- `workers/attendance/src/auth.js`
- `workers/attendance/src/index.js`
- `workers/attendance/src/student_ids.js`
- `workers/attendance/test/admin.emulator.test.js`
- `workers/attendance/test/admin.test.js`
- `workers/attendance/test/student_ids.emulator.test.js`
- `workers/attendance/test/student_ids.test.js`
- `workers/attendance/test/support/memory_db.js`

