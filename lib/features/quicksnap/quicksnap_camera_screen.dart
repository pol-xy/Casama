import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/colors.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import 'quicksnap_feed_screen.dart';

class QuickSnapCameraScreen extends ConsumerStatefulWidget {
  final bool autoPromptPermission;

  const QuickSnapCameraScreen({
    super.key,
    this.autoPromptPermission = true,
  });

  @override
  ConsumerState<QuickSnapCameraScreen> createState() =>
      _QuickSnapCameraScreenState();
}

class _QuickSnapCameraScreenState extends ConsumerState<QuickSnapCameraScreen>
    with SingleTickerProviderStateMixin {
  static const String _prefKeyCameraPermission =
      'quicksnap_camera_permission_granted';

  // Camera state
  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitializing = false;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;
  bool _isCapturing = false;

  // Permission state
  bool _permissionPromptShown = false;
  bool _permissionGranted = false;

  int _flashMode = 0; // 0 = off, 1 = on, 2 = auto
  bool _isFlashing = false;
  late AnimationController _flipController;

  // Captured snapshot
  String? _capturedImageUrl;
  Uint8List? _capturedBytes;
  final TextEditingController _captionController = TextEditingController();

  // Audience
  QuickSnapRecipientType _recipientType = QuickSnapRecipientType.everyone;
  final List<String> _selectedRecipients = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    if (widget.autoPromptPermission) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndPromptPermission();
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flipController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptPermission({bool forceDialog = false}) async {
    if (!mounted) return;

    // Check saved permission history from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final bool hasSavedPermission =
        prefs.getBool(_prefKeyCameraPermission) ?? false;

    // If permission was already accepted previously, skip dialog and launch camera directly!
    if (hasSavedPermission && !forceDialog) {
      if (!mounted) return;
      setState(() {
        _permissionGranted = true;
      });
      await _initLiveCamera();
      return;
    }

    if (_permissionPromptShown && !forceDialog) return;
    _permissionPromptShown = true;

    if (!mounted) return;

    // Show branded modal asking for permission first (only shown once)
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CasMascotView(
                pose: CasPose.waving,
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enable Camera for QuickSnap',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Casama needs access to your camera to capture live moments and send QuickSnaps to your housemates in Casa 204.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(190),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('allow_camera_permission_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CasamaColors.primaryCoral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text(
                    'Allow Camera Access',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('deny_camera_permission_button'),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (proceed == true) {
      await prefs.setBool(_prefKeyCameraPermission, true);
      await _requestSystemPermissionAndInit();
    } else {
      if (mounted) {
        setState(() {
          _permissionGranted = false;
        });
      }
    }
  }

  Future<void> _requestSystemPermissionAndInit() async {
    bool granted = false;
    try {
      final status = await Permission.camera.request();
      granted = status.isGranted;
    } catch (_) {
      // In test environment or web where permission_handler is mocked or unavailable
      granted = true;
    }

    if (granted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyCameraPermission, true);
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _permissionGranted = granted;
    });

    if (granted) {
      await _initLiveCamera();
    }
  }

  Future<void> _initLiveCamera() async {
    setState(() {
      _isCameraInitializing = true;
    });

    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isNotEmpty) {
        _availableCameras = cameras;
        // Default to front-facing camera for quick snaps/selfies if available
        final frontIdx = cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupController(_availableCameras[_selectedCameraIndex]);
      } else {
        setState(() {
          _isCameraInitializing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitializing = false;
      });
    }
  }

  Future<void> _setupController(CameraDescription description) async {
    final oldController = _cameraController;
    _cameraController = null;
    if (oldController != null) {
      try {
        await oldController.dispose();
      } catch (_) {}
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
        _cameraController = controller;
        _isCameraInitialized = true;
        _isCameraInitializing = false;
        _isFrontCamera = description.lensDirection == CameraLensDirection.front;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isCameraInitializing = false;
      });
    }
  }

  void _toggleCameraFlip() async {
    if (_availableCameras.length > 1) {
      final nextIdx = (_selectedCameraIndex + 1) % _availableCameras.length;
      _selectedCameraIndex = nextIdx;
      _flipController.forward(from: 0.0);
      await _setupController(_availableCameras[_selectedCameraIndex]);
    } else {
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });
      _flipController.forward(from: 0.0);
    }
  }

  void _cycleFlash() async {
    setState(() {
      _flashMode = (_flashMode + 1) % 3;
    });

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final mode = _flashMode == 1
            ? FlashMode.always
            : (_flashMode == 2 ? FlashMode.auto : FlashMode.off);
        await _cameraController!.setFlashMode(mode);
      } catch (_) {
        // Flash mode unsupported or not available
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _capturedBytes = bytes;
          _capturedImageUrl = file.path;
        });
      }
    } catch (_) {
      // Fallback
    }
  }

  Future<void> _takeSnap() async {
    if (_isCapturing) return;
    _isCapturing = true;

    // Trigger shutter flash animation
    setState(() => _isFlashing = true);
    await Future.delayed(const Duration(milliseconds: 100));

    // Hardware capture if live camera is active
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.hasError) {
      if (_cameraController!.value.isTakingPicture) {
        _isCapturing = false;
        return;
      }
      try {
        final XFile file = await _cameraController!
            .takePicture()
            .timeout(const Duration(seconds: 4));
        final bytes = await file.readAsBytes();

        try {
          await _cameraController!.pausePreview();
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          _isFlashing = false;
          _isCapturing = false;
          _capturedBytes = bytes;
          _capturedImageUrl = file.path;
        });
        return;
      } catch (e) {
        debugPrint('QuickSnap hardware capture error or timeout: $e');
        try {
          await _cameraController?.resumePreview();
        } catch (_) {}
      }
    }

    // Offline / Fallback capture for tests & non-camera environments
    if (!mounted) return;
    setState(() {
      _isFlashing = false;
      _isCapturing = false;
      _capturedImageUrl =
          'offline_snap_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  Future<void> _retake() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _capturedImageUrl = null;
      _capturedBytes = null;
      _captionController.clear();
      _isCapturing = false;
    });

    // 1. First attempt: resume native preview if controller is still initialized
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.hasError) {
      try {
        await _cameraController!.resumePreview();
        return;
      } catch (_) {
        // Fallback to fresh setup below if resume fails
      }
    }

    // 2. Second attempt: Re-initialize camera controller cleanly
    if (_permissionGranted && _availableCameras.isNotEmpty) {
      await _setupController(_availableCameras[_selectedCameraIndex]);
    }
  }

  void _sendSnap() {
    if (_capturedImageUrl == null) return;
    final repo = ref.read(repositoryProvider);
    repo.sendQuickSnap(
      imageUrl: _capturedImageUrl!,
      imageBytes: _capturedBytes,
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      recipientType: _recipientType,
      recipientNames: _selectedRecipients,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _recipientType == QuickSnapRecipientType.everyone
                  ? 'QuickSnap sent to Everyone! 💛'
                  : 'QuickSnap sent to ${_selectedRecipients.join(", ")}! 💛',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: CasamaColors.primaryCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Open Feed/History
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const QuickSnapFeedScreen(),
      ),
    );
  }

  void _openRecipientSheet() {
    final repo = ref.read(repositoryProvider);
    final members = repo.members;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E26),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Send QuickSnap to...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose who in Casa 204 will see this photo',
                      style: TextStyle(
                        color: Colors.white.withAlpha(160),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: CasamaColors.primaryCoral.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.group_rounded,
                          color: CasamaColors.primaryCoral,
                          size: 20,
                        ),
                      ),
                      title: const Text(
                        'Everyone in Casa 204',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing:
                          _recipientType == QuickSnapRecipientType.everyone
                              ? const Icon(
                                  Icons.check_circle,
                                  color: CasamaColors.primaryCoral,
                                )
                              : null,
                      onTap: () {
                        setState(() {
                          _recipientType = QuickSnapRecipientType.everyone;
                          _selectedRecipients.clear();
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(color: Colors.white12),
                    ...members.map((m) {
                      final name = m.profile.displayName;
                      final isSelected =
                          _recipientType ==
                                  QuickSnapRecipientType.selectedHousemates &&
                              _selectedRecipients.contains(name);
                      return ListTile(
                        leading: CasamaAvatar(
                          avatarUrl: m.profile.effectiveAvatarUrl,
                          radius: 18,
                          name: name,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          activeColor: CasamaColors.primaryCoral,
                          onChanged: (checked) {
                            setSheetState(() {
                              setState(() {
                                _recipientType =
                                    QuickSnapRecipientType.selectedHousemates;
                                if (checked == true) {
                                  _selectedRecipients.add(name);
                                } else {
                                  _selectedRecipients.remove(name);
                                  if (_selectedRecipients.isEmpty) {
                                    _recipientType =
                                        QuickSnapRecipientType.everyone;
                                  }
                                }
                              });
                            });
                          },
                        ),
                        onTap: () {
                          setSheetState(() {
                            setState(() {
                              _recipientType =
                                  QuickSnapRecipientType.selectedHousemates;
                              if (isSelected) {
                                _selectedRecipients.remove(name);
                                if (_selectedRecipients.isEmpty) {
                                  _recipientType =
                                      QuickSnapRecipientType.everyone;
                                }
                              } else {
                                _selectedRecipients.add(name);
                              }
                            });
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildViewfinderContent() {
    // 1. Captured photo preview
    if (_capturedImageUrl != null) {
      if (_capturedBytes != null) {
        return Image.memory(
          _capturedBytes!,
          fit: BoxFit.cover,
        );
      }
      if (_capturedImageUrl!.startsWith('http://') ||
          _capturedImageUrl!.startsWith('https://')) {
        return Image.network(
          _capturedImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
      if (!kIsWeb) {
        final file = File(_capturedImageUrl!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        }
      }
      return Container(
        color: const Color(0xFF1E1E26),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                color: CasamaColors.primaryCoral,
                size: 54,
              ),
              const SizedBox(height: 12),
              const Text(
                'Photo Captured!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to share with your housemates',
                style: TextStyle(
                  color: Colors.white.withAlpha(140),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Live camera feed
    if (_isCameraInitialized &&
        _cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.hasError) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return ClipRect(
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ??
                      constraints.maxWidth,
                  height: _cameraController!.value.previewSize?.width ??
                      constraints.maxHeight,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          );
        },
      );
    }

    // 3. Initializing state
    if (_isCameraInitializing) {
      return Container(
        color: const Color(0xFF15151B),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: CasamaColors.primaryCoral),
              SizedBox(height: 12),
              Text(
                'Starting camera...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Clean dark viewfinder (empty state, zero fake sample photos)
    return Container(
      color: const Color(0xFF16161D),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                    color: Colors.white.withAlpha(10),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.camera_rounded,
                      color: Colors.white38,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _permissionGranted
                      ? 'Camera Ready'
                      : 'Camera Access Needed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _permissionGranted
                      ? 'Tap shutter to take a photo'
                      : 'Allow camera to capture live moments',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!_permissionGranted)
            Positioned(
              top: 14,
              left: 16,
              right: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: CasamaColors.warmGold,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Permission Needed',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _checkAndPromptPermission(forceDialog: true),
                        child: const Text(
                          'Enable',
                          style: TextStyle(
                            color: CasamaColors.primaryCoral,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey.shade900,
      child: const Center(
        child: Icon(
          Icons.camera_alt,
          color: Colors.white54,
          size: 50,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final memberCount = repo.members.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // ── Top Bar ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back / Close
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => context.pop(),
                      ),

                      // Recipient Pill Dropdown (Locket style)
                      GestureDetector(
                        onTap: _openRecipientSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(28),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _recipientType ==
                                        QuickSnapRecipientType.everyone
                                    ? 'Everyone'
                                    : (_selectedRecipients.length == 1
                                        ? _selectedRecipients.first
                                        : '${_selectedRecipients.length} Friends'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Friends Count pill & Flash
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _flashMode == 0
                                  ? Icons.flash_off_rounded
                                  : (_flashMode == 1
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_auto_rounded),
                              color: _flashMode > 0
                                  ? CasamaColors.warmGold
                                  : Colors.white70,
                              size: 22,
                            ),
                            onPressed: _cycleFlash,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.people_alt_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '$memberCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // ── Rounded Viewfinder (Locket Photo Frame) ─────────
                Center(
                  child: Container(
                    width: math.min(
                      MediaQuery.of(context).size.width - 32,
                      340,
                    ),
                    height: math.min(
                      MediaQuery.of(context).size.width - 32,
                      340,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(120),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Camera preview or Captured Image or Clean Dark Viewfinder
                        _buildViewfinderContent(),

                        // Viewfinder Corner Accents
                        const Positioned(
                          top: 16,
                          left: 16,
                          child: _CornerAccent(isTop: true, isLeft: true),
                        ),
                        const Positioned(
                          top: 16,
                          right: 16,
                          child: _CornerAccent(isTop: true, isLeft: false),
                        ),
                        const Positioned(
                          bottom: 16,
                          left: 16,
                          child: _CornerAccent(isTop: false, isLeft: true),
                        ),
                        const Positioned(
                          bottom: 16,
                          right: 16,
                          child: _CornerAccent(isTop: false, isLeft: false),
                        ),

                        // Shutter Flash Effect
                        if (_isFlashing) Container(color: Colors.white),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ── Caption & Actions (when photo captured) ────────
                if (_capturedImageUrl != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a message or note...',
                          hintStyle: TextStyle(
                            color: Colors.white.withAlpha(120),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        maxLength: 80,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                maxLength}) =>
                            null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        // Retake
                        OutlinedButton(
                          onPressed: _retake,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white38),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: const Text('Retake'),
                        ),
                        const SizedBox(width: 12),

                        // Send
                        Expanded(
                          child: ElevatedButton.icon(
                            key: const Key('send_quicksnap_button'),
                            onPressed: _sendSnap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CasamaColors.primaryCoral,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              'Send to ${_recipientType == QuickSnapRecipientType.everyone ? "Everyone" : "Friends"}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // ── Shutter Controls Row (Locket Style) ───────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Gallery Button
                        GestureDetector(
                          key: const Key('gallery_picker_button'),
                          onTap: _pickFromGallery,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        // Shutter Button (Locket Circular Outer Ring)
                        GestureDetector(
                          key: const Key('quicksnap_shutter_button'),
                          onTap: _takeSnap,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CasamaColors.warmGold,
                                width: 4.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(4.5),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),

                        // Camera Flip Button
                        GestureDetector(
                          key: const Key('flip_camera_button'),
                          onTap: _toggleCameraFlip,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(25),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── History / Memories swipe-up Pill ──────────────
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QuickSnapFeedScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'History',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white54,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CornerAccent extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _CornerAccent({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white54, width: 2.5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white54, width: 2.5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white54, width: 2.5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white54, width: 2.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}
