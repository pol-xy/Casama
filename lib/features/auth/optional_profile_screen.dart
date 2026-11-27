import 'dart:convert';

import 'package:flutter/gestures.dart';
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
import '../../shared/widgets/casama_birthday_field.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/profile_camera_sheet.dart';
import '../legal/terms_privacy_screen.dart';
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
  late final TapGestureRecognizer _termsTap;

  int? _birthMonth;
  int? _birthDay;
  int? _birthYear;
  String? _birthdayError;

  String? _selectedAvatar;
  bool _isPickingImage = false;
  bool _agreedToTerms = false;
  String? _termsError;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()..onTap = _openTermsReader;
    final user = ref.read(repositoryProvider).currentUser;
    if (user.fullName != null && user.fullName!.trim().isNotEmpty) {
      _fullNameController.text = user.fullName!.trim();
    }
    if (user.nickname != null && user.nickname!.trim().isNotEmpty) {
      _nicknameController.text = user.nickname!.trim();
    }
    if (user.birthday != null) {
      _birthMonth = user.birthday!.month;
      _birthDay = user.birthday!.day;
      _birthYear = user.birthday!.year;
    }
    _selectedAvatar = user.avatarUrl;
    _agreedToTerms = user.hasConsentedTerms;
  }

  void _openTermsReader() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TermsPrivacyScreen(readOnly: true),
      ),
    );
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
    int age = now.year - bDate.year;
    if (now.month < bDate.month ||
        (now.month == bDate.month && now.day < bDate.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

  @override
  void dispose() {
    _termsTap.dispose();
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
    final formValid = _formKey.currentState?.validate() ?? false;
    final birthDate = _birthDate;
    String? nextBirthdayError;
    if (birthDate == null) {
      nextBirthdayError = 'Please select your complete birthday';
    } else if (birthDate.isBefore(DateTime(1900, 1, 1))) {
      nextBirthdayError = 'Please select a valid birthday';
    } else if (_isFutureDate(birthDate)) {
      nextBirthdayError = 'Birthday cannot be in the future';
    }
    final nextTermsError =
        !_agreedToTerms ? 'Please agree to the Terms & Privacy Policy' : null;

    setState(() {
      _birthdayError = nextBirthdayError;
      _termsError = nextTermsError;
    });

    if (!formValid || nextBirthdayError != null || nextTermsError != null) {
      return;
    }

    final fullName = _fullNameController.text.trim();
    final nickname = _nicknameController.text.trim();

    ref.read(repositoryProvider).updateProfile(
      fullName: fullName,
      displayName: fullName,
      nickname: nickname,
      birthday: birthDate,
      avatarUrl: _selectedAvatar,
      hasConsentedTerms: true,
    );

    GoRouter.maybeOf(context)?.push('/household-setup');
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaAuthShell(
      stepLabel: 'Step 2 of 4',
      onBack: () => context.canPop() ? context.pop() : context.go('/auth'),
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
              'Complete your profile so your housemates recognize you.',
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
                        name: _fullNameController.text.trim().isNotEmpty
                            ? _fullNameController.text.trim()
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
                  CasamaPresetAvatarPicker(
                    selectedAvatar: _selectedAvatar,
                    onSelected: (next) =>
                        setState(() => _selectedAvatar = next),
                    alignment: WrapAlignment.center,
                    avatarRadius: 18,
                    toggleDeselect: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            CasamaTextField(
              controller: _fullNameController,
              label: 'Full Name',
              hint: 'e.g., Jon Paul Berana',
              prefixIcon: Icons.badge_outlined,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please enter your full name'
                  : null,
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
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Please enter your nickname'
                  : null,
              onFieldSubmitted: (_) => _saveAndContinue(),
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
            const SizedBox(height: CasamaSpacing.md),

            Semantics(
              checked: _agreedToTerms,
              label: 'I agree to the Terms & Privacy Policy',
              child: InkWell(
                borderRadius: CasamaSpacing.roundedMd,
                onTap: () => setState(() {
                  _agreedToTerms = !_agreedToTerms;
                  if (_agreedToTerms) _termsError = null;
                }),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: CasamaSpacing.minTouchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 2,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: CasamaMotion.resolve(
                            context,
                            CasamaMotion.press,
                          ),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _agreedToTerms ? pal.forestTeal : pal.track,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: _agreedToTerms
                                  ? pal.forestTeal
                                  : (_termsError != null
                                        ? pal.dangerFg
                                        : pal.inputBorder),
                              width: 1.4,
                            ),
                          ),
                          child: _agreedToTerms
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: pal.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms & Privacy Policy',
                                  recognizer: _termsTap,
                                  style: TextStyle(
                                    color: pal.primaryCoral,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_termsError != null) ...[
              const SizedBox(height: 4),
              Text(
                _termsError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.dangerFg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: CasamaSpacing.lg),

            CasamaButton(
              label: 'Save & Continue',
              isPill: true,
              height: 50,
              onPressed: _saveAndContinue,
            ),
          ],
        ),
      ),
    );
  }
}
