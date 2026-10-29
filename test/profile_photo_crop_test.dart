import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/services/image_upload_service.dart';
import 'package:orglink/core/widgets/image_editor.dart';
import 'package:orglink/core/widgets/profile_photo_crop_dialog.dart';
import 'image_upload_test.dart' as fixture;

Future<Uint8List> stripedImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var i = 0; i < 3; i++) {
    canvas.drawRect(
      Rect.fromLTWH(i * 4, 0, 4, 4),
      ui.Paint()..color = [Colors.red, Colors.green, Colors.blue][i],
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(12, 4);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<void> waitForPreview(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump();
    if (find
        .byKey(const ValueKey('profile-crop-viewport'))
        .evaluate()
        .isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Crop preview did not decode.');
}

Future<void> openEditor(
  WidgetTester tester,
  fixture.RecordingImageApi api,
  Uint8List bytes,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ImageEditor(
          resource: const ImageResource('profile'),
          label: 'Photo',
          service: fixture.GalleryService(api, bytes),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Change Photo'));
  await waitForPreview(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'organization logos use interactive cropping before the existing upload flow',
    (tester) async {
      final api = fixture.RecordingImageApi();
      final bytes = (await tester.runAsync(stripedImage))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: const ImageResource(
                'organization',
                organizationId: 'org',
              ),
              label: 'Logo',
              service: fixture.GalleryService(api, bytes),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Change Logo'));
      await waitForPreview(tester);
      expect(find.text('Crop Organization Logo'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Keep Original'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('profile-crop-viewport')),
        const Offset(200, 0),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(api.calls.first.$2, {
        'kind': 'organization',
        'organizationId': 'org',
      });
      expect(api.calls.last.$1, '/images/finalize');
      final uploaded = base64Decode(
        api.calls.singleWhere((c) => c.$1 == '/images/upload').$2['file']
            as String,
      );
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(uploaded);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, 4);
        expect(image.height, 4);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        expect(rgba.sublist(0, 4), [244, 67, 54, 255]);
        image.dispose();
        codec.dispose();
      });
    },
  );
  for (final kind in ['event']) {
    testWidgets('$kind retains the original center-crop dialog', (
      tester,
    ) async {
      final api = fixture.RecordingImageApi();
      final bytes = (await tester.runAsync(stripedImage))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: ImageResource(
                kind,
                organizationId: 'org',
                eventId: kind == 'event' ? 'event' : null,
              ),
              label: 'Image',
              service: fixture.GalleryService(api, bytes),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Change Image'));
      await tester.pumpAndSettle();
      expect(find.text('Crop Square'), findsOneWidget);
      expect(find.byType(ProfilePhotoCropDialog), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    });
  }
  testWidgets(
    'invalid image shows a recoverable preview error without enabling Confirm',
    (tester) async {
      final api = fixture.RecordingImageApi();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: const ImageResource('profile'),
              label: 'Photo',
              service: fixture.GalleryService(
                api,
                Uint8List.fromList([1, 2, 3]),
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
      expect(
        find.text('This image could not be opened. Try another image.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Confirm'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    },
  );
  test(
    'drag selects different source pixels and stays inside landscape/portrait images',
    () {
      for (final size in [const Size(1200, 800), const Size(800, 1200)]) {
        final crop = ProfilePhotoCropController(size);
        expect(crop.sourceRect.size, const Size(800, 800));
        crop.startGesture(const Offset(.5, .5));
        crop.updateGesture(1, const Offset(10, 10));
        expect(crop.sourceRect.left, 0);
        expect(crop.sourceRect.top, 0);
        crop.startGesture(const Offset(.5, .5));
        crop.updateGesture(1, const Offset(-10, -10));
        expect(crop.sourceRect.right, size.width);
        expect(crop.sourceRect.bottom, size.height);
      }
    },
  );
  test(
    'pinch anchors source point under fingers, clamps zoom and reset restores centered crop',
    () {
      final crop = ProfilePhotoCropController(const Size(1200, 800));
      crop.startGesture(const Offset(.25, .5));
      crop.updateGesture(2, const Offset(.25, .5));
      expect(crop.zoom, 2);
      expect(crop.side, 400);
      expect(crop.sourceRect.left + crop.side * .25, 400);
      crop.updateGesture(100, const Offset(.25, .5));
      expect(crop.zoom, 8);
      crop.updateGesture(.01, const Offset(.25, .5));
      expect(crop.zoom, 1);
      crop.reset();
      expect(crop.sourceRect, const Rect.fromLTWH(200, 0, 800, 800));
    },
  );
  test(
    'rendered square contains repositioned pixels and passes existing size/type validation',
    () async {
      final original = await stripedImage(),
          before = Uint8List.fromList(await stripedImage());
      final codec = await ui.instantiateImageCodec(original);
      final image = (await codec.getNextFrame()).image;
      final crop = ProfilePhotoCropController(const Size(12, 4));
      crop.startGesture(const Offset(.5, .5));
      crop.updateGesture(1, const Offset(1.5, .5));
      final bytes = await renderProfilePhotoCrop(image, crop.sourceRect);
      image.dispose();
      codec.dispose();
      expect(original, before);
      ImageUploadService.validateBytes(bytes);
      expect(bytes.length, lessThanOrEqualTo(ImageUploadService.maxBytes));
      final outputCodec = await ui.instantiateImageCodec(bytes);
      final output = (await outputCodec.getNextFrame()).image;
      expect(output.width, 4);
      expect(output.height, 4);
      final rgba = (await output.toByteData())!.buffer.asUint8List();
      expect(rgba.sublist(0, 4), [
        244,
        67,
        54,
        255,
      ]); // Material red, not the centered green stripe.
      output.dispose();
      outputCodec.dispose();
    },
  );
  testWidgets(
    'profile preview supports drag, pinch, reset and cancel without upload',
    (tester) async {
      final api = fixture.RecordingImageApi();
      await openEditor(tester, api, (await tester.runAsync(stripedImage))!);
      final viewport = find.byKey(const ValueKey('profile-crop-viewport'));
      final image = find.byType(RawImage);
      final initialPosition = tester.getTopLeft(image);
      final initialSize = tester.getSize(image);
      await tester.drag(viewport, const Offset(40, 0));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(image).dx, greaterThan(initialPosition.dx));
      final center = tester.getCenter(viewport);
      final first = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await tester.pump();
      await first.moveTo(center - const Offset(50, 0));
      await second.moveTo(center + const Offset(50, 0));
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(tester.getSize(image).width, greaterThan(initialSize.width));
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(tester.getSize(image), initialSize);
      expect(tester.getTopLeft(image), initialPosition);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
    },
  );
  testWidgets(
    'Keep Original uploads exact selected bytes after repositioning',
    (tester) async {
      final api = fixture.RecordingImageApi(),
          bytes = (await tester.runAsync(stripedImage))!;
      await openEditor(tester, api, bytes);
      await tester.drag(
        find.byKey(const ValueKey('profile-crop-viewport')),
        const Offset(40, 0),
      );
      await tester.tap(find.text('Keep Original'));
      await tester.pumpAndSettle();
      final uploaded = api.calls.singleWhere((c) => c.$1 == '/images/upload');
      expect(base64Decode(uploaded.$2['file'] as String), bytes);
    },
  );
  testWidgets(
    'Confirm crops before invoking existing profile upload and finalization',
    (tester) async {
      final api = fixture.RecordingImageApi(),
          bytes = (await tester.runAsync(stripedImage))!;
      await openEditor(tester, api, bytes);
      await tester.drag(
        find.byKey(const ValueKey('profile-crop-viewport')),
        const Offset(200, 0),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(api.calls.first.$2, {'kind': 'profile'});
      expect(api.calls.last.$1, '/images/finalize');
      final uploaded = base64Decode(
        api.calls.singleWhere((c) => c.$1 == '/images/upload').$2['file']
            as String,
      );
      expect(uploaded, isNot(bytes));
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(uploaded);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, image.height);
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        expect(rgba.sublist(0, 4), [244, 67, 54, 255]);
        image.dispose();
        codec.dispose();
      });
    },
  );
}
