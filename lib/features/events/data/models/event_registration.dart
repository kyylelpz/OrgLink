import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../organizations/data/models/organization.dart';

class EventRegistration {
  const EventRegistration({
    required this.uid,
    required this.eventId,
    required this.organizationId,
    required this.status,
    this.registeredAt,
    this.updatedAt,
  });
  final String uid, eventId, organizationId, status;
  final DateTime? registeredAt, updatedAt;
  factory EventRegistration.fromMap(Map<String, dynamic> data) =>
      EventRegistration(
        uid: textValue(data['uid']),
        eventId: textValue(data['eventId']),
        organizationId: textValue(data['organizationId']),
        status: textValue(data['registrationStatus']),
        registeredAt: firestoreDate(data['registeredAt']),
        updatedAt: firestoreDate(data['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'eventId': eventId,
    'organizationId': organizationId,
    'registrationStatus': status,
    'registeredAt': registeredAt == null
        ? null
        : Timestamp.fromDate(registeredAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };
}
