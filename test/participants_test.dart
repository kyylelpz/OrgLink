import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/events/data/models/participant_identity.dart';
import 'package:orglink/features/events/data/models/event_registration.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/events/presentation/viewmodels/participants_view_model.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'names join once, withdrawals remain identifiable, missing/blank legacy names are safe',
    () async {
      final repository = TestEventRepository();
      final participants = ParticipantsViewModel(
        repository,
        'robotics',
        'demo',
      );
      await repository.register('robotics', 'demo', 'student', withdraw: false);
      await flush();
      expect(participants.nameFor('student'), 'Student Name');
      expect(repository.identityWatches, 1);
      await repository.register('robotics', 'demo', 'student', withdraw: true);
      await flush();
      expect(participants.registrations.value?.single.status, 'cancelled');
      expect(participants.nameFor('student'), 'Student Name');
      repository.identities.emit([]);
      await flush();
      expect(participants.nameFor('student'), 'Unknown Participant');
      repository.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: ' '),
      ]);
      await flush();
      expect(participants.nameFor('student'), 'Unknown Participant');
      repository.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: 'Juan Dela Cruz'),
      ]);
      await flush();
      expect(participants.nameFor('student'), 'Juan Dela Cruz');
      expect(repository.identityWatches, 1);
      participants.dispose();
      await repository.close();
    },
  );
  test(
    'projection loading and errors are distinct from legitimate missing names',
    () async {
      final repository = TestEventRepository();
      final participants = ParticipantsViewModel(
        repository,
        'robotics',
        'demo',
      );
      expect(participants.identities.loading, isTrue);
      await flush();
      repository.identities.fail(const AppFailure('Name lookup failed'));
      await flush();
      expect(participants.identities.failure?.message, 'Name lookup failed');
      participants.identities.retry();
      await flush();
      expect(participants.identities.failure, isNull);
      expect(repository.identityWatches, 2);
      participants.dispose();
      await repository.close();
    },
  );
  testWidgets(
    'authorized event officer sees live full names, legacy fallback and loses access on revocation',
    (tester) async {
      final authRepository = TestAuthRepository(),
          profiles = TestProfileRepository(),
          organizations = TestOrganizationRepository(),
          events = TestEventRepository();
      events.event.emit(sampleEvent(creator: 'officer'));
      events.registrations.emit([
        EventRegistration(
          uid: 'student',
          eventId: 'demo',
          organizationId: 'robotics',
          status: 'cancelled',
          registeredAt: DateTime(2026, 10, 26, 15, 18),
          updatedAt: DateTime(2026, 10, 26, 16),
        ),
      ]);
      events.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: 'Juan Dela Cruz'),
      ]);
      organizations.allMemberships.emit([
        const Membership(
          uid: 'officer',
          organizationId: 'robotics',
          role: 'officer',
          status: 'active',
          permissions: {'manageEvents': true},
        ),
      ]);
      final auth = AuthViewModel(authRepository, profiles),
          router = createAppRouter(auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            Provider<GoRouter>.value(value: router),
            Provider<OrganizationRepository>.value(value: organizations),
            Provider<EventRepository>.value(value: events),
          ],
          child: const OrgLinkApp(),
        ),
      );
      authRepository.controller.add(const AuthUser(id: 'officer'));
      await tester.pump();
      profiles.controller.add(profile());
      await tester.pumpAndSettle();
      router.go(AppRoutes.participants('robotics', 'demo'));
      await tester.pumpAndSettle();
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.textContaining('Participant UID:'), findsNothing);
      expect(find.textContaining('Cancelled'), findsOneWidget);
      expect(events.identityWatches, 1);
      events.identities.emit([]);
      await tester.pumpAndSettle();
      expect(find.text('Unknown Participant'), findsOneWidget);
      events.identities.emit([
        const ParticipantIdentity(uid: 'student', fullName: 'Juan Updated'),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Juan Updated'), findsOneWidget);
      expect(events.identityWatches, 1);
      organizations.allMemberships.emit([
        const Membership(
          uid: 'officer',
          organizationId: 'robotics',
          role: 'officer',
          status: 'removed',
          permissions: {'manageEvents': true},
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Juan Updated'), findsNothing);
      expect(
        find.text('You do not have permission to view participants.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      auth.dispose();
      await events.close();
      await organizations.close();
      await authRepository.controller.close();
      await profiles.controller.close();
    },
  );
  test(
    'owner name refresh preserves active/withdrawn registration state and capacity',
    () async {
      final repository = TestEventRepository(),
          organizations = TestOrganizationRepository();
      final hub = OrganizationHubViewModel(organizations, 'student');
      final eventHub = EventHubViewModel(repository, hub);
      await repository.register('robotics', 'demo', 'student', withdraw: false);
      await flush();
      final original = repository.registrations.value.single;
      repository.profileName = 'Updated Student Name';
      expect(await eventHub.refreshName(original), isTrue);
      expect(
        repository.identities.value.single.fullName,
        'Updated Student Name',
      );
      expect(repository.event.value?.registrationCount, 1);
      expect(
        repository.registrations.value.single.registeredAt,
        original.registeredAt,
      );
      expect(
        repository.registrations.value.single.updatedAt,
        original.updatedAt,
      );
      await repository.register('robotics', 'demo', 'student', withdraw: true);
      final withdrawn = repository.registrations.value.single;
      expect(await eventHub.refreshName(withdrawn), isTrue);
      expect(repository.event.value?.registrationCount, 0);
      expect(repository.registrations.value.single.status, 'cancelled');
      expect(
        repository.registrations.value.single.updatedAt,
        withdrawn.updatedAt,
      );
      eventHub.dispose();
      hub.dispose();
      await repository.close();
      await organizations.close();
    },
  );
}
