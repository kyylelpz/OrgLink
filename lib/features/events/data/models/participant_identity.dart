import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../organizations/data/models/organization.dart';

/// Event-scoped display information, separate from private student profiles.
class ParticipantIdentity {
  const ParticipantIdentity({
    required this.uid,
    required this.fullName,
    this.updatedAt,
  });
  final String uid, fullName;
  final DateTime? updatedAt;
  factory ParticipantIdentity.fromMap(String uid, Map<String, dynamic> data) =>
      ParticipantIdentity(
        uid: uid,
        fullName: textValue(data['fullName']).trim(),
        updatedAt: firestoreDate(data['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'fullName': fullName,
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };
}
