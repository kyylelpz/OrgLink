# Figma Migration — Phase 3

Completed 28 October 2026. Authentication and Profile only; Phase 4 not started.
The user's removal of Home's Your Activity section remains intact. Sign-out and
participation/community links are available in the authenticated Profile view.

## Visual references and implementation

Inspected live Figma design context and screenshots for Splash 15:3451,
Onboarding 15:3462, Google Sign-In 15:3490, completion 15:3515 and Profile 15:4416
in [OrgLink Wireframes](https://www.figma.com/design/9IIlHz8p1lc4aBAfep5UqH/OrgLink-Wireframes).

- Splash uses the official white-on-midnight artwork, tagline, genuine
  indeterminate loading, and existing retry/sign-out error paths.
- Onboarding/Google entry use Inter, Phase 1 tokens, official brand imagery,
  the Figma orbit decoration, readable marketing cards and working existing CTAs.
  Google sign-in cancellation, loading, failures and duplicate-submit protection
  remain in AuthViewModel; no email/password flow was added.
- Account Status uses shared feedback/surface styling and retains the existing
  pending/suspended/disabled messages, refresh, permitted profile edit and sign-out.
- The existing `/complete-profile` destination now shows an overview for eligible
  users and a completion form otherwise. An internal Edit action opens the form;
  no route or redirect changes were needed. Editing seeds the latest known values.
- Overview displays actual identity, Google email and optional academics, with
  functional links to existing communities, events and attendance. No fabricated
  statistics, badges, settings or administrative actions are shown.
- Profile completion keeps Full Name as a single stored value. College/Program
  are validated free text because no authoritative options exist. The Save action
  is fixed above keyboard insets. Cancel returns to the overview, or Account Status
  for an ineligible account. Existing save-to-Home/success feedback is retained.

## Data contract and compatibility

`users/{uid}` remains a flat document with two optional additional string keys:
`college` and `program`. Null DTO values mean "not supplied" and are omitted from
serialization, preserving existing stored values when older callers update other
fields. Explicit empty strings can clear an optional field after user editing.
Nonempty form values use 2–160 characters; casing is preserved. Capitalization
suggestions are opt-in and do not rewrite stored spelling automatically.

`StudentDetails.fromMap` reads old documents with missing academic keys as null.
Required identity checks are separated from optional-field save validation so
the existing account-completion/eligibility requirements stay unchanged. The
service retains server-confirmed snapshot handling and transactional partial
updates; UID/email, roles, account status, photo, timestamps and other stored
fields are not replaced by profile edits. Repository save validation automatically
uses the extended typed contract; no new repository or backend endpoint exists.

## Firestore rules

The user create/update whitelists now permit the two optional keys. String length,
nonblank values and multiline input are validated; missing or empty strings are
accepted. All previous required fields, owner checks, privileged-field
restrictions, timestamps and `eligible()` behavior remain unchanged. The rules
are changed **locally only**. Deploying these reviewed rules to the configured
development project is a separate required action before live academic-field
saves are enabled; no deployment or document migration was performed here.

## Changed files

- `lib/features/profile/data/models/student_profile.dart`
- `lib/features/profile/data/services/user_profile_service.dart`
- `lib/features/profile/presentation/screens/complete_profile_screen.dart`
- New `lib/features/profile/presentation/widgets/profile_overview.dart`
- `lib/features/auth/presentation/screens/auth_screens.dart`
- New `lib/features/auth/presentation/widgets/auth_branding.dart`
- `lib/features/home/presentation/screens/home_screen.dart`: only removed an import
  made unused by the user's activity-section removal; the user's subsequent
  Google-avatar hookup was preserved.
- `lib/core/widgets/community_components.dart`: corrected the import for the
  user's new ProfileIdentity header usage and formatted that shared file.
- `firebase/firebase.rules`, `firebase/tests/profile.rules.test.mjs`
- Tests: student_profile, widget, phase2_navigation, organization_workflow,
  event_workflow; new profile_repository and phase3_profile_ui tests.
- New `assets/illustrations/auth_orbit.svg` and PNG, plus this record.

The orbit SVG comes from Figma's Link orbit asset (15:3500), rasterized at 4x with
the bundled Sharp runtime. Existing asset-folder registration covers it. No
application dependency, Firebase configuration, Worker, auth service, navigation
path, permission system or other infrastructure changed. Unrelated existing
asset edits were left untouched.

## Validation and limitations

- Modified Dart files formatted; Flutter analysis: no issues.
- Full Flutter suite: **150 passed**. Model/repository tests cover old documents,
  omitted-value patch preservation, validation and intentional spelling. UI tests
  cover academic values surviving failure/retry and successful saves.
  Following the concurrent header-avatar edit/import correction, final analysis
  was clean and all **32** focused Home/navigation/Profile UI tests passed again.
- All Firestore emulator suites: **140 passed**, including new-field acceptance,
  invalid values, legacy edits, protected fields, membership/events/attendance.
  Only local emulators used `orglink-dev`; an alternate local port/config under
  ignored build/ avoided an occupied default emulator port.
- Renders compared at 320/360/393/412dp, with additional 200% text, long-name,
  keyboard/system-inset, semantic-label and touch-target checks. Previews are in
  ignored `build/ui-phase3/`.
- Official logos replace Figma's recreated marks. Native form controls, a single
  Full Name field, optional academic text inputs and content-driven heights adapt
  the design to the existing contract and accessibility. At large text sizes the
  identity block stacks vertically.
- No inactive onboarding pager, unsupported settings, statistics or legal-consent
  interaction is presented. Google entry keeps a meaningful native sign-in icon
  rather than Figma's close-circle placeholder.
- Android hardware/TalkBack and live Google sign-in acceptance remain manual.
  No production statistics, mock backend features, schema migration or deployment
  was introduced.
