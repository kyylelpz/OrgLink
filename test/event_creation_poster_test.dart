import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:orglink/app/app.dart';
import 'package:orglink/app/router.dart';
import 'package:orglink/core/constants/app_routes.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/services/image_upload_service.dart';
import 'package:orglink/core/services/worker_api_service.dart';
import 'package:orglink/core/widgets/app_components.dart';
import 'package:orglink/core/theme/app_tokens.dart';
import 'package:orglink/features/auth/data/models/auth_user.dart';
import 'package:orglink/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:orglink/features/events/data/repositories/event_repository.dart';
import 'package:orglink/features/events/presentation/viewmodels/event_context_view_model.dart';
import 'package:orglink/features/organizations/data/repositories/organization_repository.dart';
import 'image_upload_test.dart' as images;
import 'profile_photo_crop_test.dart' as crop;
import 'support/test_auth_repository.dart';
import 'support/test_event_repository.dart';
import 'support/test_organization_repository.dart';

class CreationImageApi extends images.RecordingImageApi {
  WorkerFailure? uploadFailure, finalizeFailure;
  void Function()? beforeSign;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> data,
  ) {
    if (operation == '/images/sign') beforeSign?.call();
    if (operation == '/images/finalize' && finalizeFailure != null) {
      calls.add((operation, data));
      throw finalizeFailure!;
    }
    return super.call(operation, data);
  }

  @override
  Future<Map<String, dynamic>> callWithProgress(
    String operation,
    Map<String, dynamic> data, {
    void Function(double)? onProgress,
  }) {
    if (uploadFailure != null) {
      calls.add((operation, data));
      throw uploadFailure!;
    }
    return super.callWithProgress(operation, data, onProgress: onProgress);
  }
}

class CreationPosterService extends ImageUploadService {
  CreationPosterService(super.api, this.bytes);
  Uint8List? bytes;
  @override
  Future<Uint8List?> select() async => bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('creation poster state', () {
    late TestEventRepository events;
    late TestOrganizationRepository orgs;
    late EventContextViewModel model;
    late CreationImageApi api;
    late CreationPosterService service;
    setUp(() async {
      events = TestEventRepository();
      orgs = TestOrganizationRepository();
      model = EventContextViewModel(events, orgs, 'robotics', 'manager');
      api = CreationImageApi();
      service = CreationPosterService(api, await images.imageBytes());
      await Future<void>.delayed(Duration.zero);
    });
    tearDown(() async {
      model.dispose();
      await events.close();
      await orgs.close();
    });
    test('selection, change, cancellation and removal stay local', () async {
      await model.selectPoster(service);
      final original = model.selectedPoster;
      expect(api.calls, isEmpty);
      expect(events.creates, 0);
      service.bytes = null;
      await model.selectPoster(service);
      expect(model.selectedPoster, same(original));
      service.bytes = Uint8List.fromList(original!);
      await model.selectPoster(service);
      expect(model.selectedPoster, same(service.bytes));
      model.removeSelectedPoster();
      expect(model.selectedPoster, null);
      expect(api.calls, isEmpty);
    });
    test(
      'draft is created before requesting a signed upload for its exact ID',
      () async {
        await model.selectPoster(service);
        api.beforeSign = () {
          expect(events.creates, 1);
          expect(events.event.value?.eventStatus, 'draft');
        };
        expect(await model.save(sampleDraft()), 'demo');
        expect(api.calls.map((call) => call.$1), [
          '/images/sign',
          '/images/upload',
          '/images/finalize',
        ]);
        expect(api.calls.first.$2, {
          'kind': 'event',
          'organizationId': 'robotics',
          'eventId': 'demo',
        });
        expect(model.selectedPoster, null);
        expect(model.createdDraftId, 'demo');
        expect(events.event.value?.approvalStatus, 'pending');
      },
    );
    test(
      'optional poster can be removed and draft saves without Cloudinary calls',
      () async {
        await model.selectPoster(service);
        model.removeSelectedPoster();
        expect(await model.save(sampleDraft()), 'demo');
        expect(api.calls, isEmpty);
        expect(events.creates, 1);
      },
    );
    test(
      'creation failure retains selection and never requests an upload',
      () async {
        await model.selectPoster(service);
        final bytes = model.selectedPoster;
        events.failure = const AppFailure('Draft save failed.');
        expect(await model.save(sampleDraft()), null);
        expect(model.createdDraftId, null);
        expect(model.selectedPoster, same(bytes));
        expect(api.calls, isEmpty);
      },
    );
    test(
      'upload failure retains created draft and retry never creates another event',
      () async {
        await model.selectPoster(service);
        final bytes = model.selectedPoster;
        api.uploadFailure = const WorkerFailure(
          'Upload failed.',
          'unavailable',
        );
        expect(await model.save(sampleDraft()), null);
        expect(model.creationSaved, true);
        expect(model.formLocked, true);
        expect(model.busy, false);
        expect(model.selectedPoster, same(bytes));
        expect(model.failure?.message, 'Upload failed.');
        api.uploadFailure = null;
        expect(await model.retryPoster(), 'demo');
        expect(events.creates, 1);
        expect(
          api.calls
              .where((c) => c.$1 == '/images/sign')
              .every((c) => c.$2['eventId'] == 'demo'),
          true,
        );
      },
    );
    test(
      'ambiguous verification retries existing ticket instead of uploading again',
      () async {
        await model.selectPoster(service);
        api.finalizeFailure = const WorkerFailure(
          'Verification unavailable.',
          'unavailable',
        );
        expect(await model.save(sampleDraft()), null);
        expect(model.selectedPoster, isNotNull);
        api.finalizeFailure = null;
        expect(await model.retryPoster(), 'demo');
        expect(events.creates, 1);
        expect(api.calls.where((c) => c.$1 == '/images/upload').length, 1);
      },
    );
    test(
      'expired ticket can start a fresh upload against the same saved draft',
      () async {
        await model.selectPoster(service);
        api.finalizeFailure = const WorkerFailure(
          'Expired upload.',
          'failed-precondition',
        );
        expect(await model.save(sampleDraft()), null);
        api.finalizeFailure = null;
        expect(await model.retryPoster(), 'demo');
        expect(events.creates, 1);
        expect(api.calls.where((c) => c.$1 == '/images/sign').length, 2);
      },
    );
    test(
      'busy creation and upload suppress duplicate submission and removal',
      () async {
        await model.selectPoster(service);
        final bytes = model.selectedPoster;
        events.operationGate = Completer<void>();
        final saving = model.save(sampleDraft());
        expect(await model.save(sampleDraft()), null);
        model.removeSelectedPoster();
        expect(model.selectedPoster, same(bytes));
        expect(events.creates, 1);
        expect(api.calls, isEmpty);
        events.operationGate!.complete();
        expect(await saving, 'demo');
        expect(await model.save(sampleDraft()), 'demo');
        expect(events.creates, 1);
      },
    );
    test('retry without an event ID is rejected before upload', () async {
      await model.selectPoster(service);
      expect(await model.retryPoster(), null);
      expect(api.calls, isEmpty);
      expect(events.creates, 0);
    });
    test(
      'invalid replacement retains selected poster and does not request an upload',
      () async {
        await model.selectPoster(service);
        final bytes = model.selectedPoster;
        service.bytes = Uint8List(ImageUploadService.maxBytes + 1);
        await model.selectPoster(service);
        expect(model.selectedPoster, same(bytes));
        expect(model.failure, isNotNull);
        expect(api.calls, isEmpty);
      },
    );
    test(
      'revoked create permissions block retries and preserve the local poster',
      () async {
        await model.selectPoster(service);
        api.uploadFailure = const WorkerFailure(
          'Upload failed.',
          'unavailable',
        );
        await model.save(sampleDraft());
        final calls = api.calls.length;
        orgs.document.emit(null);
        await Future<void>.delayed(Duration.zero);
        expect(await model.retryPoster(), null);
        expect(model.selectedPoster, isNotNull);
        expect(api.calls.length, calls);
        expect(events.creates, 1);
      },
    );
  });

  Future<(GoRouter, TestEventRepository, CreationImageApi)> app(
    WidgetTester tester, {
    bool confirmCrop = false,
  }) async {
    final authRepo = TestAuthRepository(), profiles = TestProfileRepository();
    final auth = AuthViewModel(authRepo, profiles),
        orgs = TestOrganizationRepository(),
        events = TestEventRepository();
    final router = createAppRouter(auth), api = CreationImageApi();
    final service = CreationPosterService(
      api,
      (await tester.runAsync(images.imageBytes))!,
    );
    addTearDown(() async {
      router.dispose();
      auth.dispose();
      await authRepo.controller.close();
      await profiles.controller.close();
      await orgs.close();
      await events.close();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          Provider<GoRouter>.value(value: router),
          Provider<OrganizationRepository>.value(value: orgs),
          Provider<EventRepository>.value(value: events),
          Provider<ImageUploadService>.value(value: service),
          Provider<TestAuthRepository>.value(value: authRepo),
        ],
        child: const OrgLinkApp(),
      ),
    );
    authRepo.controller.add(const AuthUser(id: 'manager'));
    await tester.pump();
    profiles.controller.add(profile());
    await tester.pumpAndSettle();
    router.go(AppRoutes.createEvent('robotics'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'IEEE iOS Event');
    await tester.enterText(fields.at(1), 'Synthetic event description.');
    await tester.enterText(fields.at(2), 'Synthetic Hall');
    await tester.ensureVisible(find.text('Select Poster'));
    await tester.tap(find.text('Select Poster'));
    await crop.waitForPreview(tester);
    if (confirmCrop) {
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
    } else {
      await tester.tap(find.text('Keep Original'));
    }
    await tester.pumpAndSettle();
    return (router, events, api);
  }

  testWidgets(
    'poster and optional text precede Event Details in the same card',
    (tester) async {
      await app(tester);
      final poster = find.text('Event Poster'),
          details = find.text('Event Details');
      final posterCard = find
          .ancestor(of: poster, matching: find.byType(AppSurfaceCard))
          .first;
      final detailsCard = find
          .ancestor(of: details, matching: find.byType(AppSurfaceCard))
          .first;
      final scheduleCard = find
          .ancestor(
            of: find.text('Schedule and Capacity'),
            matching: find.byType(AppSurfaceCard),
          )
          .first;
      expect(tester.widget(posterCard), same(tester.widget(detailsCard)));
      expect(
        tester.widget(posterCard),
        isNot(same(tester.widget(scheduleCard))),
      );
      expect(
        tester.getTopLeft(poster).dy,
        lessThan(tester.getTopLeft(details).dy),
      );
      final optional = tester.widget<Text>(find.text('(Optional)'));
      expect(optional.style?.fontWeight, FontWeight.normal);
      expect(optional.style?.color, AppColors.muted);
      expect(
        tester.getTopLeft(find.text('(Optional)')).dy,
        greaterThan(tester.getTopLeft(poster).dy),
      );
    },
  );
  testWidgets(
    'canceling landscape replacement keeps the locally staged poster',
    (tester) async {
      final (_, _, api) = await app(tester);
      final before = tester
          .widget<Image>(find.byKey(const ValueKey('selected-event-poster')))
          .image;
      await tester.ensureVisible(find.text('Change Poster'));
      await tester.tap(find.text('Change Poster'));
      await crop.waitForPreview(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Image>(find.byKey(const ValueKey('selected-event-poster')))
            .image,
        before,
      );
      expect(api.calls, isEmpty);
    },
  );
  testWidgets(
    'confirmed landscape crop stays local until draft creation then uploads',
    (tester) async {
      final (_, events, api) = await app(tester, confirmCrop: true);
      final selected =
          tester
                  .widget<Image>(
                    find.byKey(const ValueKey('selected-event-poster')),
                  )
                  .image
              as MemoryImage;
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(selected.bytes);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, greaterThan(image.height));
        image.dispose();
        codec.dispose();
      });
      expect(api.calls, isEmpty);
      expect(events.creates, 0);
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      final upload = api.calls.singleWhere((c) => c.$1 == '/images/upload');
      expect(base64Decode(upload.$2['file'] as String), selected.bytes);
      expect(events.creates, 1);
    },
  );

  testWidgets(
    'create form previews poster locally, supports change/removal, and does not upload early',
    (tester) async {
      final (_, events, api) = await app(tester);
      expect(
        find.byKey(const ValueKey('selected-event-poster')),
        findsOneWidget,
      );
      expect(api.calls, isEmpty);
      await tester.ensureVisible(find.text('Change Poster'));
      await tester.tap(find.text('Change Poster'));
      await crop.waitForPreview(tester);
      await tester.tap(find.text('Keep Original'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove Poster'));
      await tester.tap(find.text('Remove Poster'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selected-event-poster')), findsNothing);
      expect(events.creates, 0);
      expect(api.calls, isEmpty);
    },
  );
  testWidgets(
    'upload failure shows saved draft and Retry Upload; retry navigates with one event',
    (tester) async {
      final (router, events, api) = await app(tester);
      api.uploadFailure = const WorkerFailure('Upload failed.', 'unavailable');
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();
      expect(events.creates, 1);
      expect(find.text('Retry Upload'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('selected-event-poster')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        false,
      );
      api.uploadFailure = null;
      await tester.ensureVisible(find.text('Retry Upload'));
      await tester.tap(find.text('Retry Upload'));
      await tester.pumpAndSettle();
      expect(events.creates, 1);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.event('robotics', 'demo'),
      );
    },
  );
  testWidgets(
    'navigation away confirms loss and Stay retains selected poster',
    (tester) async {
      final (router, events, api) = await app(tester);
      router.go(AppRoutes.events);
      await tester.pumpAndSettle();
      expect(find.text('Leave Without Poster?'), findsOneWidget);
      await tester.tap(find.text('Stay'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.createEvent('robotics'),
      );
      expect(
        find.byKey(const ValueKey('selected-event-poster')),
        findsOneWidget,
      );
      router.go(AppRoutes.events);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, AppRoutes.events);
      expect(events.creates, 0);
      expect(api.calls, isEmpty);
    },
  );
  testWidgets(
    'pending upload shows progress, disables save and blocks route exit',
    (tester) async {
      final (router, events, api) = await app(tester);
      api.wait = Completer<void>();
      await tester.ensureVisible(find.text('Save Draft'));
      await tester.tap(find.text('Save Draft'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(events.creates, 1);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Retry Upload'),
            )
            .onPressed,
        isNull,
      );
      router.go(AppRoutes.events);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.createEvent('robotics'),
      );
      api.wait!.complete();
      await tester.pumpAndSettle();
      expect(events.creates, 1);
      expect(
        router.routeInformationProvider.value.uri.path,
        AppRoutes.event('robotics', 'demo'),
      );
    },
  );
  testWidgets('selected poster does not block a forced sign-out redirect', (
    tester,
  ) async {
    final (router, _, api) = await app(tester);
    tester
        .element(find.byType(OrgLinkApp))
        .read<TestAuthRepository>()
        .controller
        .add(null);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.signIn);
    expect(find.text('Leave Without Poster?'), findsNothing);
    expect(api.calls, isEmpty);
  });
  testWidgets('Android Back preserves selection when the user stays', (
    tester,
  ) async {
    await app(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave Without Poster?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-event-poster')), findsOneWidget);
  });
  testWidgets('poster preview and retry fit a narrow phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (_, events, api) = await app(tester);
    expect(tester.takeException(), isNull);
    api.uploadFailure = const WorkerFailure('Upload failed.', 'unavailable');
    await tester.ensureVisible(find.text('Save Draft'));
    await tester.tap(find.text('Save Draft'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry Upload'));
    await tester.pumpAndSettle();
    expect(events.creates, 1);
    expect(tester.takeException(), isNull);
  });
}
