import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/attendance.dart';

class AttendanceService {
  AttendanceService(this.store, this.functions);
  final FirestoreService store;
  final FirebaseFunctions functions;
  CollectionReference<Map<String, dynamic>> _records(
    String org,
    String event,
  ) => store.collection(
    'organizations/$org/events/$event/attendance',
    fromFirestore: (doc, _) => doc.data()!,
    toFirestore: (data, _) => data,
  );
  Stream<List<AttendanceRecord>> records(String org, String event) =>
      _records(org, event)
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.isFromCache && !s.metadata.hasPendingWrites)
          .map(
            (s) =>
                s.docs.map((d) => AttendanceRecord.fromMap(d.data())).toList(),
          );
  Stream<AttendanceRecord?> watchOwn(String org, String event, String uid) =>
      _records(org, event)
          .doc(uid)
          .snapshots(includeMetadataChanges: true)
          .where((s) => !s.metadata.isFromCache && !s.metadata.hasPendingWrites)
          .map((s) => s.exists ? AttendanceRecord.fromMap(s.data()!) : null);
  Future<AttendanceResult> mark(
    String org,
    String event,
    String uid,
    String operatorUid,
    AttendanceStatus status,
  ) async {
    final ref = _records(org, event).doc(uid);
    final existing = await store.runTransaction<AttendanceRecord?>((
      transaction,
    ) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) return AttendanceRecord.fromMap(snapshot.data()!);
      transaction.set(ref, {
        'uid': uid,
        'eventId': event,
        'organizationId': org,
        'attendanceStatus': status.name,
        'verifiedAt': FieldValue.serverTimestamp(),
        'verifiedBy': operatorUid,
        'verificationMethod': 'manual',
      });
      return null;
    });
    if (existing != null) return AttendanceResult(existing, duplicate: true);
    // Never report optimistic local writes as authoritative attendance.
    final confirmed = await ref.get(const GetOptions(source: Source.server));
    return AttendanceResult(AttendanceRecord.fromMap(confirmed.data()!));
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await functions
          .httpsCallable(
            name,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Map<String, dynamic>>(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        throw const AppFailure(
          'Secure QR check-in is not available yet. The attendance backend must be deployed. Manual attendance is available.',
        );
      }
      if (e.code == 'unavailable' ||
          e.code == 'deadline-exceeded' ||
          e.code == 'internal') {
        throw const AppFailure(
          'Verification could not be confirmed. Check your connection and attendance status before retrying.',
        );
      }
      throw AppFailure(e.message ?? 'QR verification failed. Please retry.');
    }
  }

  Future<QRCheckInCredential> issue(String org, String event) async {
    final data = await _call('issueAttendanceCredential', {
      'organizationId': org,
      'eventId': event,
    });
    return QRCheckInCredential(
      QRPayload(org, event, data['token'] as String),
      DateTime.fromMillisecondsSinceEpoch(
        (data['expiresAt'] as num).toInt(),
        isUtc: true,
      ),
      DateTime.fromMillisecondsSinceEpoch(
        (data['serverTime'] as num).toInt(),
        isUtc: true,
      ),
    );
  }

  Future<AttendanceResult> redeem(QRPayload payload) async {
    final data = await _call('redeemAttendanceCredential', payload.toMap());
    final record = Map<String, dynamic>.from(data['record'] as Map);
    record['verifiedAt'] = DateTime.fromMillisecondsSinceEpoch(
      (record['verifiedAt'] as num).toInt(),
      isUtc: true,
    );
    return AttendanceResult(
      AttendanceRecord.fromMap(record),
      duplicate: data['duplicate'] == true,
      fullName: data['fullName'] as String? ?? 'Unknown Participant',
      eventTitle: data['eventTitle'] as String? ?? '',
      organizationName: data['organizationName'] as String? ?? '',
    );
  }
}
