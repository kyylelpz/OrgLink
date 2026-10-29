import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/firestore_service.dart';
import '../../../../core/errors/app_failure.dart';
import '../models/attendance.dart';

class AttendanceService {
  AttendanceService(
    this.store,
    this.auth, {
    this.client,
    this.apiUrl = const String.fromEnvironment(
      'ATTENDANCE_API_URL',
      defaultValue: 'https://orglink-attendance.orglink-dev.workers.dev',
    ),
  });
  final FirestoreService store;
  final FirebaseAuth auth;
  final http.Client? client;
  final String apiUrl;
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
    final uri = Uri.tryParse(apiUrl);
    final local =
        kDebugMode &&
        uri?.scheme == 'http' &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri?.host);
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && !local)) {
      throw AppFailure(
        name == 'correctAttendance'
            ? 'Attendance corrections require the configured attendance backend. Normal manual marking remains available.'
            : 'Secure QR check-in is not configured. Manual attendance is available.',
      );
    }
    final user = auth.currentUser;
    if (user == null) {
      throw const AppFailure('Sign in before using attendance.');
    }
    final transport = client ?? http.Client();
    try {
      return await (() async {
        final token = await user.getIdToken();
        if (token == null || auth.currentUser?.uid != user.uid) {
          throw const AppFailure(
            'Your session changed. Reopen attendance and try again.',
          );
        }
        final endpoint = switch (name) {
          'issueAttendanceCredential' => '/issue',
          'redeemAttendanceCredential' => '/redeem',
          'correctAttendance' => '/correct',
          _ => throw const AppFailure('Unsupported attendance operation.'),
        };
        final request = http.Request('POST', uri.replace(path: endpoint))
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(data);
        final response = await transport.send(request);
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 32768) {
            throw const AppFailure('Invalid attendance server response.');
          }
          bytes.addAll(chunk);
        }
        if (auth.currentUser?.uid != user.uid) {
          throw const AppFailure(
            'Your session changed. Reopen attendance and try again.',
          );
        }
        Map<String, dynamic> body;
        try {
          body = Map<String, dynamic>.from(
            jsonDecode(utf8.decode(bytes)) as Map,
          );
        } catch (_) {
          throw const AppFailure(
            'Secure QR check-in is unavailable. Check the configured backend address.',
          );
        }
        if (response.statusCode != 200) {
          final error = body['error'];
          if (error is Map && error['message'] is String) {
            throw AppFailure(error['message'] as String);
          }
          throw const AppFailure(
            'Verification could not be confirmed. Check attendance status before retrying.',
          );
        }
        if (body['result'] is! Map) {
          throw const AppFailure('Invalid attendance server response.');
        }
        return Map<String, dynamic>.from(body['result'] as Map);
      })().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const AppFailure(
        'Verification could not be confirmed. Check your connection and attendance status before retrying.',
      );
    } on http.ClientException {
      throw const AppFailure(
        'Unable to connect to attendance verification. Check your connection and retry.',
      );
    } finally {
      if (client == null) transport.close();
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

  Future<AttendanceCorrectionPreview> previewCorrection(
    String org,
    String event,
    String uid,
  ) async {
    final data = await _call('correctAttendance', {
      'operation': 'preview',
      'organizationId': org,
      'eventId': event,
      'participantUid': uid,
    });
    return AttendanceCorrectionPreview(
      AttendanceStatus.values.byName(data['previousStatus'] as String),
      data['revision'] as String,
    );
  }

  Future<void> correct(
    String org,
    String event,
    String uid,
    AttendanceCorrectionPreview preview,
    AttendanceCorrectionStatus status,
    String reason,
  ) async {
    await _call('correctAttendance', {
      'operation': 'apply',
      'organizationId': org,
      'eventId': event,
      'participantUid': uid,
      'revision': preview.revision,
      'newStatus': status.name,
      'reason': reason.trim(),
    });
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
