import '../models/attendance.dart';

abstract interface class AttendanceRepository {
  Stream<List<AttendanceRecord>> records(String org, String event);
  Stream<AttendanceRecord?> watchOwn(String org, String event, String uid);
  Future<AttendanceResult> mark(
    String org,
    String event,
    String uid,
    String operatorUid,
    AttendanceStatus status,
  );
  Future<QRCheckInCredential> issue(String org, String event);
  Future<AttendanceResult> redeem(QRPayload payload);
}
