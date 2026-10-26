# OrgLink

Student Organization Management Android Application. All development, testing,
and the final demonstration use the existing Firebase project `orglink-dev`.

## Run and validate

```sh
flutter pub get
flutter run -d <android-device-id>
dart format lib test
flutter analyze
flutter test
```

Firebase is initialized once in `main.dart` using the existing
`firebase_options.dart`. The Android application ID remains `com.example.orglink`.
No Firebase configuration files or Android build settings were changed.

## Architecture

Views consume ChangeNotifier ViewModels through Provider. ViewModels depend on
repository interfaces; repository implementations map external service data to
application models. Firebase types stay in the service and repository layers.

```text
lib/
  main.dart
  firebase_options.dart                  # Existing generated configuration
  app/
    app.dart                             # MaterialApp.router
    dependency_injection.dart            # Service/repository/ViewModel/router ownership
    router.dart                          # Routes and session redirect policy
  core/
    constants/app_routes.dart
    errors/app_failure.dart
    services/firestore_service.dart      # Typed references; no automatic reads/writes
    theme/app_theme.dart                 # Material 3
    widgets/
      app_feedback.dart                  # Loading, safe errors and retry
      placeholder_screen.dart
  features/
    auth/
      data/
        models/auth_user.dart
        repositories/
          auth_repository.dart
          firebase_auth_repository.dart
        services/firebase_auth_service.dart
      presentation/
        screens/auth_screens.dart
        viewmodels/auth_view_model.dart
    profile/presentation/screens/complete_profile_screen.dart
    home/presentation/screens/home_screen.dart
    ...                                  # Existing future feature folders, untouched
test/
  auth_view_model_test.dart
  router_test.dart
  widget_test.dart
  support/test_auth_repository.dart
```

The existing dependencies already include Provider, go_router, firebase_core,
firebase_auth, cloud_firestore and google_sign_in. No dependencies were added.
Provider owns and disposes the auth subscription and router. Firebase SDK
instances retain their normal application lifetime.

## Routing and current behavior

| Route | Current behavior |
| --- | --- |
| `/` | Splash while the first auth event is pending; retry UI on stream error |
| `/onboarding` | Welcome screen for signed-out users |
| `/sign-in` | Google Sign-In placeholder; action intentionally disabled |
| `/complete-profile` | Registered placeholder; blocked pending schema and eligibility checks |
| `/account-status` | Signed-in holding screen with real Firebase sign-out |
| `/home` | Registered dashboard placeholder; blocked pending eligibility checks |

Onboarding is shown for each signed-out app launch; completion is not persisted
in this foundation. Protected deep links redirect signed-out users to sign-in.
A restored Firebase session routes to Account Status. Authentication alone does
not establish profile completion, an approved account, or a role, so signed-in
users remain on Account Status until those checks are implemented. There is no
fake authentication or role assignment.

Extend the centralized redirect policy with trusted profile/account state once
the schema is approved. Client routing is a UI concern; eventual data access
must also be enforced by Firestore Security Rules.

## Firebase and next work

No additional Firebase project or manual setup is needed for this foundation.
It does not create collections, documents, or user profiles. The Firestore service
provides converter-based references for future repositories with defined schemas.
Startup failures show a safe message; auth stream failures support resubscription.

Next, define the student profile schema, account lifecycle and authorization
rules. Then implement Google Sign-In against `orglink-dev`, verifying the Google
provider and Android signing fingerprints in Firebase, and build schema-backed
profile and eligibility checks before enabling protected routes. The complete
Google Sign-In flow and organization features are intentionally deferred.

Tests cover session loading, real-state-driven transitions via a test repository,
stream failure/retry, sign-out errors, subscription disposal, protected deep
links, and signed-in access restrictions. They do not require Firebase network
access or modify `orglink-dev`.
## Foundation validation

- `flutter pub get`: passed; existing dependency constraints and lockfile preserved.
- `dart format`: completed for all changed Dart files.
- `flutter analyze`: passed without issues.
- `flutter test`: all 9 tests passed.
- `flutter run -d emulator-5554 --no-resident`: debug APK built, installed and
  launched on the Android 17 emulator.

The Android build emits a warning about existing Firebase plugins applying the
Kotlin Gradle Plugin and future Flutter compatibility. It does not prevent the
current build; dependency and Android configuration upgrades are outside this
foundation change.