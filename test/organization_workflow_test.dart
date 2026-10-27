import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'support/test_event_repository.dart';
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
import 'support/test_auth_repository.dart';
import 'support/test_organization_repository.dart';

void main() {
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
      await tester.ensureVisible(find.text('Discover Organizations'));
      await tester.tap(find.text('Discover Organizations'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Organizations'), findsOneWidget);
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
      expect(
        find.text('Role: Member | Status: Approved (Active)'),
        findsOneWidget,
      );
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
      expect(find.text('Google Sign-In'), findsOneWidget);
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
