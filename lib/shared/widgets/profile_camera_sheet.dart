import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/colors.dart';

/// Opens the interactive live camera sheet to capture a profile picture.
/// Returns a base64-encoded image string ('data:image/jpeg;base64,...') or null if dismissed.
Future<String?> showProfileCameraSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const ProfileCameraSheet(),
  );
}

/// Helper modal displaying quick options: Take Photo, Choose from Gallery, or Remove Photo.
Future<void> showProfilePhotoOptionsModal({
  required BuildContext context,
  required ValueChanged<String> onPhotoSelected,
  VoidCallback? onRemovePhoto,
  bool hasExistingPhoto = false,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? CasamaColors.darkSurface : CasamaColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : CasamaColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CasamaColors.primaryCoral.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: CasamaColors.primaryCoral,
                  ),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Use live camera to take a selfie'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final photo = await showProfileCameraSheet(context);
                  if (photo != null) {
                    onPhotoSelected(photo);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CasamaColors.deepTeal.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: CasamaColors.deepTeal,
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Pick an existing photo from library'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  try {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 600,
                      maxHeight: 600,
                      imageQuality: 85,
                    );
                    if (picked != null) {
                      final bytes = await picked.readAsBytes();
                      final base64Str =
                          'data:image/jpeg;base64,${base64Encode(bytes)}';
                      onPhotoSelected(base64Str);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not access gallery: $e'),
                          backgroundColor: CasamaColors.errorRed,
                        ),
                      );
                    }
                  }
                },
              ),
              if (hasExistingPhoto && onRemovePhoto != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CasamaColors.errorRed.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: CasamaColors.errorRed,
                    ),
                  ),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      color: CasamaColors.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onRemovePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

class ProfileCameraSheet extends StatefulWidget {
  const ProfileCameraSheet({super.key});

  @override
  State<ProfileCameraSheet> createState() => _ProfileCameraSheetState();
}

class _ProfileCameraSheetState extends State<ProfileCameraSheet>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitializing = true;
  bool _hasPermission = false;
  bool _noCameraAvailable = false;
  bool _isFrontCamera = true;

  // Captured snapshot
  Uint8List? _capturedBytes;
  String? _capturedBase64;

  late AnimationController _flipController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _initCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
    });

    // 1. Request camera permission
    bool granted = false;
    try {
      final status = await Permission.camera.request();
      granted = status.isGranted;
    } catch (_) {
      // In web, desktop, or test environments where permission_handler is mocked or unavailable
      granted = true;
    }

    if (!granted) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _hasPermission = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasPermission = true;
    });

    // 2. Fetch available cameras
    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _noCameraAvailable = true;
        });
        return;
      }

      _cameras = cameras;
      // Default to front-facing camera for selfies
      final frontIdx = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;

      await _setupController(_cameras[_selectedCameraIndex]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _noCameraAvailable = true;
      });
    }
  }

  Future<void> _setupController(CameraDescription description) async {
    final old = _controller;
    if (old != null) {
      await old.dispose();
    }

    final controller = CameraController(
      description,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
        _isFrontCamera = description.lensDirection == CameraLensDirection.front;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _noCameraAvailable = true;
      });
    }
  }

  Future<void> _toggleFlip() async {
    if (_cameras.length <= 1) return;
    final nextIdx = (_selectedCameraIndex + 1) % _cameras.length;
    _selectedCameraIndex = nextIdx;
    _flipController.forward(from: 0.0);
    setState(() => _isInitializing = true);
    await _setupController(_cameras[_selectedCameraIndex]);
  }

  bool _isCapturing = false;

  Future<void> _takePicture() async {
    if (_isCapturing) {
      return;
    }
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _controller!.value.hasError) {
      return;
    }

    if (_controller!.value.isTakingPicture) {
      return;
    }

    _isCapturing = true;

    try {
      final file = await _controller!
          .takePicture()
          .timeout(const Duration(seconds: 4));
      final bytes = await file.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      try {
        await _controller!.pausePreview();
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _capturedBytes = bytes;
          _capturedBase64 = base64Str;
        });
      }
    } catch (e) {
      _isCapturing = false;
      try {
        await _controller?.resumePreview();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to take picture: $e'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _retakePicture() async {
    setState(() {
      _capturedBytes = null;
      _capturedBase64 = null;
      _isCapturing = false;
    });

    if (_controller != null &&
        _controller!.value.isInitialized &&
        !_controller!.value.hasError) {
      try {
        await _controller!.resumePreview();
        return;
      } catch (_) {}
    }

    if (_cameras.isNotEmpty) {
      await _setupController(_cameras[_selectedCameraIndex]);
    }
  }

  void _usePicture() {
    if (_capturedBase64 != null) {
      Navigator.of(context).pop(_capturedBase64);
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64Str);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access gallery: $e'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _pickWithSystemCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) {
          Navigator.of(context).pop(base64Str);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open camera: $e'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF16161D);

    return Container(
      decoration: const BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Take Profile Photo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _capturedBytes != null
                        ? 'Looking great! Confirm or retake'
                        : 'Position your face in the circle',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('profile_camera_close_button'),
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Circular Profile Viewfinder
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22222C),
                border: Border.all(
                  color: CasamaColors.primaryCoral,
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CasamaColors.primaryCoral.withAlpha(70),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildViewfinderContent(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Controls & Action Buttons
          _buildActionControls(),
        ],
      ),
    );
  }

  Widget _buildViewfinderContent() {
    // 1. Captured preview
    if (_capturedBytes != null) {
      return Image.memory(
        _capturedBytes!,
        width: 250,
        height: 250,
        fit: BoxFit.cover,
      );
    }

    // 2. Initializing spinner
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              color: CasamaColors.primaryCoral,
            ),
            SizedBox(height: 12),
            Text(
              'Starting camera...',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // 3. Permission denied
    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                color: CasamaColors.primaryCoral,
                size: 38,
              ),
              const SizedBox(height: 8),
              const Text(
                'Camera Access Needed',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Enable camera access to snap a selfie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _initCamera,
                child: const Text(
                  'Grant Permission',
                  style: TextStyle(
                    color: CasamaColors.primaryCoral,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. No camera available (e.g. desktop simulator or missing hardware)
    if (_noCameraAvailable || _controller == null || !_controller!.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_camera_rounded,
                color: CasamaColors.dustyBlue,
                size: 40,
              ),
              const SizedBox(height: 8),
              const Text(
                'Camera Device Offline',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose from your photos or open system camera below',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(160),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. Live camera preview
    Widget preview = FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _controller!.value.previewSize?.height ?? 250,
        height: _controller!.value.previewSize?.width ?? 250,
        child: CameraPreview(_controller!),
      ),
    );

    if (_isFrontCamera) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(math.pi),
        child: preview,
      );
    }

    return AnimatedBuilder(
      animation: _flipController,
      builder: (context, child) {
        final angle = _flipController.value * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: child,
        );
      },
      child: preview,
    );
  }

  Widget _buildActionControls() {
    // When review state (photo taken)
    if (_capturedBytes != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('profile_camera_retake_button'),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retake'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white38),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: _retakePicture,
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            key: const Key('profile_camera_use_photo_button'),
            icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
            label: const Text(
              'Use Photo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CasamaColors.primaryCoral,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: _usePicture,
          ),
        ],
      );
    }

    // When no camera available
    if (_noCameraAvailable) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            key: const Key('profile_camera_fallback_gallery_button'),
            icon: const Icon(
              Icons.photo_library_rounded,
              color: CasamaColors.deepTeal,
              size: 18,
            ),
            label: const Text(
              'Gallery',
              style: TextStyle(
                color: CasamaColors.deepTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: CasamaColors.deepTeal),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: _pickFromGallery,
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            key: const Key('profile_camera_fallback_system_button'),
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'System Camera',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: CasamaColors.primaryCoral,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: _pickWithSystemCamera,
          ),
        ],
      );
    }

    // Live Camera Controls: Gallery | Shutter | Flip
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Gallery Button
        IconButton(
          key: const Key('profile_camera_gallery_button'),
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.photo_library_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          onPressed: _pickFromGallery,
        ),

        // Double Concentric Shutter Button
        GestureDetector(
          key: const Key('profile_camera_shutter_button'),
          onTap: _takePicture,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: CasamaColors.primaryCoral,
                width: 4,
              ),
            ),
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),

        // Camera Flip Button
        IconButton(
          key: const Key('profile_camera_flip_button'),
          icon: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flip_camera_ios_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          onPressed: _cameras.length > 1 ? _toggleFlip : null,
        ),
      ],
    );
  }
}
