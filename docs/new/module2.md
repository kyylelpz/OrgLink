# Module 2: Organizations, Memberships and Officers

Source-reviewed 30 October 2026. Reuses current workflow and transaction explanations from [the existing guide](../module2.md), including its newer manager-roster implementation. Officer assignment is implemented in the app through the trusted Worker; older operator-only descriptions are obsolete.

## Discovery and Applications

Eligible students discover public active organizations and search loaded names. Details display stored names verbatim, logos/fallbacks, mission, vision, goals, requirements, positions, explicitly published officers, own membership and up to ten upcoming public approved/published events. Missing optional information has empty states. Event summaries link into Module 3; they are not a separate event implementation.

My Organizations combines own membership history and manager assignments. Private/inactive details may be unavailable while own application history remains readable. Public officer data is explicitly published, separate from private user profiles and from authoritative permission records.

Requests create `organizations/{orgId}/memberships/{uid}` as member/pending with empty permissions, null position/join/review data and a profile-derived applicant name. Requests require an active eligible user and an accepting public active organization. Multiple organization memberships are supported.

An applicant may cancel only their own unreviewed ordinary pending request. A transaction deletes that request; no cancelled status or cancellation audit is created. Review and cancellation race safely: a reviewed membership cannot be deleted through this path. Managers approve/reject others' pending requests with confirmations, and Rules recheck assignment and state. Officers cannot review requests through a `viewRoster` grant.

Removed members can reapply using the same UID document; role/permissions reset and current request/join/review metadata resets, while termination metadata and independent management audits remain. Rejected members currently cannot reapply. No automatic migration or historical-data cleanup occurs.

## Roster and Management

Managers see Active, Officers and Former Members. Existing active roster readers have read-only active/officer access; former records are manager-only. Search matches loaded name, UID, position, role and status. No private email/Student Number lookup is added.

Assigned managers of active organizations can View Details, Assign/Change Role, Manage Permissions or End Membership. Self and manager-labelled records are protected. The assigned `organization.managerUid` remains authoritative even without a manager membership record.

| Action | Behavior |
| --- | --- |
| Role | member/officer only; officer position is separate from authority; promotion starts without capabilities; reassignment preserves supported officer flags; demotion clears flags and position |
| Permissions | Only boolean `manageEvents`, `manageAttendance`, `viewRoster`; granting event power does not grant attendance power |
| End Membership | Active target becomes removed; clears permissions; preserves role/position/history/participation; stores optional reason up to 1000 characters, endedAt and endedBy |
| Reapplication | Removed → pending under constrained self-update; no self-activation or restoration of former powers |

Titles come from common options, configured organization positions and existing saved values. A complete committee membership editor and organization hierarchy editor are absent. Platform Administration can configure core organization information; an assigned-manager editor for mission/vision/requirements/visibility/approval configuration is absent apart from logo management.

## Trusted Mutations and Revocation

`POST /memberships/preview` accepts organizationId and participantUid and returns safe display fields plus an opaque document version. `/memberships/mutate` adds operation, version, stable requestId and operation-specific fields. The backend rereads active complete actor, active organization, manager UID and target, forbids self/manager mutation and requires an active target and exact version.

Target mutation and `membershipAudits/{actorUid}-{requestId}` creation commit atomically. Audits contain actor/target/request, trusted time and before/after role/status/position/permission/lifecycle snapshots. Identical committed retries return duplicate success; request-ID reuse with changed content fails. Stale dialogs must be reopened. Client audit writes and direct role grants remain denied, including from managers.

Current permissions are checked on subsequent server operations. Ending membership clears officer power but intentionally preserves registrations/attendance. Public-event participation is not equivalent to membership authority. Public officer names are separate publication data and are not automatically synchronized by role changes. Initial request approval/rejection has review metadata, not an append-only management audit entry.

## States and Evidence

Discovery, details and rosters expose loading, empty, failure/retry and success states. Busy guards prevent duplicate taps; failed/ambiguous mutations preserve an immutable retry command. Identity-keyed scopes prevent former-account content surviving an account switch. Local UI tests cover narrow screens and large text; physical Android accessibility is unverified.

Sources: `lib/features/organizations/`, `lib/features/memberships/`, `workers/attendance/src/memberships.js`, `firebase/firebase.rules`. Tests: `test/{organization_workflow,organization_view_models,member_management,phase4_organizations_ui}_test.dart`, `workers/attendance/test/{memberships.test.js,memberships.emulator.test.js}`, `firebase/tests/organization.rules.test.mjs`.

Remote acceptance must exercise request/cancel/review, officer promotion, each capability, revocation with a second session, former roster privacy and reapplication against the deployed compatible Rules/Worker/app. No deployment or live membership changes were performed.
