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
  int requestCalls = 0, reviewCalls = 0, discoverCalls = 0, cancelCalls = 0;
  Completer<void>? requestGate, reviewGate, cancelGate;
  Object? requestError, reviewError, cancelError;
  final managementCalls = <Map<String, dynamic>>[];
  Object? managementError;
  int membershipVersion = 1;
  @override
  Future<Map<String, dynamic>> membershipCommand(
    String operation,
    Map<String, dynamic> data,
  ) async {
    if (managementError case final error?) throw error;
    final member = allMemberships.value.firstWhere(
      (m) =>
          m.uid == data['participantUid'] &&
          m.organizationId == data['organizationId'],
    );
    if (operation == 'preview') {
      final value = member.toMap();
      for (final key in [
        'requestedAt',
        'joinedAt',
        'updatedAt',
        'reviewedAt',
        'endedAt',
      ]) {
        value[key] = {
          'requestedAt': member.requestedAt,
          'joinedAt': member.joinedAt,
          'updatedAt': member.updatedAt,
          'reviewedAt': member.reviewedAt,
          'endedAt': member.endedAt,
        }[key]?.millisecondsSinceEpoch;
      }
      return {'version': 'v$membershipVersion', 'membership': value};
    }
    managementCalls.add(Map.from(data));
    if (data['version'] != 'v$membershipVersion') {
      throw const AppFailure('Membership changed.');
    }
    final changed = Membership.fromMap({
      ...member.toMap(),
      if (data['operation'] == 'end') ...{
        'membershipStatus': 'removed',
        'permissions': <String, dynamic>{},
        'endedAt': DateTime.now(),
        'endedBy': 'manager',
        'endReason': data['reason'],
      },
      if (data['operation'] == 'role') ...{
        'membershipRole': data['role'],
        'positionTitle': data['positionTitle'],
        'permissions': data['role'] == 'member'
            ? <String, dynamic>{}
            : member.permissions,
      },
      if (data['operation'] == 'permissions')
        'permissions': data['permissions'],
    });
    membershipVersion++;
    allMemberships.emit([
      for (final m in allMemberships.value)
        if (m.uid == member.uid && m.organizationId == member.organizationId)
          changed
        else
          m,
    ]);
    return {'saved': true};
  }

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
      (member) =>
          member.uid == uid &&
          member.organizationId == id &&
          member.status != 'removed',
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
    allMemberships.emit([
      ...allMemberships.value.where(
        (m) => m.uid != uid || m.organizationId != id,
      ),
      member,
    ]);
  }

  @override
  Future<void> cancelMembershipRequest(String id, String uid) async {
    cancelCalls++;
    await cancelGate?.future;
    if (cancelError case final error?) throw error;
    final matches = allMemberships.value.where(
      (member) => member.uid == uid && member.organizationId == id,
    );
    if (matches.isEmpty) return;
    if (matches.single.status != 'pending' || matches.single.role != 'member') {
      throw const AppFailure('This request is no longer pending.');
    }
    allMemberships.emit([
      for (final member in allMemberships.value)
        if (member.uid != uid || member.organizationId != id) member,
    ]);
    own.emit(null);
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
