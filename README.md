# OrgLink

Platform Administration MVP is implemented locally: protected dashboard, account
decisions and organization/manager management through the existing Worker. See
[Platform Administration](docs/platform-admin.md) for explicit operator-only
bootstrap, manual deployment and acceptance. No administrator was provisioned.

Module 3 event management and registration is implemented. See
[the Module 3 guide](docs/module3.md) for the selected approval policy, atomic
registration rules, routes, indexes, deployment and testing instructions.

Module 2 organization discovery and membership is implemented. See
[the Module 2 guide](docs/module2.md) for schemas, routes, security rules,
manager provisioning, deployment steps and validation.

Flutter Android student organization application. Development, testing and the
final demonstration use the existing Firebase project **orglink-dev**.

## Authentication and student onboarding

Module 1 now supports Firebase email/password and existing Google Sign-In.
See [Module 1](docs/module1.md) for registration, verification, password reset,
explicit password linking, controlled academic dropdowns, security boundaries,
validation evidence and required manual Firebase setup.

New profiles are **user / pending**. Email verification does not approve an
account. Existing account UIDs, roles, statuses and memberships are preserved.
The app uses only the configured **orglink-dev** project. No Console settings
or deployed infrastructure were changed by this implementation.

The current implemented UI is documented in
[the UI/UX baseline](docs/ui-ux-design.md). Historical migration plans do not
override it. Passwords are handled exclusively by Firebase Authentication.

## Images and Cloudinary

Profile photos, organization logos, and event posters use the existing trusted
Cloudflare Worker for upload authorization, Cloudinary signing, asset verification,
and Firestore reference updates. Profile photos and logos support a live square
preview with drag, pinch-to-zoom, Cancel, Reset, Confirm, and Keep Original.
Managers and Platform Admins share the logo editor. Create Event and Edit Draft
posters reuse the interactive cropper with a responsive landscape frame matching
the existing Event Details slot, plus a live Home center-trim preview and Keep Original. Create Event
places Event Poster above Event Details in the same card, with a separate
normal-weight (Optional) supporting label. It can select/preview a poster locally; Save Draft creates the event first and then
automatically uploads/finalizes its poster. Failed uploads retain the saved draft
and offer Retry Upload without creating another event.

Uploads retain gallery resizing/compression and the 5 MiB limit. New uploads use
signed dynamic Media Library asset folders: `orglink/profiles`,
`orglink/organizations`, and `orglink/events`. Public IDs and existing references
are preserved; no manual dashboard folder creation or migration is needed.

See [Cloudinary setup and image workflows](docs/cloudinary-setup.md) for exact
Worker bindings, endpoints, permissions, cleanup, tests, troubleshooting, and
manual deployment/Android acceptance. Changes are implemented and tested locally;
no deployment or live Firestore changes were performed for these updates.

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
implemented. Secure QR check-in uses Cloudflare Workers Free with Firebase ID-token
authentication and atomic Firestore REST transactions; deployment and server-secret
setup are manual, with no billing account required. See [Module 4 setup, security and testing](docs/module4.md).
No billing changes or Firebase deployments are performed by the application.
