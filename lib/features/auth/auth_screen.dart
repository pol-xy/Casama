import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/router/app_router.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../data/supabase_config.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_text_field.dart';
import 'widgets/auth_wave_header.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 for Register, 1 for Login

  const AuthScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late int _activeTab;

  // Login controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginPasswordFocus = FocusNode();
  bool _isLoginLoading = false;
  bool _showResendVerification = false;
  bool _isResendingVerification = false;
  int _resendCooldownSeconds = 0;
  Timer? _resendCooldownTimer;

  // Register controllers
  final _registerFormKey = GlobalKey<FormState>();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  final _registerPasswordFocus = FocusNode();
  final _registerConfirmFocus = FocusNode();
  bool _agreedToTerms = false;
  bool _isRegisterLoading = false;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTabIndex.clamp(0, 1);
    _loginEmailController.addListener(_onLoginEmailChanged);
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegalTab('terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegalTab('privacy');
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _loginEmailController.removeListener(_onLoginEmailChanged);
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _loginPasswordFocus.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    _registerPasswordFocus.dispose();
    _registerConfirmFocus.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _openLegalTab(String tab) {
    if (GoRouter.maybeOf(context) != null) {
      context.push('/terms?tab=$tab&readOnly=true');
    }
  }

  void _switchTab(int index) {
    if (_activeTab == index) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeTab = index);
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Please enter your email address';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return 'Enter a valid email address (e.g., name@example.com)';
    }
    return null;
  }

  void _onLoginEmailChanged() {
    if (_showResendVerification && _loginEmailController.text.trim().isEmpty) {
      setState(() => _showResendVerification = false);
    }
  }

  void _startResendCooldown() {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = 60);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  Future<void> _handleResendVerification() async {
    final email = _loginEmailController.text.trim();
    if (email.isEmpty) {
      showCasamaToast(
        context,
        'Please enter your email address first.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    setState(() => _isResendingVerification = true);
    try {
      await ref
          .read(repositoryProvider)
          .resendSignupVerificationEmail(email);
      if (!mounted) return;
      setState(() => _isResendingVerification = false);
      _startResendCooldown();
      showCasamaToast(
        context,
        'Verification email sent to $email. Please check your inbox.',
        icon: Icons.mark_email_read_outlined,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isResendingVerification = false);
      final isRateLimited = e is AuthException &&
          (e.code == 'over_email_send_rate_limit' ||
              e.statusCode == '429' ||
              e.message.toLowerCase().contains('rate limit'));
      showCasamaToast(
        context,
        isRateLimited
            ? 'Too many verification emails requested. Please wait a minute before trying again.'
            : 'Could not resend verification email right now. Please try again later.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoginLoading = true);

    try {
      final email = _loginEmailController.text.trim();
      final password = _loginPasswordController.text.trim();
      final repo = ref.read(repositoryProvider);
      await repo.signInWithPassword(email: email, password: password);

      if (mounted) {
        _resendCooldownTimer?.cancel();
        setState(() {
          _isLoginLoading = false;
          _showResendVerification = false;
          _resendCooldownSeconds = 0;
        });
        context.go(resolveAuthenticatedDestination(repo.currentUser));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Casama sign-in failed (${e.runtimeType}): $e');
      }
      final isEmailNotConfirmed = e is AuthException &&
          (e.code == 'email_not_confirmed' ||
              e.message.toLowerCase().contains('email not confirmed'));
      if (mounted) {
        setState(() {
          _isLoginLoading = false;
          _showResendVerification = isEmailNotConfirmed;
        });
        showCasamaToast(
          context,
          isEmailNotConfirmed
              ? 'Your email is not verified yet. Please confirm it or resend the verification email below.'
              : 'Could not sign in. Please check your email and password.',
          icon: isEmailNotConfirmed
              ? Icons.mark_email_unread_outlined
              : Icons.error_outline_rounded,
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      showCasamaToast(
        context,
        'Please agree to the Terms of Service and Privacy Policy first.',
        icon: Icons.verified_user_outlined,
      );
      return;
    }

    setState(() => _isRegisterLoading = true);

    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();

    try {
      final repo = ref.read(repositoryProvider);
      final hasSession = await repo.signUpWithPassword(
        email: email,
        password: password,
      );
      if (!hasSession) {
        if (mounted) {
          setState(() => _isRegisterLoading = false);
          showCasamaToast(
            context,
            'Account created! Please check your email to confirm before signing in.',
            icon: Icons.mark_email_read_outlined,
          );
          _switchTab(1);
        }
        return;
      }

      if (mounted) {
        setState(() => _isRegisterLoading = false);
        context.push('/profile-setup');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Casama sign-up failed (${e.runtimeType}): $e');
      }
      if (mounted) {
        setState(() => _isRegisterLoading = false);
        showCasamaToast(
          context,
          'Unable to create account right now. Please try again.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(
        initialEmail: _loginEmailController.text.trim(),
        emailValidator: _validateEmail,
        onSent: (email) {
          if (mounted) {
            showCasamaToast(
              context,
              'Password reset link sent to $email',
              icon: Icons.mark_email_read_outlined,
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _activeTab == 1;
    final canPop = GoRouter.maybeOf(context)?.canPop() ?? Navigator.canPop(context);

    return CasamaAuthShell(
      stepLabel: isLogin ? null : 'Step 1 of 4',
      mascotPose: isLogin ? CasPose.hero : CasPose.waving,
      mascotAlignment:
          isLogin ? Alignment.bottomLeft : Alignment.bottomRight,
      onBack: canPop ? () => context.pop() : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Mode Switcher matching unified pill track
          CasamaSegmentedTrack<int>(
            margin: const EdgeInsets.only(bottom: CasamaSpacing.lg),
            segments: const [
              CasamaFilterOption(value: 0, label: 'Create an Account'),
              CasamaFilterOption(value: 1, label: 'Log In'),
            ],
            selectedValue: _activeTab,
            onSelected: _switchTab,
          ),
          AnimatedSwitcher(
            duration: CasamaMotion.resolve(context, CasamaMotion.boardSlide),
            switchInCurve: CasamaMotion.easeOut,
            child: isLogin ? _buildLoginBody() : _buildRegisterBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterBody() {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Form(
      key: _registerFormKey,
      child: Column(
        key: const ValueKey('auth_register_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join Casama',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Create an account to coordinate with your housemates.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: pal.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),
          CasamaTextField(
            controller: _registerEmailController,
            label: 'Email Address',
            hint: 'name@housemate.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _registerPasswordFocus.requestFocus(),
            validator: _validateEmail,
          ),
          const SizedBox(height: CasamaSpacing.md),
          CasamaTextField(
            controller: _registerPasswordController,
            label: 'Password',
            hint: 'At least 6 characters',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            focusNode: _registerPasswordFocus,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) => _registerConfirmFocus.requestFocus(),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: CasamaSpacing.md),
          CasamaTextField(
            controller: _registerConfirmPasswordController,
            label: 'Confirm Password',
            hint: 'Re-enter password',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            focusNode: _registerConfirmFocus,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v != _registerPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: CasamaSpacing.md),
          // Friendly full-height (48dp) inline Terms & Privacy row (`starting.html`)
          InkWell(
            borderRadius: CasamaSpacing.roundedMd,
            onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CasamaSpacing.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
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
                              : pal.inputBorder,
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
                              text: 'Terms of Service',
                              recognizer: _termsTap,
                              style: TextStyle(
                                color: pal.primaryCoral,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              recognizer: _privacyTap,
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
          const SizedBox(height: CasamaSpacing.md),
          CasamaButton(
            label: 'Create Account',
            icon: Icons.arrow_forward_rounded,
            iconAfterLabel: true,
            onPressed: _handleRegister,
            isLoading: _isRegisterLoading,
            height: 52,
          ),
          const SizedBox(height: CasamaSpacing.md),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Already sharing a nest? ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textSecondary,
                    fontSize: 13,
                  ),
                ),
                InkWell(
                  onTap: () => _switchTab(1),
                  borderRadius: CasamaSpacing.roundedSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 10,
                    ),
                    child: Text(
                      'Log In',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: pal.forestTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginBody() {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('auth_login_form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sign in to check in with your household.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),
          CasamaTextField(
            controller: _loginEmailController,
            label: 'Email Address',
            hint: 'name@housemate.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _loginPasswordFocus.requestFocus(),
            validator: _validateEmail,
          ),
          const SizedBox(height: CasamaSpacing.md),
          CasamaTextField(
            controller: _loginPasswordController,
            label: 'Password',
            hint: 'Enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            focusNode: _loginPasswordFocus,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _handleLogin(),
            validator: (v) {
              if (v == null || v.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: pal.primaryCoral,
              ),
              child: const Text('Forgot password?'),
            ),
          ),
          const SizedBox(height: CasamaSpacing.xs),
          if (_showResendVerification) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.warningBg,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(color: pal.warningFg.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mark_email_unread_outlined,
                        color: pal.warningFg,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your email is not verified yet. Please check your inbox or resend the verification email.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CasamaSpacing.sm),
                  CasamaButton(
                    label: _resendCooldownSeconds > 0
                        ? 'Resend available in ${_resendCooldownSeconds}s'
                        : 'Resend Verification Email',
                    icon: Icons.send_outlined,
                    style: CasamaButtonStyle.secondary,
                    isLoading: _isResendingVerification,
                    onPressed:
                        (_resendCooldownSeconds > 0 || _isResendingVerification)
                        ? null
                        : _handleResendVerification,
                    height: 44,
                  ),
                ],
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),
          ],
          CasamaButton(
            label: 'Log In',
            onPressed: _handleLogin,
            isLoading: _isLoginLoading,
            height: 52,
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final String? Function(String?) emailValidator;
  final ValueChanged<String> onSent;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.emailValidator,
    required this.onSent,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _sending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _errorText = null;
    });

    final email = _emailController.text.trim();
    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        await client.auth.resetPasswordForEmail(email);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSent(email);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _errorText = 'Could not send reset email right now. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: pal.surface,
      shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
      title: Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: pal.primaryCoral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reset Password',
              style: theme.textTheme.titleLarge?.copyWith(color: pal.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your registered email and we will send you a password reset link.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                ),
              ),
              const SizedBox(height: CasamaSpacing.md),
              CasamaTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'name@housemate.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.email_outlined,
                validator: widget.emailValidator,
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.dangerFg,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: pal.textSecondary)),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _submit,
          child: Text(_sending ? 'Sending...' : 'Send Link'),
        ),
      ],
    );
  }
}
