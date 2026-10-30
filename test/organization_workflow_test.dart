import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'support/test_event_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_organization_repository.dart';

void main() {
  testWidgets('persisted pending request can retry cancellation and reapply', (
    tester,
  ) async {
    final accounts = TestAuthRepository(), profiles = TestProfileRepository();
    final organizations = TestOrganizationRepository(),
        events = TestEventRepository();
    await organizations.requestMembership('robotics', 'student');
    final auth = AuthViewModel(accounts, profiles);
    final appRouter = createAppRouter(auth);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.dispose();
      auth.dispose();
      await organizations.close();
      await events.close();
      await accounts.controller.close();
      await profiles.controller.close();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<GoRouter>.value(value: appRouter),
          Provider<EventRepository>.value(value: events),
          Provider<OrganizationRepository>.value(value: organizations),
        ],
        child: const OrgLinkApp(),
      ),
    );
    accounts.controller.add(student);
    await tester.pump();
    profiles.controller.add(profile());
    await tester.pumpAndSettle();
    appRouter.go(AppRoutes.organization('robotics'));
    await tester.pumpAndSettle();
    expect(find.text('Membership: Pending'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.text('Cancel Request')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    organizations.cancelError = const AppFailure(
      'Cancellation failed. Try again.',
    );
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();
    expect(find.text('Cancellation failed. Try again.'), findsOneWidget);
    expect(find.text('Membership: Pending'), findsOneWidget);
    organizations.cancelError = null;
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();
    expect(organizations.cancelCalls, 2);
    expect(organizations.allMemberships.value, isEmpty);
    expect(find.text('Membership request cancelled.'), findsOneWidget);
    expect(find.text('Cancel Request'), findsNothing);
    await Scrollable.ensureVisible(
      tester.element(find.text('Request to Join')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request to Join'));
    await tester.pumpAndSettle();
    expect(organizations.requestCalls, 2);
    expect(find.text('Membership: Pending'), findsOneWidget);
    expect(find.text('Cancel Request'), findsOneWidget);
  });
  testWidgets(
    'student joins, assigned manager confirms approval, student sees active membership',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final authRepository = TestAuthRepository(),
          profileRepository = TestProfileRepository();
      final auth = AuthViewModel(authRepository, profileRepository);
      final router = createAppRouter(auth);
      final organizations = TestOrganizationRepository();
      final events = TestEventRepository();
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
      authRepository.controller.add(student);
      await tester.pump();
      profileRepository.controller.add(profile());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organizations').last);
      await tester.pumpAndSettle();
      expect(find.text('Find Your People'), findsOneWidget);
      expect(find.text('Demo Robotics'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'does not exist');
      await tester.pumpAndSettle();
      expect(find.text('No Organizations Found'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Robotics');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Robotics'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Request to Join'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      // Typography changes can leave the text visible behind the shell bar.
      await Scrollable.ensureVisible(
        tester.element(find.text('Request to Join')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request to Join'));
      await tester.pumpAndSettle();
      expect(find.text('Membership: Pending'), findsOneWidget);
      expect(organizations.requestCalls, 1);
      await tester.pump(const Duration(seconds: 5));
      router.go(AppRoutes.myOrganizations);
      await tester.pumpAndSettle();
      expect(find.textContaining('Status: Pending'), findsOneWidget);
      authRepository.controller.add(const AuthUser(id: 'manager'));
      await tester.pump();
      profileRepository.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.organization('robotics'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Manage Membership Requests'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Manage Membership Requests')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Membership Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Student'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve Membership Request?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(organizations.reviewCalls, 0);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();
      expect(organizations.reviewCalls, 1);
      expect(find.text('No pending requests.'), findsOneWidget);
      router.go(AppRoutes.memberRoster('robotics'));
      await tester.pumpAndSettle();
      expect(find.text('Role: Member'), findsOneWidget);
      expect(find.text('Approved (Active)'), findsOneWidget);
      authRepository.controller.add(student);
      await tester.pump();
      profileRepository.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.myOrganizations);
      await tester.pumpAndSettle();
      expect(find.textContaining('Status: Approved (Active)'), findsOneWidget);
      router.go(AppRoutes.manageMembers('robotics'));
      await tester.pumpAndSettle();
      expect(
        find.text('You do not have permission to access this page.'),
        findsOneWidget,
      );
      authRepository.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await organizations.close();
      await events.close();
      await authRepository.controller.close();
      await profileRepository.controller.close();
    },
  );
}
