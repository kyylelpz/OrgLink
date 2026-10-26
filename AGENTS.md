
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
