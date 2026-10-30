# Platform Administration

Reviewed 30 October 2026. Reuses current behaviors and operator safeguards from [the original administration guide](../platform-admin.md), excluding the personal bootstrap identity and historical test totals.

## Authorization and Navigation

An active complete profile with `platformRole: platformAdmin` sees Platform Administration in Profile. Routes `/admin`, `/admin/accounts`, `/admin/organizations` render a separate management experience. AdminScreen rejects unauthorized access before creating the querying ViewModel; router eligibility alone is not the admin role check.

The Worker verifies the Firebase token, then transactionally requires the current profile UID, active status, complete existing identity and platformAdmin role. Client email, role fields and custom claims cannot authorize administrator operations. A manager/officer is not automatically a platform administrator. Conversely a platform role grants no implicit organization event/attendance authority.

## Dashboard, Directories and Search

Dashboard counts saved user profiles, pending profiles and organization documents using aggregation queries. It does not count Firebase Auth identities without profiles. It does not implement the specification's transfer-request count, active-organization breakdown, recent activity feed or announcements.

Directories use 25-record pages with Next/Previous cursors. Explicit Search/Enter submits the selected field/query; typing does not fetch. Account search supports Name, Email, Student ID; organization search supports Name and Organization ID. Matching is case-insensitive literal substring, preserving stored values. Clear restores the first default page; refresh uses the last submitted query.

Firestore has no arbitrary substring operator. The Worker builds a projected private snapshot capped at 2,001 records, accepts directories up to 2,000, caches up to four entries for five minutes and coalesces misses. Over-limit search returns resource-exhausted rather than silently incomplete results. Normal directory pagination remains available. Each request reauthorizes the current administrator; cached search data never authorizes a mutation. External changes may remain stale until refresh/expiry.

## Account and Organization Mutations

Account actions approve/reject pending ordinary users, deactivate active ordinary users and reactivate complete disabled ordinary users. Self/other-administrator mutation is blocked. Rejected and suspended accounts have no general recovery action in this UI. These actions update application Firestore status, not Firebase Auth disable/delete.

Organization creation/editing supports core identity/content fields, visibility, active/inactive status, acceptsRequests and manager assignment. Existing child memberships/events/attendance are preserved. Optional logos use the shared verified Cloudinary flow. Complete positions/public-officer/committee/event-approval editors are not provided.

Manager assignment requires an exact ten-digit Student ID lookup, an active consistent `studentIds` claim and complete active profile. Preview contains profile/registry versions; mutation resolves and verifies them again. Raw UID assignment is not accepted from the management form. Missing/retired/conflicting mappings fail closed. Replacing managerUid changes current authority without pretending to be a manager-transfer request or rewriting membership history.

Admin mutations use a stable requestId and target version. The trusted transaction reads current actor/target and writes business change plus `activityLogs/admin-{actorUid}-{requestId}` atomically. Identical retries return the recorded result; stale/mismatched requests fail. Logs are not client-writable or a public directory. No in-app audit browser or manager-request approval workflow exists.

## Administrator Bootstrap

Bootstrap is an operator-only procedure, never a Flutter role selector or unrestricted signup grant. Use `tools/admin/provision-platform-admin.mjs` and an explicitly selected existing verified development Auth identity with a matching complete eligible profile. Keep privileged credentials outside the repository and app. Do not copy the original guide's personal email into reusable documentation or code.

The following are reference instructions only; neither was executed during this audit. First privately verify the exact existing Auth UID/email and authorized project, then review the operator dry-run; apply is a separately authorized live write:

```powershell
node tools/admin/provision-platform-admin.mjs --project orglink-dev --uid ACTUAL_UID --email OPERATOR_SELECTED_EMAIL
# Only after explicit provisioning authorization and reviewing the dry-run:
node tools/admin/provision-platform-admin.mjs --project orglink-dev --uid ACTUAL_UID --email OPERATOR_SELECTED_EMAIL --apply
```

Use the existing operator credential setup; no secret contents belong in command arguments, logs or documentation. The provisioning tool verifies identity/profile/version and records an audit; do not substitute unreviewed raw Console role changes.

## States and Verification

Screens provide loading, empty, operation error/retry and success feedback, confirmation dialogs and revoked-access handling. Lists/forms scroll, long labels wrap, and local tests cover narrow screens/large text. Physical TalkBack, predictive Back, real administrator bootstrap and actual deployed account/manager actions remain unverified.

Sources: `lib/features/admin/`, `lib/core/services/worker_api_service.dart`, `workers/attendance/src/{admin.js,admin_search.js,student_ids.js}`, `tools/admin/provision-platform-admin.mjs`. Tests: `test/{platform_admin,student_id,member_management}_test.dart`, Worker admin/search/Student ID unit and emulator tests, `tools/admin/provision-platform-admin.test.mjs`. Current executed totals are in the [audit report](v1-audit-report.md).
