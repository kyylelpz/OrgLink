import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/widgets/app_components.dart';
import 'package:orglink/features/admin/data/models/admin_models.dart';
import 'package:orglink/features/admin/data/repositories/admin_repository.dart';
import 'package:orglink/features/admin/data/services/admin_service.dart';
import 'package:orglink/features/admin/presentation/viewmodels/admin_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'package:orglink/features/profile/data/models/student_profile.dart';
import 'phase3_profile_ui_test.dart' as fixture;
import 'support/test_auth_repository.dart';

class FakeAdminRepository implements AdminRepository {
  int reads = 0;
  final mutations = <Map<String, dynamic>>[];
  final queries = <Map<String, dynamic>?>[];
  final searchRequests = <Map<String, dynamic>>[];
  Completer<void>? gate, readGate;
  bool empty = false;
  AdminFailure? failure;
  List<AdminAccount>? accountItems;
  List<AdminOrganization>? organizationItems;
  @override
  Future<AdminManager> manager(String studentId) async => AdminManager.fromMap({
    'studentId': studentId,
    'name': 'Synthetic Manager',
    'status': 'active',
    'eligible': true,
    'version': 'manager-v1',
    'registryVersion': 'registry-v1',
  });
  @override
  Future<AdminStats> stats() async {
    reads++;
    await readGate?.future;
    if (failure != null) throw failure!;
    return const AdminStats(31, 7, 4);
  }

  @override
  Future<AdminPage<AdminAccount>> accounts(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  }) async {
    reads++;
    searchRequests.add({
      'field': field,
      'search': search,
      'cursor': cursor,
      'refresh': refresh,
    });
    await readGate?.future;
    queries.add(cursor);
    if (failure == null && accountItems != null) {
      return AdminPage(accountItems!, null);
    }
    if (empty) return const AdminPage([], null);
    if (failure != null) throw failure!;
    return AdminPage([
      AdminAccount.fromMap({
        'id': 'target',
        'version': 'v1',
        'fullName':
            "A Long Student Name McDonald de la Cruz Dela Peña IEEE iOS Research",
        'email': 'synthetic@example.edu',
        'platformRole': 'user',
        'accountStatus': 'pending',
      }),
    ], cursor == null ? {'id': 'target', 'value': 'Name'} : null);
  }

  @override
  Future<AdminPage<AdminOrganization>> organizations(
    String field,
    String search,
    Map<String, dynamic>? cursor, {
    bool refresh = false,
  }) async {
    reads++;
    searchRequests.add({
      'field': field,
      'search': search,
      'cursor': cursor,
      'refresh': refresh,
    });
    await readGate?.future;
    if (failure != null) throw failure!;
    if (organizationItems != null) return AdminPage(organizationItems!, null);
    return AdminPage([
      AdminOrganization.fromMap({
        'id': 'org',
        'organizationId': 'org',
        'version': 'v1',
        'name': 'IEEE iOS Research Organization With a Long Name',
        'description': 'Existing organization',
        'managerUid': 'existing-manager',
        'visibility': 'public',
        'status': 'active',
      }),
    ], null);
  }

  @override
  Future<void> mutate(Map<String, dynamic> data) async {
    mutations.add(data);
    await gate?.future;
    if (failure != null) throw failure!;
    if (data['action'] == 'reactivate' && accountItems != null) {
      accountItems = accountItems!
          .map(
            (a) => a.uid != data['targetId']
                ? a
                : AdminAccount.fromMap({
                    'id': a.uid,
                    'version': 'v2',
                    'fullName': a.name,
                    'email': a.email,
                    'platformRole': a.role,
                    'accountStatus': 'active',
                    'canReactivate': false,
                  }),
          )
          .toList();
    }
  }
}

const adminProfile = StudentProfile(
  uid: 'student',
  email: 'student@example.edu',
  details: validDetails,
  platformRole: 'platformAdmin',
  accountStatus: 'active',
);
Future<void> mount(
  WidgetTester tester,
  fixture.ProfileApp app,
  FakeAdminRepository repo, {
  bool admin = true,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: app.auth),
        Provider<GoRouter>.value(value: app.router),
        Provider<OrganizationRepository>.value(value: app.orgs),
        Provider<EventRepository>.value(value: app.events),
        Provider<AdminRepository>.value(value: repo),
      ],
      child: RepaintBoundary(key: app.capture, child: const OrgLinkApp()),
    ),
  );
  app.accounts.controller.add(student);
  await tester.pump();
  app.profiles.controller.add(admin ? adminProfile : profile());
  await tester.pumpAndSettle();
}

class SdkUser extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'synthetic-token';
}

class SdkAuth extends Fake implements FirebaseAuth {
  User? current = SdkUser();
  @override
  User? get currentUser => current;
}

void main() {
  setUpAll(() async {
    await (FontLoader('Inter')
          ..addFont(rootBundle.load('assets/fonts/inter/Inter-Variable.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final accounts in [true, false]) {
    testWidgets(
      'admin ${accounts ? 'account' : 'organization'} search stays manual through typing, keyboard, Clear and Refresh',
      (tester) async {
        final app = fixture.ProfileApp(), repo = FakeAdminRepository();
        addTearDown(() => app.close(tester));
        await mount(tester, app, repo);
        app.router.go(
          accounts ? AppRoutes.adminAccounts : AppRoutes.adminOrganizations,
        );
        await tester.pumpAndSettle();
        final before = repo.reads,
            oldName = accounts
                ? 'A Long Student Name McDonald de la Cruz Dela Peña IEEE iOS Research'
                : 'IEEE iOS Research Organization With a Long Name';
        expect(find.text(oldName), findsOneWidget);
        if (accounts) {
          repo.accountItems = [
            AdminAccount.fromMap({
              'id': 'match',
              'version': 'v2',
              'fullName': 'Matched Cruz Student',
              'email': 'match@example.test',
              'platformRole': 'user',
              'accountStatus': 'pending',
            }),
          ];
        } else {
          repo.organizationItems = [
            AdminOrganization.fromMap({
              'id': 'match-org',
              'organizationId': 'match-org',
              'version': 'v2',
              'name': 'Matched Robotics Guild',
              'managerUid': 'existing-manager',
              'visibility': 'public',
              'status': 'active',
            }),
          ];
        }
        final input = find.byType(TextField).first;
        expect(
          tester.widget<TextField>(input).textInputAction,
          TextInputAction.search,
        );
        await tester.enterText(input, '  cRuZ  ');
        await tester.pump(const Duration(seconds: 2));
        expect(repo.reads, before);
        expect(find.text(oldName), findsOneWidget);
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(repo.reads, before + 1);
        expect(repo.searchRequests.last['search'], 'cRuZ');
        expect(
          find.text(
            accounts ? 'Matched Cruz Student' : 'Matched Robotics Guild',
          ),
          findsOneWidget,
        );
        await tester.enterText(input, 'not submitted');
        await tester.pumpAndSettle();
        expect(repo.reads, before + 1);
        final refresh = find.widgetWithText(AppActionButton, 'Refresh');
        await tester.ensureVisible(refresh);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(repo.searchRequests.last['search'], 'cRuZ');
        expect(repo.searchRequests.last['refresh'], true);
        final searchButton = find.widgetWithText(AppActionButton, 'Search');
        await tester.ensureVisible(searchButton);
        await tester.tap(searchButton);
        await tester.pumpAndSettle();
        expect(repo.searchRequests.last['search'], 'not submitted');
        final clear = find.widgetWithText(AppActionButton, 'Clear');
        await tester.ensureVisible(clear);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(repo.searchRequests.last['search'], '');
        expect(repo.searchRequests.last['cursor'], isNull);
        expect(tester.widget<TextField>(input).controller!.text, '');
      },
    );
  }
  test(
    'partial Student ID search trims whitespace and pagination retains the submitted field/query',
    () async {
      final repo = FakeAdminRepository();
      final model = AdminViewModel(repo, AdminSection.accounts);
      addTearDown(model.dispose);
      await model.find('studentNumber', ' 00012 ');
      expect(model.search, '00012');
      expect(model.field, 'studentNumber');
      await model.next();
      expect(repo.searchRequests.last['search'], '00012');
      expect(repo.searchRequests.last['field'], 'studentNumber');
      expect(model.page, 2);
      await model.previous();
      expect(model.page, 1);
      await model.find('studentNumber', '   ');
      expect(model.search, '');
      expect(model.field, 'fullName');
      expect(model.hasPrevious, false);
    },
  );
  test(
    'VM guards duplicate submissions and reuses operation ID after ambiguous failure',
    () async {
      final repo = FakeAdminRepository()..gate = Completer<void>();
      final vm = AdminViewModel(repo, AdminSection.accounts);
      addTearDown(vm.dispose);
      final data = {
        'operation': 'accountStatus',
        'targetId': 'target',
        'action': 'approve',
        'version': 'v1',
      };
      repo.failure = const AdminFailure(
        'Refresh before retrying.',
        'unavailable',
      );
      final first = vm.submit(data);
      expect(await vm.submit(data), isFalse);
      expect(repo.mutations.length, 1);
      repo.gate!.complete();
      expect(await first, isFalse);
      repo.failure = null;
      repo.gate = null;
      expect(await vm.submit(data), isTrue);
      expect(
        repo.mutations.first['requestId'],
        repo.mutations.last['requestId'],
      );
      expect(vm.message, contains('audit log'));
      await vm.next();
      expect(vm.page, 2);
      await vm.previous();
      expect(vm.page, 1);
      await vm.find('email', ' synthetic@example.edu ');
      expect(vm.search, 'synthetic@example.edu');
      expect(vm.hasPrevious, isFalse);
      repo.failure = const AdminFailure('Access denied.', 'permission-denied');
      await vm.load();
      expect(vm.unauthorized, isTrue);
    },
  );
  test(
    'service authenticates to fixed admin endpoint, rejects redirects and session changes',
    () async {
      final auth = SdkAuth();
      final client = MockClient((request) async {
        expect(request.url.path, '/admin/stats');
        expect(request.followRedirects, isFalse);
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        return http.Response(
          jsonEncode({
            'result': {'users': 3, 'pending': 1, 'organizations': 2},
          }),
          200,
        );
      });
      final result = await AdminService(auth, client: client).call('stats', {});
      expect(result['users'], 3);
      client.close();
      final redirect = MockClient(
        (_) async => http.Response(
          'redirect',
          302,
          headers: {'location': 'https://attacker.test'},
        ),
      );
      await expectLater(
        AdminService(auth, client: redirect).call('stats', {}),
        throwsA(isA<AdminFailure>()),
      );
      redirect.close();
      final changed = MockClient((_) async {
        auth.current = null;
        return http.Response('{"result":{}}', 200);
      });
      await expectLater(
        AdminService(auth, client: changed).call('stats', {}),
        throwsA(isA<AdminFailure>()),
      );
      changed.close();
      await expectLater(
        AdminService(
          SdkAuth(),
          apiUrl: 'https://example.test/?redirect=evil',
        ).call('stats', {}),
        throwsA(isA<AdminFailure>()),
      );
    },
  );
  testWidgets(
    'regular user cannot see Admin entry or load privileged data via direct routes',
    (tester) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      await mount(tester, app, repo, admin: false);
      app.router.go(AppRoutes.completeProfile);
      await tester.pumpAndSettle();
      expect(find.text('Platform Administration'), findsNothing);
      for (final route in [
        AppRoutes.admin,
        AppRoutes.adminAccounts,
        AppRoutes.adminOrganizations,
      ]) {
        app.router.go(route);
        await tester.pumpAndSettle();
        expect(
          find.text('Platform administrator access is required.'),
          findsOneWidget,
        );
        expect(repo.reads, 0);
      }
    },
  );
  for (final width in [320.0, 360.0, 393.0, 412.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Admin pages and dialogs $width dp ${scale}x, keyboard and Back',
        (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final app = fixture.ProfileApp(), repo = FakeAdminRepository();
          addTearDown(() => app.close(tester));
          await mount(tester, app, repo);
          app.router.go(AppRoutes.completeProfile);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Platform Administration'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Platform Administration'));
          await tester.pumpAndSettle();
          expect(find.text('31'), findsOneWidget);
          expect(find.text('7'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (width == 393 && scale == 1) {
            await app.screenshot(tester, 'admin-dashboard');
          }
          app.router.go(AppRoutes.adminAccounts);
          await tester.pumpAndSettle();
          expect(find.text('synthetic@example.edu'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Approve'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Approve'));
          await tester.pumpAndSettle();
          expect(find.text('Approve Account'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(repo.mutations, isEmpty);
          app.router.go(AppRoutes.adminOrganizations);
          await tester.pumpAndSettle();
          expect(find.text('Existing organization'), findsOneWidget);
          await tester.ensureVisible(find.text('Create Organization'));
          await tester.tap(find.text('Create Organization'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Review and Save'));
          await tester.pumpAndSettle();
          expect(find.text('Enter organization name.'), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey('admin-name')),
            'IEEE iOS New Organization',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('admin-managerStudentId')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('admin-managerStudentId')),
            '2026000003',
          );
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Find Manager'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Find Manager'));
          await tester.pumpAndSettle();
          expect(find.text('Synthetic Manager'), findsOneWidget);
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          tester.view.viewInsets = const FakeViewPadding();
          FocusManager.instance.primaryFocus?.unfocus();
          tester.testTextInput.hide();
          await tester.pumpAndSettle();
          await tester.tap(find.text('Review and Save'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Confirm'));
          await tester.pumpAndSettle();
          expect(repo.mutations.last['operation'], 'createOrganization');
          expect(
            (repo.mutations.last['changes'] as Map)['name'],
            'IEEE iOS New Organization',
          );
          expect(tester.takeException(), isNull);
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(app.router.state.uri.path, AppRoutes.admin);
          app.router.go(AppRoutes.adminAccounts);
          await tester.pumpAndSettle();
          app.profiles.controller.add(profile());
          await tester.pumpAndSettle();
          expect(
            find.text('Platform administrator access is required.'),
            findsOneWidget,
          );
          expect(find.text('synthetic@example.edu'), findsNothing);
        },
      );
    }
  }
  testWidgets(
    'revocation replaces an open privileged confirmation with access denied',
    (tester) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      await mount(tester, app, repo);
      app.router.go(AppRoutes.adminAccounts);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Approve'));
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      app.profiles.controller.add(profile());
      await tester.pumpAndSettle();
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Confirm'), findsNothing);
      expect(repo.mutations, isEmpty);
    },
  );
  testWidgets(
    'admin loading, retry, empty search and denied response do not fabricate records',
    (tester) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      await mount(tester, app, repo);
      repo.readGate = Completer<void>();
      app.router.go(AppRoutes.admin);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Loading administration...'), findsOneWidget);
      repo.failure = const AdminFailure('Network unavailable.', 'unavailable');
      repo.readGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Network unavailable.'), findsOneWidget);
      expect(find.text('31'), findsNothing);
      repo.readGate = null;
      repo.failure = null;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('31'), findsOneWidget);
      repo.empty = true;
      app.router.go(AppRoutes.adminAccounts);
      await tester.pumpAndSettle();
      expect(find.text('No Matching Records'), findsOneWidget);
      repo.empty = false;
      repo.failure = const AdminFailure(
        'Administration denied.',
        'permission-denied',
      );
      await tester.ensureVisible(find.text('Refresh'));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Administration denied.'), findsOneWidget);
      expect(find.text('synthetic@example.edu'), findsNothing);
    },
  );
  testWidgets(
    'Admin pushed history, direct dashboard Back and signed-out redirects remain safe',
    (tester) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      await mount(tester, app, repo);
      app.router.go(AppRoutes.completeProfile);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Platform Administration'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Platform Administration'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Account Management'));
      await tester.tap(find.text('Account Management'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, AppRoutes.admin);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, AppRoutes.completeProfile);
      app.router.go(AppRoutes.admin);
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, AppRoutes.completeProfile);
      app.accounts.controller.add(null);
      await tester.pumpAndSettle();
      app.router.go(AppRoutes.admin);
      await tester.pumpAndSettle();
      expect(app.router.state.uri.path, AppRoutes.signIn);
    },
  );
  testWidgets(
    'Reactivate is limited to eligible disabled students, confirms, and refreshes after saving',
    (tester) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      AdminAccount account(
        String uid,
        String status, {
        String role = 'user',
        bool eligible = false,
      }) => AdminAccount.fromMap({
        'id': uid,
        'version': 'v1',
        'fullName': uid,
        'email': '$uid@example.edu',
        'platformRole': role,
        'accountStatus': status,
        'canReactivate': eligible,
      });
      repo.accountItems = [
        account('target', 'disabled', eligible: true),
        account('rejected', 'rejected', eligible: true),
        account('incomplete', 'disabled'),
        account(
          'administrator',
          'disabled',
          role: 'platformAdmin',
          eligible: true,
        ),
        account('student', 'disabled', eligible: true),
      ];
      await mount(tester, app, repo);
      app.router.go(AppRoutes.adminAccounts);
      await tester.pumpAndSettle();
      expect(find.text('Reactivate'), findsOneWidget);
      await tester.ensureVisible(find.text('Reactivate'));
      await tester.tap(find.text('Reactivate'));
      await tester.pumpAndSettle();
      expect(find.text('Reactivate Account'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.mutations, isEmpty);
      await tester.tap(find.text('Reactivate'));
      await tester.pumpAndSettle();
      final reads = repo.reads;
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(repo.mutations.single['action'], 'reactivate');
      expect(repo.mutations.single['version'], 'v1');
      expect(repo.mutations.single['targetId'], 'target');
      expect(repo.mutations.single['requestId'], isNotEmpty);
      expect(repo.reads, greaterThan(reads));
      expect(repo.accountItems!.first.status, 'active');
      expect(find.text('Reactivate'), findsNothing);
      expect(
        find.text('Changes saved and recorded in the audit log.'),
        findsOneWidget,
      );
    },
  );
  for (final code in ['conflict', 'permission-denied']) {
    testWidgets('Reactivation $code response does not report success', (
      tester,
    ) async {
      final app = fixture.ProfileApp(), repo = FakeAdminRepository();
      addTearDown(() => app.close(tester));
      repo.accountItems = [
        AdminAccount.fromMap({
          'id': 'target',
          'version': 'v1',
          'fullName': 'Disabled Student',
          'email': 'synthetic@example.edu',
          'platformRole': 'user',
          'accountStatus': 'disabled',
          'canReactivate': true,
        }),
      ];
      await mount(tester, app, repo);
      app.router.go(AppRoutes.adminAccounts);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reactivate'));
      await tester.tap(find.text('Reactivate'));
      await tester.pumpAndSettle();
      repo.failure = AdminFailure('Reactivation denied: $code.', code);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Reactivation denied: $code.'), findsOneWidget);
      expect(repo.accountItems!.single.status, 'disabled');
      expect(
        find.text('Changes saved and recorded in the audit log.'),
        findsNothing,
      );
      if (code == 'permission-denied') {
        expect(find.text('Reactivate'), findsNothing);
      }
    });
  }
}
