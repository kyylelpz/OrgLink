import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/services/firestore_service.dart';
import 'package:orglink/features/attendance/data/models/attendance.dart';
import 'package:orglink/features/attendance/data/services/attendance_service.dart';

class _Store extends Fake implements FirestoreService {}

class _User extends Fake implements User {
  _User(this.uid);
  @override
  final String uid;
  Completer<void>? gate;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    await gate?.future;
    return 'firebase-id-token';
  }
}

class _Auth extends Fake implements FirebaseAuth {
  User? current;
  @override
  User? get currentUser => current;
}

void main() {
  test(
    'correction preview/apply use Firebase bearer, revision and dedicated endpoint',
    () async {
      final auth = _Auth()..current = _User('manager');
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.path, '/correct');
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        expect(request.followRedirects, isFalse);
        final data = jsonDecode(request.body) as Map;
        expect(data['participantUid'], 'student');
        expect(data['organizationId'], 'robotics');
        expect(data['eventId'], 'demo');
        expect(data.containsKey('role'), isFalse);
        expect(data.containsKey('correctedBy'), isFalse);
        if (calls == 1) {
          expect(data['operation'], 'preview');
          return http.Response(
            jsonEncode({
              'result': {
                'previousStatus': 'present',
                'revision': '2026-10-27T00:00:00.123456789Z',
              },
            }),
            200,
          );
        }
        expect(data['operation'], 'apply');
        expect(data['revision'], '2026-10-27T00:00:00.123456789Z');
        expect(data['newStatus'], 'pending');
        expect(data['reason'], 'Checked roster');
        return http.Response(
          jsonEncode({
            'result': {'correctionId': 'audit', 'newStatus': 'pending'},
          }),
          200,
        );
      });
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      final preview = await service.previewCorrection(
        'robotics',
        'demo',
        'student',
      );
      await service.correct(
        'robotics',
        'demo',
        'student',
        preview,
        AttendanceCorrectionStatus.pending,
        ' Checked roster ',
      );
      expect(calls, 2);
      client.close();
    },
  );
  test(
    'Worker issuance sends Firebase bearer token over HTTPS and preserves credential contract',
    () async {
      final auth = _Auth()..current = _User('student');
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://orglink.example/issue');
        expect(request.headers['Authorization'], 'Bearer firebase-id-token');
        expect(request.followRedirects, isFalse);
        expect(jsonDecode(request.body), {
          'organizationId': 'robotics',
          'eventId': 'demo',
        });
        return http.Response(
          jsonEncode({
            'result': {'token': 'a' * 43, 'expiresAt': 60000, 'serverTime': 0},
          }),
          200,
        );
      });
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      final credential = await service.issue('robotics', 'demo');
      expect(credential.payload.token, 'a' * 43);
      expect(credential.expiresAt.millisecondsSinceEpoch, 60000);
      client.close();
    },
  );
  test(
    'duplicate redemption preserves the existing seven-field record and display result',
    () async {
      final auth = _Auth()..current = _User('manager');
      final client = MockClient((request) async {
        expect(request.url.path, '/redeem');
        return http.Response(
          jsonEncode({
            'result': {
              'duplicate': true,
              'fullName': 'McDonald',
              'eventTitle': 'Demo Event',
              'organizationName': 'Robotics',
              'record': {
                'uid': 'student',
                'organizationId': 'robotics',
                'eventId': 'demo',
                'attendanceStatus': 'absent',
                'verifiedAt': 123000,
                'verifiedBy': 'manager',
                'verificationMethod': 'manual',
              },
            },
          }),
          200,
        );
      });
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      final result = await service.redeem(
        QRPayload('robotics', 'demo', 'a' * 43),
      );
      expect(result.duplicate, isTrue);
      expect(result.record.status, AttendanceStatus.absent);
      expect(result.record.method, VerificationMethod.manual);
      expect(result.fullName, 'McDonald');
      client.close();
    },
  );
  test(
    'missing configuration, signed-out state and server authorization failures fail closed',
    () async {
      final auth = _Auth()..current = _User('student');
      await expectLater(
        AttendanceService(_Store(), auth).issue('robotics', 'demo'),
        throwsA(isA<AppFailure>()),
      );
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'permission-denied',
              'message': 'Attendance permission was revoked.',
            },
          }),
          403,
        ),
      );
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      await expectLater(
        service.issue('robotics', 'demo'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            'Attendance permission was revoked.',
          ),
        ),
      );
      auth.current = null;
      await expectLater(
        service.issue('robotics', 'demo'),
        throwsA(isA<AppFailure>()),
      );
      client.close();
    },
  );
  test(
    'account switching during ID-token acquisition sends no request',
    () async {
      final user = _User('student')..gate = Completer();
      final auth = _Auth()..current = user;
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      final pending = expectLater(
        service.issue('robotics', 'demo'),
        throwsA(isA<AppFailure>()),
      );
      auth.current = _User('other');
      user.gate!.complete();
      await pending;
      expect(calls, 0);
      client.close();
    },
  );
  test(
    'account switching during response discards prior user result; network errors are meaningful',
    () async {
      final auth = _Auth()..current = _User('student');
      final response = Completer<http.Response>();
      final client = MockClient((_) => response.future);
      final service = AttendanceService(
        _Store(),
        auth,
        client: client,
        apiUrl: 'https://orglink.example',
      );
      final pending = expectLater(
        service.issue('robotics', 'demo'),
        throwsA(isA<AppFailure>()),
      );
      await Future<void>.delayed(Duration.zero);
      auth.current = _User('other');
      response.complete(http.Response('{"result":{}}', 200));
      await pending;
      client.close();
      final offline = MockClient(
        (_) async => throw http.ClientException('Offline'),
      );
      await expectLater(
        AttendanceService(
          _Store(),
          auth,
          client: offline,
          apiUrl: 'https://orglink.example',
        ).issue('robotics', 'demo'),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            contains('connect'),
          ),
        ),
      );
      offline.close();
    },
  );
}
