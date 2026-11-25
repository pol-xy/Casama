import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../data/supabase_config.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 for Register, 1 for Login

  const AuthScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login form controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _loginObscurePassword = true;
  bool _isLoginLoading = false;

  // Register form controllers
  final _registerFormKey = GlobalKey<FormState>();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();
  bool _registerObscurePassword = true;
  bool _isRegisterLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoginLoading = true);

    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        await client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ref.read(repositoryProvider).login(email: email, password: password);

      if (mounted) {
        setState(() => _isLoginLoading = false);
        context.go('/dashboard');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoginLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoginLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login notice: ${e.toString()}'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    setState(() => _isRegisterLoading = true);

    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text.trim();

    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        await client.auth.signUp(email: email, password: password);
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      ref.read(repositoryProvider).register(email: email, password: password);

      if (mounted) {
        setState(() => _isRegisterLoading = false);
        // Direct new user to Step 2: Optional Profile Setup
        context.push('/profile-setup');
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isRegisterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegisterLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration note: ${e.toString()}'),
            backgroundColor: CasamaColors.errorRed,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _loginEmailController.text,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CasamaColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedLg),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: CasamaColors.primaryCoral),
            SizedBox(width: 8),
            Text(
              'Reset Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CasamaColors.ink,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your registered email and we will send you a password reset link.',
              style: TextStyle(fontSize: 13, color: CasamaColors.textSecondary),
            ),
            const SizedBox(height: CasamaSpacing.md),
            CasamaTextField(
              controller: resetEmailController,
              label: 'Email',
              hint: 'name@example.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: CasamaColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: CasamaColors.primaryCoral,
              foregroundColor: CasamaColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final email = resetEmailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  final client = SupabaseConfig.client;
                  if (client != null) {
                    await client.auth.resetPasswordForEmail(email);
                  }
                } catch (_) {}
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset link sent to $email!'),
                      backgroundColor: CasamaColors.successGreen,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Account Access'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: CasamaSpacing.sm),

            // Segmented Tab Selector (Create Account vs Log In)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.xl),
              child: Container(
                decoration: BoxDecoration(
                  color: context.isDark
                      ? CasamaColors.darkSurface
                      : CasamaColors.softNeutral,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: context.isDark
                        ? CasamaColors.primaryCoral
                        : CasamaColors.midnightNavy,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  labelColor: CasamaColors.white,
                  unselectedLabelColor: CasamaColors.textSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Create an Account'),
                    Tab(text: 'Log In'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildRegisterTab(), _buildLoginTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.xl),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: CasamaSpacing.sm),
            const Text(
              'Join Casama 🦉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CasamaColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Step 1 of 4: Enter your sign-in credentials.',
              style: TextStyle(fontSize: 13, color: CasamaColors.textSecondary),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            CasamaTextField(
              controller: _registerEmailController,
              label: 'Email Address',
              hint: 'name@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final trimmed = (v ?? '').trim();
                if (trimmed.isEmpty) {
                  return 'Please enter your email';
                }
                if (!trimmed.contains('@') || !trimmed.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: CasamaSpacing.md),

            CasamaTextField(
              controller: _registerPasswordController,
              label: 'Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: _registerObscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _registerObscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: CasamaColors.textSecondary,
                ),
                onPressed: () => setState(
                  () => _registerObscurePassword = !_registerObscurePassword,
                ),
              ),
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
              hint: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: _registerObscurePassword,
              validator: (v) {
                if (v != _registerPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: CasamaSpacing.xl),

            CasamaButton(
              label: 'Continue to Profile Details',
              onPressed: _handleRegister,
              isLoading: _isRegisterLoading,
              isPill: true,
              height: 52,
            ),
            const SizedBox(height: CasamaSpacing.md),

            Center(
              child: Text(
                'Next: Optional profile details (can be skipped)',
                style: TextStyle(
                  fontSize: 12,
                  color: CasamaColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: CasamaSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.xl),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: CasamaSpacing.sm),
            const Text(
              'Welcome Back! 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: CasamaColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Log in with your existing household credentials.',
              style: TextStyle(fontSize: 13, color: CasamaColors.textSecondary),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            CasamaTextField(
              controller: _loginEmailController,
              label: 'Email Address',
              hint: 'name@example.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                final trimmed = (v ?? '').trim();
                if (trimmed.isEmpty) {
                  return 'Please enter your email';
                }
                if (!trimmed.contains('@') || !trimmed.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: CasamaSpacing.md),

            CasamaTextField(
              controller: _loginPasswordController,
              label: 'Password',
              hint: '••••••••',
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: _loginObscurePassword,
              suffix: IconButton(
                icon: Icon(
                  _loginObscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: CasamaColors.textSecondary,
                ),
                onPressed: () => setState(
                  () => _loginObscurePassword = !_loginObscurePassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    fontSize: 13,
                    color: CasamaColors.primaryCoral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            CasamaButton(
              label: 'Log In',
              onPressed: _handleLogin,
              isLoading: _isLoginLoading,
              isPill: true,
              height: 52,
            ),
            const SizedBox(height: CasamaSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
