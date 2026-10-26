import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../organizations/data/models/organization.dart';

class EventDraft {
  const EventDraft({
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.venue,
    required this.capacity,
    required this.registrationDeadline,
    required this.visibility,
    this.posterURL,
  });
  final String title, description, venue, visibility;
  final String? posterURL;
  final DateTime startAt, endAt, registrationDeadline;
  final int capacity;
  static String? requiredText(String? value, {int maximum = 200}) =>
      value == null || value.trim().isEmpty || value.trim().length > maximum
      ? 'Enter 1-$maximum characters.'
      : null;
  String? validate(DateTime now) {
    if (requiredText(title) != null ||
        requiredText(description, maximum: 5000) != null ||
        requiredText(venue) != null) {
      return 'Complete the title, description and venue.';
    }
    if (!startAt.isAfter(now) || !endAt.isAfter(startAt)) {
      return 'Start must be in the future and end must follow start.';
    }
    if (!registrationDeadline.isAfter(now) ||
        registrationDeadline.isAfter(startAt)) {
      return 'Registration deadline must be in the future and no later than the start.';
    }
    if (capacity < 1 || capacity > 100000) {
      return 'Capacity must be between 1 and 100000.';
    }
    if (!['public', 'private'].contains(visibility)) {
      return 'Choose event visibility.';
    }
    if (posterURL != null && posterURL!.isNotEmpty) {
      if (posterURL!.length > 2048) {
        return 'Poster URL must be at most 2048 characters.';
      }
      final uri = Uri.tryParse(posterURL!);
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        return 'Poster URL must be an HTTPS address.';
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'title': title.trim(),
    'description': description.trim(),
    'posterURL': posterURL == null || posterURL!.trim().isEmpty
        ? null
        : posterURL!.trim(),
    'startAt': Timestamp.fromDate(startAt),
    'endAt': Timestamp.fromDate(endAt),
    'venue': venue.trim(),
    'capacity': capacity,
    'registrationDeadline': Timestamp.fromDate(registrationDeadline),
    'visibility': visibility,
  };
}

class OrgEvent {
  const OrgEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.description,
    required this.venue,
    required this.capacity,
    required this.registrationCount,
    required this.eventStatus,
    required this.approvalStatus,
    required this.createdBy,
    required this.visibility,
    this.posterURL,
    this.startAt,
    this.endAt,
    this.registrationDeadline,
    this.createdAt,
    this.updatedAt,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.publishedAt,
    this.cancelledAt,
    this.completedAt,
    this.archivedAt,
  });
  final String id,
      organizationId,
      title,
      description,
      venue,
      eventStatus,
      approvalStatus,
      createdBy,
      visibility;
  final String? posterURL, reviewedBy;
  final int capacity, registrationCount;
  final DateTime? startAt,
      endAt,
      registrationDeadline,
      createdAt,
      updatedAt,
      submittedAt,
      reviewedAt,
      publishedAt,
      cancelledAt,
      completedAt,
      archivedAt;
  int get availableSlots =>
      (capacity - registrationCount).clamp(0, capacity < 0 ? 0 : capacity);
  bool registrationOpen(DateTime now) =>
      eventStatus == 'published' &&
      approvalStatus == 'approved' &&
      registrationDeadline != null &&
      now.isBefore(registrationDeadline!) &&
      startAt != null &&
      now.isBefore(startAt!) &&
      availableSlots > 0;
  EventDraft? get draft =>
      startAt == null || endAt == null || registrationDeadline == null
      ? null
      : EventDraft(
          title: title,
          description: description,
          startAt: startAt!,
          endAt: endAt!,
          venue: venue,
          capacity: capacity,
          registrationDeadline: registrationDeadline!,
          visibility: visibility,
          posterURL: posterURL,
        );
  factory OrgEvent.fromMap(
    String id,
    String organizationId,
    Map<String, dynamic> data,
  ) => OrgEvent(
    id: id,
    organizationId: organizationId,
    title: textValue(data['title'], 'Untitled event'),
    description: textValue(data['description']),
    venue: textValue(data['venue']),
    capacity: data['capacity'] is int ? data['capacity'] as int : 0,
    registrationCount: data['registrationCount'] is int
        ? data['registrationCount'] as int
        : 0,
    eventStatus: textValue(data['eventStatus']),
    approvalStatus: textValue(data['approvalStatus']),
    createdBy: textValue(data['createdBy']),
    visibility: textValue(data['visibility'], 'public'),
    posterURL: data['posterURL'] is String ? data['posterURL'] as String : null,
    startAt: firestoreDate(data['startAt']),
    endAt: firestoreDate(data['endAt']),
    registrationDeadline: firestoreDate(data['registrationDeadline']),
    createdAt: firestoreDate(data['createdAt']),
    updatedAt: firestoreDate(data['updatedAt']),
    submittedAt: firestoreDate(data['submittedAt']),
    reviewedAt: firestoreDate(data['reviewedAt']),
    reviewedBy: data['reviewedBy'] is String
        ? data['reviewedBy'] as String
        : null,
    publishedAt: firestoreDate(data['publishedAt']),
    cancelledAt: firestoreDate(data['cancelledAt']),
    completedAt: firestoreDate(data['completedAt']),
    archivedAt: firestoreDate(data['archivedAt']),
  );
  Map<String, dynamic> toMap() => {
    'eventId': id,
    'organizationId': organizationId,
    'title': title,
    'description': description,
    'venue': venue,
    'posterURL': posterURL,
    'visibility': visibility,
    'capacity': capacity,
    'registrationCount': registrationCount,
    'eventStatus': eventStatus,
    'approvalStatus': approvalStatus,
    'createdBy': createdBy,
    for (final entry in <String, DateTime?>{
      'startAt': startAt,
      'endAt': endAt,
      'registrationDeadline': registrationDeadline,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'submittedAt': submittedAt,
      'reviewedAt': reviewedAt,
      'publishedAt': publishedAt,
      'cancelledAt': cancelledAt,
      'completedAt': completedAt,
      'archivedAt': archivedAt,
    }.entries)
      entry.key: entry.value == null ? null : Timestamp.fromDate(entry.value!),
    'reviewedBy': reviewedBy,
  };
}
