# Module 4: Attendance Management and Secure QR Check-In

## Status and scope

Module 4 source implements manual attendance, Attendance Verification (Screen 22),
Attendance Report (Screen 23), My Attendance (Screen 24), the QR Hub, student QR
passes and a universal camera scanner. The specification PDF attendance screens
and exact seven-field schema were reviewed, together with Module 3 and the
existing provisioning and permission model.

No resources were deployed, billing changed, live records written, or new Firebase
projects introduced. The application still uses orglink-dev and Android ID
com.example.orglink. Manual attendance needs the reviewed Firestore rules deployed;
it does not need Cloud Functions. QR issuance/redemption additionally need the two
callable functions deployed. Until then, the app reports that secure QR check-in
is unavailable rather than generating an untrusted pass or reporting success.

## Architecture and affected files

Existing View -> ChangeNotifier ViewModel -> Repository -> Firebase Service ->
typed Model layering is retained. Provider owns dependencies; go_router retains
Auth/profile/account eligibility redirects. No duplicate Firebase initialization
or authentication subscription was added.

New attendance code is under lib/features/attendance:

- data/models/attendance.dart: typed records, statuses, methods, summary,
  permission helper, attendance-window display hint, QR parser and credential.
- data/services/attendance_service.dart: server-confirmed Firestore reads/manual
  transactions and callable transport. No optimistic attendance success.
- data/repositories/attendance_repository.dart and
  firestore_attendance_repository.dart: typed operations/domain error mapping.
- presentation/viewmodels/attendance_view_model.dart: authorized roster,
  projected names, search/filter, final marking and duplicate feedback.
- presentation/viewmodels/my_attendance_view_model.dart: own registration/history
  streams, selected-event credential, countdown and stale-operation handling.
- presentation/viewmodels/scanner_view_model.dart: payload validation, per-target
  permission prechecks, serialized verification and scan-next state.
- presentation/screens/attendance_screens.dart: organization/event selection,
  manual verification, report and personal history.
- presentation/screens/qr_screens.dart: QR Hub, My QR Code and camera scanner.
- presentation/attendance_scope.dart: Provider lifetime/disposal boundaries.

Additional files: core/widgets/authenticated_shell.dart; app/router.dart and
app/dependency_injection.dart; core/constants/app_routes.dart and
core/utils/display_labels.dart; existing event detail/navigation, organization
navigation and home screens; event_scope.dart; Android camera manifest;
pubspec.yaml/lock; generated macOS plugin registration; firebase.json;
firebase/firebase.rules; firebase/functions source, lockfile and tests;
firebase/tests/attendance.rules.test.mjs and test script; test/attendance_test.dart,
test/support/test_attendance_repository.dart and test/router_test.dart; README.md;
.gitignore. The existing event hub is now keyed to authenticated UID, fixing
cross-account state retention through the nested router Navigator.

## Navigation and screens

One authenticated shell supplies Home | Organizations | QR | Events | Profile.
The center QR icon is emphasized and opens the hub; it does not request camera
access. Existing organization/event navigation remains available as local links,
including My Organizations, Requests and My Events. Home retains all prior actions
and adds My Attendance and Attendance Management. Eligible event details link to
My QR Code; organizers also get Attendance Verification.

| Route | Purpose |
| --- | --- |
| /qr | QR Hub: My QR Code, permitted Scan QR Code, history and management |
| /qr/my-code | Select an active registration, generate/show/regenerate a pass |
| /qr/scan | Universal scanner, with organization-specific permission guard |
| /my-attendance | Own registration-linked attendance and participation summary |
| /attendance | Authorized organization/event selection |
| /organizations/:organizationId/attendance | Selection with this organization expanded |
| /organizations/:organizationId/events/:eventId/attendance | Verification roster |
| /organizations/:organizationId/events/:eventId/attendance/report | Read-only report |

Account/profile redirects run before these routes. Direct attendance routes deny
unauthorized roster access. Scanner access requires permission in at least one
organization, then rechecks the scanned organization. Provider keys and operation
generation checks discard prior account/selection results. Permission revocation
clears the organizer roster and scanner result. All subscriptions/timers/camera
resources are disposed on leaving their scope.

## Manual attendance workflow

1. Open Attendance Management from Home or QR Hub.
2. Expand an authorized organization; select an event (report icon opens reporting).
3. Use Manual Lookup to search projected participant names; filter attendance.
4. Inspect registration, attendance, method and timestamp.
5. During the attendance window, select Mark Present or Mark Absent and confirm.
6. A Firestore transaction reads the authoritative UID attendance document and
   writes only if it is absent. Rules enforce current permissions, registration,
   event lifecycle and request.time. Existing results return Already Verified.
7. A server read confirms the saved timestamp/result. The live roster updates.

No placeholder attendance documents are created. The first successful result is
final. Present/Absent and Manual/QR cannot be changed or deleted through ordinary
clients. There is no correction or backdated-marking workflow. Organizers cannot
verify their own attendance. Registration/capacity documents are never mutated by
attendance operations. Missing name projections show Unknown Participant.

## Authorization matrix

All operators must have an active account and completed profile. Manager identity
is the existing authoritative organization.managerUid. Officer assignments must
be securely provisioned; no new role-assignment UI or self-assignment was added.

| Identity | Own QR/history | Attendance roster/report, manual and QR verification |
| --- | --- | --- |
| Eligible registered student | Own registration/history only | Denied |
| Organization manager | Own history/pass if registered | Assigned organization only, other participants |
| Active officer with permissions.manageAttendance=true | Own history/pass | Assigned organization only, other participants |
| Event Coordinator with only manageEvents=true | Own history/pass | Denied attendance privileges |
| Officer without attendance permission, pending/removed membership | Own history/pass | Denied |
| Platform admin without organization authority | Own history/pass | Denied |
| Signed-out/ineligible account | Denied | Denied |

Existing Module 3 participant roster access for event editors is preserved; it
does not confer attendance read/write permission. Attendance officers additionally
receive scoped event, registration and participantIdentities reads needed for
this workflow, without users/{otherUid} reads or event editing privileges.

## Attendance schema

Path: organizations/{organizationId}/events/{eventId}/attendance/{uid}.
Exactly seven fields:

| Field | Type and invariant |
| --- | --- |
| uid | String matching document ID and active registration owner |
| eventId | String matching parent event |
| organizationId | String matching parent organization |
| attendanceStatus | present or absent |
| verifiedAt | Timestamp from request.time/manual server transform or trusted backend clock |
| verifiedBy | Authorized organizer UID; never the scanned student |
| verificationMethod | manual or qr; clients may create manual only |

Not Marked is derived from an absent document. No name, email or student number
is copied into attendance. Existing six-field registrations and three-field
participant identity projections remain unchanged. Names are read from the
existing event projection; its manual name-refresh operation is preserved.

## Lifecycle and attendance window

Only legitimately published, approved events with publishedAt and no archivedAt
are eligible. The organization must be active. Server time must satisfy
startAt <= now < endAt. Manual Rules use request.time; callable handlers check the
trusted server clock inside every transaction attempt, after all required reads.
Device time is only a UI hint and cannot authorize a write. QR expiration is also
capped at endAt. Existing Module 3 completion requires now >= endAt, so it does not
conflict with this window. Completed/cancelled/archived events retain reporting
records and never reopen verification. No automatic Absent assignment occurs.

Only registrationStatus=registered is eligible. Withdrawn/cancelled records are
shown in history/rosters but excluded from new marking and report denominators.
Existing attendance is retained if a registration changes through an authorized
process. Concurrent lifecycle, registration and permission changes serialize with
verification: a verification may succeed before a revocation/cancellation commits,
or fail afterward; it cannot bypass the transaction's checked state.

## QR credential architecture

Callable functions (2nd generation, us-central1):

- issueAttendanceCredential: authenticated UID, active complete profile, matching
  active registration, event/window and no attendance. Generates 32 random bytes
  (256 bits), encoded as 43 URL-safe characters. Valid for at most 60 seconds.
- redeemAttendanceCredential: authenticates the scanner, verifies current
  organization permission, token binding/expiry, student eligibility/registration,
  event/window and existing attendance. Atomically creates Present and marks the
  credential consumed. Concurrent retries return the original immutable result.

Payload contains only version=1, type=attendance, organizationId, eventId and the
opaque token. It contains no UID, profile data, password or Firebase session token.
Client parsing rejects malformed/unsupported payloads; route identifiers alone
never prove eligibility. Neither callable accepts a client verification time,
student UID or operator UID as authority. Admin SDK bypasses Rules, so all relevant
checks are explicit in attendance.js, and authoritative documents are read in the
same transaction. Secrets are never logged or returned in Firestore queries.

### Server-only storage

| Path | Data |
| --- | --- |
| _attendanceCredentials/{sha256(token)} | uid, organizationId, eventId, issuedAt, expiresAt, consumedAt |
| _attendanceIssuance/{uid} | issuedAt, tokenHash |

Only a hash of the secret is persisted. Existing default-deny Rules prevent all
client reads/listing/creation/updates/deletion in these namespaces. One global
issuance slot per student rate-limits regeneration to one pass per five seconds.
Regeneration deletes the previous credential, even across different events.
Consumption and attendance creation share a transaction. A valid duplicate pass
returns existing attendance only to an authorized operator; expired or replaced
passes fail. Returning a duplicate never changes status, method, time or operator.
If a manual record wins the race, it remains final and QR cannot overwrite it.

Functions cap instances at three. App Check enforcement and a distributed scanner
abuse limit are deferred; Auth, current permissions and unguessable tokens remain
mandatory. No raw token is written to logs. Old expired records have no automatic
TTL policy yet: expiry validation is mandatory regardless of retention, and
regeneration removes the previous credential. Administrative cleanup/TTL can be
reviewed later; no paid cleanup service is configured here.

### Display and scanner

The selected event displays organization, schedule, registration/attendance,
server-issued QR image, remaining lifetime and regenerate control. Countdown uses
server-reported duration and monotonic elapsed time, conservatively including the
request duration. The backend is authoritative. Already Verified removes the pass.

Scan QR Code opens the camera only after the route permission check. It requires
no prior organization/event selection. It parses identifiers, checks per-target
permission, calls redemption, and shows projected name, organization, event,
status, method and verification timestamp. Loading pauses scanning; a result or
error waits for Scan Next Participant. Camera denial/unavailability has a clear
message and retry; camera resources stop on backgrounding/route disposal.

A screenshot or forwarded live QR can still be presented by another person during
its short lifetime. The organizer should visually confirm identity. This is not
proof of physical presence and no biometric/location claims are made.

## Attendance reports and personal history

Statistics use unique active registration UIDs only. Present/Absent count their
corresponding authoritative records; Not Marked = active registrations - Present
- Absent. Rate = Present / active registrations * 100. An empty denominator shows
an empty-state explanation. Withdrawn registrations do not affect percentages.
Roster rows can still show their preserved records and registration status.

Reports support event selection, participant-name search and status filtering;
method and timestamp are shown. Loading/failed necessary data blocks the entire
report rather than displaying partial statistics. CSV export and a separate date
range filter are deferred; event selection shows event dates and retained events.
No public export files or private profile lookups are introduced.

My Attendance reuses the existing own-registration query and event metadata,
subscribing only to that UID's attendance document per event. It displays a
participation summary, explicit status, verification method and time. Withdrawn
and cancelled events retain records. If organization/event visibility is revoked,
metadata is labeled unavailable while the student's own attendance remains
private/readable. A failed attendance lookup is an error, never Not Marked.

## Security Rules and indexes

Manual creates require the exact schema, matching path IDs, active registration,
authorized operator, operator/request UID equality, server timestamp, open window,
published approved unarchived event and verificationMethod=manual. Updates/deletes
and client QR assertions are denied. Students can get only their own attendance;
organizers may query attendance only within an authorized organization.

Scoped event/registration/identity read permissions were extended only for
attendance operators. Profile privacy, membership role grants, event edits,
registration capacity transactions and default-deny unrelated collections remain.
No new Firestore indexes are required: attendance uses per-event collections and
own document reads; credential access uses hashes/direct documents. Existing
firebase/firestore.indexes.json is unchanged.

## Dependencies and local setup

Flutter additions: cloud_functions 7.0.1, mobile_scanner 7.4.2, qr_flutter 4.1.0
(and their resolved transitive packages). Android CAMERA permission is declared;
camera hardware is optional. Google/Firebase working configuration and application
ID are preserved. mobile_scanner uses bundled Android ML Kit by default.

Backend: firebase-admin 13.10.0 and firebase-functions 7.4.0 (locked). Runtime is
Node.js 22; install Node 22 for matching deployment behavior. This machine ran the
emulator under Node 24.11.1, which emitted a runtime-version warning. No service
account credentials belong in the Flutter app or repository; deployed functions
use the managed runtime identity.

From repository root, install dependencies and run locally in PowerShell:

```powershell
flutter pub get
npm.cmd --prefix firebase/tests ci
npm.cmd --prefix firebase/functions ci
$env:FUNCTIONS_EMULATOR_HOST = '127.0.0.1:5001'
firebase.cmd emulators:exec --only firestore,auth,functions --project orglink-dev "npm.cmd --prefix firebase/tests test && npm.cmd --prefix firebase/functions test"
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

The emulator test process refuses to run without FIRESTORE_EMULATOR_HOST; CLI
sets it and the Auth host for the child process. Functions host is explicit above.
Tests use only orglink-dev emulator fixtures and Auth emulator accounts, including
authenticated HTTP callable issuance/redemption/replay. Emulators require Java 21+
and the Firebase CLI. On Windows, if CLI shutdown leaves its Java emulator process
behind, stop that specific owned emulator before restarting; do not kill unrelated
Java processes. Logs are local ignored *.log files.

The regular Android entry point continues connecting to configured Firebase,
not the local emulators. No emulator toggle or fake Google login was inserted.
The provided JS integration tests exercise actual local callables; Flutter tests
inject explicitly named test repositories. Testing the Android app locally against
emulators would additionally require deliberately wiring all three SDKs to emulator
hosts and using an Auth emulator account. That wiring is not enabled by default.

## Validation results

Executed final results:

| Check | Actual result |
| --- | --- |
| flutter pub get / dependency resolution | Passed |
| dart format . | Passed; original generated Firebase options preserved |
| flutter analyze --no-pub | No issues found |
| flutter test --no-pub | 63 passed |
| Firestore emulator rules suite | 124 passed, 0 skipped |
| QR backend / callable emulator suite | 23 passed, 0 skipped |
| Existing provisioning unit/emulator tests | 4 passed, 0 skipped |
| flutter build apk --debug | Passed; build/app/outputs/flutter-apk/app-debug.apk |
| Physical Android camera / two-phone check-in | Not exercised |

The combined emulator run completed with exit code 0. Initial development failures
(a concurrency fixture using two Firestore instances and retained event-hub state
after account switching) were corrected; the final runs above passed.

Validation covers full existing Module 1-3 Flutter workflows plus attendance models, summary,
permissions, names, manual confirmation, duplicate guards, reporting failure,
QR selection/display, payload parsing, scanner errors, UID switching and disposal.
Rules tests cover exact schema/timestamps, privileged reads, no self-verification,
unauthorized clients, lifecycle/window, invalid/withdrawn registrations, immutable
records, concurrent manual attempts, private projections and credential denial.
Backend tests cover Auth, registration/student/event binding, secure storage,
expiry, regeneration/rate limit, replay, missing projections, concurrent redemption,
manual/QR races, in-flight revocation/cancellation/expiry and callable HTTP transport.

Android debug build passed with Flutter/plugin Kotlin migration warnings; these
are compatibility warnings for a future Flutter upgrade, not a failed build.
Physical-device camera permission/scanning and a two-phone QR workflow have not
been exercised. Automated camera decoding is not claimed by widget/backend tests.

## Manual deployment and Console requirements (not executed)

1. Review Rules/functions and keep project selection explicitly orglink-dev.
2. Cloud Functions deployment requires a Blaze-capable Firebase project and
   associated APIs/permissions. A project owner must review/approve any billing
   or API enablement; no such changes were made or assumed here.
3. Keep Firebase Auth Google provider, fingerprints and existing Android Firebase
   files as already configured. No new OAuth secret or client ID is needed.
4. With approved deployment credentials outside the app/repository, deploy only
   these reviewed resources, explicitly and manually:

```powershell
firebase.cmd deploy --only firestore:rules --project orglink-dev
firebase.cmd deploy --only functions:attendance --project orglink-dev
```

No index deployment is necessary for Module 4. Both functions are in us-central1,
matching FirebaseFunctions.instance's default region. Ensure callable HTTPS
endpoints are invocable by the mobile SDK while Firebase Auth authorization remains
inside the handlers; do not make Firestore credentials readable. Provision officer
manageAttendance=true only through an authorized administrative process. Existing
clients cannot grant that permission. Review App Check as a later hardening step
before broader usage; do not enable enforcement until Android attestation is set up.

## Manual verification checklist

1. Use two eligible Google accounts and an approved, published ongoing event with
   registration completed before cutoff. Verify no QR can be generated early/late,
   for a withdrawn registration, or after a prior Present/Absent result.
2. As the assigned manager, select organization/event, search by projected name,
   confirm Present/Absent, and check result timestamp/operator and report totals.
   Repeat marking from another organizer; the first result must remain unchanged.
3. Compare Absent with untouched Not Marked. Confirm report rate excludes withdrawn
   registrations and empty reports avoid division by zero. Test lookup/network
   failures and retry; partial summaries must not appear authoritative.
4. On the student phone generate the event pass. On the authorized organizer phone,
   open the global QR Hub scanner directly; scan without preselecting an event.
   Verify projected name, correct organization/event, Present, QR and server time.
5. Scan twice and concurrently; verify one attendance document. Regenerate a pass
   and reject the old one; wait 60 seconds and reject expiry. Race manual marking
   with scanning; verify original status/method are retained.
6. Give an officer manageEvents only: attendance must be denied. Provision
   manageAttendance in one organization; allow that organization's events only.
   Remove permission/cancel event or registration mid-request and retry.
7. Deny Android camera permission, background/resume, leave scanner, retry, and
   scan the next participant. Verify camera stops and no duplicate requests fire.
8. Switch accounts while a history/QR request is pending; no former user's names,
   records or QR must remain. Signed-out/ineligible deep links must redirect.
9. Inspect Firestore: exactly seven attendance fields, unchanged six registration
   fields/capacity and unchanged participant identities. Student clients must not
   read other attendance/profiles or credential storage; client QR writes fail.

## Limitations and next steps

- Manual resource deployment is required for live use; backend source authorization
  does not authorize automatic deployment or billing changes.
- No physical-device camera/two-phone acceptance test yet.
- CSV export, separate date range filters, audited attendance corrections, automatic
  TTL cleanup, pagination and scanner-specific distributed abuse limits are deferred.
- Full rosters and per-registration own-history listeners suit this demonstration
  MVP; large datasets should add pagination/listener bounds in a future task.
- Platform roles do not grant attendance power; officer provisioning remains an
  external trusted administrative task. No administration module was introduced.
- No badges, ratings, notification scheduling, biometrics or location verification.
