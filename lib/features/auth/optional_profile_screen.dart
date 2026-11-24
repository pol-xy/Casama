import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/profile_camera_sheet.dart';

class OptionalProfileScreen extends ConsumerStatefulWidget {
  const OptionalProfileScreen({super.key});

  @override
  ConsumerState<OptionalProfileScreen> createState() =>
      _OptionalProfileScreenState();
}

class _OptionalProfileScreenState extends ConsumerState<OptionalProfileScreen> {
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedAvatar;
  bool _isPickingImage = false;

  // Preset avatar choices for easy one-tap selection
  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _openCameraCapture() async {
    final photo = await showProfileCameraSheet(context);
    if (photo != null && mounted) {
      setState(() {
        _selectedAvatar = photo;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.camera) {
      await _openCameraCapture();
      return;
    }
    setState(() => _isPickingImage = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedAvatar = base64String;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not access image: $e'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _saveAndContinue() {
    final fullName = _fullNameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);

    ref
        .read(repositoryProvider)
        .updateProfile(
          fullName: fullName.isNotEmpty ? fullName : null,
          displayName: fullName.isNotEmpty
              ? fullName
              : (nickname.isNotEmpty ? nickname : null),
          nickname: nickname.isNotEmpty ? nickname : null,
          age: age,
          avatarUrl: _selectedAvatar,
        );

    context.push('/terms-consent');
  }

  void _skipForNow() {
    context.push('/terms-consent');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Optional Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _skipForNow,
            child: Text(
              'Skip',
              style: TextStyle(
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: CasamaSpacing.sm),
              Text(
                'Tell Us About You 👋',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Step 2 of 4: These four details are completely optional. You can skip any or all of them and update later.',
                style: TextStyle(
                  fontSize: 13,
                  color: context.textSecondaryColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: CasamaSpacing.lg),

              // Profile Picture (Optional)
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CasamaAvatar(
                          avatarUrl: _selectedAvatar,
                          radius: 46,
                          name: _fullNameController.text,
                          showEditBadge: true,
                          onTap: _openCameraCapture,
                          borderWidth: 2,
                        ),
                        if (_isPickingImage)
                          const Positioned.fill(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: CasamaColors.primaryCoral,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Camera & Gallery Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: CasamaColors.primaryCoral,
                          ),
                          label: const Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CasamaColors.primaryCoral,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: const BorderSide(
                              color: CasamaColors.primaryCoral,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: _openCameraCapture,
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.photo_library_rounded,
                            size: 16,
                            color: CasamaColors.deepTeal,
                          ),
                          label: const Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CasamaColors.deepTeal,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            side: const BorderSide(
                              color: CasamaColors.deepTeal,
                              width: 1.2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Or choose a preset:',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick Preset Chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _avatarPresets.map((url) {
                        final isSelected = _selectedAvatar == url;
                        return GestureDetector(
                          onTap: () => setState(
                            () => _selectedAvatar = isSelected ? null : url,
                          ),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? CasamaColors.primaryCoral
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: CasamaAvatar(avatarUrl: url, radius: 18),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CasamaSpacing.xl),

              // Full Name
              CasamaTextField(
                controller: _fullNameController,
                label: 'Full Name',
                hint: 'e.g., Jon Paul Berana',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Nickname
              CasamaTextField(
                controller: _nicknameController,
                label: 'Nickname',
                hint: 'e.g., JP',
                prefixIcon: Icons.sentiment_satisfied_alt_rounded,
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Age (Optional)
              CasamaTextField(
                controller: _ageController,
                label: 'Age (Optional)',
                hint: 'e.g., 21',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: CasamaSpacing.xl),

              // Action Buttons
              CasamaButton(
                label: 'Save & Continue',
                isPill: true,
                height: 52,
                onPressed: _saveAndContinue,
              ),
              const SizedBox(height: CasamaSpacing.sm),

              CasamaButton(
                label: 'Skip Profile for Now',
                style: CasamaButtonStyle.ghost,
                onPressed: _skipForNow,
                height: 44,
              ),
              const SizedBox(height: CasamaSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}
