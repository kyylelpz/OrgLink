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
it does not need a hosted QR backend. QR issuance/redemption now use Cloudflare
Workers Free instead of Firebase Cloud Functions. No billing account is required
for the Worker or the existing Spark Firestore free quota. The Worker and its
server-only secret must be configured manually. Until ATTENDANCE_API_URL is set,
QR check-in reports that it is not configured. No insecure local credential or
automatic paid fallback is generated.

## Architecture and affected files

Existing View -> ChangeNotifier ViewModel -> Repository -> Firebase Service ->
typed Model layering is retained. Provider owns dependencies; go_router retains
Auth/profile/account eligibility redirects. No duplicate Firebase initialization
or authentication subscription was added.

New attendance code is under lib/features/attendance:

- data/models/attendance.dart: typed records, statuses, methods, summary,
  permission helper, attendance-window display hint, QR parser and credential.
- data/services/attendance_service.dart: server-confirmed Firestore reads/manual
  transactions and authenticated Worker HTTPS transport. No optimistic attendance success.
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
firebase/firebase.rules; workers/attendance source, lockfile and tests;
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
startAt <= now < endAt. Manual Rules use request.time; Worker handlers check the
trusted Worker server clock inside every transaction attempt, after all required reads.
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

### Feasibility investigation (completed before migration)

This architecture can securely operate on Workers Free using the existing
orglink-dev default Firestore database and its free quota. No Cloud Functions,
Cloud Run, Durable Objects, KV, R2, new database or billing-linked service is needed.

- [Cloudflare Workers](https://www.cloudflare.com/products/workers/) offers free
  signup without a credit card. [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/)
  and [limits](https://developers.cloudflare.com/workers/platform/limits/) currently
  allow 100,000 requests/day, 10 ms CPU/request and 50 external subrequests/request.
  Network waiting is not CPU time. These are limits, not guaranteed throughput.
- [Firestore REST authentication](https://firebase.google.com/docs/firestore/use-rest-api)
  accepts service-account OAuth tokens and uses IAM, bypassing client Rules.
  Therefore the backend must explicitly retain all authorization checks.
- REST [beginTransaction](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/beginTransaction),
  [batchGet](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/batchGet)
  and [commit](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/commit)
  support read-write transactions and atomic writes. This migration tested these
  actual REST operations against the Firestore emulator, including concurrency.
  Non-atomic batchWrite and Cloudflare-local locks are never used.
- [Firestore free quota](https://firebase.google.com/docs/firestore/quotas) supports
  one free database, including 50,000 reads and 20,000 writes/day. The quota is
  shared with Modules 1-3. No transaction-only billing feature is needed. Stay on
  Spark; quota exhaustion fails requests instead of introducing a paid fallback.

Cold-key verification, OAuth signing, cache misses and contention must still be
measured on the manually deployed free Worker. Exceeding free CPU/quota limits
can reduce availability; requests fail safely and never grant attendance. No
production latency/capacity claim is inferred from local tests. Do not upgrade
plans automatically to address a limit. If organizational IAM policy prohibits
server credentials, stop setup and ask the project owner for a permitted trusted
credential approach; never fall back to privileged client writes.

### Worker endpoints and unchanged business checks

- POST /issue: authenticated UID, active complete profile, matching active
  registration, event/window and no attendance. Generates 32 random bytes
  (256 bits), encoded as 43 URL-safe characters. Valid for at most 60 seconds.
- POST /redeem: authenticates the scanner, verifies current organization
  permission, token binding/expiry, student eligibility/registration, event/window
  and existing attendance. Atomically creates Present and consumes the token.

Requests use Authorization: Bearer <Firebase Authentication ID token> and JSON
request bodies. Responses preserve the existing result fields inside {result:...};
errors use {error:{code,message}} and appropriate HTTP status codes. There are only
two endpoints; no arbitrary collection/path/proxy or administration API is exposed.
Responses are no-store and contain no upstream OAuth or service-account details.
Request bodies are bounded to 8 KiB. Redirects are rejected.

Payload remains version=1, type=attendance, organizationId, eventId and the opaque
token. It contains no UID/profile data/password/Firebase session token. The bearer
Firebase token is sent only in the HTTPS header, never inside the QR or a URL.
Neither endpoint accepts a client UID/operator/time as authority.

The original attendance business logic was moved from firebase/functions to
workers/attendance/src/attendance.js. Node crypto, Firebase Admin SDK and HttpsError
were replaced with Workers-native Web Crypto, a domain error, and a Firestore REST
adapter. Firebase Admin is a devDependency used only for emulator fixtures; it is
not imported by or bundled into the Worker. The old Functions entry point,
configuration, package and source were removed; there is no dual backend fallback.

### Authentication and privileged Firestore access

src/auth.js verifies RS256 signatures using Web Crypto against Google's fixed,
trusted Firebase Secure Token public JWK endpoint. It validates alg/kid, issuer,
audience orglink-dev, nonempty UID subject, expiry, issued-at, auth_time and nbf
when present. It never accepts unsigned Auth-emulator JWTs or a caller-supplied
key URL. Keys respect Cache-Control expiry and are cached per isolate, including
bounded refresh on key rotation. Key retrieval failure fails closed. This follows
[Firebase's token verification requirements](https://firebase.google.com/docs/auth/admin/verify-id-tokens).
Normal ID-token verification is not immediate refresh-token revocation checking;
current accountStatus/profile eligibility is rechecked from Firestore as before.

A dedicated orglink-dev service account is configured only as an encrypted Worker
secret. Web Crypto signs a Google OAuth JWT assertion for the datastore scope and
exchanges it at the fixed oauth2.googleapis.com token endpoint. Access tokens are
cached until shortly before expiry; no credentials or privileged tokens go to
Flutter. See [Google service-account OAuth](https://developers.google.com/identity/protocols/oauth2/service-account).
IAM bypasses client Rules, so all original business checks remain in the Worker.

src/firestore.js uses beginTransaction, transaction-bound batchGet reads, and one
atomic commit. Every checked profile, organization, membership, event, registration,
credential and existing attendance belongs to that transaction. Attendance creation
uses exists=false; token consumption has exists=true. Conflicts retry the whole
transaction at most five times with retryTransaction and jittered backoff. A normal
issue uses at most six reads, two writes and possibly a delete; redemption uses nine
reads and two writes. At most 27 external calls including keys/OAuth are needed for
five full redemption attempts, below the Free subrequest limit. Unknown commit
outcomes are not reported as success; subsequent scans use the authoritative
immutable record. Duplicate results also commit their read transaction before
being returned. No registration/capacity records are changed.

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

App Check enforcement and a distributed scanner abuse limit are deferred; Auth, current permissions and unguessable tokens remain
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
permission, calls the Worker redemption endpoint, and shows projected name, organization, event,
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

## Dependencies and changed migration files

Flutter now directly depends on http 1.6.0 for the Worker transport; cloud_functions
and its transitive packages were removed. QR rendering/scanning packages and every
UI/ViewModel remain unchanged. AttendanceService now uses FirebaseAuth.currentUser
and getIdToken, configured HTTPS, no redirects, timeouts, bounded responses and
account-switch checks before/after requests. Dependency injection and its test
fake constructor were updated; repository contracts/manual attendance are unchanged.
Generated macOS plugin registration reflects removal of cloud_functions.

Worker runtime has no npm production dependencies. Dev dependencies are Wrangler
and Firebase Admin (fixture seeding only). Node 22+ is recommended for local tools;
this machine used Node 24.11.1. Added files:

- workers/attendance/src/attendance.js: migrated business logic.
- workers/attendance/src/auth.js: Firebase JWT verification and Google OAuth.
- workers/attendance/src/firestore.js: Firestore REST value codec/transactions.
- workers/attendance/src/index.js: restricted HTTPS gateway.
- workers/attendance/wrangler.jsonc, package.json/lock, .gitignore.
- workers/attendance/test/auth.test.js and token-fixture.js.
- workers/attendance/test/attendance.emulator.test.cjs: adapted original 23 tests.
- test/attendance_transport_test.dart: Firebase bearer/response/account-switch tests.

Removed obsolete firebase/functions files. firebase.json drops only the Functions
source/runtime and Functions emulator; Firebase/Firestore/Auth configuration stays.
Rules, indexes, attendance schema, Modules 1-3 and all attendance UI are unchanged.

## Cloudflare and Firebase manual setup (not executed)

1. Create a Cloudflare Free account without adding a payment method. Open Workers
   & Pages, use the Workers Free plan and workers.dev subdomain. No custom domain
   or paid bindings are necessary. Do not select Workers Paid or add R2/paid services.
2. Use orglink-dev's existing default Firestore database on Spark; confirm its
   plan manually. This task did not inspect or change billing status. Do not add
   billing for this setup. In that project's IAM console, create a service account for
   attendance, with the standard Cloud Datastore User (roles/datastore.user) role.
   Do not grant Owner, Editor, Firebase Admin or Firebase Auth Admin. This role
   can access Firestore data via IAM; protect its key as a privileged backend secret.
   A project owner can instead review a suitable narrower custom IAM role.
3. Generate that account's JSON private key and store it outside the repository
   and Flutter assets. If IAM organization policy blocks keys, stop and resolve
   that policy with the owner. If any console asks to enable billing, stop; this
   design does not require enabling paid services. The existing Firestore API is
   already used by OrgLink. No new Google Cloud hosted compute API is needed.
4. From workers/attendance, install and log in locally:

```powershell
npm.cmd ci
npx.cmd wrangler login
```

5. Only when ready to publish manually (these commands were NOT executed):

```powershell
npx.cmd wrangler deploy
Get-Content -Raw -LiteralPath 'C:\secure\orglink-worker-key.json' | npx.cmd wrangler secret put FIREBASE_SERVICE_ACCOUNT
```

The first deployment fails closed until the secret exists. The secret must contain
project_id=orglink-dev, client_email and private_key from that dedicated account.
Never paste its contents in a ticket/chat, commit it, print it to logs, embed it in
Flutter, or use it as ATTENDANCE_API_URL. Wrangler stores secrets encrypted. Rotate
keys manually and redeploy/restart isolates to clear cached OAuth credentials.
Neither this repository nor the test suite provisions any real key or IAM role.

6. Publish reviewed Module 4 Firestore rules manually if they have not already
   been deployed. The migration itself makes no Rules/index changes:

```powershell
firebase.cmd deploy --only firestore:rules --project orglink-dev
```

Do not deploy Firebase Cloud Functions. There is no Functions config remaining.
If older functions were previously deployed outside this task, inventory and retire
them manually after the Worker is verified; this migration did not delete remote
resources. Keep the previous provider disabled/unconfigured in mobile builds.

## Flutter API configuration

Use the exact HTTPS workers.dev origin printed by your manual deployment:

```powershell
flutter run --dart-define=ATTENDANCE_API_URL=https://orglink-attendance.YOUR-SUBDOMAIN.workers.dev
flutter build apk --debug --dart-define=ATTENDANCE_API_URL=https://orglink-attendance.YOUR-SUBDOMAIN.workers.dev
```

This URL is public configuration, not a secret. It must have no credentials, query,
fragment or path prefix. Only /issue and /redeem are used. Without it, manual
attendance keeps working while QR reports that it is not configured. No redeployment
or billing change is triggered by the app. No browser CORS support was added;
OrgLink's target remains native Android. No UI or navigation changes are needed.

## Local testing

All emulator tests use orglink-dev synthetic data only and refuse to run without
FIRESTORE_EMULATOR_HOST. Test RSA keys are generated in memory. Firebase-shaped
JWTs in tests are RS256 signed and verified using test-only injected public-key
fetch responses; production uses Google's fixed URL. No unsigned-token bypass is
present. Fixture Admin SDK usage is confined to test files/dev dependencies.

From repository root:

```powershell
npm.cmd --prefix firebase/tests ci
npm.cmd --prefix workers/attendance ci
npm.cmd --prefix workers/attendance test
firebase.cmd emulators:exec --only firestore --project orglink-dev "npm.cmd --prefix workers/attendance run test:emulator"
npm.cmd --prefix workers/attendance run check
flutter pub get
dart format lib/features/attendance/data/services/attendance_service.dart lib/app/dependency_injection.dart test/attendance_test.dart test/attendance_transport_test.dart
flutter analyze
flutter test
flutter build apk --debug
```

check is wrangler deploy --dry-run: it bundles locally and does not deploy. The
regular app still connects to configured Firebase; emulator tests inject test
repositories/REST endpoints. Tests explicitly deny live REST access for fixtures.
For optional manual Wrangler local development, use npx wrangler dev --local and
an ignored workers/attendance/.dev.vars file with FIRESTORE_EMULATOR_HOST set to
127.0.0.1:8080. Only loopback emulator endpoints are accepted; none is set in the
production Wrangler config. Such local access uses emulator owner authentication
for Firestore only; Firebase caller JWT verification is never disabled. To try the
real app locally, its Firebase UID must have corresponding emulator fixtures,
with a genuine orglink-dev Firebase ID token; emulator unsigned tokens are rejected.
Use http://10.0.2.2:8787 for a debug Android emulator build's ATTENDANCE_API_URL.
HTTP is restricted to loopback/Android emulator development hosts in debug mode;
release builds require HTTPS. Do not set FIRESTORE_EMULATOR_HOST on a deployed
Worker. Secret files and Wrangler/build outputs are ignored.

## Migration validation results

- Flutter analysis: no issues; full Flutter suite: 68 passed.
- Worker authentication/OAuth/REST transport unit tests: 16 passed.
- Adapted Firestore REST emulator tests: 23 passed, including authorization,
  60-second expiry, replay, concurrent redemption, manual/QR race and in-flight
  registration/event/permission revocation.
- Existing Firestore Rules are byte-for-byte unchanged; previous Module 4 rules
  validation was 124 passing tests. That historical count is not a claim of a new
  rules run in this migration.
- Wrangler bundle dry-run passed with no production bindings/dependencies.
- Native workerd runtime smoke passed: missing authentication returns 401; unknown
  endpoint returns 404. No live backend calls were made.
- Android debug APK build passed; no endpoint configured in that validation build.

The initial REST concurrency test exhausted a three-attempt retry policy; it was
fixed using Firestore retryTransaction plus five bounded, jittered attempts. All
23 integration tests then passed. No global Java process cleanup is used; if the
Windows Firebase CLI leaves its own emulator alive, stop that specific process
before the next run. No production endpoints, IAM credentials, Google live writes,
Cloudflare deployments or billing changes were tested or performed.

Production IAM/OAuth permissions, Cloudflare Free CPU usage, device camera scanning
and the two-phone workflow require manual verification after setup/deployment.
The local suite verifies a signed OAuth assertion and mocks the token endpoint;
it does not exchange a real service-account credential. Quota exhaustion and
network/unknown commit outcomes fail safely. No paid fallback is implemented.

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

- Manual resource deployment is required for live use; backend migration authorization
  does not authorize automatic deployment or billing changes.
- No physical-device camera/two-phone acceptance test yet.
- CSV export, separate date range filters, audited attendance corrections, automatic
  TTL cleanup, pagination and scanner-specific distributed abuse limits are deferred.
- Full rosters and per-registration own-history listeners suit this demonstration
  MVP; large datasets should add pagination/listener bounds in a future task.
- Platform roles do not grant attendance power; officer provisioning remains an
  external trusted administrative task. No administration module was introduced.
- No badges, ratings, notification scheduling, biometrics or location verification.
