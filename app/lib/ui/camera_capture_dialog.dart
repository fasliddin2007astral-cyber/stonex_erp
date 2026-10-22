import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';

/// Windows va Mobil qurilmalarda mijoz yoki pasport suratini olish uchun qulay dialog.
class CameraCaptureDialog extends StatefulWidget {
  const CameraCaptureDialog({super.key});

  @override
  State<CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<CameraCaptureDialog> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initializing = true;
  bool _hasCamera = false;
  Uint8List? _capturedBytes;
  bool _capturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        final ctrl = CameraController(
          _cameras.first,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        _controller = ctrl;
        await ctrl.initialize();
        if (mounted) {
          setState(() {
            _hasCamera = true;
            _initializing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasCamera = false;
            _initializing = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasCamera = false;
          _initializing = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final xFile = await _controller!.takePicture();
      final bytes = await xFile.readAsBytes();
      if (mounted) {
        setState(() {
          _capturedBytes = bytes;
          _capturing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Suratga olishda xatolik: $e';
          _capturing = false;
        });
      }
    }
  }

  Future<void> _pickFromFile() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 82,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted && bytes.isNotEmpty) {
          Navigator.pop(context, bytes);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Fayl tanlashda xatolik: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sarlavha va yopish
            Row(
              children: [
                const Icon(Icons.photo_camera_rounded, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Suratga olish',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kamera / Rasm qismi
            Container(
              height: 280,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildCameraBody(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 16),

            // Boshqaruv tugmalari
            if (_capturedBytes != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _capturedBytes = null),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Qayta olish'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _capturedBytes),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Tasdiqlash'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.neonLime,
                        foregroundColor: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_hasCamera) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromFile,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Fayldan tanlash'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _capturing ? null : _takePicture,
                      icon: _capturing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Suratga olish'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.darkCard,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: _pickFromFile,
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Kompyuterdan fayl tanlash'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.darkCard,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCameraBody() {
    if (_capturedBytes != null) {
      return Image.memory(
        _capturedBytes!,
        fit: BoxFit.contain,
      );
    }

    if (_initializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.neonLime),
            SizedBox(height: 12),
            Text('Kamera ishga tushirilmoqda...', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      );
    }

    if (!_hasCamera || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(height: 10),
              const Text(
                'Veb-kamera topilmadi',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kompyuteringizdan rasm faylini tanlashingiz mumkin',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_controller!),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _capturing ? null : _takePicture,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.camera_rounded, color: AppColors.ink, size: 28),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Windows yoki Mobil qurilmalarda xavfsiz rasm olish/tanlash funksiyasi
Future<Uint8List?> pickOrCaptureCustomerImage(BuildContext context, ImageSource source) async {
  if (source == ImageSource.camera && Platform.isWindows) {
    return showDialog<Uint8List?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CameraCaptureDialog(),
    );
  }

  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 82,
    );
    if (picked != null) {
      return await picked.readAsBytes();
    }
  } catch (e) {
    if (source == ImageSource.camera && context.mounted) {
      return showDialog<Uint8List?>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const CameraCaptureDialog(),
      );
    }
  }
  return null;
}
