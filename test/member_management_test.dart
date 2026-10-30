import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/memberships/presentation/viewmodels/member_list_view_model.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

const member = Membership(
  uid: 'student',
  organizationId: 'robotics',
  role: 'member',
  status: 'active',
  applicantName: 'Alexandria de la Cruz',
);
void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'manager role, permissions, filters, details and termination at ${scale}x',
      (tester) async {
        tester.view.physicalSize = const Size(320, 852);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final accounts = TestAuthRepository(),
            profiles = TestProfileRepository(),
            repo = TestOrganizationRepository(),
            events = TestEventRepository();
        repo.allMemberships.emit([member]);
        final auth = AuthViewModel(accounts, profiles);
        final appRouter = createAppRouter(auth);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          appRouter.dispose();
          auth.dispose();
          await accounts.controller.close();
          await profiles.controller.close();
          await repo.close();
          await events.close();
        });
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              Provider<GoRouter>.value(value: appRouter),
              Provider<OrganizationRepository>.value(value: repo),
              Provider<EventRepository>.value(value: events),
            ],
            child: const OrgLinkApp(),
          ),
        );
        accounts.controller.add(const AuthUser(id: 'manager'));
        await tester.pump();
        profiles.controller.add(profile());
        await tester.pumpAndSettle();
        appRouter.go(AppRoutes.memberRoster('robotics'));
        await tester.pumpAndSettle();
        Future<void> tap(Finder finder) async {
          await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
          await tester.pumpAndSettle();
          await tester.tap(finder);
          await tester.pumpAndSettle();
          // Success snackbars can cover the next roster menu on a short page.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        Future<void> action(String label) async {
          await tap(find.byTooltip('Membership Actions'));
          await tap(find.text(label));
        }

        await action('View Details');
        expect(find.text('Member Details'), findsOneWidget);
        await tap(find.text('Close'));
        await action('Assign/Change Role');
        await tap(find.byType(DropdownButtonFormField<String>).first);
        await tap(find.text('Officer').last);
        expect(find.text('Officer Position'), findsOneWidget);
        await tap(find.text('Save Changes'));
        expect(repo.allMemberships.value.single.role, 'officer');
        await action('Assign/Change Role');
        await tap(find.byType(DropdownButtonFormField<String>).last);
        await tap(find.text('Treasurer').last);
        await tap(find.text('Save Changes'));
        expect(repo.allMemberships.value.single.positionTitle, 'Treasurer');
        await action('Manage Permissions');
        await tap(find.widgetWithText(CheckboxListTile, 'Manage Events'));
        await tap(find.widgetWithText(CheckboxListTile, 'Manage Attendance'));
        await tap(find.text('Save Changes'));
        expect(
          repo.allMemberships.value.single.permissions['manageAttendance'],
          true,
        );
        await tap(find.widgetWithText(FilterChip, 'Officers'));
        expect(find.text(member.applicantName), findsOneWidget);
        await action('End Membership');
        await tester.enterText(find.byType(TextFormField), 'Completed service');
        await tap(find.text('Cancel'));
        expect(repo.allMemberships.value.single.status, 'active');
        await action('End Membership');
        await tester.enterText(find.byType(TextFormField), 'Completed service');
        await tap(find.widgetWithText(FilledButton, 'End Membership'));
        expect(repo.allMemberships.value.single.status, 'removed');
        expect(repo.allMemberships.value.single.permissions, isEmpty);
        await tap(find.widgetWithText(FilterChip, 'Former Members'));
        expect(find.text(member.applicantName), findsOneWidget);
        await action('View Details');
        expect(find.text('Reason: Completed service'), findsOneWidget);
        await tap(find.text('Close'));
        await tester.enterText(find.byType(TextField), 'not found');
        await tester.pumpAndSettle();
        expect(find.text(member.applicantName), findsNothing);
        await tester.enterText(find.byType(TextField), 'Alexandria');
        await tester.pumpAndSettle();
        expect(find.text(member.applicantName), findsOneWidget);
      },
    );
  }
  test(
    'roster model limits views/actions and retains stable commands on failure',
    () async {
      final repo = TestOrganizationRepository();
      repo.allMemberships.emit([member]);
      final reader = MemberListViewModel(
        repo,
        'robotics',
        'reader',
        pending: false,
      );
      final manager = MemberListViewModel(
        repo,
        'robotics',
        'manager',
        pending: false,
        manager: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(reader.canManage(member), false);
      reader.filter(view: 'Former Members');
      expect(reader.view, 'Active');
      expect(await reader.preview(member), isNull);
      expect(
        manager.canManage(
          const Membership(
            uid: 'manager',
            organizationId: 'robotics',
            role: 'member',
            status: 'active',
          ),
        ),
        false,
      );
      expect(
        manager.canManage(
          const Membership(
            uid: 'other',
            organizationId: 'robotics',
            role: 'manager',
            status: 'active',
          ),
        ),
        false,
      );
      final preview = await manager.preview(member);
      final command = {
        'operation': 'end',
        'version': preview!['version'],
        'requestId': MemberListViewModel.requestId(),
        'reason': '',
      };
      repo.managementError = const AppFailure('Try again.');
      expect(await manager.manage(member, command), false);
      expect(manager.failure?.message, 'Try again.');
      repo.managementError = null;
      expect(await manager.manage(member, command), true);
      await Future<void>.delayed(Duration.zero);
      manager.filter(view: 'Former Members');
      expect(manager.visibleMembers.single.status, 'removed');
      reader.dispose();
      manager.dispose();
      await repo.close();
    },
  );
}
