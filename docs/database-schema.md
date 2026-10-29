# Firestore Database Structure

Source of truth: [Rules](../firebase/firebase.rules), [index declarations](../firebase/firestore.indexes.json), Flutter `data/models` / `data/services`, and Worker backends. Firestore is schemaless at storage level; Rules and trusted writers impose the contracts below. This is a source-derived schema, **not an inventory of live documents**. Times are Firestore Timestamps unless noted. Optional fields can be missing in older records; null lifecycle fields mean the transition has not occurred.

## Relationship Map

```text
Firebase Auth uid
 ├─ users/{uid} ← studentIds/{studentNumber}.uid
 ├─ organizations/{orgId}.managerUid
 └─ organizations/{orgId}/memberships/{uid}
organizations/{orgId}/events/{eventId}
 ├─ registrations/{uid}
 ├─ participantIdentities/{uid}
 ├─ attendance/{uid}
 └─ attendanceCorrections/{correctionId}
```

UID, organization ID and event ID are stable technical identifiers, never presentation labels. Student Number is a unique string attribute, not a replacement UID.

## Application Documents

### `users/{uid}`

| Fields | Type / contract |
| --- | --- |
| `uid`, `email` | Auth-derived strings; trusted profile creation checks identity |
| `fullName` | String, 2–100 characters with nonblank content |
| `studentNumber` | New/changed: exactly 10 ASCII digits as a string; existing identity reads retain legacy acceptance |
| `yearLevel`, `section` | Integer 1–6; section starts alphanumeric and allows letters/digits/spaces/hyphens, max 30 |
| `college`, `program` | New saves select `College of Engineering` and one of eight `Bachelor of Science in … Engineering` programs: Civil, Computer, Electrical, Electronics, Industrial, Manufacturing, Mechanical, Mechatronics. Legacy/missing values remain readable |
| `platformRole`, `accountStatus` | Role `user` or `platformAdmin`; statuses handled by app include pending, active, suspended, disabled, rejected. New profile defaults user/pending |
| `photoURL`, `photoPublicId`, `imageRevision` | Nullable/missing image fields; Worker controls new references and revision |
| `createdAt`, `updatedAt` | Timestamps |

Owners can read their profile. Other users/managers cannot list private profiles through client Rules. Platform administration uses the Worker. Client direct creation, role/status/UID/email/Student ID/image mutation is denied; text fields have a narrow update allowlist. Normal profile saves use `/profile/save`.

### `studentIds/{studentNumber}`

Fields: `uid: string`, `state: active|retired`, `createdAt`, `updatedAt`. Client reads and writes are denied. The profile Worker atomically reserves the new ID, checks legacy duplicates, updates the profile, and retires the previous valid claim. Retired claims remain reserved to the same UID and cannot be stolen; the same owner can reactivate its claim. Registry and profile must agree for manager resolution. No public lookup or arbitrary retirement endpoint exists.

### `organizations/{orgId}`

Fields: `organizationId`, `name`, `description`, `mission`, `vision`, `visibility: public|private`, `status: active|inactive`, `managerUid`, `logoURL`, optional `logoPublicId` / `imageRevision`, `goals: string[]`, `membershipRequirements: string[]`, `positions: string[]`, `approvalSettings: map` (notably `acceptsRequests`, `mode`), `publicOfficers: [{name, positionTitle}]`, `createdAt`, `updatedAt`.

Organization documents contain publication-safe information. `publicOfficers` is explicit published data, not a projection exposing private profiles. `managerUid` is authoritative even without a manager membership document. Administrative replacement does not rewrite memberships or child events. Clients cannot create/update organization documents; admin/approved operator paths and image backend perform trusted writes.

### `organizations/{orgId}/memberships/{uid}`

Fields: `uid`, `organizationId`, `membershipRole`, `membershipStatus`, `positionTitle`, `permissions: map`, `applicantName`, `requestedAt`, `joinedAt`, `updatedAt`, `reviewedAt`, `reviewedBy`.

Roles recognized by models/permissions include member, officer and manager; status values include pending, active, rejected, removed. Permission keys used are `manageEvents`, `manageAttendance`, `viewRoster`. Client requests always create member/pending with empty permissions; position titles do not grant power. Clients cannot provision officer/manager roles. Managers may approve/reject another pending applicant. Membership role `manager` alone never replaces organization ownership. Applicant names are scoped snapshots; email/Student Number are not copied into the roster.

### `organizations/{orgId}/events/{eventId}`

Fields: `eventId`, `organizationId`, `title` (1–200), `description` (1–5000), `venue` (1–200), `startAt`, `endAt`, `registrationDeadline`, `capacity` (integer 1–100000), `registrationCount`, `visibility: public|private`, `eventStatus`, `approvalStatus`, `createdBy`, `posterURL`, optional `posterPublicId` / `imageRevision`, `createdAt`, `updatedAt`, `submittedAt`, `reviewedAt`, `reviewedBy`, `publishedAt`, `cancelledAt`, `completedAt`, `archivedAt`.

New drafts have `eventStatus: draft`, `approvalStatus: pending`, zero registrations, null poster and null lifecycle timestamps. `eventStatus` values: draft, published, cancelled, completed. Approval values: pending, approved, rejected. Archive is a timestamp, not another event status. Creation/edit validation requires future start, end after start, future deadline no later than start. Publication requires approved draft. Completion requires the event to have ended. Draft submission is distinguished from an unsubmitted pending draft by non-null `submittedAt`. Private organizations require private events. [Module 3](module3.md#lifecycle-and-authority) defines transition authority.

### Registrations and Participant Identity

`…/registrations/{uid}` has `uid`, `eventId`, `organizationId`, `registrationStatus: registered|cancelled`, `registeredAt`, `updatedAt`. Withdrawal keeps the document and original registration time; re-registration follows the existing service's paired update. Event count equals active registered records and changes atomically with the user's registration. Capacity, membership and cutoff are rechecked by Rules, not inferred from UI counts.

`…/participantIdentities/{uid}` has exactly `uid`, `fullName`, `updatedAt`. Registration/withdrawal supplies the user's current profile name to a scoped identity projection. Authorized event editors/attendance operators can read it without reading `users/{uid}`. Missing legacy identity displays Unknown Participant; no email/Student Number is included.

### Attendance and Correction Audit

`…/attendance/{uid}` has exactly `uid`, `eventId`, `organizationId`, `attendanceStatus: present|absent`, `verifiedAt`, `verifiedBy`, `verificationMethod: manual|qr`. Missing document means **Not Marked/Pending**, not Absent. One document per participant prevents independent duplicate results. First manual writes are client transactions validated by Rules; QR and corrections are Worker transactions.

`…/attendanceCorrections/{correctionId}` stores `eventId`, `participantUid`, `previousStatus`, `newStatus: present|absent|pending`, `reason`, `correctedBy`, `correctedAt`, `previousRecord`. Correction requires an existing valid result, matching update-time revision and authorized operator. Pending deletes the active attendance document and retains the audit. App clients cannot write audit documents; attendance operators can read them under Rules, although no general audit-history UI is implemented.

## Private Operational Collections

| Path | Purpose / representation |
| --- | --- |
| `_attendanceCredentials/{sha256Token}` | UID/org/event, issue/expiry/consumption timestamps; raw bearer token is never stored |
| `_attendanceIssuance/{uid}` | Latest credential hash and issue timestamp; regeneration replaces the previous credential |
| `_imageUploads/{uploadId}` | Bound owner/resource/path/field/folder/public ID, base revision, state, created/expiry times. Session times use numeric milliseconds; retirement adds a Timestamp `deleteAfter` |
| `_imageSlots/{resourcePathWithUnderscores}` | Numeric `issuedAt` rate slot; one per resource |
| `_imageCleanup/{assetHexId}` | Exact owned `publicId`, numeric `after`, `done`, optional Timestamp `deleteAfter` |
| `activityLogs/admin-{actorUid}-{requestId}` | Admin request, actor/target, before/after, timestamp; atomically provides idempotency and audit |
| `activityLogs/provision-platform-admin-{uid}` | Explicit bootstrap operator audit; never a client promotion operation |
| `_demoSeeds/{seed}` and `/resources/{pathHash}` | Demo operator ownership, frozen parameters and document hashes; no app privileges |

Catch-all Rules deny client access to these private collections. Operator credentials and Worker service-account permissions remain trusted boundaries. No TTL deployment is established by source. Optional image tombstone TTL must target `deleteAfter`, not session `expiresAt`, so orphan cleanup can inspect expired uploads. QR credential retention is not automatically managed by the image-cleanup cron.

## Indexes and Maintenance

Use `firebase/firestore.indexes.json` directly; do not reconstruct a different index set from historical docs. It declares organization visibility/status and event state/approval/visibility/start/creator composite indexes plus collection-group field overrides for identity-scoped queries. Firestore ordinary automatic field indexes and emulator behavior do not prove deployed indexes are ready. Changes require approved manual deployment and a status check. Backfill and demo procedures are in their operator guides; neither has been executed for this documentation review.
