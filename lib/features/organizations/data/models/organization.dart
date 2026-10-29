import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? firestoreDate(Object? value) => value is Timestamp
    ? value.toDate().toUtc()
    : value is DateTime
    ? value
    : null;
String textValue(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;
List<String> textList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];
Map<String, dynamic> mapValue(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.description,
    required this.visibility,
    required this.status,
    required this.managerUid,
    this.logoURL,
    this.logoPublicId,
    this.mission = '',
    this.vision = '',
    this.goals = const [],
    this.membershipRequirements = const [],
    this.approvalSettings = const {},
    this.positions = const [],
    this.publicOfficers = const [],
    this.createdAt,
    this.updatedAt,
  });
  final String id, name, description, visibility, status, managerUid;
  final String? logoURL, logoPublicId;
  final String mission, vision;
  final List<String> goals, membershipRequirements, positions;
  final Map<String, dynamic> approvalSettings;
  // Explicitly published names/titles, never private profile documents.
  final List<PublicOfficer> publicOfficers;
  final DateTime? createdAt, updatedAt;
  bool get acceptsRequests =>
      status == 'active' &&
      visibility == 'public' &&
      approvalSettings['acceptsRequests'] == true;
  factory Organization.fromMap(String id, Map<String, dynamic> data) =>
      Organization(
        id: id,
        name: textValue(data['name'], 'Unnamed organization'),
        description: textValue(data['description']),
        logoURL: data['logoURL'] is String ? data['logoURL'] as String : null,
        logoPublicId: data['logoPublicId'] is String
            ? data['logoPublicId'] as String
            : null,
        visibility: textValue(data['visibility']),
        status: textValue(data['status']),
        managerUid: textValue(data['managerUid']),
        mission: textValue(data['mission']),
        vision: textValue(data['vision']),
        goals: textList(data['goals']),
        membershipRequirements: textList(data['membershipRequirements']),
        approvalSettings: mapValue(data['approvalSettings']),
        positions: textList(data['positions']),
        publicOfficers: data['publicOfficers'] is List
            ? (data['publicOfficers'] as List)
                  .whereType<Map>()
                  .map(
                    (entry) => PublicOfficer(
                      textValue(entry['name']),
                      textValue(entry['positionTitle']),
                    ),
                  )
                  .toList()
            : const [],
        createdAt: firestoreDate(data['createdAt']),
        updatedAt: firestoreDate(data['updatedAt']),
      );
  Map<String, dynamic> toMap() => {
    'organizationId': id,
    'name': name,
    'description': description,
    'logoURL': logoURL,
    if (logoPublicId != null) 'logoPublicId': logoPublicId,
    'mission': mission,
    'vision': vision,
    'goals': goals,
    'visibility': visibility,
    'status': status,
    'managerUid': managerUid,
    'membershipRequirements': membershipRequirements,
    'approvalSettings': approvalSettings,
    'positions': positions,
    'publicOfficers': [
      for (final officer in publicOfficers)
        {'name': officer.name, 'positionTitle': officer.positionTitle},
    ],
    'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
    'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
  };
}

class PublicOfficer {
  const PublicOfficer(this.name, this.positionTitle);
  final String name, positionTitle;
}

class PublishedEvent {
  const PublishedEvent(this.id, this.title, this.startAt);
  final String id, title;
  final DateTime? startAt;
  factory PublishedEvent.fromMap(String id, Map<String, dynamic> data) =>
      PublishedEvent(
        id,
        textValue(data['title'], 'Untitled event'),
        firestoreDate(data['startAt']),
      );
}
