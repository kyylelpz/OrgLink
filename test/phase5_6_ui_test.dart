import 'dart:async';
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
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:orglink/core/widgets/app_components.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/data/models/participant_identity.dart';
import 'package:orglink/features/attendance/data/repositories/attendance_repository.dart';
import 'package:orglink/features/attendance/presentation/screens/qr_screens.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/my_attendance_view_model.dart';
import 'support/test_attendance_repository.dart';

class MigrationCamera extends MobileScannerPlatform {
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

class MigrationApp {
  final accounts = TestAuthRepository(), profiles = TestProfileRepository();
  final orgs = TestOrganizationRepository(), events = TestEventRepository();
  final attendance = TestAttendanceRepository();
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
        Provider<AttendanceRepository>.value(value: attendance),
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
    await attendance.close();
  }

  Future<void> screenshot(WidgetTester tester, String name) => tester.runAsync(
    () async {
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-phase5-6/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    },
  );
}

const title =
    'IEEE / iOS Builders: Designing for de la Cruz and McDonald University';
const person = "Alexandria-McDonald de la Cruz O'Neil";
const registration = EventRegistration(
  uid: 'student',
  eventId: 'demo',
  organizationId: 'robotics',
  status: 'registered',
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
        'Events, QR and Attendance ${width}dp ${scale}x, long labels, safe areas and keyboard',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final oldCamera = MobileScannerPlatform.instance;
          final camera = MigrationCamera();
          MobileScannerPlatform.instance = camera;
          addTearDown(() => MobileScannerPlatform.instance = oldCamera);
          final app = MigrationApp();
          addTearDown(() => app.close(tester));
          app.events.change({
            'title': title,
            'venue': 'The Engineering and Computing Research Auditorium',
          });
          app.events.registrations.emit([registration]);
          app.events.identities.emit([
            const ParticipantIdentity(uid: 'student', fullName: person),
          ]);
          await app.mount(tester);
          app.accounts.controller.add(student);
          await tester.pump();
          app.profiles.controller.add(profile());
          await tester.pumpAndSettle();
          Future<void> visit(String name, String path) async {
            app.router.go(path);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: name);
            if (scale == 1 || width == 320) {
              await app.screenshot(
                tester,
                '$name-${width.toInt()}-${scale.toInt()}x',
              );
            }
            final scroll = find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            );
            if (scroll.evaluate().isNotEmpty) {
              await tester.drag(scroll.first, const Offset(0, -3000));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: '$name scrolled');
            }
          }

          for (final route in [
            ('discovery', AppRoutes.events),
            ('my-events', AppRoutes.myEvents),
            ('details', AppRoutes.event('robotics', 'demo')),
            ('registration', AppRoutes.confirmRegistration('robotics', 'demo')),
            ('qr-hub', AppRoutes.qrActions),
            ('my-attendance', AppRoutes.myAttendance),
          ]) {
            await visit(route.$1, route.$2);
          }
          // A synthetic server credential is issued only inside the test fixture's open window.
          final now = DateTime.now();
          app.events.change({
            'startAt': now.subtract(const Duration(hours: 1)),
            'endAt': now.add(const Duration(hours: 1)),
            'publishedAt': now.subtract(const Duration(hours: 2)),
          });
          await visit('qr-selection', AppRoutes.myQRCode);
          final pass = tester
              .element(find.byType(MyQRCodeScreen))
              .read<MyAttendanceViewModel>();
          pass.select('robotics/demo');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Generate QR Pass'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Generate QR Pass'));
          await tester.pumpAndSettle();
          expect(app.attendance.issues, 1);
          expect(tester.takeException(), isNull);
          await tester.drag(
            find.byType(Scrollable).last,
            const Offset(0, 1600),
          );
          await tester.pumpAndSettle();
          if (scale == 1 || width == 320) {
            await app.screenshot(
              tester,
              'qr-pass-${width.toInt()}-${scale.toInt()}x',
            );
          }
          // Manager views use the same real models and existing route/permission handling.
          app.accounts.controller.add(const AuthUser(id: 'manager'));
          await tester.pump();
          app.profiles.controller.add(profile());
          await tester.pumpAndSettle();
          await visit('management', AppRoutes.manageEvents('robotics'));
          app.events.change({'eventStatus': 'draft'});
          await visit('editor', AppRoutes.editEvent('robotics', 'demo'));
          await visit('create', AppRoutes.createEvent('robotics'));
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          addTearDown(tester.view.resetViewInsets);
          await tester.ensureVisible(find.byType(TextFormField).first);
          await tester.enterText(find.byType(TextFormField).first, title);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          app.events.change({'eventStatus': 'published'});
          for (final route in [
            ('participants', AppRoutes.participants('robotics', 'demo')),
            (
              'attendance-selection',
              AppRoutes.attendanceManagement('robotics'),
            ),
            ('roster', AppRoutes.attendance('robotics', 'demo')),
            ('report', AppRoutes.attendanceReport('robotics', 'demo')),
          ]) {
            await visit(route.$1, route.$2);
          }
          app.attendance.feed.emit([attendanceRecord()]);
          app.router.go(AppRoutes.attendance('robotics', 'demo'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Correct Attendance'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Correct Attendance'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scale == 1 || width == 320) {
            await app.screenshot(
              tester,
              'correction-${width.toInt()}-${scale.toInt()}x',
            );
          }
          await tester.ensureVisible(find.text('Cancel'));
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(app.attendance.corrections, 0);
          await visit('scanner', AppRoutes.qrScan);
          expect(camera.starts, greaterThan(0));
        },
      );
    }
  }
  testWidgets(
    'poster failure, empty catalog, scanner denial and metric semantics',
    (tester) async {
      tester.view.physicalSize = const Size(320, 852);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final oldCamera = MobileScannerPlatform.instance;
      final camera = MigrationCamera()..denied = true;
      MobileScannerPlatform.instance = camera;
      addTearDown(() => MobileScannerPlatform.instance = oldCamera);
      final app = MigrationApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(const AuthUser(id: 'manager'));
      await tester.pump();
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      app.events.change({'posterURL': 'https://example.invalid/missing.png'});
      app.router.go(AppRoutes.event('robotics', 'demo'));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Demo Event'), findsOneWidget);
      app.events.event.emit(null);
      app.router.go(AppRoutes.events);
      await tester.pumpAndSettle();
      expect(
        find.text('No accessible events match these filters.'),
        findsOneWidget,
      );
      app.events.event.emit(sampleEvent());
      app.router.go(AppRoutes.qrScan);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Camera permission was denied.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Retry Camera'));
      await tester.pumpAndSettle();
      camera.denied = false;
      await tester.tap(find.text('Retry Camera'));
      await tester.pumpAndSettle();
      expect(camera.starts, greaterThanOrEqualTo(2));
      // Metrics expose both label and value to assistive technology.
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppMetricTiles(
              values: [('64', 'Registered'), ('48', 'Present')],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Registered: 64'), findsOneWidget);
      expect(find.bySemanticsLabel('Present: 48'), findsOneWidget);
      semantics.dispose();
    },
  );
}
