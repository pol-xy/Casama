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
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
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
    with TickerProviderStateMixin {
  static const String _prefKeyCameraPermission =
      'quicksnap_camera_permission_granted';

  List<CameraDescription> _availableCameras = [];
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitializing = false;
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;
  bool _isCapturing = false;

  bool _permissionPromptShown = false;
  bool _permissionGranted = false;

  int _flashMode = 0; // 0 = off, 1 = on, 2 = auto

  late final AnimationController _flashController;
  late final AnimationController _flipController;
  double _flipAngleStart = 0;
  double _flipAngleEnd = 0;

  String? _capturedImageUrl;
  Uint8List? _capturedBytes;
  final TextEditingController _captionController = TextEditingController();

  QuickSnapRecipientType _recipientType = QuickSnapRecipientType.everyone;
  final List<String> _selectedRecipients = [];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: CasamaMotion.shutterFlash,
    );
    _flipController = AnimationController(
      vsync: this,
      duration: CasamaMotion.cameraFlip,
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
    _flashController.dispose();
    _flipController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptPermission({bool forceDialog = false}) async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSavedPermission =
        prefs.getBool(_prefKeyCameraPermission) ?? false;

    if (hasSavedPermission && !forceDialog) {
      if (!mounted) return;
      setState(() => _permissionGranted = true);
      await _initLiveCamera();
      return;
    }

    if (_permissionPromptShown && !forceDialog) return;
    _permissionPromptShown = true;
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141B29),
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
              const SizedBox(height: 14),
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
                'Casama needs camera access to capture live moments and share CASnaps with your housemates.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              CasamaButton(
                key: const Key('allow_camera_permission_button'),
                label: 'Allow Camera Access',
                isPill: true,
                height: 50,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 6),
              TextButton(
                key: const Key('deny_camera_permission_button'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
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
    } else if (mounted) {
      setState(() => _permissionGranted = false);
    }
  }

  Future<void> _requestSystemPermissionAndInit() async {
    var granted = false;
    try {
      final status = await Permission.camera.request();
      granted = status.isGranted;
    } catch (_) {
      granted = true;
    }

    if (granted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefKeyCameraPermission, true);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    if (granted) {
      await _initLiveCamera();
    }
  }

  Future<void> _initLiveCamera() async {
    setState(() => _isCameraInitializing = true);
    try {
      final cameras = await availableCameras();
      if (!mounted) return;

      if (cameras.isNotEmpty) {
        _availableCameras = cameras;
        final frontIdx = cameras.indexWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
        _selectedCameraIndex = frontIdx != -1 ? frontIdx : 0;
        await _setupController(_availableCameras[_selectedCameraIndex]);
      } else {
        setState(() => _isCameraInitializing = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraInitializing = false);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = false;
        _isCameraInitializing = false;
      });
    }
  }

  Future<void> _toggleCameraFlip() async {
    final reduced = CasamaMotion.reduceMotion(context);
    setState(() {
      _flipAngleStart = _flipAngleEnd;
      _flipAngleEnd = _flipAngleEnd + math.pi;
      _isFrontCamera = !_isFrontCamera;
    });
    if (!reduced) {
      _flipController.forward(from: 0);
    }

    if (_availableCameras.length > 1) {
      _selectedCameraIndex =
          (_selectedCameraIndex + 1) % _availableCameras.length;
      await _setupController(_availableCameras[_selectedCameraIndex]);
    }
  }

  Future<void> _cycleFlash() async {
    setState(() => _flashMode = (_flashMode + 1) % 3);
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final mode = _flashMode == 1
            ? FlashMode.always
            : (_flashMode == 2 ? FlashMode.auto : FlashMode.off);
        await _cameraController!.setFlashMode(mode);
      } catch (_) {}
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _capturedBytes = bytes;
            _capturedImageUrl = file.path;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _takeSnap() async {
    if (_isCapturing) return;
    _isCapturing = true;
    final reduced = CasamaMotion.reduceMotion(context);

    if (!reduced) {
      _flashController.forward(from: 0);
    }
    await Future.delayed(const Duration(milliseconds: 60));

    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.hasError) {
      if (_cameraController!.value.isTakingPicture) {
        _isCapturing = false;
        return;
      }
      try {
        final file = await _cameraController!
            .takePicture()
            .timeout(const Duration(seconds: 4));
        final bytes = await file.readAsBytes();
        try {
          await _cameraController!.pausePreview();
        } catch (_) {}

        if (!mounted) return;
        setState(() {
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

    if (!mounted) return;
    setState(() {
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

    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.hasError) {
      try {
        await _cameraController!.resumePreview();
        return;
      } catch (_) {}
    }

    if (_permissionGranted && _availableCameras.isNotEmpty) {
      await _setupController(_availableCameras[_selectedCameraIndex]);
    }
  }

  void _sendSnap() {
    if (_capturedImageUrl == null) return;
    final repo = ref.read(repositoryProvider);
    repo.sendQuickSnap(
      imageUrl: _capturedImageUrl!,
      caption: _captionController.text.trim().isEmpty
          ? null
          : _captionController.text.trim(),
      recipientType: _recipientType,
      recipientNames: _selectedRecipients,
    );

    final targetLabel = _recipientType == QuickSnapRecipientType.everyone
        ? 'Everyone'
        : _selectedRecipients.join(', ');

    showCasamaToast(
      context,
      'CASnap sent to $targetLabel',
      icon: Icons.send_rounded,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const QuickSnapFeedScreen(),
      ),
    );
  }

  void _openRecipientSheet() {
    final repo = ref.read(repositoryProvider);
    final members = repo.members;

    showCasamaSheet<void>(
      context,
      darkSurfaceOverride: true,
      icon: Icons.group_rounded,
      iconBackgroundColor: CasamaColors.primaryCoral.withValues(alpha: 0.2),
      iconColor: CasamaColors.primaryCoral,
      title: 'Send CASnap to...',
      subtitle: 'Choose who in ${repo.currentHousehold.name} will see this photo',
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: CasamaSpacing.roundedLg,
                  onTap: () {
                    setSheetState(() {
                      setState(() {
                        _recipientType = QuickSnapRecipientType.everyone;
                        _selectedRecipients.clear();
                      });
                    });
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 54),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: CasamaColors.primaryCoral.withValues(
                              alpha: 0.2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.group_rounded,
                            color: CasamaColors.primaryCoral,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Everyone in ${repo.currentHousehold.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        _SheetCheckCircle(
                          selected:
                              _recipientType == QuickSnapRecipientType.everyone,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...members.map((m) {
                  final name = m.profile.displayName;
                  final isSelected =
                      _recipientType ==
                              QuickSnapRecipientType.selectedHousemates &&
                          _selectedRecipients.contains(name);
                  return InkWell(
                    borderRadius: CasamaSpacing.roundedLg,
                    onTap: () {
                      setSheetState(() {
                        setState(() {
                          _recipientType =
                              QuickSnapRecipientType.selectedHousemates;
                          if (isSelected) {
                            _selectedRecipients.remove(name);
                            if (_selectedRecipients.isEmpty) {
                              _recipientType = QuickSnapRecipientType.everyone;
                            }
                          } else {
                            _selectedRecipients.add(name);
                          }
                        });
                      });
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: Row(
                        children: [
                          CasamaAvatar(
                            avatarUrl: m.profile.effectiveAvatarUrl,
                            radius: 18,
                            name: name,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          _SheetCheckCircle(selected: isSelected),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: CasamaSpacing.md),
                CasamaButton(
                  label: 'Done',
                  isPill: true,
                  height: 50,
                  onPressed: () => Navigator.of(sheetCtx).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildViewfinderContent() {
    if (_capturedImageUrl != null) {
      if (_capturedBytes != null) {
        return Image.memory(_capturedBytes!, fit: BoxFit.cover);
      }
      if (_capturedImageUrl!.startsWith('http://') ||
          _capturedImageUrl!.startsWith('https://')) {
        return Image.network(
          _capturedImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
        );
      }
      if (!kIsWeb) {
        final file = File(_capturedImageUrl!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildPlaceholder(),
          );
        }
      }
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2D625F), Color(0xFF10161F)],
          ),
        ),
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
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Ready to share with your housemates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(
                    _isFrontCamera ? -1.0 : 1.0,
                    1.0,
                    1.0,
                  ),
                  child: SizedBox(
                    width:
                        _cameraController!.value.previewSize?.height ??
                        constraints.maxWidth,
                    height:
                        _cameraController!.value.previewSize?.width ??
                        constraints.maxHeight,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (_isCameraInitializing) {
      return const ColoredBox(
        color: Color(0xFF10161F),
        child: Center(
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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D625F), Color(0xFF10161F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CasMascotView(
                  pose: CasPose.hero,
                  width: 92,
                  height: 92,
                ),
                const SizedBox(height: 10),
                Text(
                  _permissionGranted ? 'Camera Ready' : 'Camera Access Needed',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _permissionGranted
                      ? 'Tap shutter to take a photo'
                      : 'Allow camera to capture live moments',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.56),
                    fontSize: 11.5,
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
                    color: Colors.black.withValues(alpha: 0.72),
                    borderRadius: CasamaSpacing.roundedPill,
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
                            fontWeight: FontWeight.w700,
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
      color: const Color(0xFF141B29),
      child: const Center(
        child: Icon(Icons.photo_camera_outlined, color: Colors.white54, size: 50),
      ),
    );
  }

  String _recipientLabel() {
    if (_recipientType == QuickSnapRecipientType.everyone) return 'Everyone';
    if (_selectedRecipients.length == 1) return _selectedRecipients.first;
    return '${_selectedRecipients.length} Friends';
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final memberCount = repo.members.length;
    final vfSize = math.min(MediaQuery.sizeOf(context).width - 32, 340.0);

    return Scaffold(
      backgroundColor: const Color(0xFF070C16),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Semantics(
                    button: true,
                    label: 'Close camera',
                    child: CasamaPressable(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  Semantics(
                    button: true,
                    label: 'Choose recipients',
                    child: CasamaPressable(
                      onTap: _openRecipientSheet,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: CasamaSpacing.roundedPill,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.group_rounded,
                              color: Colors.white70,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _recipientLabel(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
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
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        button: true,
                        label: 'Cycle flash mode',
                        child: CasamaPressable(
                          onTap: _cycleFlash,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
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
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: CasamaSpacing.roundedPill,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$memberCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
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

            // Rounded Square Viewfinder + 450ms White Shutter Flash Fade-out
            Center(
              child: Container(
                width: vfSize,
                height: vfSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildViewfinderContent(),
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
                    // 450ms flash pulse (fades 0.90 -> 0.0)
                    AnimatedBuilder(
                      animation: _flashController,
                      builder: (context, _) {
                        if (!_flashController.isAnimating &&
                            _flashController.value == 0) {
                          return const SizedBox.shrink();
                        }
                        final opacity =
                            (1.0 - _flashController.value).clamp(0.0, 1.0) *
                            0.9;
                        if (opacity <= 0.01) return const SizedBox.shrink();
                        return IgnorePointer(
                          child: Container(
                            color: Colors.white.withValues(alpha: opacity),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'Sending to ${_recipientLabel()} in ${repo.currentHousehold.name}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            if (_capturedImageUrl != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 6,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: TextField(
                    controller: _captionController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Add a message or note...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      fillColor: Colors.transparent,
                      filled: false,
                      isDense: true,
                    ),
                    maxLength: 80,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _retake,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        side: const BorderSide(color: Colors.white38),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        'Retake',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CasamaButton(
                        key: const Key('send_quicksnap_button'),
                        icon: Icons.send_rounded,
                        label:
                            'Send to ${_recipientType == QuickSnapRecipientType.everyone ? "Everyone" : "Friends"}',
                        isPill: true,
                        height: 50,
                        onPressed: _sendSnap,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Choose photo from gallery',
                      child: CasamaPressable(
                        key: const Key('gallery_picker_button'),
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),

                    Semantics(
                      button: true,
                      label: 'Take CASnap',
                      child: CasamaPressable.fab(
                        key: const Key('quicksnap_shutter_button'),
                        onTap: _takeSnap,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: CasamaColors.warmGold,
                              width: 4,
                            ),
                          ),
                          padding: const EdgeInsets.all(5),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 350ms 180-degree camera flip rotation
                    Semantics(
                      button: true,
                      label: 'Flip camera',
                      child: CasamaPressable(
                        key: const Key('flip_camera_button'),
                        onTap: _toggleCameraFlip,
                        child: AnimatedBuilder(
                          animation: _flipController,
                          builder: (context, child) {
                            final angle =
                                _flipAngleStart +
                                (_flipAngleEnd - _flipAngleStart) *
                                    CurvedAnimation(
                                      parent: _flipController,
                                      curve: CasamaMotion.easeOut,
                                    ).value;
                            return Transform.rotate(angle: angle, child: child);
                          },
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Semantics(
                button: true,
                label: 'Open CASnap gallery history',
                child: CasamaPressable(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const QuickSnapFeedScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: CasamaSpacing.roundedPill,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: Colors.white70,
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'History',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white54,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetCheckCircle extends StatelessWidget {
  final bool selected;

  const _SheetCheckCircle({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: selected ? CasamaColors.primaryCoral : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? CasamaColors.primaryCoral : Colors.white30,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
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
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white60, width: 2.5)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white60, width: 2.5)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white60, width: 2.5)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white60, width: 2.5)
              : BorderSide.none,
        ),
      ),
    );
  }
}
