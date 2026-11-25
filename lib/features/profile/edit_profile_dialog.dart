import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
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
      setState(() => _selectedAvatar = photo);
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
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() => _selectedAvatar = base64String);
      }
    } catch (e) {
      if (mounted) {
        showCasamaToast(
          context,
          'Could not access image: $e',
          icon: Icons.error_outline_rounded,
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

    ref.read(repositoryProvider).updateProfile(
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

    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    showCasamaToast(
      context,
      'Profile updated successfully! ✨',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  void _removeAvatar() {
    setState(() => _selectedAvatar = null);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final reduced = CasamaMotion.reduceMotion(context);

    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: CasamaSpacing.lg,
        right: CasamaSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: CasamaSpacing.roundedSheetTop,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: pal.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header
              Container(
                padding: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: pal.divider)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: pal.softBlush,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.edit_rounded,
                        color: pal.primaryCoral,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Profile',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            'Update your avatar, nickname & details',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Close Edit Profile',
                      child: CasamaPressable(
                        onTap: () {
                          if (Navigator.canPop(context)) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Container(
                          width: CasamaSpacing.minTouchTarget,
                          height: CasamaSpacing.minTouchTarget,
                          decoration: BoxDecoration(
                            color: pal.track,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CasamaSpacing.md),

              // Avatar Preview + Camera & Gallery Actions
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CasamaAvatar(
                          avatarUrl: _selectedAvatar,
                          radius: 44,
                          name: _nameController.text,
                          showEditBadge: true,
                          onTap: _openCameraCapture,
                          borderWidth: 2,
                          borderColor: pal.coralFab,
                        ),
                        if (_isPickingImage)
                          Positioned.fill(
                            child: reduced
                                ? Icon(
                                    Icons.hourglass_top_rounded,
                                    color: pal.primaryCoral,
                                  )
                                : CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: pal.primaryCoral,
                                  ),
                          ),
                      ],
                    ),
                    if (_selectedAvatar == null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Default Avatar',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _AvatarActionPill(
                          icon: Icons.photo_camera_rounded,
                          label: 'Take Photo',
                          color: pal.primaryCoral,
                          borderColor: pal.primaryCoral.withValues(alpha: 0.45),
                          bgColor: pal.softBlush,
                          onTap: _openCameraCapture,
                        ),
                        _AvatarActionPill(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          color: pal.forestTeal,
                          borderColor: pal.forestTeal.withValues(alpha: 0.45),
                          bgColor: pal.softSage,
                          onTap: () => _pickImage(ImageSource.gallery),
                        ),
                      ],
                    ),

                    if (_selectedAvatar != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: pal.dangerFg,
                        ),
                        label: Text(
                          'Remove Picture',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.dangerFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: _removeAvatar,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: CasamaSpacing.sm),

              Text(
                'Or Choose a Preset Photo',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: pal.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _avatarPresets.map((url) {
                    final isSelected = _selectedAvatar == url;
                    return CasamaPressable(
                      onTap: () => setState(() => _selectedAvatar = url),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? pal.primaryCoral
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

              CasamaTextField(
                controller: _nicknameController,
                label: 'Nickname',
                hint: 'e.g., JP',
                prefixIcon: Icons.sentiment_satisfied_alt_rounded,
              ),
              const SizedBox(height: CasamaSpacing.md),

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

              CasamaButton(
                label: 'Save Changes',
                icon: Icons.check_circle_outline_rounded,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color borderColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _AvatarActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.borderColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        child: Container(
          height: CasamaSpacing.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
