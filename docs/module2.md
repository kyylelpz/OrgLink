# Module 2: Organization discovery and membership

The [Platform Administration MVP](platform-admin.md) adds trusted organization
creation/editing and explicit manager assignment. Existing organization-scoped
permissions still use managerUid; memberships and child records are preserved.

Module 3 extends the read-only event baseline described here; see
[module3.md](module3.md) for current event permissions and summary-query compatibility.

Implemented against the organization and membership structure in
Elective3_FinalProject.pdf (roles, screens 7-10 and 19-20, hierarchy, data
architecture and authorization requirements). The current user instruction to
use only orglink-dev takes precedence over the PDF's proposed production project.
The PDF is a source document, not an implemented-feature inventory.

## Implemented workflow

Eligible students can use **Cancel Request** on Organization Details for their own
pending ordinary membership, including after reopening the screen. Cancellation
deletes only the unreviewed request in a Firestore transaction; it introduces no
new membership status or audit record. Manager review and cancellation compete
atomically: an approved/rejected membership cannot be deleted by the applicant.
Successful cancellation removes the request from personal/manager lists and
allows a fresh application if the organization still accepts requests. Errors
retain the request and allow retry; duplicate taps are blocked while busy.
Other users, managers and officers cannot cancel someone else's request. These
Rules changes require an approved manual deployment; local implementation alone
does not update the live policy.

An active account with a completed student profile can discover public active
organizations, search their names locally, open details, request membership,
and track pending/active/rejected/removed records. Firestore streams update the
screens after decisions. Multiple organizations per student are supported.

Details include logo/fallback, description, mission, vision, goals, positions,
requirements, explicitly published officers, current membership and up to ten
future published/approved events. Missing optional data has explicit empty states.
Events are read-only summaries of existing records, not an event-management or
registration implementation.

My Organizations includes associated organizations and assigned organizations
for managers. Pending, rejected or removed members retain their own history even
if an organization's current visibility makes its details inaccessible. A safe
unavailable label is shown when a name/details can no longer be read; private or
inactive organization data is not exposed by bypassing its access rules.

Designated managers can inspect pending applicants, approve/reject with a
confirmation dialog, see operation feedback and view active members. Applicant
name is captured from the requester's profile at submission; managers and roster
readers do not gain access to users/{uid}, student numbers, or emails.

The active manager UID on the organization document is authoritative. An officer
title, membership role string or platform role never substitutes for it. Active
members need an explicitly provisioned permissions.viewRoster=true to read the
active roster; officers do not automatically receive this permission. Managers
always have roster access. Client assignment of roles or permissions is denied.

## Architecture and files

### Manager Roster Membership and Role Management

The existing Member Roster now provides **Active**, **Officers**, and
manager-only **Former Members** views. Search matches loaded names, UID,
position, role and status. Existing active roster readers keep read-only access;
they do not gain former-roster access or action menus.

Assigned managers of active organizations get a three-dot menu per roster entry:
View Details, Assign/Change Role, Manage Permissions (officers only), and End
Membership. Self and manager-labelled records expose details only. Former members
are read-only. Existing responsive cards and Material 3 dialogs are reused.

- **End Membership** is an explicit confirmation with an optional reason up to
  1000 characters. It updates the existing UID document to `membershipStatus:
  removed`, clears permissions, and adds `endedAt`, `endedBy`, `endReason`.
  Role/position and previous request/join/review metadata are retained. It does
  not delete the membership, event registrations, attendance or child records.
- **Assign/Change Role** supports `member` and `officer`, with common positions
  (President, Vice President, Secretary, Treasurer, etc.), configured organization
  positions and any existing stored position. Positions remain labels. Promotion
  starts with no capabilities; reassignment of an existing officer preserves
  supported capabilities. Demotion clears permissions and position.
- **Manage Permissions** configures only `manageEvents`, `manageAttendance`,
  and `viewRoster`. Event authority remains limited to the officer's own events;
  attendance authority is independent. No organization role grants Platform Admin
  or manager assignment. Unsupported historical permission keys are not granted.
- `organization.managerUid` is never changed. The actor's own record, the assigned
  manager and any manager-labelled record cannot be terminated/demoted here; this
  protects the sole authoritative manager and preserves administrative assignment.
- Membership termination and permission/role changes affect authoritative checks
  immediately on subsequent server requests. Offline cached UI cannot guarantee
  instant visual revocation. Existing registration-based participation rules are
  unchanged; retaining a registration does not retain officer/roster privileges.

#### Trusted API and Audit

The existing Worker adds authenticated POST JSON routes:

| Endpoint | Fields | Result |
| --- | --- | --- |
| `/memberships/preview` | `organizationId`, `participantUid` | Fresh membership display fields and opaque Firestore `version` |
| `/memberships/mutate` | Same IDs, `operation`, `version`, stable `requestId` | `{saved: true, duplicate: boolean}` |

Mutation operation fields: `end` takes optional `reason`; `role` takes
`role: member|officer` and `positionTitle` (null for member, nonempty up to 100
characters for officer); `permissions` takes a map of supported boolean flags.
Unknown fields/roles/capabilities are rejected. The existing `ATTENDANCE_API_URL`,
Firebase ID-token verifier, service-account binding, REST transactions and error
envelope are reused; no new credentials, indexes or dependencies are required.

Every request rereads the manager profile (active and complete), active
organization, assigned manager UID and target membership. Mutations require an
active target and matching preview version. Concurrent decisions have one winner;
stale dialogs must be closed and reopened to review fresh values. Ambiguous retry
uses the same immutable command/request ID; dialog fields lock after the first
submission. Identical committed retries return success without duplicate audit;
reusing an ID with different content fails. A manager transfer/revocation also
blocks the former actor's retries.

Target update and audit creation commit atomically at
`organizations/{orgId}/membershipAudits/{actorUid}-{requestId}`. Audit fields are
organization/participant IDs, actor UID, operation, request ID, validated request,
trusted timestamp `createdAt`, and relevant before/after role/status/position,
permissions, request/join/review/end values. Audit failure prevents the change.
Only the currently assigned eligible manager can read these records through Rules;
all client audit writes are denied. No general audit-history browser is added;
View Details shows membership details and the most recent termination metadata.
Organization `publicOfficers` remains separately published, non-authoritative
information; role changes do not guess identities by matching published names.

#### Reapplication and History

An ended (`removed`) member may submit a fresh request to an accepting public,
active organization, reusing `memberships/{uid}` without duplicates. The new
request resets role to member, empties permissions/position, records current name
and request time, and clears current join/review metadata. Latest termination
metadata is preserved; immutable audits retain prior-cycle join/role/permission
history. Approval remains the existing manager review workflow. Rejected members
still cannot reapply. Cancellation of an unreviewed new request remains available;
its deletion does not delete the separate management audits.

Direct client role/permission/termination/history edits remain denied, including
for managers. The sole added self-update is the tightly constrained
`removed → pending` reapplication; clients cannot self-activate or erase audit/end
metadata. Existing private/closed organization and account eligibility rules apply.

#### Validation and Deployment

Local commands (never live data):

```powershell
flutter test test/member_management_test.dart test/organization_view_models_test.dart test/organization_workflow_test.dart test/phase4_organizations_ui_test.dart
npm.cmd test --prefix workers/attendance
firebase.cmd emulators:exec --project orglink-dev --only firestore "node --test --test-concurrency=1 firebase/tests/organization.rules.test.mjs workers/attendance/test/memberships.emulator.test.js"
```

Coverage includes manager-only access, forged roles/fields, self/manager
protection, audit rollback/idempotence, concurrent/stale writes, real REST
transactions, access revocation, former-roster/audit privacy, retained participation,
UID-preserving reapplication, and dialogs at 320 dp with 100%/200% text.

Deploy only after explicit approval: from repository root,
`firebase deploy --only firestore:rules --project orglink-dev`; then from
`workers/attendance`, `npx wrangler deploy`; rebuild/install the compatible app.
No deployment, live role change or live Firebase write was performed for this
implementation. Do not use manual client writes as a workaround for an old Worker.

Local results for this implementation: full Flutter suite **293 passed**;
focused roster/organization Flutter suite **28 passed**; Worker unit/runtime
suite **95 passed**; organization Rules plus real membership REST integration
**42 passed**. Analysis retains four existing warnings and one existing style
hint, with no introduced errors or warnings. Source formatting and diff checks
were run. These results do not establish deployed acceptance.

Affected files:

- `lib/features/memberships/data/models/membership.dart`
- `lib/features/memberships/presentation/screens/member_list_screen.dart`
- `lib/features/memberships/presentation/screens/member_management_dialog.dart`
- `lib/features/memberships/presentation/viewmodels/member_list_view_model.dart`
- `lib/features/organizations/data/repositories/organization_repository.dart`
- `lib/features/organizations/data/repositories/firestore_organization_repository.dart`
- `lib/features/organizations/data/services/organization_service.dart`
- `lib/features/organizations/presentation/viewmodels/organization_details_view_model.dart`
- `lib/features/organizations/presentation/screens/organization_details_screen.dart`
- `lib/core/services/worker_api_service.dart`, `lib/app/dependency_injection.dart`
- `workers/attendance/src/memberships.js`, `workers/attendance/src/index.js`
- `workers/attendance/package.json`
- `firebase/firebase.rules`, `firebase/tests/organization.rules.test.mjs`
- `workers/attendance/test/memberships.test.js`
- `workers/attendance/test/memberships.emulator.test.js`
- `test/member_management_test.dart`, `test/organization_view_models_test.dart`
- `test/support/test_organization_repository.dart`
- `docs/module2.md`

The feature folders follow View -> ChangeNotifier ViewModel -> Repository ->
Service -> typed Model, using the existing Provider composition and Firebase
service. Firebase initialization, authentication/profile implementations,
Android settings and Flutter dependencies are unchanged.

Added:

```text
lib/core/utils/live_query.dart
lib/features/organizations/
  data/models/organization.dart
  data/repositories/organization_repository.dart
  data/repositories/firestore_organization_repository.dart
  data/services/organization_service.dart
  presentation/organization_scope.dart
  presentation/viewmodels/organization_hub_view_model.dart
  presentation/viewmodels/organization_details_view_model.dart
  presentation/screens/organization_discovery_screen.dart
  presentation/screens/organization_details_screen.dart
  presentation/screens/my_organizations_screen.dart
  presentation/widgets/organization_widgets.dart
lib/features/memberships/
  data/models/membership.dart
  presentation/viewmodels/member_list_view_model.dart
  presentation/screens/member_list_screen.dart
firebase/tests/organization.rules.test.mjs
test/organization_view_models_test.dart
test/organization_workflow_test.dart
test/support/test_organization_repository.dart
tools/test-firestore.ps1
tools/admin/
   package.json
   package-lock.json
   .gitignore
   provision-demo.mjs
   provision-demo.test.mjs
   provision-demo.emulator.test.mjs
```

Modified: lib/app/dependency_injection.dart, lib/app/router.dart,
lib/core/constants/app_routes.dart, lib/core/services/firestore_service.dart,
lib/features/home/presentation/screens/home_screen.dart, firebase/firebase.rules,
firebase/firestore.indexes.json, firebase/tests/package.json, test/router_test.dart, and README.md.

LiveQuery owns one subscription, provides initial loading/error/retry states,
clears stale values on failures, and has a 20-second initial-server timeout.
Organization feature providers are scoped to the signed-in UID and disposed on
navigation out of the feature/authentication changes. Search does not create
Firestore listeners. Associated organization listeners are retained by ID and
removed when their membership disappears. Normal widget rebuilds do not refetch.

## Organization Logos

Assigned managers of active organizations can Change Logo or Remove Logo in
Organization Details. Active Platform Admins have the same verified logo editor
on their admin organization cards. An officer role or title alone does not grant
logo management. The Worker authorizes against the current complete active
account, manager assignment or authoritative platform-admin role, and organization
status; direct Firestore organization writes remain blocked.

Logos share the profile photo's interactive square editor: drag, pinch to zoom,
Cancel, Reset, Confirm, and Keep Original. Confirm crops before upload; Keep
Original preserves the selected framing. The existing 5 MiB validation,
resizing/compression, immediate image saves, and logo/error fallbacks remain.

Verified uploads update `logoURL`, `logoPublicId`, `imageRevision`, and `updatedAt`.
New uploads sign `asset_folder: orglink/organizations` without changing public-ID
generation. Existing references and organization names remain unchanged. See
[Cloudinary setup](cloudinary-setup.md) for endpoints, configuration, and cleanup.

## Schemas

### organizations/{organizationId}

| Field | Type / meaning |
| --- | --- |
| organizationId | string, document ID |
| name, description, mission, vision | strings |
| logoURL | verified Cloudinary HTTPS URL or null for new image changes; existing stored URLs remain readable |
| logoPublicId | optional Worker-managed Cloudinary public ID; null after removal |
| imageRevision | optional Worker-managed concurrency token for image changes |
| goals | array of strings |
| visibility | public or private |
| status | active or inactive |
| managerUid | authorized manager's Firebase UID; administrative assignment |
| membershipRequirements | array of informational strings |
| approvalSettings | map: acceptsRequests boolean; mode manual |
| createdAt, updatedAt | Firestore server timestamps |
| positions | optional array of customizable position titles |
| publicOfficers | optional array of explicitly published {name, positionTitle} maps |

Organization documents must contain only publication-safe organization
information. Firestore cannot redact individual fields during a document read.
Do not place private contact or student records in these documents.

### organizations/{organizationId}/memberships/{uid}

| Field | Type / meaning |
| --- | --- |
| uid, organizationId | strings matching identity/path |
| membershipRole | member on student requests; officer via trusted manager Worker; manager assignment remains administrative |
| membershipStatus | pending, active, rejected or removed |
| positionTitle | nullable string, separate from authorization |
| permissions | map; empty on student requests; viewRoster=true is an explicit delegated read permission |
| joinedAt | null until approved, then server timestamp |
| updatedAt | server timestamp |
| applicantName | additional field: full-name snapshot, equal to own profile on creation |
| requestedAt | additional field: server timestamp at request creation |
| reviewedAt, reviewedBy | additional fields: decision server timestamp and manager UID |
| endedAt, endedBy, endReason | optional trusted termination metadata; latest values retained on reapplication |

A UID document path prevents duplicate records. Creation always requires
member/pending, null position/join/review values, empty permissions and exact
identity/timestamps. Managers may perform only pending -> active or pending ->
rejected. Review metadata is mandatory; all other fields are preserved.
The transaction rereads current state, so a second competing decision fails.
Clients may cancel their own unreviewed pending request or reapply from removed
under the narrow Rules above. They cannot edit roles, self-approve, erase end
metadata or reapply after rejection. Trusted management records before/after
history in the manager-private membership audit collection.

### Existing event summaries

Read organizations/{organizationId}/events/{eventId} using eventStatus=published,
approvalStatus=approved and startAt>=now, ordered by startAt. Display title and
startAt. All event writes and nested registration/attendance/rating access remain
denied. No synthetic events are provisioned by this module.

## Routes

| Route | Access |
| --- | --- |
| /organizations | Eligible account; public active discovery |
| /organizations/:organizationId | Public active, assigned manager or active member |
| /my-organizations | Own memberships and assigned manager organizations |
| /membership-requests | Own application statuses |
| /organizations/:organizationId/requests | Assigned manager only |
| /organizations/:organizationId/members | Manager or explicitly authorized active roster reader |

Home links into these pages. The feature has Discover/My organizations/Requests
navigation. Existing auth redirects still precede all organization routes;
organization-specific checks produce access-denied/error states and Firestore
independently enforces authorization. Protected deep links remain blocked for
signed-out, incomplete or inactive accounts.

## Security rules and indexes

The Module 1 users/{uid} rules are preserved. Added organization read rules,
owner membership reads and own-UID collection-group queries, validated pending
creation, narrowly constrained manager decisions and active-roster permission
checks. Broad organization queries, unrelated student memberships, private user
profiles, unauthorized organization creation/manager changes, self-promotion,
direct role assignment and deletion of reviewed memberships remain denied.
Trusted management and tightly constrained self-reapplication are described above.

Discovery queries filter both public and active. The My Organizations query uses
collectionGroup('memberships').where('uid', isEqualTo: current UID); its rules
allow only matching own records. Future collections must not reuse the
memberships subcollection name for unrelated private record types without
revisiting that collection-group list rule.

firebase/firestore.indexes.json includes discovery and published-event composite
indexes plus collection-group indexing of membership uid. The emulator does not
validate production index availability.

**Rules and indexes have not been deployed.** An authorized operator must review
and publish them before using Module 2 against the live development database:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project orglink-dev
```

Wait until indexes finish building in Firebase Console. No additional Firebase
project, OAuth changes, or Android configuration changes are required.

## Secure demonstration provisioning

The Flutter app cannot create organizations or assign managers. Use the separate
Node Admin SDK procedure from an authorized administrative workstation. The
procedure has no credentials in source, only accepts orglink-dev and leaves
platformRole unchanged. Sample organization names/descriptions/officers and the
manager's membership display name are synthetic. Existing records are preserved
on repeat execution; an existing different manager causes failure rather than
an implicit manager transfer.

1. Use a dedicated Google demonstration account. Sign into OrgLink and complete
   Module 1 with synthetic student details. Copy its Firebase Authentication UID
   using authorized Console access. Do not use real student information.
2. Install only the administrative tool's dependencies:

   ```sh
   npm --prefix tools/admin ci
   ```

3. Establish Application Default Credentials for an approved administrative
   identity with Firestore write access and Firebase Auth read access, for example
   using `gcloud auth application-default login`. Alternatively set
   GOOGLE_APPLICATION_CREDENTIALS to an authorized service-account file **outside
   this repository**. The tool rejects credential files inside the repository.
   Never put administrative credentials into Flutter assets or source.
4. Preview the plan. This command makes no Firebase calls:

   ```sh
   node tools/admin/provision-demo.mjs --project orglink-dev --manager-uid YOUR_DEMO_MANAGER_UID
   ```

5. After reviewing the plan, explicitly apply it:

   ```sh
   node tools/admin/provision-demo.mjs --project orglink-dev --manager-uid YOUR_DEMO_MANAGER_UID --confirm-demo-manager --apply
   ```

It verifies the Auth user and active demo profile, then atomically creates four
stable sample organizations: two public/active, one private/active and one
public/inactive. Manager memberships use manager/active with viewRoster=true.
The manager receives organization-specific authority only. No actual live
provisioning was performed during this implementation.

The same CLI supports `--emulator` only with a loopback FIRESTORE_EMULATOR_HOST;
this bypasses live Auth lookup and is used exclusively for local tests. The
live mode rejects accidental emulator configuration.

## Validation and manual demonstration

```sh
flutter pub get
dart format .
flutter analyze
flutter test
npm --prefix firebase/tests ci
npm --prefix tools/admin ci
node --test tools/admin/provision-demo.test.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File tools/test-firestore.ps1
flutter run -d emulator-5554 --no-resident
```

The PowerShell test runner requires the Firebase CLI, Java, and free port 8080.
It runs the two security suites and the administrative emulator test serially,
then cleans up only emulator processes started by that invocation. All security
and provisioning tests use local emulator data, never live Firestore. Do not run
an unrelated emulator on the same port while executing the isolated tests.

Results:

- Flutter dependency resolution completed; no Flutter dependencies added.
- Formatting and analysis passed.
- 32 Flutter tests passed, including all Module 1 tests and a phone-sized UI
  workflow covering discovery/search, requesting, manager confirmation/approval,
  active roster, My Organizations, direct unauthorized access and sign-out.
- 58 Firestore rules tests passed: 30 original profile tests and 28 organization/
  membership/event-read tests. Coverage includes forged fields, privacy,
  wrong-org managers, unauthorized officers, timestamps and competing decisions.
- One administrative emulator test passed, proving idempotency, preserved edits/
  timestamps, refusal of implicit manager transfer and no platform-role grant.
- Three administrative plan/guard tests passed.
- Debug APK built, installed and launched on the Android 17 emulator. Existing
  Firebase plugin warnings about future Kotlin Gradle compatibility remain.

For the live demonstration, first publish reviewed rules/indexes and provision
the demo organizations. Sign in with a second dedicated demo student, discover
Demo Robotics Society, open details and request membership. Verify pending in
Requests and My Organizations. Sign in as the provisioned manager, open the same
organization, confirm an approval and inspect the active roster. Return to the
student account and verify active membership without duplicate records. Repeat
with Demo Creative Guild to demonstrate rejection and blocked reapplication.
Check that the private/inactive samples are absent from ordinary discovery and
that a student cannot open management routes. Re-run Module 1 sign-out/restart/
profile-edit checks with the same accounts. Real-account live membership writes
were not performed automatically.

## Explicit boundaries

- Member Roster includes trusted officer/permission management and membership
  termination. Manager assignment and organization administration remain separate
  Platform Admin operations; no public creation or invitation workflow is added.
- Requests are limited to public, active, accepting organizations and eligible
  accounts. Custom membership requirement strings are informational, not a
  programmable enrollment-verification policy. Private organizations can be
  opened by provisioned active members/managers; students cannot request them.
- Reapplication after rejection remains unavailable. Ended members reapply as
  ordinary pending members at the same UID path; cancelling an unreviewed request
  permits a fresh application without granting any permissions.
- Search filters the loaded discovery list. Full-text search and pagination are
  deferred for the small academic dataset.
- Positions/public officers are optional publication-safe extensions. No private
  roster is exposed as a public officer directory.
- Firestore server connectivity is required for initial data and transactions.
  Previously received status changes cannot be revoked instantly while offline.
- Event summaries require published/approved records. Modules 3/4 own the existing
  event/registration and attendance workflows; this change does not alter them.
  Badges and ratings remain outside the implementation.
