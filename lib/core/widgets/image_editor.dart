import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../errors/app_failure.dart';
import '../services/image_upload_service.dart';
import '../services/worker_api_service.dart';
import 'profile_photo_crop_dialog.dart';

/// The surrounding screen supplies permission hints; the Worker always authorizes.
class ImageEditor extends StatefulWidget {
  const ImageEditor({
    super.key,
    required this.resource,
    required this.label,
    this.currentURL,
    this.service,
    this.onSaved,
  });
  final ImageResource resource;
  final String label;
  final String? currentURL;
  final ImageUploadService? service;
  final Future<void> Function()? onSaved;
  @override
  State<ImageEditor> createState() => _ImageEditorState();
}

class _ImageEditorState extends State<ImageEditor> {
  ImageUploadViewModel? _model;
  bool _selecting = false;
  String? _selectionError;
  ImageUploadViewModel get model => _model ??= ImageUploadViewModel(
    widget.service ??
        ImageUploadService(WorkerApiService(FirebaseAuth.instance)),
    widget.resource,
  )..addListener(_changed);
  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _model?.dispose();
    super.dispose();
  }

  Future<void> _select() async {
    setState(() {
      _selecting = true;
      _selectionError = null;
    });
    try {
      var bytes = await model.service.select();
      if (bytes == null || !mounted) return;
      if (['profile', 'organization'].contains(widget.resource.kind)) {
        final selected = bytes;
        bytes = await showDialog<Uint8List>(
          context: context,
          builder: (context) => ProfilePhotoCropDialog(
            bytes: selected,
            label: widget.resource.kind == 'organization'
                ? 'Organization Logo'
                : 'Profile Photo',
          ),
        );
        if (bytes == null || !mounted) return;
      } else {
        final crop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text('Change ${widget.label}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  width: 240,
                  child: Image.memory(bytes!, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Keep the original framing or crop the center to a square.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Original'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Crop Square'),
              ),
            ],
          ),
        );
        if (crop == null || !mounted) return;
        if (crop) bytes = await ImageUploadService.cropSquare(bytes);
      }
      if (!mounted) return;
      if (await model.save(bytes) && mounted) {
        await widget.onSaved?.call();
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _selectionError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _selectionError =
              'The gallery or image could not be opened. Try another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${widget.label}'),
        content: const Text(
          'Remove this image and use the default appearance?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      if (await model.remove(widget.currentURL) && mounted) {
        await widget.onSaved?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _selecting || (_model?.busy ?? false);
    final message = _selectionError ?? _model?.message;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: busy ? null : _select,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Change ${widget.label}'),
              ),
              if (widget.currentURL?.isNotEmpty == true)
                TextButton(
                  onPressed: busy ? null : _remove,
                  child: Text('Remove ${widget.label}'),
                ),
              if (_model?.pendingUpload != null && !busy)
                TextButton(
                  onPressed: () async {
                    if (await model.save(null) && mounted) {
                      await widget.onSaved?.call();
                    }
                  },
                  child: const Text('Retry Verification'),
                ),
            ],
          ),
          if (_model?.busy == true)
            LinearProgressIndicator(
              value: _model?.progress == 1 ? null : _model?.progress,
            ),
          if (message != null)
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          const Text(
            'JPEG, PNG or WebP, up to 5 MB. Image changes save immediately.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
