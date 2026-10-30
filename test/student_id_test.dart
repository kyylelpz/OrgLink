import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/services/firestore_service.dart';
import 'package:orglink/core/services/worker_api_service.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'package:orglink/features/profile/data/services/user_profile_service.dart';
import 'package:orglink/features/admin/data/models/admin_models.dart';
import 'phase3_profile_ui_test.dart' as fixture;
import 'platform_admin_test.dart' as admin;
import 'support/test_auth_repository.dart';

class FakeStore extends Fake implements FirestoreService {}

class StudentSearchRepository extends admin.FakeAdminRepository {
  String? fieldUsed, searchUsed;
  @override
  Future<AdminPage<AdminAccount>> accounts(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  }) async {
    fieldUsed = field;
    searchUsed = search;
    return AdminPage([
      AdminAccount.fromMap({
        'id': 'internal-uid',
        'version': 'v1',
        'studentNumber': '2026000001',
        'fullName': 'McDonald de la Cruz',
        'email': 'synthetic@example.edu',
        'platformRole': 'user',
        'accountStatus': 'active',
      }),
    ], null);
  }
}

void main() {
  test(
    'strict string validation preserves sequence zeros and never derives entry year; stored legacy profiles remain readable',
    () {
      for (final value in [
        null,
        '',
        '2026-00001',
        '2026 00001',
        '202600001',
        '20260000011',
        '2026x00001',
        ' 2026000001',
        '2026000001 ',
      ]) {
        expect(StudentDetails.validateStudentNumber(value), isNotNull);
      }
      expect(StudentDetails.validateStudentNumber('2026000001'), isNull);
      final details = StudentDetails.fromMap({
        ...validDetails.toMap(),
        'studentNumber': '2026000001',
        'yearLevel': 6,
      });
      expect(details.toMap()['studentNumber'], '2026000001');
      expect(details.yearLevel, 6);
      final legacy = StudentDetails.fromMap({
        ...validDetails.toMap(),
        'studentNumber': '2026-001',
      });
      expect(profile(details: legacy).isEligible, isTrue);
      expect(legacy.isValid, isFalse);
      expect(
        StudentDetails.fromMap({
          ...validDetails.toMap(),
          'studentNumber': 2026000001,
        }).studentNumber,
        '',
      );
    },
  );
  test(
    'profile save uses only authenticated Worker details and keeps ID as a string; duplicate errors stay clear',
    () async {
      final auth = admin.SdkAuth();
      final transport = MockClient((request) async {
        expect(request.url.path, '/profile/save');
        expect(request.followRedirects, isFalse);
        final body = jsonDecode(request.body) as Map;
        expect(body.keys, ['details']);
        expect((body['details'] as Map)['studentNumber'], '2026000001');
        expect((body['details'] as Map).containsKey('uid'), isFalse);
        return http.Response('{"result":{"saved":true}}', 200);
      });
      final api = WorkerApiService(auth, client: transport);
      await UserProfileService(FakeStore(), api: api).save(
        const AuthUser(id: 'admin', email: 'admin@example.edu'),
        validDetails,
      );
      transport.close();
      final duplicate = MockClient(
        (_) async => http.Response(
          '{"error":{"code":"already-exists","message":"This Student ID is already registered."}}',
          409,
        ),
      );
      await expectLater(
        WorkerApiService(
          auth,
          client: duplicate,
        ).call('/profile/save', {'details': validDetails.toMap()}),
        throwsA(
          isA<WorkerFailure>().having(
            (e) => e.message,
            'message',
            contains('already registered'),
          ),
        ),
      );
      duplicate.close();
    },
  );
  testWidgets(
    'Student ID field has numeric keyboard, length limit and inline format error',
    (tester) async {
      final app = fixture.ProfileApp();
      addTearDown(() => app.close(tester));
      await app.mount(tester);
      app.accounts.controller.add(student);
      await tester.pump();
      app.profiles.controller.add(null);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Student ID');
      expect(field, findsOneWidget);
      final widget = tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );
      expect(widget.maxLength, 10);
      expect(
        tester
            .widget<TextField>(
              find.descendant(of: field, matching: find.byType(TextField)),
            )
            .keyboardType,
        TextInputType.number,
      );
      await tester.enterText(field, '2026-00001');
      await tester.ensureVisible(find.text('Save Student Profile'));
      await tester.tap(find.text('Save Student Profile'));
      await tester.pumpAndSettle();
      expect(
        find.text('Enter exactly 10 numeric digits (e.g. 2026000001).'),
        findsOneWidget,
      );
      expect(app.profiles.saveCalls, 0);
    },
  );
  testWidgets(
    'admin cards/details use Student ID and partial directory search instead of UID',
    (tester) async {
      final app = fixture.ProfileApp(), repo = StudentSearchRepository();
      addTearDown(() => app.close(tester));
      await admin.mount(tester, app, repo);
      app.router.go(AppRoutes.adminAccounts);
      await tester.pumpAndSettle();
      expect(find.text('Student ID: 2026000001'), findsOneWidget);
      expect(find.textContaining('UID: internal-uid'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Student ID').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, ' 00001 ');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Search').last);
      await tester.tap(find.widgetWithText(FilledButton, 'Search'));
      await tester.pumpAndSettle();
      expect(repo.fieldUsed, 'studentNumber');
      expect(repo.searchUsed, '00001');
      await tester.ensureVisible(find.text('Account Details'));
      await tester.tap(find.text('Account Details'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Student ID: 2026000001'),
        ),
        findsOneWidget,
      );
    },
  );
}
