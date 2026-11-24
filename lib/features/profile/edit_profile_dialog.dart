import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/profile_camera_sheet.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({super.key});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _handleController;
  late TextEditingController _ageController;
  String? _selectedAvatar;
  bool _isPickingImage = false;

  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(repositoryProvider).currentUser;
    _nameController = TextEditingController(
      text: user.fullName ?? user.displayName,
    );
    _nicknameController = TextEditingController(text: user.nickname ?? '');
    _handleController = TextEditingController(text: user.handle);
    _ageController = TextEditingController(
      text: user.age != null ? user.age.toString() : '',
    );
    _selectedAvatar = user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _handleController.dispose();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final trimmedAge = _ageController.text.trim();
    final age = trimmedAge.isNotEmpty ? int.tryParse(trimmedAge) : null;
    final clearNickname = _nicknameController.text.trim().isEmpty;
    final clearAge = trimmedAge.isEmpty;
    final clearAvatar =
        _selectedAvatar == null || _selectedAvatar!.trim().isEmpty;

    ref
        .read(repositoryProvider)
        .updateProfile(
          displayName: _nameController.text.trim(),
          fullName: _nameController.text.trim(),
          nickname: clearNickname ? null : _nicknameController.text.trim(),
          handle: _handleController.text.trim(),
          age: age,
          avatarUrl: clearAvatar ? null : _selectedAvatar,
          clearAvatar: clearAvatar,
          clearNickname: clearNickname,
          clearAge: clearAge,
        );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully! ✨'),
        backgroundColor: CasamaColors.successGreen,
      ),
    );
  }

  void _removeAvatar() {
    setState(() {
      _selectedAvatar = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : CasamaColors.ink;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? CasamaColors.darkSurface : CasamaColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CasamaColors.primaryCoral.withValues(
                            alpha: 0.15,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: CasamaColors.primaryCoral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: isDark ? Colors.white70 : CasamaColors.textMuted,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CasamaAvatar(
                          avatarUrl: _selectedAvatar,
                          radius: 46,
                          name: _nameController.text,
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
                    if (_selectedAvatar == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Default Avatar',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white70
                              : CasamaColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Photo Action Buttons: Take Photo & Upload from Gallery
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

                    // Remove Picture Option
                    if (_selectedAvatar != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 15,
                          color: CasamaColors.errorRed,
                        ),
                        label: const Text(
                          'Remove Picture',
                          style: TextStyle(
                            fontSize: 12,
                            color: CasamaColors.errorRed,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: _removeAvatar,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: CasamaSpacing.sm),

              // Preset Avatars
              Text(
                'Or Choose a Preset Photo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? CasamaColors.darkTextSecondary
                      : CasamaColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _avatarPresets.map((url) {
                    final isSelected = _selectedAvatar == url;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAvatar = url),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
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
                        child: CasamaAvatar(avatarUrl: url, radius: 22),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: CasamaSpacing.lg),

              // Full Name Field
              CasamaTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Juan dela Cruz',
                prefixIcon: Icons.badge_outlined,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter your full name'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Nickname Field
              CasamaTextField(
                controller: _nicknameController,
                label: 'Nickname',
                hint: 'e.g., JP',
                prefixIcon: Icons.sentiment_satisfied_alt_rounded,
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Handle Field
              CasamaTextField(
                controller: _handleController,
                label: 'Handle',
                hint: '@handle',
                prefixIcon: Icons.alternate_email_rounded,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter a valid handle'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Age Field (Optional, with range validation)
              CasamaTextField(
                controller: _ageController,
                label: 'Age (Optional)',
                hint: 'e.g., 21',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.calendar_today_outlined,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = int.tryParse(v.trim());
                  if (val == null || val < 1 || val > 120) {
                    return 'Please enter a valid age between 1 and 120';
                  }
                  return null;
                },
              ),
              const SizedBox(height: CasamaSpacing.xl),

              // Save Changes Button
              CasamaButton(
                label: 'Save Changes',
                isPill: true,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
