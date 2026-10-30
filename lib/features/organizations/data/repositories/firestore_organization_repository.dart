import '../../../../core/errors/app_failure.dart';
import '../../../memberships/data/models/membership.dart';
import '../models/organization.dart';
import '../services/organization_service.dart';
import 'organization_repository.dart';

class FirestoreOrganizationRepository implements OrganizationRepository {
  FirestoreOrganizationRepository(this._service);
  final OrganizationService _service;
  Stream<T> _guard<T>(Stream<T> source) async* {
    try {
      yield* source;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Stream<List<Organization>> discover() => _guard(_service.discover());
  @override
  Stream<List<Organization>> managed(String uid) =>
      _guard(_service.managed(uid));
  @override
  Stream<Organization?> watchOrganization(String id) =>
      _guard(_service.watchOrganization(id));
  @override
  Stream<List<Membership>> myMemberships(String uid) =>
      _guard(_service.myMemberships(uid));
  @override
  Stream<Membership?> watchMembership(String id, String uid) =>
      _guard(_service.watchMembership(id, uid));
  @override
  Stream<List<Membership>> members(String id, String status) =>
      _guard(_service.members(id, status));
  @override
  Stream<List<PublishedEvent>> upcomingEvents(String id) =>
      _guard(_service.upcomingEvents(id));
  @override
  Future<void> requestMembership(String id, String uid) async {
    try {
      await _service.requestMembership(id, uid);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> cancelMembershipRequest(String id, String uid) async {
    try {
      await _service.cancelMembershipRequest(id, uid);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<void> reviewMembership(
    String id,
    String applicantUid,
    String managerUid, {
    required bool approve,
  }) async {
    try {
      await _service.reviewMembership(
        id,
        applicantUid,
        managerUid,
        approve: approve,
      );
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  @override
  Future<Map<String, dynamic>> membershipCommand(
    String operation,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _service.membershipCommand(operation, data);
    } catch (error) {
      throw AppFailure.from(error);
    }
  }
}
