import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../errors/app_failure.dart';
import '../services/image_upload_service.dart';

/// Crop geometry is kept in source-image pixels, independent of screen size.
class ProfilePhotoCropController {
  ProfilePhotoCropController(this.imageSize)
    : center = imageSize.center(Offset.zero);
  final Size imageSize;
  double zoom = 1, _startZoom = 1;
  Offset center, _anchor = Offset.zero;
  double get side => math.min(imageSize.width, imageSize.height) / zoom;
  Rect get sourceRect =>
      Rect.fromCenter(center: center, width: side, height: side);
  void reset() {
    zoom = 1;
    center = imageSize.center(Offset.zero);
  }

  // Focal coordinates are relative to the square viewport, in the range 0..1.
  void startGesture(Offset focal) {
    _startZoom = zoom;
    _anchor = center + (focal - const Offset(.5, .5)) * side;
  }

  void updateGesture(double scale, Offset focal) {
    zoom = (_startZoom * scale).clamp(1, 8);
    final wanted = _anchor - (focal - const Offset(.5, .5)) * side;
    center = Offset(
      wanted.dx.clamp(side / 2, imageSize.width - side / 2),
      wanted.dy.clamp(side / 2, imageSize.height - side / 2),
    );
  }
}

Future<Uint8List> renderProfilePhotoCrop(ui.Image image, Rect source) async {
  final size = source.width.floor().clamp(1, 2048);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    source,
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..filterQuality = FilterQuality.high,
  );
  final picture = recorder.endRecording();
  late ui.Image cropped;
  try {
    cropped = await picture.toImage(size, size);
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
  });
  final Uint8List bytes;
  final String label;
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
    return Semantics(
      label:
          '${widget.label} crop preview. Drag to reposition and pinch to zoom.',
      child: GestureDetector(
        key: const ValueKey('profile-crop-viewport'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: _busy
            ? null
            : (details) =>
                  crop.startGesture(details.localFocalPoint / viewport),
        onScaleUpdate: _busy
            ? null
            : (details) => setState(
                () => crop.updateGesture(
                  details.scale,
                  details.localFocalPoint / viewport,
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
              const Text(
                'Drag to reposition and pinch to zoom. The square shows the image that will be saved.',
              ),
              const SizedBox(height: 16),
              SizedBox.square(
                dimension: viewport,
                child: _preview(context, viewport),
              ),
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
