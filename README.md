# OrgLink

Module 3 event management and registration is implemented. See
[the Module 3 guide](docs/module3.md) for the selected approval policy, atomic
registration rules, routes, indexes, deployment and testing instructions.

Module 2 organization discovery and membership is implemented. See
[the Module 2 guide](docs/module2.md) for schemas, routes, security rules,
manager provisioning, deployment steps and validation.

Flutter Android student organization application. Development, testing and the
final demonstration use the existing Firebase project **orglink-dev**.

## Authentication and student onboarding

Google Sign-In uses the installed google_sign_in 7.2 API (`initialize`,
`authenticate`, ID token), then Firebase Authentication credential exchange.
Firebase's persisted Android session and a single auth listener restore sign-in
on restart; Google authentication is only requested by a button press. Sign-out
attempts Google and Firebase, even if Google cleanup fails. Cancellation is
shown separately from failures. Operations prevent duplicate submissions.

Routing follows auth state ? server-confirmed profile lookup ? profile form if
missing/incomplete ? account-status check ? Home for active complete accounts.
Signed-out startup goes directly to sign-in. Onboarding remains registered.
One profile subscription per UID receives status changes without reads from
widget builds. Profile errors block protected navigation and offer retry and
sign-out; an initial server response has a 20-second timeout. Cached/optimistic
profile snapshots cannot establish eligibility.

New profiles receive **user / active**, providing immediate access as requested.
Pending, suspended, disabled and unknown statuses block Home. No administrative
routes or privileges are granted from profile role strings. Home is a simple
welcome screen with edit-profile and sign-out actions; organization features
remain outside this module.

## Profile schema

Document path: `users/{Firebase Auth UID}`.

| Field | Type | Source / behavior |
| --- | --- | --- |
| uid | string | Firebase UID, also document ID; immutable to client |
| email | string | Auth email; read-only and immutable to client |
| fullName | string | Required, trimmed, 2?100 characters |
| studentNumber | string | Required, 3?30 letters, digits or hyphens |
| yearLevel | integer | Required, 1?6 |
| section | string | Required, 1?30 letters, digits, spaces or hyphens |
| photoURL | string or null | Google photo at creation; immutable to client |
| platformRole | string | `user` at creation; protected afterward |
| accountStatus | string | `active` at creation; protected afterward |
| createdAt | Firestore Timestamp | Server timestamp on creation; immutable |
| updatedAt | Firestore Timestamp | Server timestamp on every save |

Only an explicit valid form submission creates a document. A transaction checks
existence and creates defaults only for a missing document. Existing documents
update only student fields and updatedAt, preserving identity, role, status,
photo, creation time and unrelated existing data. Later sign-ins never overwrite
profile details. The form prefills existing values and displays Google email
and the photo when available.

The number/section formats and year range are baseline validation; no project
specification PDF was present in the repository. Student-number uniqueness and
institutional enrollment verification are not implemented.

## Architecture and changed files

The existing View ? ChangeNotifier ViewModel ? Repository ? Service ? Model
structure remains. Provider owns dependencies and subscriptions; go_router
refreshes from the same AuthViewModel. Firebase initialization, generated options,
google-services.json, Android app ID and Flutter dependencies are preserved.

Modified:

- `lib/app/dependency_injection.dart`, `lib/app/router.dart`
- `lib/core/errors/app_failure.dart`, `lib/core/services/firestore_service.dart`
- `lib/features/auth/data/models/auth_user.dart`
- `lib/features/auth/data/repositories/auth_repository.dart`, `firebase_auth_repository.dart`
- `lib/features/auth/data/services/firebase_auth_service.dart`
- `lib/features/auth/presentation/viewmodels/auth_view_model.dart`
- `lib/features/auth/presentation/screens/auth_screens.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- `lib/features/home/presentation/screens/home_screen.dart`
- Root `firebase.json`: adds rules/index paths and local emulator configuration;
  preserves all existing FlutterFire mappings.
- `firebase/firebase.rules`, `firebase/firestore.indexes.json`
- Existing Flutter tests/support and this README.

Added:

- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/repositories/profile_repository.dart`
- `lib/features/profile/data/repositories/firestore_profile_repository.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `test/student_profile_test.dart`, `test/firebase_auth_service_test.dart`
- `firebase/tests/`: Node rules tests, dev dependencies, lockfile and local ignore.

No Flutter dependencies were added. Node packages firebase and
@firebase/rules-unit-testing are development-only dependencies for rules tests.

## Security rules and manual Firebase setup

The previously empty local rules file now permits only the authenticated owner
to get their profile, create a validated profile with user/active defaults, and
update permitted student fields with a server updatedAt. UID/email must match
the Firebase identity on creation. Client role/status changes, profile deletion,
collection listing and reading another student's private data are denied.
Unrelated collections and subcollections are denied. Account/role changes require
Firebase Console or a trusted backend; there is no client admin bypass.

**The rules have not been deployed.** Review and explicitly publish them to the
existing development project before relying on these restrictions:

```sh
firebase deploy --only firestore:rules --project orglink-dev
```

Firebase Console checks for `orglink-dev`:

1. Enable Authentication ? Sign-in method ? Google, and select a support email.
2. Ensure Cloud Firestore's default database exists.
3. Verify Android app `com.example.orglink` has the SHA-1 and SHA-256 fingerprints
   for the signing key used to run the app. Use Android `signingReport` if needed.
4. Existing google-services.json includes Android and web OAuth clients. If the
   Firebase Console requires a refreshed file after configuration changes,
   download it from the same project/app; no configuration file was replaced here.
5. If the Google OAuth consent setup uses test-user restrictions, add the demo
   Google accounts there.

Never place service-account credentials in this app. Review existing development
profiles before publishing rules: the rules protect future writes and do not
repair previously modified privileged fields.

## Validation and repeatable commands

```sh
flutter pub get
dart format .
flutter analyze
flutter test
npm --prefix firebase/tests ci
firebase emulators:exec --project orglink-dev --only firestore "node --test firebase/tests/profile.rules.test.mjs"
flutter run -d emulator-5554 --no-resident
```

Validation performed:

- Dependency resolution and Dart formatting completed.
- Flutter analysis: no issues.
- Flutter tests: 21 passed, covering token exchange, cancellation, Google/Firebase
  sign-out, duplicate operations, restored sessions, profile failure/retry,
  account changes, form validation/prefilling/saving and routing.
- Firestore emulator tests: 30 passed, including ownership, schema, timestamps,
  protected fields, self-reactivation, default-deny and privileged-profile attacks.
  These tests use local emulator data and do not write to live Firestore.
- Debug APK built, installed and launched on the connected Android 17 emulator.
  Existing Firebase plugin warnings about future Kotlin Gradle compatibility
  remain; the current build passes.

Tests use explicitly named test doubles; production code uses real Firebase and
Google services. Interactive Google account selection and live Firestore profile
creation have not been performed with a real student account during this task.

## Manual end-to-end test

1. Complete the Console checks and publish the reviewed rules above.
2. Run on an Android device/emulator with Google Play services and internet.
3. Cancel the Google picker; verify cancellation and a working retry button.
4. Sign in. A new account should reach Student Profile and show its Google email.
5. Submit blank/invalid fields; verify field errors. Fill valid student details,
   save once, then verify Home and `users/{uid}` with user/active and timestamps.
6. Close/reopen the app. Verify the persisted session goes to Home and retains
   the saved student information.
7. Edit profile. Verify permitted fields/updatedAt change while createdAt, role,
   status, email and photo stay unchanged.
8. With trusted Console access, change accountStatus to suspended. Verify Home
   redirects to Account Status. Restore active and verify Home becomes available.
9. Disconnect during initial profile lookup; verify error/retry and sign-out.
   Reconnect and retry. Writes use online transactions so offline saves cannot
   report a false success.
10. Sign out and restart; verify Google Sign-In and blocked protected routes.

Privileged live-data writes are intentionally manual. Revocations require server
connectivity to reach an existing listener; no client can guarantee immediate
status changes while offline. Future data modules must enforce their own trusted
eligibility/authorization checks in Firestore rules; this module denies all such
collections. Android is the supported sign-in target; web/native desktop Google
Sign-In flows were not implemented.


## Google Sign-In configuration diagnosis

The configuration error was traced to a duplicate **android/app/src/google-services.json**.
Gradle's processDebugGoogleServices task explicitly selected that file instead
of android/app/google-services.json. The duplicate had the correct Firebase
project/app identity but an empty OAuth client list. It therefore generated no
`default_web_client_id`, even though the canonical app-level file contained the
required type-3 web OAuth client. The obsolete duplicate was removed. Keep one
canonical file unless deliberately configuring build variants.

The installed Android plugin maps a missing server client ID to
`GoogleSignInExceptionCode.clientConfigurationError` with description
`serverClientId must be provided on Android`. The friendly screen message maps
both clientConfigurationError and providerConfigurationError; it is not the
fallback message for arbitrary exceptions. Prior raw exceptions were not logged,
so that original exception description is inferred from the verified missing
resource and plugin implementation, rather than a preserved device log.

The 7.2.0 API usage is correct. On Android the plugin reads the web OAuth client
from the generated native resource, so no hardcoded serverClientId is necessary.
The Android app ID matches the JSON and the local debug certificate SHA-1 matches
the Android OAuth entry. Firebase initialization remains unchanged and precedes
all authentication services.

The auth service now logs the operation stage, original Google code/description
or Firebase code/message, and stack trace in debug mode before repository error
mapping. Initialization errors are inside the same diagnostic path. Credential
objects, ID tokens and opaque exception details are not logged. Google sign-out
errors also retain their original stack trace.

After changing google-services.json, stop the app and run a full native rebuild
(`flutter run -d emulator-5554`); hot reload/restart cannot update native resources.
Verify build/app/generated/res/processDebugGoogleServices/values/values.xml
contains default_web_client_id. If resources remain stale, run flutter clean,
flutter pub get, then flutter run again.

If a configuration error remains after rebuilding, check the exact new debug
log first. In Firebase Console ? orglink-dev ? Authentication ? Sign-in method,
enable Google and select a support email. In Project settings ? General ? Android
app com.example.orglink, verify these local debug signing fingerprints:

- SHA-1: 65:03:3E:94:80:AC:60:70:43:93:7D:30:C4:4B:6F:BD:B3:B9:A2:9F
- SHA-256: E9:D5:DD:4E:9E:28:E6:88:02:0E:5F:29:53:A1:96:83:08:16:13:3C:7F:4F:1B:51:09:CF:A7:BF:AF:3D:D5:BD

If different signing keys are used, obtain their fingerprints with signingReport.
Download updated configuration only from the same Firebase Android app, place it
at android/app/google-services.json, and rebuild. In the same project's Google
Cloud Console ? APIs & Services ? Credentials, verify the Android OAuth client
uses that package/SHA-1 and the web OAuth client matches the type-3 JSON entry.
If the OAuth consent setup is restricted to test users, add the intended test
accounts. No Console configuration changes were made or assumed completed.

Debugging validation: Flutter analysis passed and all 24 Flutter tests passed,
including original Google/Firebase diagnostic logging, initialization failures,
error mapping and token/detail omission. Real account selection still requires
a manual sign-in attempt.

## Module 4: Attendance

Manual attendance, attendance reports, personal history and the global QR Hub are
implemented. Secure QR check-in uses callable Functions that require a separate
manual deployment. See [Module 4 setup, security and testing](docs/module4.md).
No billing changes or Firebase deployments are performed by the application.
