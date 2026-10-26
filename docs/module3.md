# Module 3: Event management and registration

Implemented within the existing View -> ChangeNotifier ViewModel -> Repository
-> Firebase Service -> typed Model architecture, using Provider, go_router,
Material 3 and the existing orglink-dev Firebase project. Modules 1 and 2 are
preserved. No live demonstration records were created and no Firebase rules,
indexes or backend services were deployed automatically.

## Specification and explicit project decisions

Read Elective3_FinalProject.pdf, especially screens 11-16, roles, organization
settings, and the event/registration schemas. The PDF defines draft, published,
cancelled and completed event states and an archive action. It does not define
approval authority/status values, registration-status values, or detailed
withdrawal rules. The following decisions were supplied by the project owner:

- managerUid on the organization is the organization-level authority. Managers
  can create/edit/review/publish/cancel their organization's events. Managers may
  approve events they created themselves.
- Securely provisioned active officers with the assigned manageEvents=true
  permission can create, edit and submit their own drafts. They cannot edit
  another creator's draft, approve, publish or cancel events. Position titles
  alone confer no permissions. Existing officer assignments must be made through
  an authorized administrative process; there is no self-assignment UI.
- Ordinary members cannot create or approve events. Platform roles, including
  platformAdmin, do not automatically grant event permissions.
- Public events admit active accounts with complete student profiles. Members-
  only events additionally require active membership in the organizing
  organization. Pending, rejected and removed memberships are insufficient.
- Withdrawal is allowed before the earlier of registrationDeadline/startAt,
  retains the record and original registeredAt, changes registrationStatus to
  cancelled, and releases capacity atomically. Re-registration is allowed before
  cutoff if eligibility and capacity permit it. Event cancellation blocks new
  registrations; an existing owner can still withdraw before cutoff.

Approved published compatibility remains eventStatus=published,
approvalStatus=approved and startAt. Private events use visibility=private and
are labeled Members only in the UI. To preserve Module 2 organization privacy,
private organizations create members-only events; public events are hosted by
active public organizations. Public discovery means eligible authenticated
accounts, not anonymous access.

Approval values are pending/approved/rejected. Registration values are
registered/cancelled. These values resolve unspecified PDF details explicitly;
organization membership statuses remain unchanged.

## Implemented screens and routes

| Screen | Route |
| --- | --- |
| Event Discovery | /events |
| My Events | /my-events |
| Organization Event Management | /organizations/:organizationId/events/manage |
| Create Event | /organizations/:organizationId/events/new |
| Event Details | /organizations/:organizationId/events/:eventId |
| Edit Event | /organizations/:organizationId/events/:eventId/edit |
| Registration Confirmation | /organizations/:organizationId/events/:eventId/registration |
| Participants | /organizations/:organizationId/events/:eventId/participants |

Home links to Discovery/My Events. Organization Details links to event summaries,
browsing and authorized event management. Discovery has an organization selector,
local title search and Upcoming/Ongoing/Past/All filters. Organization management
lists events with title search and lifecycle/archive filters; officers see only
their own records there. My Events filters All/Upcoming/Past/Cancelled and shows
registration and event statuses. Published event cards show organizer, schedule,
venue, available capacity and registration availability.

Event Details shows poster/default organization logo, description, schedule,
venue, capacity, deadline, visibility, lifecycle, own registration and permitted
actions. A separate confirmation screen precedes registration. Lifecycle actions
and withdrawal use confirmation dialogs and feedback. Participant lists are
read-only and show event-scoped full names, registration status and timestamps,
with the reserved count. Missing legacy names display Unknown Participant. Private profiles, emails and student numbers are not exposed.

Loading, initial-server timeouts, empty states, retry, field validation, operation
errors and duplicate-submission guards are included. Providers are keyed to and
react to Firebase UID changes so a reused route cannot retain a prior account's
organization/event context. Auth/profile redirects still precede these routes.

## Firestore schema

### organizations/{organizationId}/events/{eventId}

| Field | Type / purpose |
| --- | --- |
| eventId, organizationId | strings matching document identity/path |
| title | required string, 1-200 trimmed characters |
| description | required string, 1-5000 trimmed characters |
| posterURL | optional HTTPS URL or null, maximum 2048 characters |
| startAt, endAt | Firestore timestamps; end strictly follows start |
| venue | required string, 1-200 trimmed characters |
| capacity | integer, 1-100000 prototype bound |
| registrationDeadline | timestamp; future on save/submit/publish, no later than start |
| registrationCount | integer; zero at creation, modified only by paired registration operations |
| eventStatus | draft, published, cancelled or completed |
| approvalStatus | pending, approved or rejected |
| createdBy | authenticated creator UID, immutable |
| createdAt | server timestamp at creation, immutable |
| updatedAt | server timestamp for every mutation |
| visibility | public or private (members only); specified by the PDF form but omitted from its abbreviated schema |
| submittedAt | nullable server timestamp, submission metadata |
| reviewedAt, reviewedBy | nullable last-decision server timestamp and manager UID |
| publishedAt, cancelledAt, completedAt | nullable server timestamps for lifecycle history |
| archivedAt | nullable server timestamp; archiving preserves cancelled/completed eventStatus |

No alternative event-type field was invented: the PDF does not define one.
Local UI dates/times convert to Firestore timestamps; server request time enforces
cutoffs. Device clock differences can affect display/prechecks, never server
eligibility or capacity enforcement. Optional legacy values deserialize safely.

### organizations/{organizationId}/events/{eventId}/registrations/{uid}

Uses the PDF's exact six fields:

| Field | Type / purpose |
| --- | --- |
| uid | authenticated Firebase UID and document ID |
| eventId, organizationId | matching event/path identities |
| registrationStatus | registered or cancelled |
| registeredAt | original server registration timestamp; preserved on withdrawal/re-registration |
| updatedAt | server timestamp at latest status change |

The stable UID path prevents duplicate active records. Records cannot be deleted.
No client or organizer can forge another student's registration or modify an
organizer-wide counter independently. The record retains its original timestamp
and latest status; an append-only history of every toggle is deferred. The six
registration fields remain unchanged; display names live in a separate scoped
projection below.

## Lifecycle and authority

1. Save draft: eventStatus=draft, approvalStatus=pending, submittedAt=null,
   registrationCount=0. Only assigned managers or permitted active officers.
2. Edit draft: manager or its creating officer; editing is blocked while awaiting
   a decision. Editing an approved/rejected draft resets approval to pending and
   submittedAt to null. Prior last-review metadata is preserved as history but
   does not authorize publication after revision.
3. Submit: keep draft, set pending and submittedAt=server time. Submitted content
   is locked until review.
4. Manager review: pending submitted draft -> approved or rejected, recording
   reviewedAt/reviewedBy. Self-approval by the assigned manager is permitted by
   the selected project policy. Rejected drafts can be revised and resubmitted.
5. Manager publish: approved draft -> published; still requires future start and
   registration deadline. Officers cannot publish even an approved own event.
6. Manager cancel: draft/published -> cancelled. No reopen transition is allowed.
7. Manager complete: published -> completed only after endAt.
8. Manager archive: cancelled/completed remains its lifecycle state and receives
   archivedAt. This avoids inventing an extra event status absent from the PDF.

Published content is immutable. To change it, the organizer cancels it and creates
an appropriate replacement rather than altering an approved schedule/capacity
under existing registrations. Only the manager controls cancel/complete/archive.
Officers with event permissions can view participants for their own events;
managers can view participants for any event in their assigned organization.
No organizer mutation of student registration status is exposed or authorized.

## Atomic registration and withdrawal

Registration uses a Firestore transaction reading the event and the own UID
registration, then writing the registration transition, registrationCount+1 and the participant
identity projection, derived from the own private profile in that same transaction.
Both rules require the corresponding post-commit state via getAfter. The counter
must change by exactly one, stay within capacity, and match that same user's
new/previously cancelled registration transition in the same commit. An event
counter edit alone, registration-only write or mismatched delta is denied.

Withdrawal uses an atomic batch with registrationStatus=cancelled and
FieldValue.increment(-1). Rules require a previously registered owned record,
open cutoff, positive previous counter, exact -1 and the paired post-commit
record. This does not require reading private event content: a removed member
can release an owned reservation before cutoff without regaining private access.
My Events offers this server-checked action on an unavailable event. Cancellation
retains records; re-registration preserves registeredAt and reserves a slot anew.

A batch waiting on connectivity has a 20-second confirmation timeout. The UI says
its outcome is unconfirmed, not that a queued server write definitely failed.
Authoritative snapshots eventually display the final state. Duplicate queued
withdrawals cannot release two slots because rules require the registered ->
cancelled transition. Registration transactions reread on conflicts; capacity,
cutoff, account and membership checks are independently enforced server-side.

No Cloud Function is needed for this bounded operation: the emulator suite
proves concurrent capacity enforcement, duplicate prevention, forged-counter
rejection and exactly-once slot release. The mechanism does not rely on Flutter
checks to authorize writes or prevent oversubscription.

## Rules, indexes and Module 2 compatibility

Existing profile and membership rules are preserved. The event block now
validates full creation schema, protected identities/timestamps, organizer
permissions, lifecycle transitions, visibility and paired registration writes.
The registration collection-group list rule allows only resource.uid equal to
request.auth.uid, matching My Events' own-UID query. Do not reuse registrations
for unrelated private records without revisiting that list rule. Attendance,
badges, ratings and unrelated collections remain denied.

Discovery fans out through accessible organization records from the existing
organization hub, rather than issuing a broad event collection-group query that
could include private organizations. Public event lists filter approval/lifecycle
and visibility; active members/managers may also query members-only published
content within accessible organizations. Drafts are never public discovery data.

Indexes include:

- events: eventStatus + approvalStatus + visibility + startAt (public lists and
  Module 2 upcoming published summaries).
- events: eventStatus + approvalStatus + startAt (authorized member event lists).
- events: createdBy + startAt (officer own-event management).
- registrations: collection-group single-field uid, in addition to local indexes.
- Existing organization discovery/membership indexes are retained.

Module 2 summaries retain published/approved/startAt but now filter
visibility=public. This prevents a new members-only event from causing either a
private-data leak or a permission-denied summary query for nonmembers. Authorized
members can find private events in Event Discovery. Module 2 regression tests
were updated to include explicit public visibility on their event fixtures.

Existing manually created event summaries without visibility will not appear in
filtered public lists until an authorized operator reviews and explicitly sets
visibility=public. Legacy documents also need the complete schema before event
management/registration can use them. Do not guess counters for events with
existing registrations: verify actual reserved records before any administrative
backfill. No existing data was reset, overwritten or automatically migrated.

## Deployment and demonstration

Review the source changes, then an authorized operator can deploy only the rules
and indexes to the existing project:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project orglink-dev
```

Wait for indexes to finish building in Firebase Console. No new Firebase project,
Firebase initialization changes, OAuth changes, Flutter package additions or
Cloud Functions deployment are required. Emulator tests do not verify production
index availability. Rules/indexes have not been deployed during implementation.

Use the Module 2 administrative procedure to assign the manager securely, if not
already done. Officer event permissions must be provisioned by an authorized
administrator on an existing active membership: membershipRole=officer,
permissions.manageEvents=true, and an appropriate separate positionTitle such as
Event Coordinator. Preserve other membership fields/permissions and leave
platformRole=user. No Flutter UI can assign itself these privileges.

Create demonstration events explicitly through the application after reviewing
and confirming your intended live data. No automatic event-seeding script runs.

Manual end-to-end procedure:

1. Sign in as the organization's manager. Open Organization Details -> Manage
   organization events, or Event Discovery -> Manage -> choose the organization.
2. Create a synthetic event with a future deadline/start, end after start and
   capacity 1 or 2. Leave poster blank for the organization-logo fallback.
3. Save draft. Verify a student cannot discover it. Submit, approve and publish
   as manager; self-approval is allowed. Inspect the server timestamps and UID.
4. With a securely provisioned event officer, repeat draft creation and submit.
   Verify the officer cannot edit another creator's draft, approve or publish.
   Have the manager reject, let the officer revise/resubmit, then approve/publish.
5. Sign in as a second dedicated student demo account. Discover the public event,
   open details, confirm registration and verify My Events and registrationCount.
6. Use two eligible accounts/devices to compete for the last slot. Verify only
   one reserves it and count never exceeds capacity.
7. Before cutoff, withdraw and verify cancelled status, retained registeredAt and
   released slot. Register again and verify the same stable UID document.
8. Create a members-only event. Verify pending/rejected/removed memberships cannot
   access or register; an active member can. Revoke membership and verify private
   details disappear while own registration remains and an allowed withdrawal
   can release the slot without exposing event content.
9. As manager, view participant names/statuses/timestamps and authoritative counts.
   Verify ordinary students and unassigned officers cannot open that roster.
10. Test closed deadlines, cancelled events and invalid status transitions. Cancel
    an event with registrations and verify My Events displays event cancellation.
11. Mark a past ended published event completed and archive it. Verify history is
    retained and archived records are excluded from normal discovery.
12. Recheck Google Sign-In, profile editing, organization joining, membership
    approval and account switching. These existing workflows remain covered by
    regression tests.

## Files created and modified

Added under lib/features/events:

```text
data/models/event.dart
data/models/event_registration.dart
data/repositories/event_repository.dart
data/repositories/firestore_event_repository.dart
data/services/event_service.dart
presentation/event_scope.dart
presentation/viewmodels/event_context_view_model.dart
presentation/viewmodels/event_hub_view_model.dart
presentation/widgets/event_access_view.dart
presentation/widgets/event_widgets.dart
presentation/screens/event_discovery_screen.dart
presentation/screens/event_details_screen.dart
presentation/screens/event_editor_screen.dart
presentation/screens/event_management_screen.dart
presentation/screens/my_events_screen.dart
```

Added test/event_view_models_test.dart, test/event_workflow_test.dart,
test/support/test_event_repository.dart, test/participants_test.dart,
firebase/tests/event.rules.test.mjs and this document. The participant-name
extension also adds data/models/participant_identity.dart and
presentation/viewmodels/participants_view_model.dart under the events feature. Modified dependency injection, router/routes, Home, the shared
Firestore service (atomic batch support), organization provider UID binding,
organization summary query/navigation, Firebase rules/indexes, rules-test package
script and emulator runner, organization rules fixtures, route tests and README.

## Validation results

- dart format and flutter analyze completed; no analyzer issues.
- 44 Flutter tests passed, including existing Modules 1/2 and a phone-sized
  creation -> submission -> manager self-approval -> publication -> student
  confirmation -> withdrawal -> authorized/unauthorized participant-view flow.
- 91 Firestore security tests passed: 30 profile, 28 organization/membership and
  33 event/registration/participant-identity tests. Includes atomic concurrent registration, duplicate
  withdrawal batches, privacy, officer ownership, manager self-approval,
  lifecycle, forged counter/metadata, deadline and eligibility restrictions.
- The existing administrative emulator test passed alongside the rules tests
  (92 tests total in the emulator runner).
- Three administrative provisioning guard/plan tests passed.
- Flutter dependency resolution completed with existing dependencies.
- Android debug APK built, installed and launched on the connected emulator.
  Existing Firebase plugin warnings about future Kotlin Gradle compatibility
  remain; the current build passes.

The live end-to-end event workflow still needs the manual steps above after
reviewed rules/index deployment. No live event/registration records were created
or event permissions provisioned by this task.

## Known limitations and deferred features

- Poster input accepts an optional HTTPS URL with a default-logo fallback.
  Cloud Storage file upload is deferred until its billing/storage/rules setup is
  explicitly configured. No nonfunctional upload control is shown.
- Event-type taxonomy and organization-wide automatic approval bypass are not
  defined in the PDF or selected policy, so neither was invented. Every event
  follows the selected manager approval flow.
- Calendar integration, attendance, badges, ratings, notifications, officer-
  assignment UI and final visual styling remain outside this module.
- Small-prototype discovery uses per-organization listeners and local filtering.
  Large catalogs need pagination/search infrastructure and read-cost review.
- Last-decision/lifecycle timestamps and original registration timestamps are
  retained; a full append-only activity audit is deferred.
- Server connectivity is required for authoritative initial lookup and writes.
  Permission revocation cannot reach an offline device instantly; server writes
  still enforce current authorization and deadlines.


## Participant full-name enhancement

### Minimal data flow and authorization

Event Participants now joins registration records with a minimal event-specific
projection at:

`organizations/{organizationId}/events/{eventId}/participantIdentities/{uid}`

Only these three fields are stored:

| Field | Type / source |
| --- | --- |
| uid | string matching the document ID and authenticated student |
| fullName | exact top-level users/{uid}.fullName value |
| updatedAt | server timestamp of capture/refresh |

In Dart the source is StudentProfile.details.fullName; the Firestore field is
fullName at the top level. The projection contains no email, student number,
section, role, photo or other private profile fields. UID remains the registration
identity and the internal join key, while the primary label is the full name.
Status, original registered time, latest updated time, counts and navigation are
preserved. Dates/times use Flutter localization and the device's time preference.

The registration service reads the authenticated student's own profile inside
the transaction and writes the projection alongside the registration and event
counter. The client does not pass a name argument. Rules independently compare
it with the existing private profile and require the correct UID, exact three
keys, server updatedAt and a corresponding own registration. Registration and
re-registration require that matching projection in the same commit. A failed
name/projection check rolls back registration and capacity changes atomically.
The existing six registration fields and UID document identity are unchanged.

Only the same authorized managers and event officers who may read that event's
participant roster can read/list its name projections. An officer must be active,
have manageEvents=true, and be the event creator; the assigned manager can read
all event participants in their own organization. Ordinary students cannot read
this collection, even their own projection; their own private profile remains
available through Module 1. Unrelated managers and broad collection-group name
queries are denied. users/{uid} read access is still owner-only.

Students cannot create projections without an owned registration, forge another
UID or copy a different name, add private fields, delete projections, or change
another student's name. Managers/officers do not receive permission to write
other participants' identities. The source profile is still user-maintained:
this feature establishes provenance from that profile, not institutional
verification of the legal name.

### Read efficiency, profile changes and legacy records

ParticipantsViewModel owns one registration listener and one projection listener
per event, with an in-memory UID/name index. Widgets do not call Firebase or read
private profiles and do not issue one read per participant on every rebuild.
Loading names has an explicit loading state; query errors show retry rather than
being mislabeled as missing names. A missing or blank legacy projection displays
Unknown Participant. Revoking roster access removes the name view and Firestore
independently rejects subsequent reads.

Name projections are snapshots, not a globally readable live student directory.
A later profile edit does not silently rewrite every historical event. A new
registration/re-registration captures the current profile name. Students can
also use **My Events -> Refresh My Participant Name** for either a registered or
cancelled record. This explicit transaction reads only their own profile and
registration and updates only the projection. It safely backfills legacy records
and propagates profile-name changes without affecting registration state,
registeredAt, updatedAt on the registration, deadline, eligibility or capacity.
The refresh does not require reading private event details, so a former member
can update an owned historical name without regaining private access.

Withdrawal does not delete or change the identity projection. Existing legacy
registrations without a projection can still withdraw; name capture is required
only on a new registration or re-registration. Withdrawn participants therefore
remain identifiable whenever a projection was captured or explicitly refreshed.
If an old participant never refreshes, staff see Unknown Participant rather than
an unauthorized private-profile lookup. No live records were backfilled by this
task and no refresh is automatically triggered on app launch or build validation.

### Tradeoffs, reuse and deployment

This solution needs no paid service, Cloud Function, billing enablement, new
Flutter dependency, new Firebase project or additional query index. Its cost is
one own-profile read and one small projection write per registration/refresh,
plus one projection query on the authorized participant screen. Snapshot names
can lag profile edits until re-registration or explicit refresh. Projections
follow event/registration retention and are not automatically removed when a
private profile is deleted; account-removal/retention automation is deferred.
The typed ParticipantIdentity model, event-scoped repository method and name
index can be reused by future authorized Attendance Management. No attendance
features or new attendance-officer privileges are introduced here.

Deploy the reviewed rules with the updated app together:

```sh
firebase deploy --only firestore:rules --project orglink-dev
```

No deployment was executed. Old app builds that omit the required identity write
will have new registration/re-registration commits rejected after the new rules
are published. Existing registrations and withdrawal remain supported. For a
first Module 3 deployment, also deploy its existing indexes as described above;
this enhancement adds no new index requirements. Do not broaden users reads or
make a public student directory to work around missing legacy projections.

### Enhancement verification

1. With an eligible demo student and an open event, register. Verify the original
   registration still has only the six schema fields, the counter increments
   once, and participantIdentities/{uid} contains the profile's exact fullName,
   matching UID and server timestamp.
2. As the assigned manager, open Event Participants. Verify the full name is the
   primary label, with status and localized timestamps, and no primary UID label.
3. Repeat with an authorized active event officer viewing their own event.
   Ordinary students, unrelated managers and unassigned officers must not gain
   name or private-profile read access.
4. Withdraw before cutoff. Verify the participant still has a name, status is
   cancelled and the reserved count decreases exactly once.
5. Edit the student's own full name in the existing profile UI. In My Events tap
   Refresh My Participant Name. Verify the manager's open participant list
   receives the new name; registration timestamps/status and capacity stay intact.
6. For an existing legacy record naturally missing a name projection, verify
   Unknown Participant, then use that record owner's refresh action to populate
   it. Use emulator fixtures for manufactured missing-record/error cases.
7. Exercise offline/name lookup failure and retry. Verify a loading/error state,
   not a raw UID fallback, and check that ordinary screen rebuilds keep one name
   query. Revoke officer permissions and verify names disappear.

Automated coverage adds authorized manager/officer names, denied student and
unrelated-manager reads, global-directory denial, private-profile isolation,
forged UID/name/extra-field writes, atomic rollback, withdrawn-name retention,
legacy withdrawal/backfill, profile-name refresh and unchanged capacity/history.
All existing Module 1-3 regression tests remain in the validation run.


Latest enhancement validation uses the Android debug APK build: the previously
connected emulator was no longer available for the final enhancement launch.
Live device verification remains the manual procedure above. The affected event
labels follow AGENTS.md Title Case conventions using a shared display-identifier
formatter; stored identifiers, queries, rules and user-entered names keep their
original values/capitalization. The enhancement also adds
lib/core/utils/display_labels.dart for reusable presentation-only formatting.
