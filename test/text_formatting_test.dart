import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'support/test_event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/utils/display_labels.dart';
import 'package:orglink/core/widgets/capitalization_suggestion.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';
import 'package:orglink/features/organizations/presentation/widgets/organization_widgets.dart';
import 'support/test_auth_repository.dart';

void main() {
  test('canonical status and role labels are centralized and readable', () {
    const expected = {
      'active': 'Active',
      'pending': 'Pending',
      'registered': 'Registered',
      'published': 'Published',
      'cancelled': 'Cancelled',
      'manager': 'Manager',
      'officer': 'Officer',
      'member': 'Member',
      'rejected': 'Rejected',
      'removed': 'Removed',
      'platformAdmin': 'Platform Admin',
      'organization_manager': 'Organization Manager',
      'organization manager': 'Organization Manager',
      'registrationPending': 'Registration Pending',
    };
    for (final entry in expected.entries) {
      expect(displayIdentifier(entry.key), entry.value);
    }
    expect(displayIdentifier(''), 'Unknown');
    expect(displayMembershipStatus('active'), 'Approved (Active)');
  });
  test(
    'optional previews handle lowercase names and titles, including punctuation',
    () {
      expect(capitalizationSuggestion('juan dela cruz'), 'Juan Dela Cruz');
      expect(capitalizationSuggestion('robotics society'), 'Robotics Society');
      expect(
        capitalizationSuggestion('annual general assembly'),
        'Annual General Assembly',
      );
      expect(capitalizationSuggestion("o'neil"), "O'Neil");
      expect(capitalizationSuggestion('dela peña'), 'Dela Peña');
      expect(capitalizationSuggestion('anne-marie'), 'Anne-Marie');
    },
  );
  test(
    'intentional name/title casing and acronyms receive no guessed correction',
    () {
      for (final value in [
        'McDonald',
        'de la Cruz',
        "O'Neil",
        'Dela Peña',
        'IEEE',
        'ACM',
        'NASA',
        'iOS Developers Club',
        'IEEE annual meetup',
        '',
        '123',
      ]) {
        expect(capitalizationSuggestion(value), isNull, reason: value);
      }
    },
  );
  testWidgets(
    'suggestions require explicit action and keep the result editable',
    (tester) async {
      final controller = TextEditingController(text: 'juan dela cruz');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller),
                CapitalizationSuggestion(controller: controller),
              ],
            ),
          ),
        ),
      );
      expect(controller.text, 'juan dela cruz');
      expect(find.text('Use Suggestion'), findsOneWidget);
      await tester.tap(find.text('Use Suggestion'));
      await tester.pump();
      expect(controller.text, 'Juan Dela Cruz');
      await tester.enterText(find.byType(TextField), 'de la Cruz');
      await tester.pump();
      expect(controller.text, 'de la Cruz');
      expect(find.text('Use Suggestion'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
  testWidgets(
    'organization names and prose stay verbatim while identifiers get labels',
    (tester) async {
      const org = Organization(
        id: 'example',
        name: 'iOS Developers Club',
        description: 'this prose keeps its original casing.',
        visibility: 'public',
        status: 'active',
        managerUid: 'manager',
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: OrganizationCard(organization: org)),
        ),
      );
      expect(find.text('iOS Developers Club'), findsOneWidget);
      expect(
        find.textContaining('this prose keeps its original casing.'),
        findsOneWidget,
      );
      expect(find.textContaining('Public | Active'), findsOneWidget);
    },
  );
  testWidgets(
    'profile save preserves lowercase input unless the suggestion is chosen',
    (tester) async {
      final repository = TestAuthRepository(),
          profiles = TestProfileRepository();
      final organizations = TestOrganizationRepository(),
          events = TestEventRepository();
      final auth = AuthViewModel(repository, profiles),
          router = createAppRouter(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<GoRouter>.value(value: router),
            Provider<EventRepository>.value(value: events),
            Provider<OrganizationRepository>.value(value: organizations),
          ],
          child: const OrgLinkApp(),
        ),
      );
      repository.controller.add(student);
      await tester.pump();
      profiles.controller.add(null);
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'juan dela cruz');
      await tester.pump();
      expect(
        find.text('Suggested capitalization: Juan Dela Cruz'),
        findsOneWidget,
      );
      await tester.enterText(fields.at(2), '2026-001');
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 1').last);
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(3), 'A');
      await tester.ensureVisible(find.byKey(const ValueKey('college-field')));
      await tester.tap(find.byKey(const ValueKey('college-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('College of Engineering').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('program-field')));
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Bachelor of Science in Civil Engineering').last,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(profiles.savedDetails?.fullName, 'juan dela cruz');
      expect(find.textContaining('\njuan!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await repository.controller.close();
      await profiles.controller.close();
      await organizations.close();
      await events.close();
    },
  );
}
