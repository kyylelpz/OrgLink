import 'dart:async';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/memberships/data/models/membership.dart';

class TestFeed<T> {
  TestFeed(this.value);
  T value;
  final controller = StreamController<T>.broadcast();
  Stream<T> watch() => Stream.multi((sink) {
    sink.add(value);
    final subscription = controller.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.onCancel = subscription.cancel;
  });
  void emit(T data) {
    value = data;
    controller.add(data);
  }

  void fail(Object error) => controller.addError(error);
  Future<void> close() => controller.close();
}

const demoOrg = Organization(
  id: 'robotics',
  name: 'Demo Robotics',
  description: 'Build together',
  visibility: 'public',
  status: 'active',
  managerUid: 'manager',
  approvalSettings: {'acceptsRequests': true},
);
const otherOrg = Organization(
  id: 'creative',
  name: 'Demo Creative',
  description: 'Create together',
  visibility: 'public',
  status: 'active',
  managerUid: 'other',
  approvalSettings: {'acceptsRequests': true},
);

class TestOrganizationRepository implements OrganizationRepository {
  final organizations = TestFeed<List<Organization>>([demoOrg, otherOrg]);
  final allMemberships = TestFeed<List<Membership>>([]);
  final document = TestFeed<Organization?>(demoOrg);
  final own = TestFeed<Membership?>(null);
  final events = TestFeed<List<PublishedEvent>>([]);
  int requestCalls = 0, reviewCalls = 0, discoverCalls = 0;
  Completer<void>? requestGate, reviewGate;
  Object? requestError, reviewError;
  @override
  Stream<List<Organization>> discover() {
    discoverCalls++;
    return organizations.watch();
  }

  @override
  Stream<List<Organization>> managed(String uid) => organizations.watch().map(
    (values) => values.where((org) => org.managerUid == uid).toList(),
  );
  @override
  Stream<Organization?> watchOrganization(String id) =>
      document.watch().map((_) => id == 'robotics' ? document.value : otherOrg);
  @override
  Stream<List<Membership>> myMemberships(String uid) => allMemberships
      .watch()
      .map((values) => values.where((member) => member.uid == uid).toList());
  @override
  Stream<Membership?> watchMembership(String id, String uid) =>
      allMemberships.watch().map((values) {
        for (final member in values) {
          if (member.organizationId == id && member.uid == uid) return member;
        }
        return null;
      });
  @override
  Stream<List<Membership>> members(String id, String status) =>
      allMemberships.watch().map(
        (values) => values
            .where(
              (member) =>
                  member.organizationId == id && member.status == status,
            )
            .toList(),
      );
  @override
  Stream<List<PublishedEvent>> upcomingEvents(String id) => events.watch();
  @override
  Future<void> requestMembership(String id, String uid) async {
    requestCalls++;
    await requestGate?.future;
    if (requestError case final error?) throw error;
    if (allMemberships.value.any(
      (member) => member.uid == uid && member.organizationId == id,
    )) {
      throw const AppFailure('Already requested');
    }
    final member = Membership(
      uid: uid,
      organizationId: id,
      role: 'member',
      status: 'pending',
      applicantName: 'Demo Student',
      requestedAt: DateTime(2026, 10, 26),
    );
    own.emit(member);
    allMemberships.emit([...allMemberships.value, member]);
  }

  @override
  Future<void> reviewMembership(
    String id,
    String applicantUid,
    String managerUid, {
    required bool approve,
  }) async {
    reviewCalls++;
    await reviewGate?.future;
    if (reviewError case final error?) throw error;
    final member = Membership(
      uid: applicantUid,
      organizationId: id,
      role: 'member',
      status: approve ? 'active' : 'rejected',
      applicantName: 'Demo Student',
      joinedAt: approve ? DateTime(2026, 10, 26) : null,
    );
    allMemberships.emit([
      for (final existing in allMemberships.value)
        if (existing.uid != applicantUid || existing.organizationId != id)
          existing,
      member,
    ]);
    own.emit(member);
  }

  Future<void> close() async {
    await organizations.close();
    await allMemberships.close();
    await document.close();
    await own.close();
    await events.close();
  }
}
