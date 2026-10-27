import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../organizations/data/models/organization.dart';
import '../../../memberships/data/models/membership.dart';
import '../../../events/data/models/event.dart';
import '../../../events/data/models/event_registration.dart';

bool canManageAttendance(Organization? org, Membership? member, String uid) =>
    org != null &&
    org.status == 'active' &&
    (org.managerUid == uid ||
        (member?.organizationId == org.id &&
            member?.uid == uid &&
            member?.status == 'active' &&
            member?.role == 'officer' &&
            member?.permissions['manageAttendance'] == true));

// A UI hint only; Rules and the backend enforce authoritative server time.
bool attendanceWindow(OrgEvent event, DateTime now) =>
    attendanceUnavailableReason(event, now) == null;

String? attendanceUnavailableReason(OrgEvent event, DateTime now) {
  if (event.eventStatus != 'published') return 'This event is not published.';
  if (event.approvalStatus != 'approved') return 'This event is not approved.';
  if (event.publishedAt == null) {
    return 'The event publication timestamp is missing. Contact the organizer.';
  }
  if (event.archivedAt != null) return 'This event has been archived.';
  if (event.startAt == null || event.endAt == null) {
    return 'The event schedule is incomplete. Contact the organizer.';
  }
  if (now.isBefore(event.startAt!)) return 'Attendance has not opened yet.';
  if (!now.isBefore(event.endAt!)) return 'The attendance window has closed.';
  return null;
}

enum AttendanceStatus { present, absent }

enum VerificationMethod { manual, qr }

class AttendanceRecord {
  const AttendanceRecord({
    required this.uid,
    required this.eventId,
    required this.organizationId,
    required this.status,
    required this.verifiedAt,
    required this.verifiedBy,
    required this.method,
  });
  final String uid, eventId, organizationId, verifiedBy;
  final AttendanceStatus status;
  final VerificationMethod method;
  final DateTime verifiedAt;
  factory AttendanceRecord.fromMap(Map<String, dynamic> data) =>
      AttendanceRecord(
        uid: data['uid'] as String,
        eventId: data['eventId'] as String,
        organizationId: data['organizationId'] as String,
        status: AttendanceStatus.values.byName(
          data['attendanceStatus'] as String,
        ),
        verifiedAt:
            firestoreDate(data['verifiedAt']) ??
            (throw const FormatException('Missing verification time.')),
        verifiedBy: data['verifiedBy'] as String,
        method: VerificationMethod.values.byName(
          data['verificationMethod'] as String,
        ),
      );
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'eventId': eventId,
    'organizationId': organizationId,
    'attendanceStatus': status.name,
    'verifiedAt': Timestamp.fromDate(verifiedAt),
    'verifiedBy': verifiedBy,
    'verificationMethod': method.name,
  };
}

class AttendanceSummary {
  AttendanceSummary(
    Iterable<EventRegistration> registrations,
    Iterable<AttendanceRecord> records,
  ) {
    final active = registrations
        .where((r) => r.status == 'registered')
        .map((r) => r.uid)
        .toSet();
    final unique = {for (final record in records) record.uid: record};
    registered = active.length;
    present = active
        .where((uid) => unique[uid]?.status == AttendanceStatus.present)
        .length;
    absent = active
        .where((uid) => unique[uid]?.status == AttendanceStatus.absent)
        .length;
  }
  late final int registered, present, absent;
  int get notMarked => registered - present - absent;
  double? get rate => registered == 0 ? null : present / registered * 100;
}

class AttendanceResult {
  const AttendanceResult(
    this.record, {
    this.duplicate = false,
    this.fullName = 'Unknown Participant',
    this.eventTitle = '',
    this.organizationName = '',
  });
  final AttendanceRecord record;
  final bool duplicate;
  final String fullName, eventTitle, organizationName;
}

class QRPayload {
  const QRPayload(this.organizationId, this.eventId, this.token);
  final String organizationId, eventId, token;
  static bool validId(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value.length <= 1500 &&
      !value.contains('/') &&
      value != '.' &&
      value != '..';
  factory QRPayload.parse(String raw) {
    if (raw.length > 5000) throw const FormatException('Invalid QR format.');
    final data = jsonDecode(raw);
    if (data is! Map ||
        data['version'] != 1 ||
        data['type'] != 'attendance' ||
        !validId(data['organizationId']) ||
        !validId(data['eventId']) ||
        data['token'] is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(data['token'])) {
      throw const FormatException(
        'This is not a supported OrgLink attendance QR code.',
      );
    }
    return QRPayload(
      data['organizationId'] as String,
      data['eventId'] as String,
      data['token'] as String,
    );
  }
  Map<String, dynamic> toMap() => {
    'version': 1,
    'type': 'attendance',
    'organizationId': organizationId,
    'eventId': eventId,
    'token': token,
  };
  String get encoded => jsonEncode(toMap());
}

class QRCheckInCredential {
  const QRCheckInCredential(this.payload, this.expiresAt, this.serverTime);
  final QRPayload payload;
  final DateTime expiresAt, serverTime;
}
