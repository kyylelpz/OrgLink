import '../../../../core/errors/app_failure.dart';
import '../models/attendance.dart';
import '../services/attendance_service.dart';
import 'attendance_repository.dart';

class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository(this.service);
  final AttendanceService service;
  Stream<T> _stream<T>(Stream<T> source) async* {
    try {
      yield* source;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  @override
  Stream<List<AttendanceRecord>> records(String org, String event) =>
      _stream(service.records(org, event));
  @override
  Stream<AttendanceRecord?> watchOwn(String org, String event, String uid) =>
      _stream(service.watchOwn(org, event, uid));
  @override
  Future<AttendanceResult> mark(
    String org,
    String event,
    String uid,
    String operatorUid,
    AttendanceStatus status,
  ) => _run(() => service.mark(org, event, uid, operatorUid, status));
  @override
  Future<QRCheckInCredential> issue(String org, String event) =>
      _run(() => service.issue(org, event));
  @override
  Future<AttendanceResult> redeem(QRPayload payload) =>
      _run(() => service.redeem(payload));
  @override
  Future<AttendanceCorrectionPreview> previewCorrection(
    String org,
    String event,
    String uid,
  ) => _run(() => service.previewCorrection(org, event, uid));
  @override
  Future<void> correct(
    String org,
    String event,
    String uid,
    AttendanceCorrectionPreview preview,
    AttendanceCorrectionStatus status,
    String reason,
  ) => _run(() => service.correct(org, event, uid, preview, status, reason));
}
