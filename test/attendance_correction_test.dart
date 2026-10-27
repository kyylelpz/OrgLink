import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/presentation/screens/attendance_screens.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/my_attendance_view_model.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_context_view_model.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'support/test_attendance_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

const student = EventRegistration(
  uid: 'student',
  eventId: 'demo',
  organizationId: 'robotics',
  status: 'registered',
);

void main() {
  testWidgets(
    'manager confirms reason, prevents duplicate correction, resets Pending and updates personal history',
    (tester) async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      final now = DateTime.now();
      events.change({
        'startAt': now.subtract(const Duration(hours: 2)),
        'endAt': now.subtract(const Duration(hours: 1)),
        'eventStatus': 'completed',
        'publishedAt': now.subtract(const Duration(hours: 3)),
      });
      events.registrations.emit([student]);
      repo.feed.emit([attendanceRecord()]);
      final event = EventContextViewModel(
        events,
        orgs,
        'robotics',
        'manager',
        eventId: 'demo',
      );
      final model = AttendanceViewModel(repo, event);
      final organizations = OrganizationHubViewModel(orgs, 'student');
      final hub = EventHubViewModel(events, organizations);
      final mine = MyAttendanceViewModel(repo, hub);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: AttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Mark Present'),
        findsNothing,
      ); // Correction does not reopen normal marking.
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Correct Attendance'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct Attendance'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Attendance Correction'), findsOneWidget);
      expect(repo.corrections, 0);
      await tester.tap(find.text('Confirm Correction'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a correction reason.'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Checked signed roster.',
      );
      repo.gate = Completer<void>();
      await tester.tap(find.text('Confirm Correction'));
      await tester.pump();
      expect(repo.corrections, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm Correction'),
            )
            .onPressed,
        isNull,
      );
      repo.gate!.complete();
      repo.gate = null;
      await tester.pumpAndSettle();
      expect(model.recordFor('student')!.status, AttendanceStatus.absent);
      expect(
        mine.records['robotics/demo']!.value!.status,
        AttendanceStatus.absent,
      );
      expect(repo.correctionReason, 'Checked signed roster.');
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Correct Attendance'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct Attendance'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<AttendanceCorrectionStatus>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Remove an incorrect verification.',
      );
      await tester.tap(find.text('Confirm Correction'));
      await tester.pumpAndSettle();
      expect(repo.corrections, 2);
      expect(model.recordFor('student'), isNull);
      expect(model.summary.notMarked, 1);
      expect(mine.records['robotics/demo']!.value, isNull);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: mine,
          child: const MaterialApp(home: MyAttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not Marked'), findsOneWidget);
      expect(
        find.textContaining('Present: 0 | Absent: 0 | Not Marked: 1'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      event.dispose();
      mine.dispose();
      hub.dispose();
      organizations.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );

  for (final uid in ['officer', 'student', 'manager']) {
    testWidgets(
      '$uid cannot correct without independent manager authority or correct self',
      (tester) async {
        final orgs = TestOrganizationRepository(),
            events = TestEventRepository(),
            repo = TestAttendanceRepository();
        orgs.allMemberships.emit([
          Membership(
            organizationId: 'robotics',
            uid: uid,
            role: 'officer',
            status: 'active',
            permissions: const {'manageAttendance': true},
          ),
        ]);
        final now = DateTime.now();
        events.change({
          'startAt': now.subtract(const Duration(hours: 1)),
          'publishedAt': now.subtract(const Duration(hours: 2)),
        });
        final target = uid == 'manager' ? 'manager' : 'student';
        final registration = EventRegistration(
          uid: target,
          eventId: 'demo',
          organizationId: 'robotics',
          status: 'registered',
        );
        events.registrations.emit([registration]);
        repo.feed.emit([attendanceRecord(uid: target)]);
        final event = EventContextViewModel(
          events,
          orgs,
          'robotics',
          uid,
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
        expect(find.text('Correct Attendance'), findsNothing);
        expect(await model.previewCorrection(registration), isNull);
        expect(
          await model.correct(
            registration,
            const AttendanceCorrectionPreview(
              AttendanceStatus.present,
              'forged',
            ),
            AttendanceCorrectionStatus.absent,
            'Reason',
          ),
          isFalse,
        );
        expect(repo.corrections, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        event.dispose();
        await orgs.close();
        await events.close();
        await repo.close();
      },
    );
  }

  testWidgets(
    'server conflict remains visible and never shows correction success',
    (tester) async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      final now = DateTime.now();
      events.change({
        'startAt': now.subtract(const Duration(hours: 1)),
        'publishedAt': now.subtract(const Duration(hours: 2)),
      });
      events.registrations.emit([student]);
      repo.feed.emit([attendanceRecord()]);
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
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Correct Attendance'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Correct Attendance'));
      await tester.pumpAndSettle();
      repo.error = const AppFailure(
        'Attendance changed. Review the current result and confirm a new correction.',
      );
      await tester.enterText(find.byType(TextFormField), 'Checked roster');
      await tester.tap(find.text('Confirm Correction'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm Attendance Correction'), findsOneWidget);
      expect(find.textContaining('Attendance changed.'), findsWidgets);
      expect(model.correctionMessage, isNull);
      expect(model.recordFor('student')!.status, AttendanceStatus.present);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      event.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
}
