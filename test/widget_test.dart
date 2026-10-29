import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'support/test_event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_organization_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:provider/provider.dart';
import 'support/test_auth_repository.dart';

void main() {
  testWidgets(
    'Google sign-in, validation, profile saving, status changes and sign-out',
    (tester) async {
      final repository = TestAuthRepository();
      final profiles = TestProfileRepository();
      final organizations = TestOrganizationRepository(),
          events = TestEventRepository();
      final auth = AuthViewModel(repository, profiles);
      final router = createAppRouter(auth);
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
      expect(find.bySemanticsLabel('Loading OrgLink...'), findsOneWidget);
      repository.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
      repository.cancelSignIn = true;
      await tester.ensureVisible(find.text('Continue With Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue With Google'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sign-in cancelled'), findsOneWidget);
      repository.cancelSignIn = false;
      await tester.ensureVisible(find.text('Continue With Google'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue With Google'));
      await tester.pump();
      profiles.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Student Profile'), findsOneWidget);
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Enter exactly 10 numeric digits (e.g. 2026000001).'), findsOneWidget);
      expect(find.text('Select a year level.'), findsOneWidget);
      expect(find.text('Select a college.'), findsOneWidget);
      expect(find.text('Select a program.'), findsOneWidget);
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.at(0)).initialValue,
        student.email,
      );
      await tester.enterText(fields.at(2), '2026000001');
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
      await tester.tap(find.byKey(const ValueKey('program-field')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Bachelor of Science in Computer Engineering').last,
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
      expect(profiles.saveCalls, 1);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Student Profile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller
            ?.text,
        '2026000001',
      );
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      profiles.controller.add(profile(status: 'suspended'));
      await tester.pumpAndSettle();
      expect(find.text('Account Status'), findsOneWidget);
      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsNothing);
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
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
