import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/supabase_config.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Terms of Service & Privacy Policy to continue.',
          ),
          backgroundColor: CasamaColors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = SupabaseConfig.client;
      if (client != null) {
        await client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {
            'full_name': _nameController.text.trim(),
            'handle': _handleController.text.trim(),
          },
        );
      } else {
        // High-fidelity mock mode delay
        await Future.delayed(const Duration(milliseconds: 600));
      }

      if (mounted) {
        setState(() => _isLoading = false);
        // Direct new user to optional profile setup
        context.push('/profile-setup');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration note: ${e.toString()}'),
            backgroundColor: CasamaColors.errorRed,
            action: SnackBarAction(
              label: 'Continue Demo',
              textColor: CasamaColors.white,
              onPressed: () => context.push('/profile-setup'),
            ),
          ),
        );
      }
    }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: CasamaSpacing.sm),
                Text(
                  'Join Casama 🦉',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create an account to start organizing your home.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: CasamaSpacing.xl),

                CasamaTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'e.g., Jon Paul Berana',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: CasamaSpacing.md),

                CasamaTextField(
                  controller: _handleController,
                  label: 'Handle / Nickname',
                  hint: '@jpberana',
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Please enter a handle' : null,
                ),
                const SizedBox(height: CasamaSpacing.md),

                CasamaTextField(
                  controller: _emailController,
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
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: CasamaColors.textSecondary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: CasamaSpacing.md),

                // Terms & Privacy Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _agreedToTerms,
                        activeColor: CasamaColors.primaryCoral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) {
                          setState(() => _agreedToTerms = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        children: [
                          const Text(
                            'I agree to Casama\'s ',
                            style: TextStyle(
                              fontSize: 12,
                              color: CasamaColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final agreed = await context.push<bool>('/terms');
                              if (agreed == true && mounted) {
                                setState(() => _agreedToTerms = true);
                              }
                            },
                            child: const Text(
                              'Terms of Service & Privacy Policy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: CasamaColors.primaryCoral,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CasamaSpacing.xl),

                CasamaButton(
                  label: 'Create Account',
                  onPressed: _register,
                  isLoading: _isLoading,
                  isPill: true,
                  height: 52,
                ),
                const SizedBox(height: CasamaSpacing.lg),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: CasamaColors.textSecondary),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: CasamaColors.primaryCoral,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CasamaSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
