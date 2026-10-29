import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/errors/app_failure.dart';
import 'package:orglink/core/services/image_upload_service.dart';
import 'package:orglink/core/services/worker_api_service.dart';
import 'package:orglink/core/widgets/image_editor.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/organizations/data/models/organization.dart';

class RecordingImageApi extends Fake implements WorkerApiService {
  final calls = <(String, Map<String, dynamic>)>[];
  bool failVerification = false;
  Completer<void>? wait;
  @override
  Future<Map<String, dynamic>> call(
    String operation,
    Map<String, dynamic> data,
  ) async {
    calls.add((operation, data));
    if (operation == '/images/sign') {
      return {
        'uploadId': 'synthetic-ticket',
        'signature': 'synthetic-signature',
      };
    }
    if (operation == '/images/finalize' && failVerification) {
      throw const WorkerFailure('Verification unavailable.', 'unavailable');
    }
    if (wait != null) await wait!.future;
    return {'saved': true};
  }

  @override
  Future<Map<String, dynamic>> callWithProgress(
    String operation,
    Map<String, dynamic> data, {
    void Function(double)? onProgress,
  }) async {
    onProgress?.call(0.5);
    onProgress?.call(1);
    return call(operation, data);
  }
}

class GalleryService extends ImageUploadService {
  GalleryService(super.api, this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List?> select() async => bytes;
}

Future<Uint8List> imageBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const Color(0xff123456), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('file validation rejects empty, oversized and non-image payloads', () {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList(utf8.encode('<svg/>')),
      Uint8List(ImageUploadService.maxBytes + 1),
    ]) {
      expect(
        () => ImageUploadService.validateBytes(bytes),
        throwsA(isA<AppFailure>()),
      );
    }
  });
  test(
    'square crop changes image dimensions without altering original bytes',
    () async {
      final original = await imageBytes(),
          before = Uint8List.fromList(await imageBytes());
      final cropped = await ImageUploadService.cropSquare(original);
      expect(original, before);
      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 4);
      expect(frame.image.height, 4);
      frame.image.dispose();
      codec.dispose();
    },
  );
  test(
    'transport sends resource IDs and bytes, never a client URL or public ID; progress is emitted',
    () async {
      final api = RecordingImageApi(),
          service = ImageUploadService(RecordingImageApi());
      final stages = <String>[];
      final id = await ImageUploadService(api).upload(
        const ImageResource('event', organizationId: 'org', eventId: 'event'),
        await imageBytes(),
        onProgress: (stage, _) => stages.add(stage),
      );
      expect(id, 'synthetic-ticket');
      expect(api.calls.first.$2, {
        'kind': 'event',
        'organizationId': 'org',
        'eventId': 'event',
      });
      expect(api.calls.last.$2.keys.toSet(), {'uploadId', 'file', 'signature'});
      expect(
        stages.where((s) => s == 'Uploading image').length,
        greaterThan(1),
      );
      await service.remove(const ImageResource('profile'), null);
    },
  );
  test(
    'verification retry uses same uploaded asset and does not upload again',
    () async {
      final api = RecordingImageApi()..failVerification = true;
      final model = ImageUploadViewModel(
        ImageUploadService(api),
        const ImageResource('profile'),
      );
      expect(await model.save(await imageBytes()), false);
      expect(model.pendingUpload, 'synthetic-ticket');
      expect(model.message, 'Verification unavailable.');
      expect(model.busy, false);
      api.failVerification = false;
      expect(await model.save(null), true);
      expect(api.calls.where((c) => c.$1 == '/images/upload').length, 1);
      expect(model.pendingUpload, null);
      expect(model.message, 'Image saved.');
      model.dispose();
    },
  );
  test(
    'duplicate operations are suppressed while an image request is pending',
    () async {
      final api = RecordingImageApi()..wait = Completer<void>();
      final model = ImageUploadViewModel(
        ImageUploadService(api),
        const ImageResource('profile'),
      );
      final first = model.remove('https://example.test/current.png');
      expect(model.busy, true);
      expect(await model.remove(null), false);
      api.wait!.complete();
      expect(await first, true);
      expect(api.calls.length, 1);
      model.dispose();
    },
  );
  test(
    'trusted image IDs parse separately from displayed URLs and preserve titles',
    () {
      final org = Organization.fromMap('org', {
        'name': 'IEEE iOS Society',
        'logoURL': 'https://example.test/a.png',
        'logoPublicId': 'orglink/organizations/id',
      });
      final event = OrgEvent.fromMap('event', 'org', {
        'title': 'McDonald and iOS',
        'posterURL': null,
        'posterPublicId': 'orglink/events/id',
      });
      expect(org.logoPublicId, 'orglink/organizations/id');
      expect(org.name, 'IEEE iOS Society');
      expect(event.posterPublicId, 'orglink/events/id');
      expect(event.title, 'McDonald and iOS');
      expect(Organization.fromMap('legacy', {}).logoPublicId, null);
      expect(OrgEvent.fromMap('legacy', 'org', {}).posterPublicId, null);
    },
  );
  testWidgets(
    'image editor requires crop confirmation and supports cancellation without uploading',
    (tester) async {
      final api = RecordingImageApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: const ImageResource('profile'),
              label: 'Photo',
              service: GalleryService(
                api,
                (await tester.runAsync(imageBytes))!,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Change Photo'), findsOneWidget);
      expect(find.text('Remove Photo'), findsNothing);
      await tester.tap(find.text('Change Photo'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    },
  );
  testWidgets(
    'image editor saves confirmed gallery image and removal sends expected current URL',
    (tester) async {
      final api = RecordingImageApi();
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: const ImageResource(
                'organization',
                organizationId: 'org',
              ),
              label: 'Logo',
              currentURL: 'https://example.test/current.png',
              onSaved: () async {
                saved++;
              },
              service: GalleryService(
                api,
                (await tester.runAsync(imageBytes))!,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Change Logo'));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Original'));
      await tester.pumpAndSettle();
      expect(api.calls.last.$1, '/images/finalize');
      expect(saved, 1);
      expect(find.text('Image saved.'), findsOneWidget);
      await tester.tap(find.text('Remove Logo'));
      await tester.pumpAndSettle();
      expect(api.calls.where((c) => c.$1 == '/images/remove'), isEmpty);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(saved, 2);
      expect(api.calls.last.$2, {
        'kind': 'organization',
        'organizationId': 'org',
        'expectedURL': 'https://example.test/current.png',
      });
    },
  );
  testWidgets('image selection dialog fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(imageBytes))!;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ImageEditor(
              resource: const ImageResource('profile'),
              label: 'Photo',
              service: GalleryService(RecordingImageApi(), bytes),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Change Photo'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
