import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/services/firestore_service.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/data/repositories/attendance_repository.dart';
import 'package:orglink/features/attendance/data/repositories/firestore_attendance_repository.dart';
import 'package:orglink/features/attendance/data/services/attendance_service.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/scanner_view_model.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/my_attendance_view_model.dart';
import 'package:orglink/features/attendance/presentation/screens/attendance_screens.dart';
import 'package:orglink/features/attendance/presentation/screens/qr_screens.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/data/models/participant_identity.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_context_view_model.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'support/test_attendance_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

Future<void> settle() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

EventRegistration registration(String uid, {String status = 'registered'}) =>
    EventRegistration(
      uid: uid,
      eventId: 'demo',
      organizationId: 'robotics',
      status: status,
    );
void openWindow(TestEventRepository events) => events.change({
  'startAt': DateTime.now().subtract(const Duration(hours: 1)),
  'endAt': DateTime.now().add(const Duration(hours: 1)),
  'publishedAt': DateTime.now().subtract(const Duration(hours: 2)),
});

class FakeStore extends Fake implements FirestoreService {}

class FakeAttendanceAuth extends Fake implements FirebaseAuth {}

class FailingAttendanceService extends AttendanceService {
  FailingAttendanceService() : super(FakeStore(), FakeAttendanceAuth());
  @override
  Future<AttendanceResult> mark(
    String org,
    String event,
    String uid,
    String operatorUid,
    AttendanceStatus status,
  ) async {
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
  }
}

void main() {
  testWidgets(
    'My QR Code selects a registered event, generates a pass and shows verified state',
    (tester) async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      openWindow(events);
      events.registrations.emit([registration('student')]);
      final organizations = OrganizationHubViewModel(orgs, 'student');
      final hub = EventHubViewModel(events, organizations);
      final model = MyAttendanceViewModel(repo, hub);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: MyQRCodeScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo Event').last);
      await tester.pumpAndSettle();
      expect(find.text('Attendance: Not Marked'), findsOneWidget);
      await tester.ensureVisible(find.text('Generate QR Pass'));
      await tester.tap(find.text('Generate QR Pass'));
      await tester.pumpAndSettle();
      expect(repo.issues, 1);
      expect(model.credential, isNotNull);
      expect(find.textContaining('Expires in'), findsOneWidget);
      repo.feed.emit([attendanceRecord()]);
      await tester.pumpAndSettle();
      expect(find.text('Already Verified'), findsOneWidget);
      expect(model.credential, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      hub.dispose();
      organizations.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );

  testWidgets(
    'manual marking confirms Absent, updates report and never labels missing attendance Absent',
    (tester) async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      openWindow(events);
      events.registrations.emit([
        registration('student'),
        registration('other'),
        registration('cancelled', status: 'cancelled'),
      ]);
      events.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: 'McDonald'),
      ]);
      final event = EventContextViewModel(
        events,
        orgs,
        'robotics',
        'manager',
        eventId: 'demo',
      );
      final model = AttendanceViewModel(repo, event);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: AttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('McDonald'), findsOneWidget);
      expect(
        find.textContaining(
          'Registered: 2 | Present: 0 | Absent: 0 | Not Marked: 2',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Mark Absent').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark Absent').first);
      await tester.pumpAndSettle();
      expect(find.text('Mark Absent?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.marks, 1);
      expect(model.summary.absent, 1);
      expect(model.summary.notMarked, 1);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: AttendanceScreen(report: true)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attendance Report'), findsOneWidget);
      expect(find.text('Mark Present'), findsNothing);
      repo.feed.fail(const AppFailure('Attendance connection failed.'));
      await tester.pumpAndSettle();
      expect(find.text('Attendance connection failed.'), findsOneWidget);
      expect(find.textContaining('Attendance Rate:'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      event.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );

  test(
    'attendance seven-field schema round trip and strict status parsing',
    () {
      final record = attendanceRecord();
      expect(record.toMap().length, 7);
      expect(
        AttendanceRecord.fromMap(record.toMap()).verifiedAt,
        record.verifiedAt,
      );
      expect(
        AttendanceRecord.fromMap(record.toMap()).method,
        VerificationMethod.manual,
      );
      expect(
        () => AttendanceRecord.fromMap({
          ...record.toMap(),
          'attendanceStatus': 'notMarked',
        }),
        throwsArgumentError,
      );
      expect(
        () => AttendanceRecord.fromMap({...record.toMap(), 'verifiedAt': null}),
        throwsFormatException,
      );
      expect(attendanceLabel(null), 'Not Marked');
      expect(
        attendanceLabel(attendanceRecord(status: AttendanceStatus.absent)),
        'Absent',
      );
    },
  );
  test(
    'summary excludes cancelled registrations, deduplicates users and distinguishes unmarked',
    () {
      final summary = AttendanceSummary(
        [
          registration('student'),
          registration('student'),
          registration('absent'),
          registration('unmarked'),
          registration('withdrawn', status: 'cancelled'),
        ],
        [
          attendanceRecord(),
          attendanceRecord(uid: 'absent', status: AttendanceStatus.absent),
          attendanceRecord(uid: 'withdrawn'),
        ],
      );
      expect(summary.registered, 3);
      expect(summary.present, 1);
      expect(summary.absent, 1);
      expect(summary.notMarked, 1);
      expect(summary.rate, closeTo(100 / 3, .001));
      expect(AttendanceSummary([], []).rate, isNull);
    },
  );
  test(
    'attendance permission is organization specific and independent of event permission or title',
    () {
      Membership member({
        String org = 'robotics',
        String role = 'officer',
        String status = 'active',
        Map<String, dynamic> permissions = const {'manageAttendance': true},
      }) => Membership(
        uid: 'officer',
        organizationId: org,
        role: role,
        status: status,
        permissions: permissions,
        positionTitle: 'President',
      );
      expect(canManageAttendance(demoOrg, null, 'manager'), isTrue);
      expect(canManageAttendance(demoOrg, member(), 'officer'), isTrue);
      expect(
        canManageAttendance(demoOrg, member(org: 'creative'), 'officer'),
        isFalse,
      );
      expect(
        canManageAttendance(demoOrg, member(status: 'pending'), 'officer'),
        isFalse,
      );
      expect(
        canManageAttendance(demoOrg, member(role: 'member'), 'officer'),
        isFalse,
      );
      expect(
        canManageAttendance(
          demoOrg,
          member(permissions: {'manageEvents': true}),
          'officer',
        ),
        isFalse,
      );
      expect(canManageAttendance(otherOrg, null, 'manager'), isFalse);
    },
  );
  test(
    'attendance window rejects cancelled, completed, unapproved and unpublished lifecycle',
    () {
      final events = TestEventRepository();
      openWindow(events);
      final event = events.event.value!;
      expect(attendanceWindow(event, DateTime.now()), isTrue);
      expect(attendanceWindow(event, event.endAt!), isFalse);
      expect(attendanceWindow(event, event.startAt!), isTrue);
      for (final status in ['draft', 'cancelled', 'completed']) {
        events.change({'eventStatus': status});
        expect(attendanceWindow(events.event.value!, DateTime.now()), isFalse);
      }
      events.close();
    },
  );
  test(
    'QR parser restricts version, type, paths and token without private profile data',
    () {
      final payload = QRPayload('robotics', 'demo', 'a' * 43);
      expect(QRPayload.parse(payload.encoded).eventId, 'demo');
      expect(
        payload.toMap().keys,
        unorderedEquals([
          'version',
          'type',
          'organizationId',
          'eventId',
          'token',
        ]),
      );
      for (final raw in [
        '{}',
        'not json',
        '{"version":2}',
        QRPayload('robotics/other', 'demo', 'a' * 43).encoded,
        QRPayload('robotics', 'demo', 'uid-student').encoded,
      ]) {
        expect(() => QRPayload.parse(raw), throwsA(anything));
      }
    },
  );
  test(
    'repository maps Firebase permission failures to domain errors',
    () async {
      final repo = FirestoreAttendanceRepository(FailingAttendanceService());
      await expectLater(
        repo.mark(
          'robotics',
          'demo',
          'student',
          'manager',
          AttendanceStatus.present,
        ),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            contains('permission'),
          ),
        ),
      );
    },
  );
  test(
    'scanner validates permissions, serializes requests, exposes error/retry and discards stale results',
    () async {
      final repo = TestAttendanceRepository();
      final scanner = ScannerViewModel(repo, (org) => org == 'robotics');
      await scanner.scan('invalid');
      expect(scanner.failure, isNotNull);
      expect(repo.redemptions, 0);
      scanner.next();
      await scanner.scan(QRPayload('creative', 'demo', 'a' * 43).encoded);
      expect(scanner.failure!.message, contains('not authorized'));
      scanner.next();
      repo.gate = Completer();
      final first = scanner.scan(
        QRPayload('robotics', 'demo', 'a' * 43).encoded,
      );
      expect(scanner.busy, isTrue);
      await scanner.scan(QRPayload('robotics', 'demo', 'a' * 43).encoded);
      expect(repo.redemptions, 1);
      repo.gate!.complete();
      await first;
      expect(scanner.result!.fullName, 'McDonald');
      expect(scanner.paused, isTrue);
      scanner.next();
      repo.error = const AppFailure('Network unavailable.');
      await scanner.scan(QRPayload('robotics', 'demo', 'a' * 43).encoded);
      expect(scanner.failure!.message, 'Network unavailable.');
      scanner.next();
      repo.error = null;
      repo.gate = Completer();
      final old = scanner.scan(QRPayload('robotics', 'demo', 'a' * 43).encoded);
      scanner.dispose();
      repo.gate!.complete();
      await old;
      expect(scanner.result, isNull);
      await repo.close();
    },
  );
  test(
    'manual ViewModel loads scoped names, marks once, reports duplicates and filters',
    () async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      openWindow(events);
      events.registrations.emit([
        registration('student'),
        registration('other'),
      ]);
      events.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: 'McDonald'),
      ]);
      final event = EventContextViewModel(
        events,
        orgs,
        'robotics',
        'manager',
        eventId: 'demo',
      );
      final model = AttendanceViewModel(repo, event);
      await settle();
      expect(model.authorized, isTrue);
      expect(model.nameFor('other'), 'Unknown Participant');
      repo.gate = Completer();
      final work = model.mark(
        registration('student'),
        AttendanceStatus.present,
      );
      await model.mark(registration('student'), AttendanceStatus.absent);
      expect(repo.marks, 1);
      repo.gate!.complete();
      expect((await work)!.duplicate, isFalse);
      await settle();
      expect(
        (await model.mark(
          registration('student'),
          AttendanceStatus.absent,
        ))!.duplicate,
        isTrue,
      );
      expect(repo.marks, 1);
      expect(model.summary.present, 1);
      expect(model.summary.notMarked, 1);
      model.setFilter(text: 'McDonald', status: 'present');
      expect(model.participants.length, 1);
      model.dispose();
      event.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
  test(
    'attendance officer revocation clears roster and in-flight result',
    () async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      openWindow(events);
      events.registrations.emit([registration('student')]);
      orgs.allMemberships.emit([
        const Membership(
          uid: 'officer',
          organizationId: 'robotics',
          role: 'officer',
          status: 'active',
          permissions: {'manageAttendance': true},
        ),
      ]);
      final event = EventContextViewModel(
        events,
        orgs,
        'robotics',
        'officer',
        eventId: 'demo',
      );
      final model = AttendanceViewModel(repo, event);
      await settle();
      expect(model.authorized, isTrue);
      repo.gate = Completer();
      final work = model.mark(
        registration('student'),
        AttendanceStatus.present,
      );
      orgs.allMemberships.emit([]);
      await settle();
      expect(model.records, isNull);
      repo.gate!.complete();
      expect(await work, isNull);
      expect(model.result, isNull);
      model.dispose();
      event.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
  test(
    'My Attendance watches only current UID; changed selection/disposal discard QR responses',
    () async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      openWindow(events);
      events.registrations.emit([
        registration('student'),
        registration('other'),
      ]);
      final hub = OrganizationHubViewModel(orgs, 'student');
      final eventHub = EventHubViewModel(events, hub);
      final model = MyAttendanceViewModel(repo, eventHub);
      await settle();
      expect(repo.ownWatches, ['student']);
      model.select('robotics/demo');
      repo.gate = Completer();
      final work = model.generate();
      expect(repo.issues, 1);
      model.select(null);
      repo.gate!.complete();
      await work;
      expect(model.credential, isNull);
      repo.gate = null;
      model.select('robotics/demo');
      await model.generate();
      expect(model.credential, isNotNull);
      expect(model.secondsRemaining, inInclusiveRange(1, 60));
      model.dispose();
      eventHub.dispose();
      hub.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
  testWidgets(
    'global QR Hub opens centrally; student scanner route guarded; history clears on account switch',
    (tester) async {
      final authRepo = TestAuthRepository(),
          profiles = TestProfileRepository(),
          orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      events.registrations.emit([registration('student')]);
      repo.feed.emit([attendanceRecord()]);
      final auth = AuthViewModel(authRepo, profiles);
      final appRouter = createAppRouter(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<GoRouter>.value(value: appRouter),
            Provider<OrganizationRepository>.value(value: orgs),
            Provider<EventRepository>.value(value: events),
            Provider<AttendanceRepository>.value(value: repo),
          ],
          child: const OrgLinkApp(),
        ),
      );
      authRepo.controller.add(student);
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      await tester.tap(find.text('QR'));
      await tester.pumpAndSettle();
      expect(find.text('QR Hub'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Scan QR Code'),
            )
            .onPressed,
        isNull,
      );
      appRouter.go(AppRoutes.qrScan);
      await tester.pumpAndSettle();
      expect(
        find.text('Attendance scanning permission is required.'),
        findsOneWidget,
      );
      appRouter.go(AppRoutes.myAttendance);
      await tester.pumpAndSettle();
      expect(find.text('Present'), findsOneWidget);
      expect(repo.ownWatches.last, 'student');
      authRepo.controller.add(const AuthUser(id: 'other'));
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      expect(find.text('Present'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      appRouter.dispose();
      auth.dispose();
      await authRepo.controller.close();
      await profiles.controller.close();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
}
