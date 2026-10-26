import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_organization_repository.dart';
import 'support/test_event_repository.dart';

void main() {
  testWidgets(
    'manager creates, submits, approves, publishes; student confirms registration and withdrawal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final authRepository = TestAuthRepository(),
          profiles = TestProfileRepository();
      final auth = AuthViewModel(authRepository, profiles);
      final router = createAppRouter(auth),
          orgs = TestOrganizationRepository(),
          events = TestEventRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<GoRouter>.value(value: router),
            Provider<OrganizationRepository>.value(value: orgs),
            Provider<EventRepository>.value(value: events),
          ],
          child: const OrgLinkApp(),
        ),
      );
      authRepository.controller.add(const AuthUser(id: 'manager'));
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.createEvent('robotics'));
      await tester.pumpAndSettle();
      expect(find.text('Create Event'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'annual general assembly');
      await tester.pump();
      expect(
        find.text('Suggested capitalization: Annual General Assembly'),
        findsOneWidget,
      );
      await tester.enterText(
        fields.at(1),
        'A complete synthetic demonstration event.',
      );
      await tester.enterText(fields.at(2), 'Demo Hall');
      await tester.enterText(fields.at(3), '2');
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(events.creates, 1);
      expect(events.event.value?.title, 'annual general assembly');
      expect(find.text('annual general assembly'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      Future<void> action(String label) async {
        await tester.scrollUntilVisible(
          find.text(label),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text(label)),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 5));
      }

      await action('Submit for Approval');
      await action('Approve Event');
      await action('Publish Event');
      expect(events.actions, ['submit', 'approve', 'publish']);
      authRepository.controller.add(student);
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.events);
      await tester.pumpAndSettle();
      expect(find.text('annual general assembly'), findsOneWidget);
      await tester.tap(find.text('annual general assembly'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Register'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Registration Confirmation'), findsOneWidget);
      await tester.ensureVisible(find.text('Confirm Registration'));
      await tester.tap(find.text('Confirm Registration'));
      await tester.pumpAndSettle();
      expect(events.registrations.value.single.status, 'registered');
      await tester.pump(const Duration(seconds: 5));
      router.go(AppRoutes.myEvents);
      await tester.pumpAndSettle();
      expect(find.textContaining('Registration: Registered'), findsOneWidget);
      await tester.tap(find.text('annual general assembly'));
      await tester.pumpAndSettle();
      await action('Withdraw Registration');
      expect(events.registrations.value.single.status, 'cancelled');
      expect(events.event.value?.registrationCount, 0);
      router.go(AppRoutes.participants('robotics', 'demo'));
      await tester.pumpAndSettle();
      expect(
        find.text('You do not have permission to view participants.'),
        findsOneWidget,
      );
      authRepository.controller.add(const AuthUser(id: 'manager'));
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.participants('robotics', 'demo'));
      await tester.pumpAndSettle();
      expect(
        find.text(profile().details.fullName),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join(' | '),
      );
      authRepository.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Google Sign-In'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await events.close();
      await orgs.close();
      await authRepository.controller.close();
      await profiles.controller.close();
    },
  );
}
