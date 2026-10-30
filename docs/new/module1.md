# Module 1: Authentication, Profiles and Approval

Source-reviewed 30 October 2026. Reuses the existing [Module 1](../module1.md) workflow explanations; historical validation totals are replaced by the [audit report](v1-audit-report.md).

## Identity and Routing

Firebase Authentication supplies Google and email/password identities. `FirebaseAuthService` implements registration, sign-in, sign-out, verification/resend, password-reset actions and explicit Google-to-password linking. Registration creates an Auth identity and sends verification; it does not create an approved Firestore profile.

Unverified password identities go to Verify Email. Reload/forced token refresh follows verification. Missing profile goes to Complete Student Profile; a completed pending profile goes to Account Status. Only an active complete profile reaches normal protected features. Rejected, suspended and disabled statuses remain ineligible. Email verification never grants organization or platform power.

`AppStartup` paints the existing splash before Firebase initialization. A shared `SplashGate` enforces two seconds from its first visible frame on startup and successful sign-in, overlapping asynchronous work. Profile/auth loading or errors remain guarded. Restored sessions do not create a redundant second startup interval.

Firebase validates action codes on `/__/auth/action`, reset and verification routes. Invalid/expired codes have explicit error/retry flows. Action routes cannot bypass normal eligibility. Reset success requires a real successful in-memory operation. Forgot-password completion avoids confirming whether an address exists.

Google-to-password linking explicitly reauthenticates the current Google identity, checks the UID and calls Firebase linking. It does not merge accounts, rewrite identity documents or infer ownership from matching email. This has local Dart coverage; the installed Auth emulator rejects the same-email linking scenario, recorded as one TODO. Real Android verification remains required.

## Profile and Student ID

The existing View → AuthViewModel → AuthRepository → FirebaseAuthService flow is retained. Profile saves use ProfileRepository → UserProfileService → WorkerApiService → `/profile/save` → Firestore transaction. Own profile reads use a server-confirmed stream; cached/pending status never grants access.

New profiles default to `platformRole: user` and `accountStatus: pending`. Existing stored profiles are not migrated. Profile fields include name, email, Student Number, year, section, college/program and optional photo. New/changed Student IDs are exactly ten ASCII digits stored as strings; an enrollment year is not inferred from the first four digits. Legacy readable IDs have deliberately more permissive eligibility validation.

Worker `student_ids.js` validates saves, reserves `studentIds/{studentNumber}`, checks legacy duplicates and updates profile/registry atomically. Previous valid claims become retired and remain reserved for their UID. Clients cannot query or edit the registry or directly create profiles. Manager lookup additionally requires consistent active registry/profile versions. Any live legacy registry audit/backfill is a separate approved operation, not an audit action performed here.

New academic saves use College of Engineering and the eight configured engineering programs. Legacy values remain readable; changing academic selection uses the supported options. Names are preserved verbatim, including acronyms and intentional casing. Lowercase capitalization suggestions require an explicit user action and remain editable; display labels never become stored role/status keys.

Profile images use the authorized Cloudinary proxy/crop/verification lifecycle described in [architecture](architecture.md). Text saves do not overwrite verified image references. Passwords/action codes are transient SDK inputs, not Firestore profile fields.

## Account Decisions and States

| Current state | Trusted administrator action | Result |
| --- | --- | --- |
| pending | Approve complete ordinary profile | active |
| pending | Reject | rejected |
| active | Deactivate ordinary profile | disabled |
| disabled | Reactivate complete ordinary profile | active |

There is no general suspended/rejected recovery action in the administrator MVP. Application status changes do not delete or disable the Firebase Auth identity. Self/other-admin status mutations are blocked. Live application status is reread for authorization; Firebase token revocation checking is a separate limitation described in [security](security.md).

## UI States and Acceptance

Forms provide field validation, loading/disabled actions, operation feedback and actionable errors. Profile/auth stream errors block protected content. Profile provides My Organizations, My Attendance, eligible admin entry, Link Password where applicable, and Sign Out. There is no implemented account-removal request or notification-preference workflow. Terms/Privacy wording on auth screens is plain text rather than functional policy links.

Evidence: `lib/app/{startup.dart,splash_gate.dart,router.dart}`, `lib/features/auth/`, `lib/features/profile/`, `workers/attendance/src/{auth.js,student_ids.js,admin.js}`, `firebase/firebase.rules`. Tests include `test/{firebase_auth_service,email_auth,email_auth_service,email_auth_ui,auth_view_model,profile_repository,student_profile,student_id,splash_timing,router,text_formatting}_test.dart`, `firebase/tests/{profile.rules,email-auth.integration}.test.mjs`, Worker Student ID/admin tests and emulator integrations.

Manual acceptance still needs Google OAuth for the built certificate, real email delivery/action links, UID-preserving linking, cold/restarted sessions, approval/revocation on another device, gallery behavior and keyboard/TalkBack. No live Firebase provider or Android domain-association state is certified.
