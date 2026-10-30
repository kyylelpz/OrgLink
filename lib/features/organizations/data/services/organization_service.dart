import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/organization.dart';
import '../../../memberships/data/models/membership.dart';

class OrganizationService {
  OrganizationService(this._store);
  final FirestoreService _store;
  CollectionReference<Map<String, dynamic>> _collection(String path) =>
      _store.collection<Map<String, dynamic>>(
        path,
        fromFirestore: (snapshot, _) => snapshot.data()!,
        toFirestore: (data, _) => data,
      );
  CollectionReference<Map<String, dynamic>> _members(String id) =>
      _collection('organizations/$id/memberships');
  Stream<List<Organization>> _organizations(
    Query<Map<String, dynamic>> query,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .where((snapshot) => !snapshot.metadata.isFromCache)
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Organization.fromMap(doc.id, doc.data()))
            .toList(),
      );
  Stream<List<Organization>> discover() => _organizations(
    _collection('organizations')
        .where('visibility', isEqualTo: 'public')
        .where('status', isEqualTo: 'active'),
  );
  Stream<List<Organization>> managed(String uid) => _organizations(
    _collection('organizations').where('managerUid', isEqualTo: uid),
  );
  Stream<Organization?> watchOrganization(String id) =>
      _collection('organizations')
          .doc(id)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.isFromCache)
          .map(
            (doc) => doc.data() == null
                ? null
                : Organization.fromMap(doc.id, doc.data()!),
          );
  Stream<List<Membership>> _memberships(Query<Map<String, dynamic>> query) =>
      query
          .snapshots(includeMetadataChanges: true)
          .where(
            (snapshot) =>
                !snapshot.metadata.isFromCache &&
                !snapshot.metadata.hasPendingWrites,
          )
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => Membership.fromMap(doc.data()))
                .toList(),
          );
  Stream<List<Membership>> myMemberships(String uid) => _memberships(
    _store
        .collectionGroup<Map<String, dynamic>>(
          'memberships',
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (data, _) => data,
        )
        .where('uid', isEqualTo: uid),
  );
  Stream<Membership?> watchMembership(String id, String uid) => _members(id)
      .doc(uid)
      .snapshots(includeMetadataChanges: true)
      .where(
        (snapshot) =>
            !snapshot.metadata.isFromCache &&
            !snapshot.metadata.hasPendingWrites,
      )
      .map(
        (doc) => doc.data() == null ? null : Membership.fromMap(doc.data()!),
      );
  Stream<List<Membership>> members(String id, String status) =>
      _memberships(_members(id).where('membershipStatus', isEqualTo: status));
  Stream<List<PublishedEvent>> upcomingEvents(String id) =>
      _collection('organizations/$id/events')
          .where('visibility', isEqualTo: 'public')
          .where('eventStatus', isEqualTo: 'published')
          .where('approvalStatus', isEqualTo: 'approved')
          .where('startAt', isGreaterThanOrEqualTo: Timestamp.now())
          .orderBy('startAt')
          .limit(10)
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => !snapshot.metadata.isFromCache)
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => PublishedEvent.fromMap(doc.id, doc.data()))
                .toList(),
          );

  Future<void> requestMembership(
    String id,
    String uid,
  ) => _store.runTransaction((transaction) async {
    final reference = _members(id).doc(uid);
    final existing = await transaction.get(reference);
    if (existing.exists) {
      throw const AppFailure(
        'A membership record already exists. Reapplication is not available.',
      );
    }
    final org = await transaction.get(_collection('organizations').doc(id));
    final profile = await transaction.get(_collection('users').doc(uid));
    if (!org.exists || !Organization.fromMap(id, org.data()!).acceptsRequests) {
      throw const AppFailure(
        'This organization is not accepting membership requests.',
      );
    }
    if (profile.data()?['accountStatus'] != 'active') {
      throw const AppFailure(
        'Your account is not eligible to request membership.',
      );
    }
    transaction.set(reference, {
      'uid': uid,
      'organizationId': id,
      'membershipRole': 'member',
      'membershipStatus': 'pending',
      'positionTitle': null,
      'permissions': <String, dynamic>{},
      'applicantName': profile.data()?['fullName'] ?? '',
      'requestedAt': FieldValue.serverTimestamp(),
      'joinedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedBy': null,
    });
  });

  Future<void> cancelMembershipRequest(
    String id,
    String uid,
  ) => _store.runTransaction((transaction) async {
    final reference = _members(id).doc(uid);
    final record = await transaction.get(reference);
    if (!record.exists) return;
    final data = record.data()!;
    if (data['uid'] != uid ||
        data['organizationId'] != id ||
        data['membershipStatus'] != 'pending' ||
        data['membershipRole'] != 'member') {
      throw const AppFailure(
        'This request is no longer pending. Refresh your membership status.',
      );
    }
    transaction.delete(reference);
  });

  Future<void> reviewMembership(
    String id,
    String applicantUid,
    String managerUid, {
    required bool approve,
  }) => _store.runTransaction((transaction) async {
    final org = await transaction.get(_collection('organizations').doc(id));
    final reference = _members(id).doc(applicantUid);
    final record = await transaction.get(reference);
    if (org.data()?['managerUid'] != managerUid ||
        org.data()?['status'] != 'active' ||
        applicantUid == managerUid) {
      throw const AppFailure('You are not authorized to review this request.');
    }
    if (record.data()?['membershipStatus'] != 'pending') {
      throw const AppFailure('This request has already been reviewed.');
    }
    transaction.update(reference, {
      'membershipStatus': approve ? 'active' : 'rejected',
      'joinedAt': approve ? FieldValue.serverTimestamp() : null,
      'updatedAt': FieldValue.serverTimestamp(),
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': managerUid,
    });
  });
}
