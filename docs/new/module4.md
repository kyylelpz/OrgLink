# Module 4: Attendance, QR and Reporting

Source-reviewed 30 October 2026. Reuses the current attendance security, correction and reporting explanations from [the existing guide](../module4.md); removes obsolete backend-migration counts and configuration claims.

## Attendance Records and Manual Marking

One `organizations/{orgId}/events/{eventId}/attendance/{uid}` document records exactly UID/event/org, present/absent, verifiedAt, verifiedBy and manual/qr method. Missing record means Not Marked/Pending, never automatically Absent. An active assigned manager or active officer with `manageAttendance` may verify another eligible registered participant. Event-management and platform roles do not substitute for this permission.

First manual marking uses Firestore transaction/Rules enforcement. The organization must be active and the event approved, published, unarchived, with publication timestamp and `startAt <= serverTime < endAt`. Participant must have an active complete profile and registered record. Caller UID must match verifiedBy; verifiedAt is server time. Self-marking, client QR assertions, updates/deletion and schema additions are denied. Duplicate/racing first results preserve the authoritative record.

## Short-Lived QR Protocol

`POST /issue` authenticates the student, rereads profile/event/registration/attendance, generates 32 random bytes and stores only their SHA-256 hash in `_attendanceCredentials`. A pass lasts at most 60 seconds and is capped by event end. `_attendanceIssuance/{uid}` rate-limits issuance to once per five seconds and regeneration invalidates the prior pass even across events.

`POST /redeem` authenticates and authorizes the scanner before revealing credential information. It rechecks current actor permission, event/window, participant eligibility, registration, token binding/expiry and existing result transactionally. Attendance creation and consumption commit atomically. A valid duplicate returns the original result; manual marking wins without QR overwrite. Expired/replaced/consumed invalid credentials fail. Ordinary clients cannot read credential namespaces.

The scanner opens after route/target checks, works without preselecting an event, pauses during a request, and requires Scan Next Participant after a result. Camera errors/denial have retry feedback; lifecycle/route disposal stops camera resources. The student pass displays event/context, lifetime and regeneration and disappears after verified attendance. Device countdown is advisory; backend time is authoritative.

A forwarded live QR can be shown by another person during its lifetime. Operators must visually confirm identity. This implementation does not prove location/biometrics or physical presence.

## Corrections and Audit

`POST /correct` supports preview/apply with participant/event scope. An authorized manager or attendance officer may correct another participant's existing valid result to Present, Absent or Pending with a required bounded reason and matching document revision. Approved published/completed unarchived events that have started may be corrected after the original marking window; cancelled/archived events are excluded.

Correction and append-only `attendanceCorrections/{correctionId}` creation are atomic. Audit contains previous record/status, new status, reason, actor and trusted timestamp. Pending deletes the active result while retaining audit and invalidates old QR credentials so an old pass cannot recreate it. Stale/concurrent revisions yield one winner; failed commits leave result/audit/credential unchanged. Clients cannot write correction audits or rewrite attendance directly. No general in-app audit-history browser exists.

## Reports and Personal History

Statistics use unique active registration UIDs. Present/Absent count their authoritative records; Not Marked = active registered − Present − Absent. Attendance rate = Present / active registered × 100; empty denominator has an explanatory empty state. Withdrawn registrations are excluded from percentages, while retained records can remain visible with their registration state.

Reports provide event selection, participant-name search, status filters, method and timestamp. Failure to load necessary data blocks authoritative totals rather than treating unknown records as absent. My Attendance uses own registrations plus event metadata and own attendance documents; inaccessible metadata is labelled unavailable. It does not grant access to other students' private profiles or history.

Date-range reporting, authorized export/CSV, pagination and an audit browser remain incomplete/deferred. Unbounded full-roster and per-registration listeners suit a small demonstration, not an established large-scale capacity target. Expiry is enforced without TTL; image cleanup does not clean QR/audit collections.

## Configuration and Evidence

AttendanceService shares the configured `ATTENDANCE_API_URL` default development origin, while using its own bounded authenticated transport for `/issue`, `/redeem`, `/correct`. An omitted dart-define does not mean unconfigured: source has a default. Missing/invalid backend configuration or network failure is an error, not successful verification. No live endpoint was contacted by this audit.

Sources: `lib/features/attendance/`, `workers/attendance/src/{attendance.js,auth.js,firestore.js,index.js}`, `firebase/firebase.rules`. Tests: `test/{attendance,attendance_transport,attendance_correction,manual_attendance_access,qr_window,phase5_6_ui}_test.dart`, `firebase/tests/attendance.rules.test.mjs`, `workers/attendance/test/attendance.emulator.test.cjs`.

Local coverage includes 60-second boundary, duplicate/replay, concurrent redemption, manual/QR race, in-flight permission/event/registration revocation, correction conflict/rollback/reset and account-switch transport. It does not establish physical camera behavior, live IAM/OAuth, two-phone operation, Worker quota suitability or deployed version correctness. Follow the [minimum acceptance checklist](v1-audit-report.md#minimum-actions-before-presentation).
