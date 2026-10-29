import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../errors/app_failure.dart';
import 'worker_api_service.dart';

class ImageResource {
  const ImageResource(this.kind, {this.organizationId, this.eventId});
  final String kind;
  final String? organizationId, eventId;
  Map<String, dynamic> toMap() => {
    'kind': kind,
    if (organizationId != null) 'organizationId': organizationId,
    if (eventId != null) 'eventId': eventId,
  };
}

/// Shared transport: image references can only be written by the trusted Worker.
class ImageUploadService {
  ImageUploadService(this.api, {ImagePicker? picker})
    : picker = picker ?? ImagePicker();
  final WorkerApiService api;
  final ImagePicker picker;
  static const maxBytes = 5 * 1024 * 1024;

  Future<Uint8List?> select() async {
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const AppFailure('Choose an image up to 5 MB.');
    }
    final bytes = await file.readAsBytes();
    validateBytes(bytes);
    return bytes;
  }

  static void validateBytes(Uint8List bytes) {
    final jpg =
        bytes.length >= 3 &&
        bytes[0] == 255 &&
        bytes[1] == 216 &&
        bytes[2] == 255;
    final png =
        bytes.length >= 8 &&
        bytes[0] == 137 &&
        bytes[1] == 80 &&
        bytes[2] == 78 &&
        bytes[3] == 71;
    final webp =
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
    if (bytes.isEmpty || bytes.length > maxBytes || !(jpg || png || webp)) {
      throw const AppFailure('Choose a JPEG, PNG or WebP image up to 5 MB.');
    }
  }

  static Future<Uint8List> cropSquare(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final side = image.width < image.height ? image.width : image.height;
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImageRect(
          image,
          ui.Rect.fromLTWH(
            (image.width - side) / 2,
            (image.height - side) / 2,
            side.toDouble(),
            side.toDouble(),
          ),
          ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
          ui.Paint(),
        );
        final picture = recorder.endRecording();
        final cropped = await picture.toImage(side, side);
        picture.dispose();
        try {
          final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
          if (data == null) {
            throw const AppFailure('This image could not be prepared.');
          }
          final result = data.buffer.asUint8List();
          validateBytes(result);
          return result;
        } finally {
          cropped.dispose();
        }
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  Future<String> upload(
    ImageResource resource,
    Uint8List bytes, {
    required void Function(String, double?) onProgress,
  }) async {
    validateBytes(bytes);
    onProgress('Preparing upload', null);
    final session = await api.call('/images/sign', resource.toMap());
    final id = session['uploadId'] as String;
    onProgress('Uploading image', 0);
    await api.callWithProgress('/images/upload', {
      'uploadId': id,
      'file': base64Encode(bytes),
      'signature': session['signature'],
    }, onProgress: (value) => onProgress('Uploading image', value));
    return id;
  }

  Future<void> finalize(String id) async {
    await api.call('/images/finalize', {'uploadId': id});
  }

  Future<void> remove(ImageResource resource, String? currentURL) async {
    await api.call('/images/remove', {
      ...resource.toMap(),
      'expectedURL': currentURL,
    });
  }
}

class ImageUploadViewModel extends ChangeNotifier {
  ImageUploadViewModel(this.service, this.resource);
  final ImageUploadService service;
  final ImageResource resource;
  bool busy = false, _disposed = false;
  String? message, pendingUpload;
  double? progress;
  void update(String value, double? amount) {
    message = value;
    progress = amount;
    if (!_disposed) notifyListeners();
  }

  Future<bool> save(Uint8List? bytes) => _run(() async {
    if (bytes != null) {
      pendingUpload = await service.upload(resource, bytes, onProgress: update);
    }
    final id = pendingUpload;
    if (id == null) throw const AppFailure('Choose an image first.');
    update('Verifying image', null);
    await service.finalize(id);
    pendingUpload = null;
  });
  Future<bool> remove(String? url) => _run(() async {
    update('Removing image', null);
    await service.remove(resource, url);
    pendingUpload = null;
  });
  Future<bool> _run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    notifyListeners();
    try {
      await action();
      update('Image saved.', null);
      return true;
    } on AppFailure catch (error) {
      update(error.message, null);
      return false;
    } catch (_) {
      update('The image could not be saved. Refresh before retrying.', null);
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
