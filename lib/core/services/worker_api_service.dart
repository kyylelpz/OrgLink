import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../errors/app_failure.dart';

class WorkerFailure extends AppFailure {
  const WorkerFailure(super.message, this.code);
  final String code;
}

class WorkerApiService {
  WorkerApiService(
    this.auth, {
    this.client,
    this.apiUrl = const String.fromEnvironment(
      'ATTENDANCE_API_URL',
      defaultValue: 'https://orglink-attendance.orglink-dev.workers.dev',
    ),
  });
  final FirebaseAuth auth;
  final http.Client? client;
  final String apiUrl;
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> data,
  ) => callWithProgress(operation, data);

  Future<Map<String, dynamic>> callWithProgress(
    String operation,
    Map<String, dynamic> data, {
    void Function(double)? onProgress,
  }) async {
    final uri = Uri.tryParse(apiUrl);
    final local =
        kDebugMode &&
        uri?.scheme == 'http' &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri?.host);
    if (![
          '/admin/stats',
          '/admin/list',
          '/admin/mutate',
          '/admin/manager',
          '/profile/save',
          '/memberships/preview',
          '/memberships/mutate',
          '/images/sign',
          '/images/upload',
          '/images/finalize',
          '/images/remove',
        ].contains(operation) ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && !local)) {
      throw const WorkerFailure(
        'The secure backend is not configured.',
        'unavailable',
      );
    }
    final user = auth.currentUser;
    if (user == null) {
      throw const WorkerFailure(
        'Sign in before continuing.',
        'unauthenticated',
      );
    }
    final transport = client ?? http.Client();
    try {
      return await (() async {
        final token = await user.getIdToken();
        if (token == null || auth.currentUser?.uid != user.uid) {
          throw const WorkerFailure(
            'Your session changed. Reopen this screen.',
            'unauthenticated',
          );
        }
        final request =
            _ProgressRequest('POST', uri.replace(path: operation), onProgress)
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              })
              ..body = jsonEncode(data);
        final response = await transport.send(request);
        final bytes = <int>[];
        await for (final chunk in response.stream) {
          if (bytes.length + chunk.length > 262144) {
            throw const WorkerFailure(
              'Invalid server response.',
              'unavailable',
            );
          }
          bytes.addAll(chunk);
        }
        if (auth.currentUser?.uid != user.uid) {
          throw const WorkerFailure(
            'Your session changed. Reopen this screen.',
            'unauthenticated',
          );
        }
        final body = jsonDecode(utf8.decode(bytes)) as Map;
        if (response.statusCode != 200) {
          final error = body['error'];
          throw WorkerFailure(
            error is Map && error['message'] is String
                ? error['message'] as String
                : 'The server is unavailable.',
            error is Map && error['code'] is String
                ? error['code'] as String
                : 'unavailable',
          );
        }
        return Map<String, dynamic>.from(body['result'] as Map);
      })().timeout(Duration(seconds: operation == '/images/upload' ? 60 : 25));
    } on WorkerFailure {
      rethrow;
    } catch (_) {
      throw const WorkerFailure(
        'The operation could not be confirmed. Refresh before retrying.',
        'unavailable',
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}

// Progress measures request bytes sent to the transport; verification is a separate stage.
class _ProgressRequest extends http.Request {
  _ProgressRequest(super.method, super.url, this.onProgress);
  final void Function(double)? onProgress;
  @override
  http.ByteStream finalize() {
    final total = bodyBytes.length;
    final original = super.finalize();
    return http.ByteStream(() async* {
      var sent = 0;
      await for (final chunk in original) {
        for (var offset = 0; offset < chunk.length; offset += 65536) {
          final end = (offset + 65536).clamp(0, chunk.length);
          yield chunk.sublist(offset, end);
          sent += end - offset;
          onProgress?.call(total == 0 ? 1 : sent / total);
        }
      }
    }());
  }
}
