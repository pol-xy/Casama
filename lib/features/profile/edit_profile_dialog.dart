import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_birthday_field.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/profile_camera_sheet.dart';

enum _AvatarMenuAction { takePhoto, chooseGallery, removePicture }

class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({super.key});

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _nicknameController;
  final _lastNameFocus = FocusNode();
  final _nicknameFocus = FocusNode();
  int? _birthMonth;
  int? _birthDay;
  int? _birthYear;
  String? _birthdayError;
  String? _nicknameError;
  String? _selectedAvatar;
  bool _isPickingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(repositoryProvider).currentUser;
    final parts = user.resolveNameParts(fallbackToDisplayName: true);
    _firstNameController = TextEditingController(text: parts.firstName);
    _lastNameController = TextEditingController(text: parts.lastName);
    _nicknameController = TextEditingController(text: user.nickname ?? '');
    if (user.birthday != null) {
      _birthMonth = user.birthday!.month;
      _birthDay = user.birthday!.day;
      _birthYear = user.birthday!.year;
    }
    _selectedAvatar = user.avatarUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _nicknameController.dispose();
    _lastNameFocus.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  DateTime? get _birthDate {
    if (_birthMonth == null || _birthDay == null || _birthYear == null) {
      return null;
    }
    final maxDays = daysInBirthMonth(_birthYear, _birthMonth);
    if (_birthDay! > maxDays) return null;
    final dt = DateTime(_birthYear!, _birthMonth!, _birthDay!);
    if (dt.year != _birthYear ||
        dt.month != _birthMonth ||
        dt.day != _birthDay) {
      return null;
    }
    return dt;
  }

  bool _isFutureDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.isAfter(today);
  }

  int? get _computedAge {
    final bDate = _birthDate;
    if (bDate == null || _isFutureDate(bDate)) return null;
    final now = DateTime.now();
    var age = now.year - bDate.year;
    if (now.month < bDate.month ||
        (now.month == bDate.month && now.day < bDate.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  Future<void> _pickBirthdayDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null && mounted) {
      setState(() {
        _birthMonth = picked.month;
        _birthDay = picked.day;
        _birthYear = picked.year;
        _birthdayError = null;
      });
    }
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

  Future<void> _save() async {
    setState(() => _nicknameError = null);
    final formValid = _formKey.currentState!.validate();
    final birthDate = _birthDate;
    String? nextBirthdayError;
    if (birthDate == null) {
      nextBirthdayError = 'Please select your complete birthday';
    } else if (birthDate.isBefore(DateTime(1900, 1, 1))) {
      nextBirthdayError = 'Please select a valid birthday';
    } else if (_isFutureDate(birthDate)) {
      nextBirthdayError = 'Birthday cannot be in the future';
    }
    setState(() => _birthdayError = nextBirthdayError);
    if (!formValid || nextBirthdayError != null) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = UserProfile.joinFullName(firstName, lastName);
    final nickname = _nicknameController.text.trim();
    final clearAvatar =
        _selectedAvatar == null || _selectedAvatar!.trim().isEmpty;

    setState(() => _isSaving = true);
    final error = await ref.read(repositoryProvider).updateProfile(
      displayName: fullName,
      firstName: firstName,
      lastName: lastName,
      fullName: fullName,
      nickname: nickname,
      birthday: birthDate,
      avatarUrl: clearAvatar ? null : _selectedAvatar,
      clearAvatar: clearAvatar,
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _isSaving = false;
        _nicknameError = error;
      });
      return;
    }

    setState(() => _isSaving = false);
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

    final hasAvatar =
        _selectedAvatar != null && _selectedAvatar!.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        top: 14,
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CasamaSpacing.lg,
                ),
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

                    // Avatar Preview with Compact Action Popover
                    Center(
                      child: Column(
                        children: [
                          PopupMenuButton<_AvatarMenuAction>(
                            key: const Key('edit_profile_avatar_menu_trigger'),
                            tooltip: 'Change profile photo',
                            position: PopupMenuPosition.under,
                            offset: const Offset(0, 8),
                            constraints: const BoxConstraints(
                              minWidth: 210,
                              maxWidth: 300,
                            ),
                            color: pal.surface,
                            surfaceTintColor: Colors.transparent,
                            elevation: context.isDark ? 8 : 4,
                            popUpAnimationStyle: reduced
                                ? AnimationStyle.noAnimation
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: pal.border, width: 1),
                            ),
                            onSelected: (action) {
                              switch (action) {
                                case _AvatarMenuAction.takePhoto:
                                  _openCameraCapture();
                                case _AvatarMenuAction.chooseGallery:
                                  _pickImage(ImageSource.gallery);
                                case _AvatarMenuAction.removePicture:
                                  _removeAvatar();
                              }
                            },
                            itemBuilder: (ctx) => [
                              PopupMenuItem<_AvatarMenuAction>(
                                value: _AvatarMenuAction.takePhoto,
                                height: CasamaSpacing.minTouchTarget,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_camera_rounded,
                                      size: 19,
                                      color: pal.primaryCoral,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        'Take Photo',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: pal.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<_AvatarMenuAction>(
                                value: _AvatarMenuAction.chooseGallery,
                                height: CasamaSpacing.minTouchTarget,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_library_rounded,
                                      size: 19,
                                      color: pal.forestTeal,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        'Choose from Gallery',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodyMedium?.copyWith(
                                          color: pal.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (hasAvatar)
                                PopupMenuItem<_AvatarMenuAction>(
                                  value: _AvatarMenuAction.removePicture,
                                  height: CasamaSpacing.minTouchTarget,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                        color: pal.dangerFg,
                                      ),
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Text(
                                          'Remove Picture',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                            color: pal.dangerFg,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            child: Semantics(
                              button: true,
                              label: 'Change profile photo',
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CasamaAvatar(
                                    avatarUrl: _selectedAvatar,
                                    radius: 44,
                                    name: () {
                                      final joined = UserProfile.joinFullName(
                                        _firstNameController.text,
                                        _lastNameController.text,
                                      );
                                      return joined.isNotEmpty
                                          ? joined
                                          : 'Casama';
                                    }(),
                                    showEditBadge: true,
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
                            ),
                          ),
                          if (!hasAvatar) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Default Avatar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: CasamaSpacing.md),

                    Text(
                      'Or Choose a Preset Photo',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              CasamaPresetAvatarPicker(
                selectedAvatar: _selectedAvatar,
                onSelected: (next) => setState(() => _selectedAvatar = next),
                horizontalScroll: true,
                spacing: 12,
                horizontalPadding: const EdgeInsets.symmetric(
                  horizontal: CasamaSpacing.lg,
                ),
                scrollViewKey: const Key('edit_profile_preset_photos_scroll'),
                avatarRadius: 20,
              ),
              const SizedBox(height: CasamaSpacing.lg),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CasamaSpacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

              CasamaTextField(
                controller: _firstNameController,
                label: 'First Name',
                hint: 'e.g., Jon Paul',
                prefixIcon: Icons.badge_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter your first name'
                    : null,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_lastNameFocus),
              ),
              const SizedBox(height: CasamaSpacing.md),

              CasamaTextField(
                controller: _lastNameController,
                label: 'Last Name',
                hint: 'e.g., Berana',
                prefixIcon: Icons.badge_outlined,
                focusNode: _lastNameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter your last name'
                    : null,
                onFieldSubmitted: (_) =>
                    FocusScope.of(context).requestFocus(_nicknameFocus),
              ),
              const SizedBox(height: CasamaSpacing.md),

              CasamaTextField(
                controller: _nicknameController,
                label: 'Nickname',
                hint: 'e.g., JP',
                prefixIcon: Icons.sentiment_satisfied_alt_rounded,
                focusNode: _nicknameFocus,
                textCapitalization: TextCapitalization.words,
                forceErrorText: _nicknameError,
                onChanged: (_) {
                  if (_nicknameError != null) {
                    setState(() => _nicknameError = null);
                  }
                },
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Please enter your nickname'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.md),

              CasamaBirthdayField(
                label: 'Birthday',
                month: _birthMonth,
                day: _birthDay,
                year: _birthYear,
                computedAge: _computedAge,
                errorText: _birthdayError,
                onMonthChanged: (val) => setState(() {
                  _birthMonth = val;
                  final maxDays = daysInBirthMonth(_birthYear, _birthMonth);
                  if (_birthDay != null && _birthDay! > maxDays) {
                    _birthDay = maxDays;
                  }
                  _birthdayError = null;
                }),
                onDayChanged: (val) => setState(() {
                  _birthDay = val;
                  _birthdayError = null;
                }),
                onYearChanged: (val) => setState(() {
                  _birthYear = val;
                  final maxDays = daysInBirthMonth(_birthYear, _birthMonth);
                  if (_birthDay != null && _birthDay! > maxDays) {
                    _birthDay = maxDays;
                  }
                  _birthdayError = null;
                }),
                onPickCalendar: _pickBirthdayDate,
              ),
              const SizedBox(height: CasamaSpacing.xl),

                    CasamaButton(
                      label: 'Save Changes',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
