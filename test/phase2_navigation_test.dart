import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/core/widgets/authenticated_shell.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/widgets/app_back_button.dart';
import 'package:orglink/features/attendance/data/repositories/attendance_repository.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';
import 'package:orglink/core/widgets/app_asset_icon.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'support/test_attendance_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class _Camera extends MobileScannerPlatform {
  int starts = 0, stops = 0, disposals = 0;
  bool denied = false, failed = false;
  Completer<void>? startGate;
  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text(
        'Camera Preview (Test)',
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    await startGate?.future;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    if (failed) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.genericError,
      );
    }
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
  }

  @override
  Future<void> updateScanWindow(Rect? window) async {}
}

class _Catalog extends TestEventRepository {
  final catalog = TestFeed<List<OrgEvent>>([]);
  final modes = <bool>[];
  @override
  Stream<List<OrgEvent>> organizationEvents(
    String org, {
    required bool management,
    required bool includePrivate,
    String? createdBy,
  }) {
    modes.add(management);
    return catalog.watch().map((events) => org == 'robotics' ? events : []);
  }

  @override
  Future<void> close() async {
    await catalog.close();
    await super.close();
  }
}

OrgEvent _event(
  String id,
  int days, {
  String status = 'published',
  String approval = 'approved',
}) => OrgEvent.fromMap(id, 'robotics', {
  ...sampleEvent().toMap(),
  'title': 'Event $id',
  'eventStatus': status,
  'approvalStatus': approval,
  'startAt': DateTime.now().add(Duration(days: days)),
  'endAt': DateTime.now().add(Duration(days: days, hours: 1)),
  'publishedAt': DateTime.now().subtract(const Duration(days: 1)),
});

class _App {
  final accounts = TestAuthRepository(),
      profiles = TestProfileRepository(),
      orgs = TestOrganizationRepository(),
      events = _Catalog(),
      attendance = TestAttendanceRepository();
  late final auth = AuthViewModel(accounts, profiles);
  late final router = createAppRouter(auth);
  final capture = GlobalKey();
  Future<void> mount(WidgetTester tester, {bool officer = false}) async {
    if (officer) {
      orgs.allMemberships.emit([
        const Membership(
          organizationId: 'robotics',
          uid: 'student',
          role: 'officer',
          status: 'active',
          permissions: {'manageAttendance': true},
        ),
      ]);
    }
    events.catalog.emit([
      _event('Late', 4),
      _event('Soon', 1),
      _event('Middle', 2),
      _event('Draft', 3, status: 'draft'),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<GoRouter>.value(value: router),
          Provider<OrganizationRepository>.value(value: orgs),
          Provider<EventRepository>.value(value: events),
          Provider<AttendanceRepository>.value(value: attendance),
        ],
        child: RepaintBoundary(key: capture, child: const OrgLinkApp()),
      ),
    );
    accounts.controller.add(student);
    await tester.pump();
    profiles.controller.add(profile());
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    auth.dispose();
    await accounts.controller.close();
    await profiles.controller.close();
    await orgs.close();
    await events.close();
    await attendance.close();
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  setUpAll(() async {
    for (final (family, path) in [
      ('Inter', 'assets/fonts/inter/Inter-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      final loader = FontLoader(family)..addFont(rootBundle.load(path));
      await loader.load();
    }
  });
  test(
    'Home limits and sorts published upcoming events without privileged queries',
    () async {
      final app = _App();
      final orgs = OrganizationHubViewModel(app.orgs, 'student');
      final hub = EventHubViewModel(app.events, orgs);
      final home = HomeViewModel(hub);
      app.events.catalog.emit([
        _event('Late', 4),
        _event('Soon', 1),
        _event('Middle', 2),
        _event('Draft', 1, status: 'draft'),
        _event('Past', -1),
        _event('Unapproved', 1, approval: 'pending'),
      ]);
      await _flush();
      expect(home.upcoming.map((e) => e.title), ['Event Soon', 'Event Middle']);
      expect(app.events.modes, everyElement(false));
      home.searchFor('robotics');
      expect(home.matchingOrganizations.single.name, 'Demo Robotics');
      home.searchFor('late');
      expect(home.matchingEvents.single.title, 'Event Late');
      home.dispose();
      hub.dispose();
      orgs.dispose();
      await app.orgs.close();
      await app.events.close();
    },
  );
  test(
    'organization filters use active memberships and preserve public discovery queries',
    () async {
      final repo = TestOrganizationRepository();
      repo.allMemberships.emit([
        const Membership(
          organizationId: 'robotics',
          uid: 'student',
          role: 'member',
          status: 'active',
        ),
      ]);
      final model = OrganizationHubViewModel(repo, 'student');
      await _flush();
      expect(model.browseResults.length, 2);
      model.browse(OrganizationBrowseFilter.joined);
      expect(model.browseResults.single.id, 'robotics');
      model.browse(OrganizationBrowseFilter.discover);
      expect(model.browseResults.single.id, 'creative');
      repo.allMemberships.emit([
        const Membership(
          organizationId: 'robotics',
          uid: 'student',
          role: 'member',
          status: 'pending',
        ),
      ]);
      await _flush();
      model.browse(OrganizationBrowseFilter.joined);
      expect(model.browseResults, isEmpty);
      model.browse(OrganizationBrowseFilter.all);
      model.searchFor('creative');
      expect(model.browseResults.single.id, 'creative');
      model.dispose();
      await repo.close();
    },
  );
  testWidgets(
    'five exact tabs preserve student QR access, events, Coming Soon destinations and Android Back',
    (tester) async {
      final camera = _Camera(), old = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = camera;
      final app = _App();
      addTearDown(() async {
        await app.close(tester);
        MobileScannerPlatform.instance = old;
      });
      await app.mount(tester);
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byType(OrgLinkNavigationBar),
                matching: find.byType(Text),
              ),
            )
            .map((t) => t.data),
        ['Home', 'Calendar', 'QR', 'Organizations', 'Profile'],
      );
      expect(find.textContaining('Student!'), findsOneWidget);
      expect(find.text('Event Soon'), findsOneWidget);
      expect(find.text('Event Middle'), findsOneWidget);
      expect(find.text('Event Late'), findsNothing);
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(find.text('Coming Soon'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        app.router.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      expect(find.text('QR Hub'), findsOneWidget);
      expect(camera.starts, 0);
      await tester.ensureVisible(find.text('My QR Code'));
      await tester.tap(find.text('My QR Code'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'My QR Code'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.router.routeInformationProvider.value.uri.path, AppRoutes.qr);
      await tester.tap(find.text('Organizations').last);
      await tester.pumpAndSettle();
      expect(find.text('Find Your People'), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Your Profile'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        app.router.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No notification feed'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Event Discovery'), findsOneWidget);
      expect(app.router.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        app.router.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      expect(find.text('Exit OrgLink?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
    },
  );
  testWidgets(
    'authorized QR auto-starts camera; cover, lifecycle, tab switch and revocation release it',
    (tester) async {
      final camera = _Camera(), old = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = camera;
      final app = _App();
      addTearDown(() async {
        await app.close(tester);
        MobileScannerPlatform.instance = old;
      });
      await app.mount(tester, officer: true);
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      expect(find.text('Camera Preview (Test)'), findsOneWidget);
      expect(camera.starts, 1);
      final starts = camera.starts;
      app.router.push(AppRoutes.myQRCode);
      await tester.pumpAndSettle();
      expect(camera.stops, greaterThan(0));
      final stoppedStarts = camera.starts;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, stoppedStarts);
      app.router.pop();
      await tester.pumpAndSettle();
      expect(camera.starts, greaterThan(starts));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      final beforeResume = camera.starts;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(camera.starts, greaterThan(beforeResume));
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(camera.disposals, greaterThan(0));
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      app.orgs.allMemberships.emit([]);
      await tester.pumpAndSettle();
      expect(find.text('QR Hub'), findsOneWidget);
      expect(camera.disposals, greaterThan(1));
    },
  );
  testWidgets(
    'Home search navigates real results and organization filter chips remain functional',
    (tester) async {
      final app = _App();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      await tester.enterText(find.byType(TextField), 'robotics');
      await tester.pumpAndSettle();
      expect(find.text('Search Results'), findsOneWidget);
      expect(find.text('Demo Robotics'), findsOneWidget);
      await tester.ensureVisible(find.text('Demo Robotics'));
      await tester.tap(find.text('Demo Robotics'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Organization Details'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Organizations').last);
      await tester.pumpAndSettle();
      app.orgs.allMemberships.emit([
        const Membership(
          organizationId: 'robotics',
          uid: 'student',
          role: 'member',
          status: 'active',
        ),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Joined'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Robotics'), findsOneWidget);
      expect(find.text('Demo Creative'), findsNothing);
      await tester.tap(find.widgetWithText(FilterChip, 'Discover'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Creative'), findsOneWidget);
      expect(find.text('Demo Robotics'), findsNothing);
      await tester.enterText(find.byType(TextField), 'not a real organization');
      await tester.pumpAndSettle();
      expect(find.text('No Organizations Found'), findsOneWidget);
    },
  );

  testWidgets(
    'repeat tabs do not stack and Home exits only after explicit confirmation',
    (tester) async {
      var exits = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemNavigator.pop') exits++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final app = _App();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Calendar').last);
        await tester.pumpAndSettle();
      }
      expect(app.router.canPop(), isFalse);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-dashboard')), findsOneWidget);
      expect(exits, 0);
      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      expect(exits, 0);
      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      expect(find.text('Exit OrgLink?'), findsNothing);
      expect(exits, 0);
      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(exits, 1);
    },
  );

  testWidgets('core layouts keep controls usable at large Android text size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final app = _App();
    addTearDown(() => app.close(tester));
    await app.mount(tester);
    for (final path in [
      AppRoutes.home,
      AppRoutes.organizations,
      AppRoutes.calendar,
      AppRoutes.qr,
      AppRoutes.completeProfile,
    ]) {
      app.router.go(path);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Edit Student Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Save Student Profile'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save Student Profile'), findsOneWidget);
  });
  for (final covered in [true, false]) {
    testWidgets(
      'camera initialization finishing after ${covered ? 'cover' : 'tab switch'} is stopped',
      (tester) async {
        final camera = _Camera()..startGate = Completer<void>();
        final old = MobileScannerPlatform.instance;
        MobileScannerPlatform.instance = camera;
        final app = _App();
        addTearDown(() async {
          await app.close(tester);
          MobileScannerPlatform.instance = old;
        });
        await app.mount(tester, officer: true);
        await tester.tap(find.text('QR'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(camera.starts, 1);
        if (covered) {
          app.router.push(AppRoutes.myQRCode);
        } else {
          app.router.go(AppRoutes.calendar);
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        camera.startGate!.complete();
        await tester.pumpAndSettle();
        expect(camera.stops, greaterThan(0));
        expect(
          find.widgetWithText(AppBar, covered ? 'My QR Code' : 'Calendar'),
          findsOneWidget,
        );
        if (!covered) expect(camera.disposals, greaterThan(0));
      },
    );
  }

  testWidgets(
    'rapid scanner re-entry waits for the previous native startup and cleanup',
    (tester) async {
      final camera = _Camera()..startGate = Completer<void>();
      final old = MobileScannerPlatform.instance;
      MobileScannerPlatform.instance = camera;
      final app = _App();
      addTearDown(() async {
        await app.close(tester);
        MobileScannerPlatform.instance = old;
      });
      await app.mount(tester, officer: true);
      await tester.tap(find.text('QR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      app.router.go(AppRoutes.calendar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      app.router.go(AppRoutes.qr);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final startsBeforeRelease = camera.starts;
      camera.startGate!.complete();
      await tester.pumpAndSettle();
      expect(startsBeforeRelease, 1);
      expect(camera.starts, 2);
      expect(camera.stops, greaterThan(0));
      expect(find.text('Camera Preview (Test)'), findsOneWidget);
    },
  );

  for (final denied in [true, false]) {
    testWidgets(
      'scanner shows ${denied ? 'permission denial' : 'camera error'} and can retry',
      (tester) async {
        final camera = _Camera()
          ..denied = denied
          ..failed = !denied;
        final old = MobileScannerPlatform.instance;
        MobileScannerPlatform.instance = camera;
        final app = _App();
        addTearDown(() async {
          await app.close(tester);
          MobileScannerPlatform.instance = old;
        });
        await app.mount(tester, officer: true);
        await tester.tap(find.text('QR'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            denied
                ? 'Camera permission was denied'
                : 'The camera is unavailable',
          ),
          findsOneWidget,
        );
        camera.denied = false;
        camera.failed = false;
        await tester.tap(find.text('Retry Camera'));
        await tester.pumpAndSettle();
        expect(find.text('Camera Preview (Test)'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'deep links have valid parent Back and auth redirects survive exit confirmation',
    (tester) async {
      final app = _App();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.router.go('/organizations/robotics/events/demo/attendance/report');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        app.router.routeInformationProvider.value.uri.path,
        AppRoutes.home,
      );
      expect(
        parentDestination(
          '/organizations/robotics/events/demo/attendance/report',
        ),
        '/organizations/robotics/events/demo/attendance',
      );
      expect(
        parentDestination('/organizations/robotics/events/new'),
        '/organizations/robotics',
      );
      unawaited(tester.binding.handlePopRoute());
      await tester.pumpAndSettle();
      app.accounts.controller.add(null);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('google-sign-in')), findsOneWidget);
      expect(find.byType(OrgLinkNavigationBar), findsNothing);
    },
  );
  for (final size in [
    const Size(320, 720),
    const Size(360, 800),
    const Size(393, 852),
    const Size(412, 915),
  ]) {
    testWidgets('Phase 2 core layouts at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final app = _App();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      for (final (name, path) in [
        ('home', AppRoutes.home),
        ('organizations', AppRoutes.organizations),
        ('profile', AppRoutes.completeProfile),
        ('calendar', AppRoutes.calendar),
        ('qr', AppRoutes.qr),
      ]) {
        app.router.go(path);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              app.capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ui-phase2/$name-${size.width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      app.router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      app.events.catalog.fail(const AppFailure('Event catalog unavailable.'));
      await tester.pumpAndSettle();
      expect(find.text('Event catalog unavailable.'), findsOneWidget);
    });
  }

  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    testWidgets(
      'Home preserves long names and real content at ${width}dp and 200% text',
      (tester) async {
        tester.view.physicalSize = Size(width, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final app = _App();
        addTearDown(() => app.close(tester));
        await app.mount(tester);
        const name = "Alexandria-McDonald de la Cruz O'Neil";
        app.profiles.controller.add(
          profile(
            details: const StudentDetails(
              fullName: name,
              studentNumber: '2026-001',
              yearLevel: 1,
              section: 'A',
            ),
          ),
        );
        const orgName =
            'IEEE and ACM Student Organization for Computing and Engineering';
        app.orgs.organizations.emit([
          Organization.fromMap('robotics', {
            ...demoOrg.toMap(),
            'name': orgName,
          }),
        ]);
        const eventTitle =
            'iOS and NASA Research: Engineering Together with IEEE and ACM';
        app.events.catalog.emit([
          OrgEvent.fromMap('long', 'robotics', {
            ..._event('long', 2).toMap(),
            'title': eventTitle,
          }),
        ]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Alexandria-McDonald!'), findsOneWidget);
        expect(app.auth.profile!.details.fullName, name);
        expect(find.text(eventTitle), findsOneWidget);
        await tester.ensureVisible(find.text(eventTitle));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(orgName).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final raised = find.byKey(const ValueKey('raised-qr-action'));
        expect(
          tester.getTopLeft(raised).dy,
          lessThan(tester.getTopLeft(find.byType(OrgLinkNavigationBar)).dy),
        );
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        // The real Android keyboard must not collapse the scrollable header.
        await tester.ensureVisible(find.byType(TextField));
        tester.view.viewInsets = const FakeViewPadding(bottom: 260);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Home empty state, manager access, and selected navigation survive redesign',
    (tester) async {
      final app = _App();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.events.catalog.emit([]);
      await tester.pumpAndSettle();
      expect(find.text('No Upcoming Events'), findsOneWidget);
      expect(find.text('Organization Management'), findsNothing);
      // Permission-derived management getter remains the source of visibility.
      final managed = Organization.fromMap('robotics', {
        ...demoOrg.toMap(),
        'managerUid': 'student',
      });
      app.orgs.document.emit(managed);
      app.orgs.organizations.emit([managed, otherOrg]);
      await tester.pumpAndSettle();
      expect(find.text('Manage Events: Demo Robotics'), findsOneWidget);
      await tester.ensureVisible(find.text('Manage Events: Demo Robotics'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage Events: Demo Robotics'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(AppBar, 'Organization Event Management'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OrgLinkNavigationBar>(find.byType(OrgLinkNavigationBar))
            .selectedIndex,
        3,
      );
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OrgLinkNavigationBar>(find.byType(OrgLinkNavigationBar))
            .selectedIndex,
        4,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home Figma icons load as transparent high-resolution assets', (
    tester,
  ) async {
    final app = _App();
    addTearDown(() => app.close(tester));
    await app.mount(tester);
    final names = tester
        .widgetList<AppAssetIcon>(find.byType(AppAssetIcon))
        .map((icon) => icon.name)
        .toSet();
    expect(
      names,
      containsAll([
        'home',
        'calendar',
        'qr',
        'organizations',
        'profile',
        'search',
        'bell',
        'my_events',
        'attendance',
        'arrow',
      ]),
    );
    await tester.runAsync(() async {
      for (final name in names) {
        final data = await rootBundle.load('assets/icons/figma_$name.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(
          pixels!.getUint8(3),
          0,
          reason: '$name must have a transparent canvas',
        );
        expect(frame.image.width, greaterThanOrEqualTo(72));
        frame.image.dispose();
        codec.dispose();
      }
    });
    expect(tester.takeException(), isNull);
  });
}
