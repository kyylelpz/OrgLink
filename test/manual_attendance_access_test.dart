import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/presentation/screens/attendance_screens.dart';
import 'package:orglink/features/attendance/presentation/viewmodels/attendance_view_model.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/presentation/screens/event_management_screen.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_context_view_model.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'support/test_attendance_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

EventRegistration registration(String uid, {String status = 'registered'}) =>
    EventRegistration(
      uid: uid,
      eventId: 'demo',
      organizationId: 'robotics',
      status: status,
    );

void main() {
  for (final uid in ['manager', 'officer', 'event-editor']) {
    testWidgets(
      '$uid attendance navigation preserves independent attendance permission',
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
            permissions: uid == 'officer'
                ? {'manageAttendance': true}
                : {'manageEvents': true},
          ),
        ]);
        final now = DateTime.now();
        events.change({
          'startAt': now.subtract(const Duration(hours: 1)),
          'endAt': now.add(const Duration(hours: 1)),
          'publishedAt': now.subtract(const Duration(hours: 2)),
        });
        events.registrations.emit([
          registration('student'),
          registration(uid),
          registration('withdrawn', status: 'cancelled'),
        ]);
        final event = EventContextViewModel(
          events,
          orgs,
          'robotics',
          uid,
          eventId: 'demo',
        );
        final model = AttendanceViewModel(repo, event);
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const ParticipantsScreen()),
            GoRoute(
              path: AppRoutes.attendance('robotics', 'demo'),
              builder: (_, _) => const AttendanceScreen(),
            ),
          ],
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: event),
              ChangeNotifierProvider.value(value: model),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        if (uid == 'event-editor') {
          expect(find.byTooltip('Attendance Verification'), findsNothing);
          router.go(AppRoutes.attendance('robotics', 'demo'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              'You do not have permission to manage attendance',
            ),
            findsOneWidget,
          );
          expect(find.text('Mark Present'), findsNothing);
        } else {
          await tester.tap(find.byTooltip('Attendance Verification'));
          await tester.pumpAndSettle();
          // Only the other, active, unmarked participant is eligible.
          expect(find.text('Mark Present'), findsOneWidget);
          expect(find.text('Mark Absent'), findsOneWidget);
          await tester.ensureVisible(find.text('Mark Present'));
          await tester.tap(find.text('Mark Present'));
          await tester.pumpAndSettle();
          expect(find.text('Mark Present?'), findsOneWidget);
          expect(repo.marks, 0);
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          expect(repo.marks, 1);
          expect(model.summary.present, 1);
          expect(find.text('Mark Present'), findsNothing);
          expect(find.text('Mark Absent'), findsNothing);
          expect(model.recordFor('student')!.status, AttendanceStatus.present);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        model.dispose();
        event.dispose();
        await orgs.close();
        await events.close();
        await repo.close();
      },
    );
  }

  testWidgets(
    'manual actions appear and disappear at event boundaries without refetching',
    (tester) async {
      final orgs = TestOrganizationRepository(),
          events = TestEventRepository(),
          repo = TestAttendanceRepository();
      var now = DateTime.utc(2026, 10, 27, 12);
      events.change({
        'startAt': now.add(const Duration(seconds: 2)),
        'endAt': now.add(const Duration(seconds: 4)),
        'publishedAt': now.subtract(const Duration(hours: 1)),
      });
      events.registrations.emit([registration('student')]);
      final event = EventContextViewModel(
        events,
        orgs,
        'robotics',
        'manager',
        eventId: 'demo',
      );
      final model = AttendanceViewModel(repo, event, now: () => now);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: model,
          child: const MaterialApp(home: AttendanceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attendance has not opened yet.'), findsOneWidget);
      expect(find.text('Mark Present'), findsNothing);
      final watches = events.identityWatches;
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Mark Present'), findsOneWidget);
      expect(find.text('Mark Absent'), findsOneWidget);
      expect(events.identityWatches, watches);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('The attendance window has closed.'), findsOneWidget);
      expect(find.text('Mark Present'), findsNothing);
      expect(find.text('Mark Absent'), findsNothing);
      expect(repo.marks, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      event.dispose();
      await orgs.close();
      await events.close();
      await repo.close();
    },
  );
}
