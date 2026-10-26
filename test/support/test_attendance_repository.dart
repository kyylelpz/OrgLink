import 'dart:async';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/data/repositories/attendance_repository.dart';
import 'test_organization_repository.dart';

AttendanceRecord attendanceRecord({
  String uid = 'student',
  AttendanceStatus status = AttendanceStatus.present,
  VerificationMethod method = VerificationMethod.manual,
}) => AttendanceRecord(
  uid: uid,
  eventId: 'demo',
  organizationId: 'robotics',
  status: status,
  verifiedAt: DateTime.utc(2026, 10, 27),
  verifiedBy: 'manager',
  method: method,
);

class TestAttendanceRepository implements AttendanceRepository {
  final feed = TestFeed<List<AttendanceRecord>>([]);
  int marks = 0, issues = 0, redemptions = 0;
  final ownWatches = <String>[];
  Object? error;
  Completer<void>? gate;
  @override
  Stream<List<AttendanceRecord>> records(String org, String event) =>
      feed.watch();
  @override
  Stream<AttendanceRecord?> watchOwn(String org, String event, String uid) {
    ownWatches.add(uid);
    return feed.watch().map((values) {
      for (final r in values) {
        if (r.uid == uid) return r;
      }
      return null;
    });
  }

  @override
  Future<AttendanceResult> mark(
    String org,
    String event,
    String uid,
    String operatorUid,
    AttendanceStatus status,
  ) async {
    marks++;
    await gate?.future;
    if (error case final e?) throw e;
    for (final record in feed.value) {
      if (record.uid == uid) return AttendanceResult(record, duplicate: true);
    }
    final record = attendanceRecord(uid: uid, status: status);
    feed.emit([...feed.value, record]);
    return AttendanceResult(record);
  }

  @override
  Future<QRCheckInCredential> issue(String org, String event) async {
    issues++;
    await gate?.future;
    if (error case final e?) throw e;
    final now = DateTime.now().toUtc();
    return QRCheckInCredential(
      QRPayload(org, event, 'a' * 43),
      now.add(const Duration(seconds: 60)),
      now,
    );
  }

  @override
  Future<AttendanceResult> redeem(QRPayload payload) async {
    redemptions++;
    await gate?.future;
    if (error case final e?) throw e;
    return AttendanceResult(
      attendanceRecord(method: VerificationMethod.qr),
      fullName: 'McDonald',
      eventTitle: 'Demo Event',
      organizationName: 'Demo Robotics',
    );
  }

  Future<void> close() => feed.close();
}
