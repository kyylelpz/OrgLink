import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../organizations/data/models/organization.dart';

class Membership {
  const Membership({
    required this.uid,
    required this.organizationId,
    required this.role,
    required this.status,
    this.positionTitle,
    this.permissions = const {},
    this.applicantName = '',
    this.requestedAt,
    this.joinedAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.endedAt,
    this.endedBy,
    this.endReason,
  });
  final String uid, organizationId, role, status, applicantName;
  final String? positionTitle, reviewedBy;
  final Map<String, dynamic> permissions;
  final DateTime? requestedAt, joinedAt, updatedAt, reviewedAt;
  final DateTime? endedAt;
  final String? endedBy, endReason;
  bool get canViewRoster =>
      status == 'active' && permissions['viewRoster'] == true;
  String get statusLabel => status == 'active' ? 'Approved (active)' : status;
  factory Membership.fromMap(Map<String, dynamic> data) => Membership(
    uid: textValue(data['uid']),
    organizationId: textValue(data['organizationId']),
    role: textValue(data['membershipRole']),
    status: textValue(data['membershipStatus']),
    positionTitle: data['positionTitle'] is String
        ? data['positionTitle'] as String
        : null,
    permissions: mapValue(data['permissions']),
    applicantName: textValue(data['applicantName']),
    requestedAt: firestoreDate(data['requestedAt']),
    joinedAt: firestoreDate(data['joinedAt']),
    updatedAt: firestoreDate(data['updatedAt']),
    reviewedAt: firestoreDate(data['reviewedAt']),
    reviewedBy: data['reviewedBy'] is String
        ? data['reviewedBy'] as String
        : null,
    endedAt: firestoreDate(data['endedAt']),
    endedBy: data['endedBy'] as String?,
    endReason: data['endReason'] as String?,
  );
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'organizationId': organizationId,
    'membershipRole': role,
    'membershipStatus': status,
    'positionTitle': positionTitle,
    'permissions': permissions,
    'applicantName': applicantName,
    'requestedAt': _timestamp(requestedAt),
    'joinedAt': _timestamp(joinedAt),
    'updatedAt': _timestamp(updatedAt),
    'reviewedAt': _timestamp(reviewedAt),
    'reviewedBy': reviewedBy,
    if (endedAt != null) 'endedAt': _timestamp(endedAt),
    if (endedBy != null) 'endedBy': endedBy,
    if (endReason != null) 'endReason': endReason,
  };
  static Timestamp? _timestamp(DateTime? value) =>
      value == null ? null : Timestamp.fromDate(value);
}
