import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/presentation/screens/qr_screens.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/my_attendance_view_model.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/events/presentation/widgets/event_widgets.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'support/test_attendance_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class WindowFixture {
  WindowFixture(this.now, {DateTime? start, DateTime? end}) {
    events.change({
      'startAt': Timestamp.fromDate(
        start ?? now.subtract(const Duration(hours: 1)),
      ),
      'endAt': Timestamp.fromDate(end ?? now.add(const Duration(hours: 1))),
      'publishedAt': Timestamp.fromDate(now.subtract(const Duration(hours: 2))),
    });
    events.registrations.emit([
      const EventRegistration(
        uid: 'student',
        eventId: 'demo',
        organizationId: 'robotics',
        status: 'registered',
      ),
    ]);
    organizations = OrganizationHubViewModel(orgs, 'student');
    hub = EventHubViewModel(events, organizations);
    model = MyAttendanceViewModel(repo, hub, now: () => now);
  }
  DateTime now;
  final orgs = TestOrganizationRepository();
  final events = TestEventRepository();
  final repo = TestAttendanceRepository();
  late final OrganizationHubViewModel organizations;
  late final EventHubViewModel hub;
  late final MyAttendanceViewModel model;
  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: model,
        child: const MaterialApp(home: MyQRCodeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    model.select('robotics/demo');
    await tester.pumpAndSettle();
  }

  FilledButton button(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Generate QR Pass'));
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    hub.dispose();
    organizations.dispose();
    await events.close();
    await orgs.close();
    await repo.close();
  }
}

void main() {
  test(
    'Firestore timestamps preserve Manila schedule instants without a second timezone shift',
    () {
      final start = DateTime.parse('2026-10-27T09:00:00+08:00');
      final end = DateTime.parse('2026-10-27T11:00:00+08:00');
      final event = OrgEvent.fromMap('demo', 'robotics', {
        ...sampleEvent().toMap(),
        'startAt': Timestamp.fromDate(start),
        'endAt': Timestamp.fromDate(end),
        'publishedAt': Timestamp.fromDate(
          start.subtract(const Duration(days: 1)),
        ),
      });
      expect(event.startAt, DateTime.utc(2026, 10, 27, 1));
      expect(event.endAt, DateTime.utc(2026, 10, 27, 3));
      expect(event.startAt!.isUtc, isTrue);
      final during = DateTime.parse('2026-10-27T10:00:00+08:00');
      expect(attendanceWindow(event, during), isTrue);
      expect(attendanceWindow(event, during.toLocal()), isTrue);
      expect(attendanceWindow(event, start), isTrue);
      expect(attendanceWindow(event, end), isFalse);
      expect(schedule(event.startAt), schedule(start.toLocal()));
      expect(schedule(event.endAt), schedule(end.toLocal()));
    },
  );
  test(
    'ongoing time alone does not bypass approval, publication timestamp or archival checks',
    () {
      final now = DateTime.utc(2026, 10, 27, 2);
      final data = {
        ...sampleEvent().toMap(),
        'startAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'endAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
        'publishedAt': Timestamp.fromDate(
          now.subtract(const Duration(days: 1)),
        ),
      };
      for (final changes in <Map<String, dynamic>>[
        {'eventStatus': 'draft'},
        {'eventStatus': 'cancelled'},
        {'eventStatus': 'completed'},
        {'approvalStatus': 'pending'},
        {'publishedAt': null},
        {'archivedAt': Timestamp.fromDate(now)},
        {'startAt': null},
        {'endAt': null},
      ]) {
        final event = OrgEvent.fromMap('demo', 'robotics', {
          ...data,
          ...changes,
        });
        expect(attendanceWindow(event, now), isFalse, reason: '$changes');
        expect(attendanceUnavailableReason(event, now), isNotNull);
      }
      final missing = OrgEvent.fromMap('demo', 'robotics', {
        ...data,
        'publishedAt': null,
      });
      expect(
        attendanceUnavailableReason(missing, now),
        contains('publication timestamp'),
      );
    },
  );
  testWidgets(
    'button opens and closes automatically at boundaries before any QR is issued',
    (tester) async {
      final now = DateTime.utc(2026, 10, 27, 2),
          start = DateTime.utc(2026, 10, 27, 2, 0, 5),
          end = DateTime.utc(2026, 10, 27, 2, 0, 10);
      final f = WindowFixture(now, start: start, end: end);
      await f.mount(tester);
      expect(f.button(tester).onPressed, isNull);
      expect(find.text('Attendance has not opened yet.'), findsOneWidget);
      f.now = start;
      await tester.pump(const Duration(seconds: 5));
      expect(f.button(tester).onPressed, isNotNull);
      expect(f.model.canGenerate, isTrue);
      expect(find.text('Attendance has not opened yet.'), findsNothing);
      expect(f.repo.issues, 0);
      f.now = end;
      await tester.pump(const Duration(seconds: 5));
      expect(f.button(tester).onPressed, isNull);
      expect(find.text('The attendance window has closed.'), findsOneWidget);
      expect(f.repo.ownWatches, ['student']);
      await f.close(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'ongoing event with missing publication metadata shows the real cause, then updates from its stream',
    (tester) async {
      final f = WindowFixture(DateTime.utc(2026, 10, 27, 2));
      f.events.change({'publishedAt': null});
      await f.mount(tester);
      expect(f.button(tester).onPressed, isNull);
      expect(
        find.textContaining('publication timestamp is missing'),
        findsOneWidget,
      );
      await f.model.generate();
      expect(f.repo.issues, 0);
      f.events.change({
        'publishedAt': Timestamp.fromDate(
          f.now.subtract(const Duration(days: 1)),
        ),
      });
      await tester.pumpAndSettle();
      expect(f.button(tester).onPressed, isNotNull);
      expect(f.model.windowMessage, isNull);
      expect(f.repo.ownWatches, ['student']);
      await f.close(tester);
    },
  );
  testWidgets(
    'window closure discards an in-flight pass instead of displaying late credentials',
    (tester) async {
      final now = DateTime.utc(2026, 10, 27, 2),
          end = DateTime.utc(2026, 10, 27, 2, 0, 5);
      final f = WindowFixture(now, end: end);
      await f.mount(tester);
      f.repo.gate = Completer<void>();
      final pending = f.model.generate();
      expect(f.model.busy, isTrue);
      f.now = end;
      await tester.pump(const Duration(seconds: 5));
      f.repo.gate!.complete();
      await pending;
      await tester.pump();
      expect(f.model.credential, isNull);
      expect(f.button(tester).onPressed, isNull);
      await f.close(tester);
    },
  );
}
