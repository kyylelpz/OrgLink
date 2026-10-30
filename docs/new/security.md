# Authentication, Roles and Permissions

## Audit Protections and Residual Risks

No confirmed privilege-escalation or capacity/attendance-integrity defect was demonstrated in this audit. That is bounded evidence from source review and the existing tests, not a penetration-test certification. The new report distinguishes unverified deployment from confirmed defects.

Membership mutations, administrator changes and attendance corrections atomically write audit records; failure rolls back the business change. Initial membership review, event lifecycle and registration retain state/timestamps rather than a complete immutable activity stream. There is no platform activity-log viewer. Worker service-account IAM bypasses client Rules, so backend validation and key custody remain essential.

No App Check enforcement, distributed scanner abuse limit or general QR/audit retention automation is implemented. QR issuance and image slots have specific rate limits; these do not protect every endpoint. Valid forwarded QR passes do not prove physical identity. These are explicit residual risks for supervised small demonstrations, and need policy/control review before broader rollout.

App-status deactivation is not Firebase Auth disablement or token revocation. Existing signed tokens are checked for expiry/signature, with authoritative application status/roles reread for feature operations. Firebase Auth console-only disablement is not guaranteed to revoke an already issued token immediately. Emergency access removal must include the application status path.

Cloudinary images use public delivery URLs: organization/event visibility is not image-URL access control. Only imagery suitable for public delivery should be uploaded. No dependency-advisory scan, external penetration test, live secret/IAM inspection or repository-history credential audit was performed. This documentation includes no real operator identity or credential values.

Reviewed 30 October 2026; reused from the existing permissions guide with updated membership capabilities. Enforcement sources: [`firebase.rules`](../../firebase/firebase.rules), Worker [`auth.js`](../../workers/attendance/src/auth.js), [`admin.js`](../../workers/attendance/src/admin.js), [`student_ids.js`](../../workers/attendance/src/student_ids.js), [`attendance.js`](../../workers/attendance/src/attendance.js), [`images.js`](../../workers/attendance/src/images.js), and Flutter router/models. UI guards are presentation hints, not authorization substitutes.

## Identity and Eligibility

Firebase Authentication provides Google/email-password identity. Password-provider ID tokens must have `email_verified: true` for protected Rules/Worker operations. Owner profile reads remain possible before normal feature eligibility. Email action codes are validated by Firebase and cannot bypass account approval.

The Worker checks RS256 signatures against Google's fixed Firebase public-key source, issuer/audience `orglink-dev`, subject and token time claims. It does not implement Firebase refresh-token revocation lookup; authorization also rereads authoritative application documents. Application `accountStatus` is separate from Firebase Auth's disabled flag. Admin account decisions change Firestore status, not Auth user deletion/disablement.

An eligible app account has an active profile and valid existing student identity. New saves require strict numeric Student ID and controlled academic selection; legacy readable profiles are not silently migrated. `platformRole` supports `user` and `platformAdmin`. An organization manager is an assigned UID, not a platform role. An officer is an active organization membership with `membershipRole: officer` and explicit permission flags.

## Permission Matrix

All allowed actions below still require the relevant active account/org, record state, window and version checks.

| Action | Ordinary eligible user/member | Assigned organization manager | Active officer/member with permission | Active Platform Admin |
| --- | --- | --- | --- | --- |
| Own profile read/save | Owner; creation/ID changes through Worker | Own only | Own only | Own only through normal flow |
| Discover organizations | Public + active | Also assigned orgs | Also accessible joined/private orgs | Normal discovery; admin directory via Worker |
| Request membership | Own request to accepting public active org | Cannot self-apply to assigned org | Same ordinary request restrictions | No special membership bypass |
| Review membership | No | Pending others: approve/reject | No | No implicit manager power |
| Cancel membership request | Owner's unreviewed ordinary pending request only | No authority over others' cancellation | No authority over others' cancellation | No special cancellation privilege |
| Read active roster | No by default | Yes | Active membership + `viewRoster: true` (role need not be officer) | No implicit roster power |
| Create event | No | Yes | Officer + `manageEvents: true` | No implicit event power |
| Edit/submit draft or change poster | No | Eligible editable drafts | Officer + `manageEvents`, own `createdBy` only | No implicit event power |
| Approve/reject/publish/cancel/complete/archive | No | Yes, lifecycle restrictions apply | No | No implicit event power |
| Register/withdraw | Own participation; private event requires active membership | Same participant eligibility; manager assignment alone is not private membership | Same participant eligibility | No bypass |
| View participants | Not general access | Yes | Event editor for own event or attendance operator | No implicit access |
| Manual mark/QR redeem/correct | No; eligible registered user may issue own pass | Yes; never own attendance | Officer + `manageAttendance: true`, independently of `manageEvents` | No implicit attendance power |
| Change organization logo | No | Yes | No independent permission | Yes, active org via Worker |
| Account/organization administration | No | No | No | Allowlisted Worker operations only |
| Assign/revoke officer powers or end active membership | No | Versioned membership Worker operations; self/manager protected | No | No implicit organization authority |
| Assign platform role | No | No | No | No public role editor; explicit trusted bootstrap only |

## Enforcement Details

- Firestore denies direct client profile creation, Student ID registry access, organization writes, protected image fields, privileged account fields, QR credential storage and audit mutation. Owner text-profile updates have a narrow allowlist; the normal profile service uses the Worker for validated saves.
- Membership clients create only their own pending ordinary membership with empty permissions. Managers review others' pending records; direct client role/termination writes are denied. Assigned managers use the trusted membership Worker for officer grants/revocation and removal. Manager reassignment remains a separate admin operation.
- Event creators start with draft/pending and no poster. Draft submission locks editing while review is pending. Managers may approve their own events. Private organizations require private events. Registered/cancelled participant relationships and counter deltas are paired transactionally.
- First manual attendance requires registered eligible participant, approved published unarchived event and `startAt <= serverTime < endAt`. Existing results are not overwritten by ordinary marking. Corrections use Worker preview/apply revisions, a reason, and immutable audit writes; approved published/completed unarchived events that have started may be corrected, including after the event window.
- Admin status changes target ordinary `user` accounts only, exclude self/other administrators, and enforce current state. Reactivate applies to eligible disabled profiles, not rejected/suspended profiles. Manager assignment resolves a unique active Student ID registry mapping and profile versions; historical membership role strings do not preserve former manager power.
- Trusted operator credentials bypass client Rules and must be separately controlled. Bootstrap does not expose a public promotion endpoint. Demo ownership claims are inert, not privilege grants.

See [database schema](architecture.md) for private data boundaries and [module guides](README.md#supported-functionality) for individual operations.

