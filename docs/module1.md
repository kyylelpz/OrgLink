# Module 1 — Authentication and Student Profile

Updated 29 October 2026. Implementation targets the configured `orglink-dev`
project. No Firebase Console changes, Rules publishing, Worker deployment or
live-user migration was performed.

## Audit and architecture

The existing implementation used Google Sign-In 7.2, Firebase Auth persisted
sessions, one auth listener, a server-confirmed profile subscription, Provider,
ChangeNotifier and go_router. Profiles are UID-keyed and saved transactionally.
The former new-profile default was active; the requested approval requirement
now makes every newly created profile pending. Existing active profiles remain
active and no existing document is migrated.

The existing View → AuthViewModel → AuthRepository → FirebaseAuthService →
Firebase Auth identity flow is retained. Profile saves continue through the
existing ProfileRepository → UserProfileService → Firestore transaction.
No dependencies, projects, credentials, collection names or privileged roles
were added. Existing organization/event/navigation/attendance workflows remain.

## Authentication flows

- Initial signed-out destination: Sign In (`/sign-in`). Google and email/password
  share the existing theme and official OrgLink logo. Loading is unchanged.
- Create an Account → `/sign-up`: email, new password, matching confirmation.
  Firebase creates the Auth user and sends verification; this creates no
  Firestore profile. Client validation requires 8 characters with a number or
  special character. Firebase password policy remains authoritative.
- Unverified password identities are redirected to `/verify-email` before any
  profile or dashboard eligibility check. Resend uses Firebase. Returning from
  email/browser triggers identity reload and forced token refresh. Android Back
  signs out rather than reaching protected pages.
- After verification: missing profile → existing Student Profile form; completed
  pending profile → existing Account Status. Only trusted approval can change
  pending to active. Verification never writes status or platform role.
- Forgot Password → `/forgot-password` → `/reset-email-sent`. Known and unknown
  addresses get the same neutral completion. Network/rate-limit errors remain
  actionable. Firebase controls email delivery and action-code expiry.
- Firebase action URL `/__/auth/action?mode=resetPassword&oobCode=...` opens the
  reset form when delivered to the app. Firebase validates the code before
  enabling submission, then confirms the password and consumes the code.
  `/password-reset-success` requires an actual successful operation in memory.
  Invalid/expired codes offer a new reset request. Arbitrary URL apiKey or
  continueUrl values are not used to change project or redirect externally.
- `mode=verifyEmail` validates the action type, applies Firebase's code and
  refreshes the current identity. If no user is signed in, sign-in is still
  required. Action-code routes never bypass protected-route eligibility.
- Existing verified Google users may explicitly select Link Password from
  Profile. The app requests fresh Google authentication and reauthenticates the
  current Firebase user before `linkWithCredential`. UID must remain unchanged.
  A mismatched or already-owned credential fails; no email lookup, profile merge,
  delete/recreate or Firestore identity reassignment occurs.
- Native Back pops pushed forms; direct utility routes fall back to Sign In.
  Existing authenticated shell Back behavior is unchanged.

Passwords are passed only to Firebase SDK calls and transient field controllers,
which are disposed with the screen. They are never stored in Firestore, custom
local storage or application logs. Firebase handles persistence of auth sessions.
Error messages suppress raw SDK details and distinguish network/rate-limit/action
code failures without exposing account existence. Password reset does not claim
instant revocation on every device or a fixed email expiry.

## Academic constants and compatibility

`AcademicOptions` in `lib/features/profile/data/models/student_profile.dart`
contains controlled persisted strings. Field names remain `college` and
`program`; adding options later does not require schema changes, but the matching
Rules allowlist must be updated deliberately.

College: **College of Engineering**.

Programs:

- Bachelor of Science in Civil Engineering
- Bachelor of Science in Computer Engineering
- Bachelor of Science in Electrical Engineering
- Bachelor of Science in Electronics Engineering
- Bachelor of Science in Industrial Engineering
- Bachelor of Science in Manufacturing Engineering
- Bachelor of Science in Mechanical Engineering
- Bachelor of Science in Mechatronics Engineering

Program options depend on College. Both are required on profile save, with the
existing red inline field error treatment and checkmarked menu selection. Year
Level remains 1–6 and Section retains its existing validation; no fixed Section
list was supplied. Long program choices wrap in menus. Legacy academic strings
remain readable and displayed verbatim; editing requires an explicit supported
selection and never silently replaces stored values. Legacy active profiles are
not forced through onboarding merely because they lack these newer fields.

## Authorization and data integrity

- Profiles remain `users/{auth.uid}`. Creation requires verified password identity,
  canonical academics, `platformRole: user`, `accountStatus: pending`, matching
  Auth UID/email and server timestamps. No profile is written during sign-in,
  verification, linking or password reset.
- Existing profile transactions verify identity and update only student details
  and updatedAt. Role/status/creation metadata/memberships remain unchanged.
- Rules gate protected data on verified password identity plus existing active
  profile and student validity; email verification alone grants nothing.
  Owner access to their own profile does not grant organization access.
- Existing profile update restrictions, membership permissions, event conditions
  and role checks remain. Changed academic fields must use the controlled pair;
  unrelated updates can preserve legacy academic values.
- Attendance Worker checks the signed password-provider token's email_verified
  claim in addition to its existing signature, project, profile/status and
  attendance authorization. No QR payload/credential/lifecycle logic changed.
- Client validation/routing are convenience layers. The matching Rules and Worker
  changes must be reviewed and released together before enabling the feature.

## Figma and visual acceptance

Inspected final Figma frames directly through MCP: `22:513` Sign In, `67:527`
Sign Up, `67:559` Verification, `67:574` Forgot Password, `67:591` Reset Email
Sent, `67:606` Reset Password and `67:625` Success; also existing profile,
College/Program, inactive and error states. Existing Inter, #152D97, surfaces,
radii, actions, feedback and official PNG logo are reused; loading is unchanged.
Only auth/profile presentation was changed. Figma feedback icons were exported
into the already registered assets/icons directory and rasterized locally;
no image dependency or pubspec change was needed.

Reviewed Flutter renders at 393dp and 320dp/200%; automated matrices cover 320,
360, 393 and 412dp at 100%/200%, safe areas, keyboard, errors and Back. Content
scrolls instead of copying fixed Figma heights. Footers/touch targets expand at
large text sizes. Wording does not promise Figma's fixed 30-minute expiry,
previous-password comparison or immediate logout on every device because those
claims are not guaranteed by the SDK. The Google-labelled exported Figma icon
is X-like rather than the official Google G; retained to match the supplied
frame, and requires a design/branding review before release. Profile structure
outside the requested dropdowns retains the approved implemented baseline.

## Required manual setup (user/operator)

1. In **orglink-dev**, Authentication → Sign-in method: enable Email/Password
   alongside the existing Google provider. Preserve existing accounts and UIDs.
   Do not enable email-link passwordless sign-in for this flow.
2. Review Firebase password policy (at least the app's minimum 8 characters and
   number/special-character expectation), keep email enumeration protection,
   authorized domains and sender/support settings appropriate to this project.
   Review verification and password-reset templates. Do not use sample API keys
   or a second Firebase project.
3. Review and publish the accompanying Firestore Rules and attendance Worker
   authorization check through the existing release process **before enabling
   email/password for users**. Nothing was deployed here; client-only rollout
   would not enforce the new server-side verification restriction.
4. For native email-action screens, associate the existing HTTPS host
   `orglink-dev.firebaseapp.com` with Android package `com.example.orglink` and
   the actual signing fingerprints using Android's verified App Links setup.
   The intent filter alone does not establish domain ownership. Review hosted
   assetlinks availability and email-template URL behavior. Until associated,
   Firebase's existing hosted verification/reset page remains the browser
   fallback; new native reset screens will not automatically open from email.
   No Hosting/Worker infrastructure was introduced to force this association.
5. Use the existing trusted provisioning/admin process or Firebase Console to
   approve pending test users. No client self-approval route was added.

Manual acceptance: real Google sign-in/cancellation and preserved UID/membership;
email signup/login, delivery/resend/rate limits, browser verification and resume;
pending denial until trusted approval; duplicate email and incorrect credentials;
expired/used reset code, old/new password; explicit Google reauthentication with
correct and different accounts; restored sessions, deep links and Android Back;
TalkBack, autofill, keyboard and physical-device large text. Confirm Google
password linking on Android: the installed local Auth emulator rejects the same
Google email during linking before checking the same UID (firebase-tools
`emulator/auth/operations.js` signUp EMAIL_EXISTS check). The integration test
keeps that known failure visible as TODO; it is not counted as a passing link test.
Dart tests verify fresh reauthentication, same-UID SDK calls and failure safety.

## Changed files and validation

Production: auth model/repository/service/ViewModel/screens/branding;
profile model/repository/service/completion/overview; app router/routes and error
mapping; AndroidManifest; `firebase/firebase.rules`; Worker auth guard; auth
feedback PNG/SVG assets. Tests: email_auth, email_auth_ui, email_auth_service,
legacy auth/profile/widget tests and fixtures; profile Rules and local SDK
integration; Worker token tests. README and implemented UI documentation updated.

Validation:

- Touched Dart files formatted; `git diff --check` clean.
- `flutter analyze`: no issues.
- `flutter test --no-pub`: **191 passed**, including email VM/service flows,
  required dropdown errors, Android Back, responsive auth/profile matrices and
  existing membership/event/QR/attendance regression suites.
- Local Auth + Firestore emulator suite: **145 passed, 0 failed, 1 TODO**
  (Google password linking; emulator limitation described above). Real emulator
  SDK tests cover verification, pending approval, self-approval denial, duplicate
  signup, reset-code consumption, changed password and UID/status preservation.
- Attendance Worker local suite: **50 passed**, including verified/unverified
  password-token authorization. No remote Worker request/deployment was made.
- Asset loading/font registration covered by rendered widget tests. Physical
  Android, email delivery, verified App Links and real Google linking remain
  manual acceptance. No APK/device installation is claimed.

No deployment or Firebase Console configuration is part of this change.

### File manifest

- `README.md`
- `android/app/src/main/AndroidManifest.xml`
- `assets/icons/auth_check.png`
- `assets/icons/auth_check.svg`
- `assets/icons/auth_google.png`
- `assets/icons/auth_google.svg`
- `assets/icons/auth_sent.png`
- `assets/icons/auth_sent.svg`
- `assets/icons/auth_verify.png`
- `assets/icons/auth_verify.svg`
- `docs/module1.md`
- `docs/ui-ux-design.md`
- `firebase/firebase.rules`
- `firebase/tests/email-auth.integration.test.mjs`
- `firebase/tests/package.json`
- `firebase/tests/profile.rules.test.mjs`
- `lib/app/router.dart`
- `lib/core/constants/app_routes.dart`
- `lib/core/errors/app_failure.dart`
- `lib/features/auth/data/models/auth_user.dart`
- `lib/features/auth/data/repositories/auth_repository.dart`
- `lib/features/auth/data/repositories/firebase_auth_repository.dart`
- `lib/features/auth/data/services/firebase_auth_service.dart`
- `lib/features/auth/presentation/screens/auth_screens.dart`
- `lib/features/auth/presentation/viewmodels/auth_view_model.dart`
- `lib/features/auth/presentation/widgets/auth_branding.dart`
- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/repositories/firestore_profile_repository.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- `lib/features/profile/presentation/widgets/profile_overview.dart`
- `test/email_auth_service_test.dart`
- `test/email_auth_test.dart`
- `test/email_auth_ui_test.dart`
- `test/phase3_profile_ui_test.dart`
- `test/profile_repository_test.dart`
- `test/student_profile_test.dart`
- `test/support/test_auth_repository.dart`
- `test/text_formatting_test.dart`
- `test/widget_test.dart`
- `workers/attendance/src/auth.js`
- `workers/attendance/test/auth.test.js`

## Platform administrator approvals

The separately implemented [Platform Administration MVP](platform-admin.md) now
provides trusted account approval/rejection/deactivation. It preserves this
module's email-verification and pending defaults. The initial administrator must
be explicitly provisioned by an operator; an email address alone grants nothing.
