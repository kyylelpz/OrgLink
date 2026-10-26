
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

Follow consistent capitalization throughout OrgLink.

### User Interface
- Use Title Case for screen titles, navigation labels, section headings, buttons, and short action labels.
- Use sentence case for descriptions, instructions, placeholders, validation messages, and notifications.
- Display statuses and roles in a readable format (e.g., `registered` → `Registered`, `organization manager` → `Organization Manager`).
- Maintain consistent capitalization across existing and newly implemented screens.

### User-Entered Content
- Use consistent, readable capitalization for student names, organization names, and event titles.
- Preserve intentional capitalization, acronyms, abbreviations, and proper names (e.g., `NASA`, `IEEE`, `McDonald`, `iOS`).
- Do not automatically overwrite existing user-entered values or apply destructive capitalization transformations.
- Prefer editable formatting suggestions or previews when normalizing new input.

### Data Integrity
- Never change Firestore field names, collection names, document IDs, status values, role identifiers, permission keys, or route paths solely for capitalization.
- Apply display formatting at the presentation layer without affecting stored values, queries, authorization, or business logic.
- Reuse shared formatting utilities rather than implementing duplicate capitalization logic.

### Development Requirements
- Apply these conventions to all future features and UI modifications.
- Maintain consistency with existing screens when implementing new modules.
- Update affected tests when changing user-facing text.
- Avoid unrelated code or database refactoring.