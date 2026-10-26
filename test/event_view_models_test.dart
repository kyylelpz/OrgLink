import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_context_view_model.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_hub_view_model.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'event models preserve Firestore timestamps and required validation',
    () {
      final original = sampleEvent();
      final copy = OrgEvent.fromMap('demo', 'robotics', original.toMap());
      expect(copy.startAt?.isAtSameMomentAs(original.startAt!), isTrue);
      expect(sampleDraft().validate(DateTime.now()), isNull);
      final invalid = EventDraft(
        title: '',
        description: '',
        startAt: DateTime.now(),
        endAt: DateTime.now(),
        venue: '',
        capacity: 0,
        registrationDeadline: DateTime.now(),
        visibility: 'public',
      );
      expect(invalid.validate(DateTime.now()), isNotNull);
      expect(
        OrgEvent.fromMap(
          'legacy',
          'robotics',
          {},
        ).registrationOpen(DateTime.now()),
        isFalse,
      );
    },
  );
  test(
    'members cannot create; assigned active event officer can create only own editable drafts',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      repo.event.emit(
        sampleEvent(status: 'draft', approval: 'pending', creator: 'student'),
      );
      final model = EventContextViewModel(
        repo,
        orgs,
        'robotics',
        'student',
        eventId: 'demo',
      );
      await flush();
      expect(model.canCreate, isFalse);
      expect(model.canEdit, isFalse);
      orgs.allMemberships.emit([
        const Membership(
          uid: 'student',
          organizationId: 'robotics',
          role: 'officer',
          status: 'active',
          permissions: {'manageEvents': true},
        ),
      ]);
      await flush();
      expect(model.canCreate, isTrue);
      expect(model.canEdit, isTrue);
      expect(model.canReview, isFalse);
      expect(model.canPublish, isFalse);
      repo.event.emit(
        sampleEvent(status: 'draft', approval: 'pending', creator: 'manager'),
      );
      await flush();
      expect(model.canEdit, isFalse);
      model.dispose();
      await orgs.close();
      await repo.close();
    },
  );
  test(
    'manager may self-approve submitted drafts; edit invalidates approval',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      repo.event.emit(sampleEvent(status: 'draft', approval: 'pending'));
      final model = EventContextViewModel(
        repo,
        orgs,
        'robotics',
        'manager',
        eventId: 'demo',
      );
      await flush();
      expect(model.canEdit, isTrue);
      expect(model.canReview, isFalse);
      await model.act('submit');
      await flush();
      expect(model.canReview, isTrue);
      expect(model.canEdit, isFalse);
      await model.act('approve');
      await flush();
      expect(model.canPublish, isTrue);
      await model.save(sampleDraft());
      await flush();
      expect(model.canPublish, isFalse);
      expect(repo.event.value?.approvalStatus, 'pending');
      model.dispose();
      await orgs.close();
      await repo.close();
    },
  );
  test(
    'registration prevents duplicate submissions, withdrawal preserves timestamp, re-registration works',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      final model = EventContextViewModel(
        repo,
        orgs,
        'robotics',
        'student',
        eventId: 'demo',
      );
      await flush();
      repo.operationGate = Completer<void>();
      final first = model.register(withdraw: false);
      expect(await model.register(withdraw: false), isFalse);
      repo.operationGate!.complete();
      expect(await first, isTrue);
      await flush();
      final original = model.registration!.value!.registeredAt;
      expect(model.canRegister, isFalse);
      expect(model.canWithdraw, isTrue);
      await model.register(withdraw: true);
      await flush();
      expect(model.registration!.value?.status, 'cancelled');
      await model.register(withdraw: false);
      await flush();
      expect(model.registration!.value?.registeredAt, original);
      expect(repo.event.value?.registrationCount, 1);
      model.dispose();
      await orgs.close();
      await repo.close();
    },
  );
  test(
    'private registration requires active membership and revoked officers lose controls',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      repo.event.emit(sampleEvent(visibility: 'private'));
      final model = EventContextViewModel(
        repo,
        orgs,
        'robotics',
        'student',
        eventId: 'demo',
      );
      await flush();
      expect(model.canRegister, isFalse);
      orgs.allMemberships.emit([
        const Membership(
          uid: 'student',
          organizationId: 'robotics',
          role: 'officer',
          status: 'active',
          permissions: {'manageEvents': true},
        ),
      ]);
      await flush();
      expect(model.canRegister, isTrue);
      expect(model.canCreate, isTrue);
      orgs.allMemberships.emit([
        const Membership(
          uid: 'student',
          organizationId: 'robotics',
          role: 'officer',
          status: 'removed',
          permissions: {'manageEvents': true},
        ),
      ]);
      await flush();
      expect(model.canRegister, isFalse);
      expect(model.canCreate, isFalse);
      model.dispose();
      await orgs.close();
      await repo.close();
    },
  );
  test(
    'operation errors do not fake a registration and can be retried',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      final model = EventContextViewModel(
        repo,
        orgs,
        'robotics',
        'student',
        eventId: 'demo',
      );
      await flush();
      repo.failure = const AppFailure('Offline');
      expect(await model.register(withdraw: false), isFalse);
      expect(model.failure?.message, 'Offline');
      expect(model.registration!.value, isNull);
      expect(model.busy, isFalse);
      model.dispose();
      await orgs.close();
      await repo.close();
    },
  );
  test(
    'catalog search, membership-sensitive privacy and My Events follow repository streams',
    () async {
      final orgs = TestOrganizationRepository(), repo = TestEventRepository();
      final hub = OrganizationHubViewModel(orgs, 'student');
      final model = EventHubViewModel(repo, hub);
      await flush();
      await flush();
      expect(model.results.length, 1);
      model.filter(text: 'missing');
      expect(model.results, isEmpty);
      model.filter(text: 'demo');
      expect(model.results.length, 1);
      await repo.register('robotics', 'demo', 'student', withdraw: false);
      await flush();
      expect(model.mine.value?.single.status, 'registered');
      expect(
        model.registeredEvents['robotics/demo']?.value?.title,
        'Demo Event',
      );
      repo.event.emit(sampleEvent(visibility: 'private'));
      await flush();
      expect(model.results, isEmpty);
      orgs.allMemberships.emit([
        const Membership(
          uid: 'student',
          organizationId: 'robotics',
          role: 'member',
          status: 'active',
        ),
      ]);
      await flush();
      await flush();
      expect(model.results.length, 1);
      model.dispose();
      hub.dispose();
      await orgs.close();
      await repo.close();
    },
  );
}
