import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../errors/app_failure.dart';
import '../services/image_upload_service.dart';
import '../utils/event_poster_layout.dart';

Future<Uint8List?> showEventPosterCrop(BuildContext context, Uint8List bytes) =>
    showDialog<Uint8List>(
      context: context,
      builder: (context) => ProfilePhotoCropDialog(
        bytes: bytes,
        label: 'Event Poster',
        aspectRatio: EventPosterLayout.aspectRatio(context),
        secondaryAspectRatio: EventPosterLayout.featuredAspectRatio(context),
      ),
    );

/// Crop geometry is kept in source-image pixels, independent of screen size.
class ProfilePhotoCropController {
  ProfilePhotoCropController(this.imageSize, {this.aspectRatio = 1})
    : assert(aspectRatio > 0 && aspectRatio.isFinite),
      center = imageSize.center(Offset.zero);
  final Size imageSize;
  final double aspectRatio;
  double zoom = 1, _startZoom = 1;
  Offset center, _anchor = Offset.zero;
  double get side =>
      math.min(imageSize.width, imageSize.height * aspectRatio) / zoom;
  double get height => side / aspectRatio;
  Rect get sourceRect =>
      Rect.fromCenter(center: center, width: side, height: height);
  void reset() {
    zoom = 1;
    center = imageSize.center(Offset.zero);
  }

  // Focal coordinates are normalized independently by viewport width and height.
  void startGesture(Offset focal) {
    _startZoom = zoom;
    _anchor = center + Offset((focal.dx - .5) * side, (focal.dy - .5) * height);
  }

  void updateGesture(double scale, Offset focal) {
    zoom = (_startZoom * scale).clamp(1, 8);
    final wanted =
        _anchor - Offset((focal.dx - .5) * side, (focal.dy - .5) * height);
    center = Offset(
      wanted.dx.clamp(side / 2, imageSize.width - side / 2),
      wanted.dy.clamp(height / 2, imageSize.height - height / 2),
    );
  }
}

Future<Uint8List> renderProfilePhotoCrop(ui.Image image, Rect source) async {
  final scale = math.min(1.0, 2048 / math.max(source.width, source.height));
  final width = (source.width * scale).round().clamp(1, 2048);
  final height = (source.height * scale).round().clamp(1, 2048);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  late ui.Image cropped;
  try {
    cropped = await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
  try {
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw const AppFailure('This image could not be prepared.');
    }
    final bytes = data.buffer.asUint8List();
    ImageUploadService.validateBytes(bytes);
    return bytes;
  } finally {
    cropped.dispose();
  }
}

class ProfilePhotoCropDialog extends StatefulWidget {
  const ProfilePhotoCropDialog({
    super.key,
    required this.bytes,
    this.label = 'Profile Photo',
    this.aspectRatio = 1,
    this.secondaryAspectRatio,
  });
  final Uint8List bytes;
  final String label;
  final double aspectRatio;
  final double? secondaryAspectRatio;
  @override
  State<ProfilePhotoCropDialog> createState() => _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<ProfilePhotoCropDialog> {
  ui.Image? _image;
  ProfilePhotoCropController? _crop;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      late ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _crop = ProfilePhotoCropController(
          Size(image.width.toDouble(), image.height.toDouble()),
          aspectRatio: widget.aspectRatio,
        );
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'This image could not be opened. Try another image.',
        );
      }
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    // A clone keeps the pixels alive if the dialog is dismissed during encoding.
    final image = _image!.clone();
    try {
      final bytes = await renderProfilePhotoCrop(image, _crop!.sourceRect);
      if (mounted) Navigator.pop(context, bytes);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This image could not be prepared. Try again.');
      }
    } finally {
      image.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didUpdateWidget(ProfilePhotoCropDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aspectRatio != widget.aspectRatio && _crop != null) {
      _crop = ProfilePhotoCropController(
        _crop!.imageSize,
        aspectRatio: widget.aspectRatio,
      );
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Widget _preview(BuildContext context, double viewport) {
    final crop = _crop;
    if (crop == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator()
            : const Icon(Icons.broken_image_outlined),
      );
    }
    final factor = viewport / crop.side;
    final rect = crop.sourceRect;
    Offset normalized(Offset point) =>
        Offset(point.dx / viewport, point.dy / (viewport / widget.aspectRatio));
    return Semantics(
      label:
          '${widget.label} crop preview. Drag to reposition and pinch to zoom.',
      child: GestureDetector(
        key: const ValueKey('profile-crop-viewport'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: _busy
            ? null
            : (details) =>
                  crop.startGesture(normalized(details.localFocalPoint)),
        onScaleUpdate: _busy
            ? null
            : (details) => setState(
                () => crop.updateGesture(
                  details.scale,
                  normalized(details.localFocalPoint),
                ),
              ),
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: -rect.left * factor,
                top: -rect.top * factor,
                width: crop.imageSize.width * factor,
                height: crop.imageSize.height * factor,
                child: RawImage(
                  image: _image,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Dialog insets (40 each side) and content padding (24 each side).
      final viewport = math.min(
        280.0,
        math.max(1.0, constraints.maxWidth - 128),
      );
      return AlertDialog(
        scrollable: true,
        title: Text('Crop ${widget.label}'),
        content: SizedBox(
          width: viewport,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.secondaryAspectRatio == null
                    ? 'Drag to reposition and pinch to zoom. The square shows the image that will be saved.'
                    : 'Drag to reposition and pinch to zoom. The crop matches Event Details; cards keep the whole image. Home uses the center trim shown below.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: viewport,
                height: viewport / widget.aspectRatio,
                child: _preview(context, viewport),
              ),
              // if (widget.secondaryAspectRatio case final ratio?) ...[
              //   const SizedBox(height: 12),
              //   Text(
              //     'Home Preview',
              //     style: Theme.of(context).textTheme.bodySmall,
              //   ),
              //   SizedBox(
              //     width: viewport,
              //     height: viewport / ratio,
              //     child: _image == null || _crop == null
              //         ? const SizedBox.shrink()
              //         : CustomPaint(
              //             key: const ValueKey('event-poster-home-preview'),
              //             painter: _CropCoverPreview(
              //               _image!,
              //               _crop!.sourceRect,
              //             ),
              //           ),
              //   ),
              // ],
              if (_busy) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _busy || _crop == null
                ? null
                : () => setState(() => _crop!.reset()),
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => Navigator.pop(context, widget.bytes),
            child: const Text('Keep Original'),
          ),
          FilledButton(
            onPressed: _busy || _crop == null ? null : _confirm,
            child: const Text('Confirm'),
          ),
        ],
      );
    },
  );
}

class _CropCoverPreview extends CustomPainter {
  _CropCoverPreview(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) {
    final fit = applyBoxFit(BoxFit.cover, source.size, size);
    final sourceCrop = Alignment.center.inscribe(fit.source, source);
    canvas.drawImageRect(
      image,
      sourceCrop,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_CropCoverPreview oldDelegate) =>
      oldDelegate.image != image || oldDelegate.source != source;
}
