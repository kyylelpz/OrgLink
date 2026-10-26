import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/utils/live_query.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_hub_view_model.dart';
import 'package:orglink/features/organizations/presentation/viewmodels/organization_details_view_model.dart';
import 'package:orglink/features/memberships/presentation/viewmodels/member_list_view_model.dart';
import 'support/test_organization_repository.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);
void main() {
  test('typed model round trips timestamps and optional fields', () {
    final org = Organization.fromMap('id', {
      'name': 'Demo',
      'goals': ['one', 4],
      'createdAt': null,
      'publicOfficers': [
        {'name': 'Demo President', 'positionTitle': 'President'},
      ],
    });
    expect(org.goals, ['one']);
    expect(org.acceptsRequests, isFalse);
    expect(org.logoURL, isNull);
    expect(
      Organization.fromMap('id', org.toMap()).publicOfficers.single.name,
      'Demo President',
    );
    final member = Membership(
      uid: 'student',
      organizationId: 'id',
      role: 'member',
      status: 'pending',
      requestedAt: DateTime.utc(2026),
    );
    final copy = Membership.fromMap(member.toMap());
    expect(copy.requestedAt, member.requestedAt);
    expect(copy.canViewRoster, isFalse);
    expect(Membership.fromMap({}).status, '');
  });
  test('search and membership updates reuse discovery listener', () async {
    final repo = TestOrganizationRepository();
    final model = OrganizationHubViewModel(repo, 'student');
    await flush();
    expect(model.results.length, 2);
    model.searchFor('ROBOT');
    expect(model.results.single.id, 'robotics');
    await repo.requestMembership('robotics', 'student');
    await flush();
    expect(model.membership('robotics')?.status, 'pending');
    expect(model.associated['robotics']?.value?.name, 'Demo Robotics');
    expect(repo.discoverCalls, 1);
    model.dispose();
    await repo.close();
  });
  test(
    'duplicate join submissions and terminal memberships stay blocked',
    () async {
      final repo = TestOrganizationRepository();
      final model = OrganizationDetailsViewModel(repo, 'robotics', 'student');
      await flush();
      repo.requestGate = Completer<void>();
      final first = model.request();
      expect(await model.request(), isFalse);
      repo.requestGate!.complete();
      expect(await first, isTrue);
      await flush();
      expect(model.canRequest, isFalse);
      expect(repo.requestCalls, 1);
      for (final status in ['pending', 'active', 'rejected', 'removed']) {
        repo.allMemberships.emit([
          Membership(
            uid: 'student',
            organizationId: 'robotics',
            role: 'member',
            status: status,
          ),
        ]);
        await flush();
        expect(model.canRequest, isFalse);
      }
      model.dispose();
      await repo.close();
    },
  );
  test(
    'join failures expose a retryable error and do not invent membership',
    () async {
      final repo = TestOrganizationRepository();
      final model = OrganizationDetailsViewModel(repo, 'robotics', 'student');
      await flush();
      repo.requestError = const AppFailure('Offline');
      expect(await model.request(), isFalse);
      expect(model.actionFailure?.message, 'Offline');
      expect(model.canRequest, isTrue);
      model.dispose();
      await repo.close();
    },
  );
  test('role labels alone do not grant manager or roster controls', () async {
    final repo = TestOrganizationRepository();
    final model = OrganizationDetailsViewModel(repo, 'robotics', 'student');
    await flush();
    repo.allMemberships.emit([
      const Membership(
        uid: 'student',
        organizationId: 'robotics',
        role: 'officer',
        status: 'active',
      ),
    ]);
    await flush();
    expect(model.isManager, isFalse);
    expect(model.canViewRoster, isFalse);
    repo.allMemberships.emit([
      const Membership(
        uid: 'student',
        organizationId: 'robotics',
        role: 'officer',
        status: 'active',
        permissions: {'viewRoster': true},
      ),
    ]);
    await flush();
    expect(model.canViewRoster, isTrue);
    expect(model.isManager, isFalse);
    model.dispose();
    await repo.close();
  });
  test(
    'review prevents duplicate operations and self-approval; errors remain visible',
    () async {
      final repo = TestOrganizationRepository();
      final model = MemberListViewModel(
        repo,
        'robotics',
        'manager',
        pending: true,
      );
      await flush();
      const member = Membership(
        uid: 'student',
        organizationId: 'robotics',
        role: 'member',
        status: 'pending',
      );
      expect(
        await model.review(
          const Membership(
            uid: 'manager',
            organizationId: 'robotics',
            role: 'member',
            status: 'pending',
          ),
          approve: true,
        ),
        isFalse,
      );
      repo.reviewGate = Completer<void>();
      final first = model.review(member, approve: true);
      expect(await model.review(member, approve: false), isFalse);
      repo.reviewGate!.complete();
      expect(await first, isTrue);
      expect(repo.reviewCalls, 1);
      repo.reviewError = const AppFailure('Permission denied');
      expect(await model.review(member, approve: false), isFalse);
      expect(model.failure?.message, 'Permission denied');
      model.dispose();
      await repo.close();
    },
  );
  test(
    'query errors clear data and retry with one replacement listener',
    () async {
      final feed = TestFeed<int>(1);
      final query = LiveQuery(feed.watch);
      await flush();
      expect(query.value, 1);
      feed.fail(const AppFailure('Unavailable'));
      await flush();
      expect(query.value, isNull);
      expect(query.failure?.message, 'Unavailable');
      query.retry();
      await flush();
      expect(query.value, 1);
      expect(query.failure, isNull);
      query.dispose();
      await feed.close();
    },
  );
}
