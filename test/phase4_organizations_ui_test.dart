import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/presentation/widgets/organization_widgets.dart';
import 'package:orglink/core/widgets/app_feedback.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class OrganizationApp {
  final accounts = TestAuthRepository(), profiles = TestProfileRepository();
  final orgs = TestOrganizationRepository(), events = TestEventRepository();
  late final auth = AuthViewModel(accounts, profiles);
  late final router = createAppRouter(auth);
  final capture = GlobalKey();
  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        Provider<GoRouter>.value(value: router),
        Provider<OrganizationRepository>.value(value: orgs),
        Provider<EventRepository>.value(value: events),
      ],
      child: RepaintBoundary(key: capture, child: const OrgLinkApp()),
    ),
  );
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    auth.dispose();
    await accounts.controller.close();
    await profiles.controller.close();
    await orgs.close();
    await events.close();
  }

  Future<void> screenshot(WidgetTester tester, String name) => tester.runAsync(
    () async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-phase4/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    },
  );
}

const longName = "IEEE / iOS Builders of de la Cruz and McDonald University";
const applicant = "Alexandria-McDonald de la Cruz O'Neil";
Organization organization({
  String? logo,
  String id = 'robotics',
  String name = longName,
}) => Organization(
  id: id,
  name: name,
  description: 'Build skills. Share ideas. Find your people.',
  visibility: 'public',
  status: 'active',
  managerUid: 'manager',
  logoURL: logo,
  mission:
      'Empower students through technology, collaboration, and practical learning.',
  vision: 'A campus where everyone can build with confidence.',
  goals: [
    'Share skills.',
    'Build useful projects.',
    'Grow an inclusive community.',
  ],
  approvalSettings: {'acceptsRequests': true},
);
const pendingMember = Membership(
  uid: 'applicant',
  organizationId: 'robotics',
  role: 'member',
  status: 'pending',
  applicantName: applicant,
  positionTitle: 'Research and Development Representative',
);
const activeMember = Membership(
  uid: 'student',
  organizationId: 'robotics',
  role: 'officer',
  status: 'active',
  applicantName: applicant,
  permissions: {'viewRoster': true},
);

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'organization screens at ${width}dp and ${scale}x with long names and safe areas',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = OrganizationApp();
          addTearDown(() => app.close(tester));
          app.orgs.organizations.emit([
            organization(),
            organization(id: 'creative', name: 'Discover: $longName'),
          ]);
          app.orgs.document.emit(organization());
          app.orgs.allMemberships.emit([activeMember, pendingMember]);
          await app.mount(tester);
          app.accounts.controller.add(student);
          await tester.pump();
          app.profiles.controller.add(profile());
          await tester.pumpAndSettle();
          for (final route in [
            ('discovery', AppRoutes.organizations),
            ('memberships', AppRoutes.myOrganizations),
            ('requests', AppRoutes.membershipRequests),
            ('details', AppRoutes.organization('robotics')),
            ('roster', AppRoutes.memberRoster('robotics')),
          ]) {
            app.router.go(route.$2);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: route.$1);
            expect(
              find.text(
                route.$1 == 'discovery' ? 'Discover: $longName' : longName,
              ),
              findsWidgets,
              reason: route.$1,
            );
            if (scale == 1 || width == 320) {
              await app.screenshot(
                tester,
                '${route.$1}-${width.toInt()}-${scale.toInt()}x',
              );
            }
            final scrollables = find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            );
            if (scrollables.evaluate().isNotEmpty) {
              await tester.drag(scrollables.first, const Offset(0, -1600));
              await tester.pumpAndSettle();
              expect(
                tester.takeException(),
                isNull,
                reason: '${route.$1} scrolled',
              );
            }
          }
          // Keep the real discovery search usable above the keyboard.
          app.router.go(AppRoutes.organizations);
          await tester.pumpAndSettle();
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.enterText(find.byType(TextField), 'not present');
          await tester.pumpAndSettle();
          expect(find.text('No Organizations Found'), findsOneWidget);
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          app.accounts.controller.add(const AuthUser(id: 'manager'));
          await tester.pump();
          app.profiles.controller.add(profile());
          await tester.pumpAndSettle();
          app.router.go(AppRoutes.manageMembers('robotics'));
          await tester.pumpAndSettle();
          expect(find.text(applicant), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1 || width == 320) {
            await app.screenshot(
              tester,
              'approval-queue-${width.toInt()}-${scale.toInt()}x',
            );
          }
          await tester.ensureVisible(find.text('Approve'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Approve'));
          await tester.pumpAndSettle();
          expect(find.text('Approve Membership Request?'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (scale == 1 || width == 320) {
            await app.screenshot(
              tester,
              'approval-confirmation-${width.toInt()}-${scale.toInt()}x',
            );
          }
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(app.orgs.reviewCalls, 0);
        },
      );
    }
  }
  testWidgets(
    'rejection cancellation, failed save, retry, and self-review guards survive presentation',
    (tester) async {
      final app = OrganizationApp();
      addTearDown(() => app.close(tester));
      app.orgs.allMemberships.emit([
        pendingMember,
        const Membership(
          uid: 'manager',
          organizationId: 'robotics',
          role: 'member',
          status: 'pending',
          applicantName: 'Manager Request',
        ),
      ]);
      await app.mount(tester);
      app.accounts.controller.add(const AuthUser(id: 'manager'));
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.manageMembers('robotics'));
      await tester.pumpAndSettle();
      expect(find.text('You cannot review your own request.'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.orgs.reviewCalls, 0);
      app.orgs.reviewError = const AppFailure('Review failed. Try again.');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reject'),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.orgs.allMemberships.value.first.status, 'pending');
      expect(find.text('Review failed. Try again.'), findsWidgets);
      app.orgs.reviewError = null;
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Reject'),
        ),
      );
      await tester.pumpAndSettle();
      expect(app.orgs.allMemberships.value.last.status, 'rejected');
      expect(app.orgs.reviewCalls, 2);
    },
  );
  testWidgets(
    'discovery errors retry, empty data, unavailable details, and missing logos',
    (tester) async {
      final app = OrganizationApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.organizations);
      await tester.pumpAndSettle();
      app.orgs.organizations.fail(
        const AppFailure('Organization connection failed.'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppErrorView), findsOneWidget);
      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.byType(OrganizationCard), findsWidgets);
      app.orgs.organizations.emit([]);
      await tester.pumpAndSettle();
      expect(find.text('No Organizations Found'), findsOneWidget);
      app.orgs.document.emit(null);
      app.router.go(AppRoutes.organization('robotics'));
      await tester.pumpAndSettle();
      expect(find.text('Organization not found.'), findsOneWidget);
      // HttpClient returns 400 in widget tests: exercise the real image errorBuilder.
      app.orgs.document.emit(
        organization(logo: 'https://example.invalid/missing-logo.png'),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'direct membership pages use safe Back without a pushed navigator entry',
    (tester) async {
      final app = OrganizationApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      for (final path in [
        AppRoutes.myOrganizations,
        AppRoutes.membershipRequests,
      ]) {
        app.router.go(path);
        await tester.pumpAndSettle();
        expect(app.router.canPop(), isFalse);
        final back = find.byTooltip('Back');
        expect(tester.getSize(back).shortestSide, greaterThanOrEqualTo(48));
        expect(
          tester
              .widget<Icon>(
                find.descendant(
                  of: back,
                  matching: find.byIcon(Icons.arrow_back),
                ),
              )
              .color,
          Colors.white,
        );
        await tester.tap(back);
        await tester.pumpAndSettle();
        expect(
          app.router.routeInformationProvider.value.uri.path,
          AppRoutes.home,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
