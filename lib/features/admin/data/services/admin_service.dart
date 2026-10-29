import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/admin_models.dart';

class AdminService {
  AdminService(
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
  ) async {
    final uri = Uri.tryParse(apiUrl);
    final local =
        kDebugMode &&
        uri?.scheme == 'http' &&
        ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri?.host);
    if (!['stats', 'list', 'mutate'].contains(operation) ||
        uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        (uri.scheme != 'https' && !local)) {
      throw const AdminFailure(
        'Platform administration is not configured.',
        'unavailable',
      );
    }
    final user = auth.currentUser;
    if (user == null) {
      throw const AdminFailure(
        'Sign in before opening administration.',
        'unauthenticated',
      );
    }
    final transport = client ?? http.Client();
    try {
      return await (() async {
        final token = await user.getIdToken();
        if (token == null || auth.currentUser?.uid != user.uid) {
          throw const AdminFailure(
            'Your session changed. Reopen administration.',
            'unauthenticated',
          );
        }
        final request =
            http.Request('POST', uri.replace(path: '/admin/$operation'))
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
            throw const AdminFailure(
              'Invalid administration response.',
              'unavailable',
            );
          }
          bytes.addAll(chunk);
        }
        if (auth.currentUser?.uid != user.uid) {
          throw const AdminFailure(
            'Your session changed. Reopen administration.',
            'unauthenticated',
          );
        }
        final body = jsonDecode(utf8.decode(bytes)) as Map;
        if (response.statusCode != 200) {
          final error = body['error'];
          throw AdminFailure(
            error is Map && error['message'] is String
                ? error['message'] as String
                : 'Administration is unavailable.',
            error is Map && error['code'] is String
                ? error['code'] as String
                : 'unavailable',
          );
        }
        return Map<String, dynamic>.from(body['result'] as Map);
      })().timeout(const Duration(seconds: 25));
    } on AdminFailure {
      rethrow;
    } catch (_) {
      throw const AdminFailure(
        'The operation could not be confirmed. Refresh before retrying.',
        'unavailable',
      );
    } finally {
      if (client == null) transport.close();
    }
  }
}
