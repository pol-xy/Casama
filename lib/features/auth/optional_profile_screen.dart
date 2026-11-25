import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/profile_camera_sheet.dart';
import 'widgets/auth_wave_header.dart';

class OptionalProfileScreen extends ConsumerStatefulWidget {
  const OptionalProfileScreen({super.key});

  @override
  ConsumerState<OptionalProfileScreen> createState() =>
      _OptionalProfileScreenState();
}

class _OptionalProfileScreenState extends ConsumerState<OptionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _nicknameFocus = FocusNode();

  int? _birthMonth;
  int? _birthDay;
  int? _birthYear;

  String? _selectedAvatar;
  bool _isPickingImage = false;

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  DateTime? get _birthDate {
    if (_birthMonth == null || _birthDay == null || _birthYear == null) {
      return null;
    }
    try {
      return DateTime(_birthYear!, _birthMonth!, _birthDay!);
    } catch (_) {
      return null;
    }
  }

  int? get _computedAge {
    final bDate = _birthDate;
    if (bDate == null) return null;
    final now = DateTime.now();
    int age = now.year - bDate.year;
    if (now.month < bDate.month ||
        (now.month == bDate.month && now.day < bDate.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  // Preset avatar choices for quick one-tap selection
  final List<String> _avatarPresets = const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
  ];

  @override
  void dispose() {
    _fullNameController.dispose();
    _nicknameController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickBirthdayDate() async {
    final now = DateTime.now();
    final initialDate = _birthDate ?? DateTime(now.year - 20, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        if (mounted) {
          setState(() => _selectedAvatar = base64String);
        }
      }
    } catch (_) {
      if (mounted) {
        showCasamaToast(
          context,
          'Could not access that photo. Please try again.',
          icon: Icons.info_outline_rounded,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _saveAndContinue() {
    if (!(_formKey.currentState?.validate() ?? true)) {
      return;
    }

    final fullName = _fullNameController.text.trim();
    final nickname = _nicknameController.text.trim();
    final birthDate = _birthDate;
    final age = _computedAge;

    ref
        .read(repositoryProvider)
        .updateProfile(
          fullName: fullName.isNotEmpty ? fullName : null,
          displayName: fullName.isNotEmpty
              ? fullName
              : (nickname.isNotEmpty ? nickname : null),
          nickname: nickname.isNotEmpty ? nickname : null,
          birthDate: birthDate,
          age: age,
          avatarUrl: _selectedAvatar,
        );

    context.push('/household-setup');
  }

  void _skipForNow() {
    context.push('/household-setup');
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaAuthShell(
      stepLabel: 'Step 2 of 4',
      onBack: () => context.canPop() ? context.pop() : context.go('/auth'),
      skipLabel: 'Skip',
      onSkip: _skipForNow,
      mascotPose: CasPose.standing,
      mascotAlignment: Alignment.bottomRight,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tell Us About You',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: pal.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'These details are completely optional. Add a photo or name now, or update anytime from Profile.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: pal.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            // Avatar + quick photo actions
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CasamaAvatar(
                        avatarUrl: _selectedAvatar,
                        radius: 44,
                        name: _fullNameController.text.isNotEmpty
                            ? _fullNameController.text
                            : 'Casama',
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
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.photo_camera_rounded,
                          size: 17,
                          color: CasamaColors.primaryCoral,
                        ),
                        label: const Text(
                          'Take Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: CasamaColors.primaryCoral,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          side: const BorderSide(
                            color: CasamaColors.primaryCoral,
                            width: 1.2,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _openCameraCapture,
                      ),
                      OutlinedButton.icon(
                        icon: Icon(
                          Icons.photo_library_rounded,
                          size: 17,
                          color: pal.forestTeal,
                        ),
                        label: Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: pal.forestTeal,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          side: BorderSide(color: pal.forestTeal, width: 1.2),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Or choose a preset',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_avatarPresets.length, (i) {
                      final url = _avatarPresets[i];
                      final isSelected = _selectedAvatar == url;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: 'Preset avatar ${i + 1}',
                        child: CasamaPressable(
                          onTap: () => setState(
                            () => _selectedAvatar = isSelected ? null : url,
                          ),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Center(
                              child: AnimatedContainer(
                                duration: CasamaMotion.resolve(
                                  context,
                                  CasamaMotion.press,
                                ),
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? CasamaColors.primaryCoral
                                        : pal.border,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                child: CasamaAvatar(avatarUrl: url, radius: 18),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            CasamaTextField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'Enter your full name',
              prefixIcon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              onChanged: (_) => setState(() {}),
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_nicknameFocus),
            ),
            const SizedBox(height: CasamaSpacing.md),

            CasamaTextField(
              controller: _nicknameController,
              label: 'Nickname',
              hint: 'Enter your nickname',
              prefixIcon: Icons.sentiment_satisfied_alt_rounded,
              focusNode: _nicknameFocus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _saveAndContinue(),
            ),
            const SizedBox(height: CasamaSpacing.md),

            // Birthday (Optional) with Birth Month, Day, and Year selectors
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Birthday (Optional)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_computedAge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: pal.softSage,
                          borderRadius: CasamaSpacing.roundedPill,
                        ),
                        child: Text(
                          'Age: $_computedAge',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pal.forestTeal,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select your birth month, day, and year',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Month Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: pal.track,
                          borderRadius: CasamaSpacing.roundedSm,
                          border: Border.all(color: pal.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _birthMonth,
                            hint: Text(
                              'Month',
                              style: TextStyle(
                                color: pal.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: pal.surface,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: pal.textSecondary,
                            ),
                            items: List.generate(12, (i) {
                              final monthNum = i + 1;
                              return DropdownMenuItem<int>(
                                value: monthNum,
                                child: Text(
                                  _monthNames[i],
                                  style: TextStyle(
                                    color: pal.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (val) =>
                                setState(() => _birthMonth = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Day Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: pal.track,
                          borderRadius: CasamaSpacing.roundedSm,
                          border: Border.all(color: pal.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _birthDay,
                            hint: Text(
                              'Day',
                              style: TextStyle(
                                color: pal.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: pal.surface,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: pal.textSecondary,
                            ),
                            items: List.generate(31, (i) {
                              final dayNum = i + 1;
                              return DropdownMenuItem<int>(
                                value: dayNum,
                                child: Text(
                                  '$dayNum',
                                  style: TextStyle(
                                    color: pal.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (val) => setState(() => _birthDay = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Year Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: pal.track,
                          borderRadius: CasamaSpacing.roundedSm,
                          border: Border.all(color: pal.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _birthYear,
                            hint: Text(
                              'Year',
                              style: TextStyle(
                                color: pal.textMuted,
                                fontSize: 13,
                              ),
                            ),
                            isExpanded: true,
                            dropdownColor: pal.surface,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: pal.textSecondary,
                            ),
                            items: List.generate(
                              DateTime.now().year - 1920 + 1,
                              (i) {
                                final yr = DateTime.now().year - i;
                                return DropdownMenuItem<int>(
                                  value: yr,
                                  child: Text(
                                    '$yr',
                                    style: TextStyle(
                                      color: pal.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
                            ),
                            onChanged: (val) =>
                                setState(() => _birthYear = val),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Optional quick calendar picker button
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month_outlined,
                        color: pal.forestTeal,
                        size: 22,
                      ),
                      tooltip: 'Pick date from calendar',
                      onPressed: _pickBirthdayDate,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: CasamaSpacing.xl),

            CasamaButton(
              label: 'Save & Continue',
              isPill: true,
              height: 50,
              onPressed: _saveAndContinue,
            ),
            const SizedBox(height: CasamaSpacing.xs),

            CasamaButton(
              label: 'Skip Profile for Now',
              style: CasamaButtonStyle.ghost,
              onPressed: _skipForNow,
              height: 48,
            ),
          ],
        ),
      ),
    );
  }
}
