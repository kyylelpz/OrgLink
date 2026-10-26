import '../models/organization.dart';
import '../../../memberships/data/models/membership.dart';

abstract interface class OrganizationRepository {
  Stream<List<Organization>> discover();
  Stream<List<Organization>> managed(String uid);
  Stream<Organization?> watchOrganization(String id);
  Stream<List<Membership>> myMemberships(String uid);
  Stream<Membership?> watchMembership(String id, String uid);
  Stream<List<Membership>> members(String id, String status);
  Stream<List<PublishedEvent>> upcomingEvents(String id);
  Future<void> requestMembership(String id, String uid);
  Future<void> reviewMembership(
    String id,
    String applicantUid,
    String managerUid, {
    required bool approve,
  });
}
