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

## Schemas

### organizations/{organizationId}

| Field | Type / meaning |
| --- | --- |
| organizationId | string, document ID |
| name, description, mission, vision | strings |
| logoURL | string or null |
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
| membershipRole | member on student requests; manager/officer only through trusted provisioning |
| membershipStatus | pending, active, rejected or removed |
| positionTitle | nullable string, separate from authorization |
| permissions | map; empty on student requests; viewRoster=true is an explicit delegated read permission |
| joinedAt | null until approved, then server timestamp |
| updatedAt | server timestamp |
| applicantName | additional field: full-name snapshot, equal to own profile on creation |
| requestedAt | additional field: server timestamp at request creation |
| reviewedAt, reviewedBy | additional fields: decision server timestamp and manager UID |

A UID document path prevents duplicate records. Creation always requires
member/pending, null position/join/review values, empty permissions and exact
identity/timestamps. Managers may perform only pending -> active or pending ->
rejected. Review metadata is mandatory; all other fields are preserved.
The transaction rereads current state, so a second competing decision fails.
No client can delete/reset a membership, edit roles, self-approve, or reapply
following rejection/removal. Requested and decision timestamps are retained;
there is no separate unbounded audit-log collection in this module.

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
role assignment and deletion remain denied. Other collections remain denied.

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

- No public organization creation, officer assignment UI, manager-transfer UI,
  removal UI, invitation workflow or platform administration is included.
  Existing removed statuses are displayed; permission/role provisioning remains
  an authorized administrative operation.
- Requests are limited to public, active, accepting organizations and eligible
  accounts. Custom membership requirement strings are informational, not a
  programmable enrollment-verification policy. Private organizations can be
  opened by provisioned active members/managers; students cannot request them.
- Reapplication is deliberately unavailable. There is no automatic status reset.
- Search filters the loaded discovery list. Full-text search and pagination are
  deferred for the small academic dataset.
- Positions/public officers are optional publication-safe extensions. No private
  roster is exposed as a public officer directory.
- Firestore server connectivity is required for initial data and transactions.
  Previously received status changes cannot be revoked instantly while offline.
- Event summaries require existing published/approved records. Event creation,
  registration, attendance, badges and ratings remain unimplemented and denied.
