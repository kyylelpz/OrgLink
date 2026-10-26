
# OrgLink — Codex Development Instructions

## Project
OrgLink is a Flutter Android application for student organization management using Firebase.

## Deadline
3 days. Prioritize a functional, demonstrable MVP.

## Technology
- Flutter and Dart
- Firebase Authentication (Google Sign-In)
- Cloud Firestore
- Provider + ChangeNotifier
- go_router
- Material 3

## Architecture
Use feature-based organization with:
- View
- ViewModel
- Repository
- Service
- Model

Inspect the existing directory structure before adding files.
Do not create duplicate implementations.

## Rules
1. Preserve the existing working Firebase configuration.
2. Use only the configured development Firebase project.
3. Reuse existing widgets, services, and models.
4. Follow the project specification PDF.
5. Implement real functionality for required MVP workflows.
6. Never hardcode privileged user roles.
7. Enforce authorization through Firestore Security Rules or trusted backend logic.
8. Never place service-account credentials in the Flutter app.
9. Use mock data only when explicitly identified as mock.
10. Avoid unnecessary packages and architectural changes.

## Implementation
- Make focused changes.
- Include loading, empty, success, and error states.
- Handle null values and Firebase exceptions.
- Avoid placeholder functionality disguised as complete.
- Keep UI responsive on Android phones.

## Validation
After each implementation:
- dart format .
- flutter analyze
- flutter test

Fix errors introduced by the task.

## Completion Report
Summarize:
- Implemented functionality
- Modified files
- Tests and validation results
- Required manual actions
- Remaining limitations

## UI Text and Capitalization Conventions

Apply these conventions to every future module, feature, screen and UI change.
Preserve all architectural, security and validation requirements above.

### User Interface
- Use Title Case for screen/AppBar titles, navigation labels, section headings,
  buttons, short actions and form field labels (for example, Save Draft and
  Student Number). Keep short connecting words consistent with existing labels.
- Use sentence case for descriptions, instructions, placeholders, validation
  messages, notifications and confirmation-message bodies.
- Use Title Case for confirmation-dialog titles and their action buttons.
- Display statuses and roles with human-readable labels. Prefer the centralized
  mappings in lib/core/utils/display_labels.dart; use displayMembershipStatus
  when preserving the membership approval context.
- Never feed a display label back into filters, comparisons, permissions or saves.

### User-Entered Content
- Prefer readable student names, organization names and event titles, while
  preserving intentional casing, acronyms, abbreviations and proper names such
  as McDonald, de la Cruz, O'Neil, Dela Peña, IEEE, ACM, NASA and iOS.
- Preserve existing stored values and their displayed spelling/capitalization.
  Do not automatically normalize names/titles during editing or saving.
- For all-lowercase input, reuse capitalizationSuggestion and the optional
  CapitalizationSuggestion preview widget where a relevant input form exists.
  Apply a suggestion only after an explicit user action; keep the result editable.
  Suggestions are not authoritative spelling or acronym detection.
- If correct casing is uncertain, retain the original. Mixed/uppercase input
  should not be guessed at. Never Title Case free-form paragraphs, descriptions,
  announcements or other prose.
- Organization names currently come from administrative provisioning; display
  them verbatim. A future organization editor should follow the same opt-in
  suggestion convention, without modifying existing records automatically.

### Data Integrity
- Never change Firestore collection/field names, document IDs, Firebase UIDs,
  stored statuses/roles, permission keys, route names/paths, query filters,
  Security Rules comparisons, repository contracts or serialization keys solely
  for capitalization. Do not migrate or overwrite existing database records.
- Keep formatting in the presentation layer, using shared helpers rather than
  duplicated string transformations. Do not change authorization/business logic.
- A capitalization refactor requires no Firebase configuration changes or deploy.

### Development Requirements
- Maintain consistency across existing and new screens without unrelated
  refactoring or a UI redesign. Add no dependencies solely for casing.
- Update affected exact-text tests. Cover known display labels, opt-in suggestion
  behavior and preservation of intentional names/titles and original saved values.
- Run formatting, analysis and relevant/full Flutter tests. Verify canonical
  status comparisons and critical workflows remain unchanged.
