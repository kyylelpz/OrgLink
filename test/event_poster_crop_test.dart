import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orglink/core/utils/event_poster_layout.dart';
import 'package:orglink/core/services/image_upload_service.dart';
import 'package:orglink/core/widgets/app_components.dart';
import 'package:orglink/core/widgets/image_editor.dart';
import 'package:orglink/core/widgets/profile_photo_crop_dialog.dart';
import 'package:orglink/features/events/data/models/event.dart';
import 'package:orglink/features/events/presentation/widgets/event_widgets.dart';
import 'image_upload_test.dart' as fixture;
import 'profile_photo_crop_test.dart' as crop_fixture;
import 'support/test_event_repository.dart';

Future<Uint8List> gradientImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  for (var y = 0; y < 200; y++) {
    canvas.drawRect(
      Rect.fromLTWH(0, y.toDouble(), 300, 1),
      Paint()..color = Color.fromARGB(255, 0, y, 0),
    );
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(300, 200);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  picture.dispose();
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'landscape geometry preserves ratio, covers viewport, clamps panning and resets',
    () {
      for (final size in [const Size(1200, 800), const Size(800, 1200)]) {
        final crop = ProfilePhotoCropController(size, aspectRatio: 15 / 8);
        final original = crop.sourceRect;
        expect(original.width / original.height, closeTo(15 / 8, 1e-10));
        crop.startGesture(const Offset(.3, .7));
        crop.updateGesture(2, const Offset(.3, .7));
        expect(crop.sourceRect.width, closeTo(original.width / 2, 1e-9));
        expect(crop.sourceRect.height, closeTo(original.height / 2, 1e-9));
        crop.updateGesture(2, const Offset(100, -100));
        expect(crop.sourceRect.left, 0);
        expect(crop.sourceRect.bottom, size.height);
        crop.reset();
        expect(crop.sourceRect, original);
      }
    },
  );
  test(
    'export retains landscape dimensions and fractional square crops remain square',
    () async {
      final codec = await ui.instantiateImageCodec(await gradientImage());
      final image = (await codec.getNextFrame()).image;
      for (final ratio in [1.0, 15 / 8]) {
        final crop = ProfilePhotoCropController(
          const Size(300, 200),
          aspectRatio: ratio,
        );
        crop.startGesture(const Offset(.5, .5));
        crop.updateGesture(1.7, const Offset(.5, .5));
        final exported = await renderProfilePhotoCrop(image, crop.sourceRect);
        final outputCodec = await ui.instantiateImageCodec(exported);
        final output = (await outputCodec.getNextFrame()).image;
        expect(
          (output.width - output.height * ratio).abs(),
          lessThanOrEqualTo(ratio),
        );
        if (ratio == 1) expect(output.width, output.height);
        expect(output.width, lessThanOrEqualTo(2048));
        expect(output.height, lessThanOrEqualTo(2048));
        output.dispose();
        outputCodec.dispose();
      }
      image.dispose();
      codec.dispose();
    },
  );
  for (final width in [320.0, 393.0, 800.0]) {
    testWidgets(
      'crop ratio follows existing details and Home slots at $width dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late double ratio, homeRatio;
        final event = OrgEvent.fromMap('demo', 'robotics', {
          ...sampleEvent().toMap(),
          'posterURL': 'https://example.invalid/poster.png',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  ratio = EventPosterLayout.aspectRatio(context);
                  homeRatio = EventPosterLayout.featuredAspectRatio(context);
                  return AppPageBody(
                    child: Column(
                      children: [
                        EventPoster(event: event, organizationName: 'Demo'),
                        EventCard(event: event, organizationName: 'Demo'),
                        EventCard(
                          event: event,
                          organizationName: 'Demo',
                          style: EventCardStyle.featured,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final slots = tester
            .widgetList<Image>(
              find.byWidgetPredicate(
                (widget) => widget is Image && widget.image is NetworkImage,
              ),
            )
            .toList();
        expect(slots.map((image) => image.height), [184, 184, 174]);
        expect(slots.map((image) => image.fit), [
          BoxFit.cover,
          BoxFit.cover,
          BoxFit.cover,
        ]);
        final detailsWidth = tester
            .getSize(find.byType(EventPoster).first)
            .width;
        expect(ratio, closeTo(detailsWidth / 184, .001));
        expect(homeRatio, closeTo(detailsWidth / 174, .001));
        expect(ratio, closeTo((width - 48) / 184, .001));
      },
    );
  }
  testWidgets(
    'crop ratio retains physical safe-area insets inside a SafeArea',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(left: 20, right: 16);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      late double ratio;
      await tester.pumpWidget(
        MaterialApp(
          home: SafeArea(
            child: Builder(
              builder: (context) {
                ratio = EventPosterLayout.aspectRatio(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(ratio, closeTo((393 - 36 - 48) / 184, .001));
    },
  );
  testWidgets(
    'landscape dialog supports pinch, drag and Reset without a Home preview',
    (tester) async {
      final bytes = (await tester.runAsync(gradientImage))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfilePhotoCropDialog(
              bytes: bytes,
              label: 'Event Poster',
              aspectRatio: 2,
              secondaryAspectRatio: 4,
            ),
          ),
        ),
      );
      await crop_fixture.waitForPreview(tester);
      final viewport = find.byKey(const ValueKey('profile-crop-viewport'));
      final size = tester.getSize(viewport);
      expect(size.width / size.height, 2);
      final raw = find.byType(RawImage),
          initialSize = tester.getSize(raw),
          initialOffset = tester.getTopLeft(raw);
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
      expect(tester.getSize(raw).width, greaterThan(initialSize.width));
      await tester.drag(viewport, const Offset(20, 15));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(tester.getSize(raw), initialSize);
      expect(tester.getTopLeft(raw), initialOffset);
      expect(find.text('Home Preview'), findsNothing);
      expect(
        find.byKey(const ValueKey('event-poster-home-preview')),
        findsNothing,
      );
    },
  );
  testWidgets(
    'Edit Draft poster confirms a landscape crop through the same upload endpoints',
    (tester) async {
      final api = fixture.RecordingImageApi();
      final bytes = (await tester.runAsync(gradientImage))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageEditor(
              resource: const ImageResource(
                'event',
                organizationId: 'robotics',
                eventId: 'demo',
              ),
              label: 'Poster',
              service: fixture.GalleryService(api, bytes),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Change Poster'));
      await crop_fixture.waitForPreview(tester);
      await tester.runAsync(() async {
        await tester.tap(find.text('Confirm'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(api.calls.first.$2, {
        'kind': 'event',
        'organizationId': 'robotics',
        'eventId': 'demo',
      });
      expect(api.calls.last.$1, '/images/finalize');
      await tester.runAsync(() async {
        final exported = base64Decode(
          api.calls
                  .singleWhere((call) => call.$1 == '/images/upload')
                  .$2['file']
              as String,
        );
        final codec = await ui.instantiateImageCodec(exported),
            image = (await codec.getNextFrame()).image;
        expect(image.width, greaterThan(image.height));
        image.dispose();
        codec.dispose();
      });
    },
  );
}
