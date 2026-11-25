import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../data/supabase_config.dart';
import '../../shared/widgets/casama_button.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final repo = ref.watch(repositoryProvider);
    final client = SupabaseConfig.client;
    final hasRealAuthUser = client?.auth.currentUser != null;
    final isReturningUser = hasRealAuthUser &&
        repo.isAuthenticated &&
        repo.currentUser.hasCompletedOnboarding &&
        repo.currentUser.id.isNotEmpty;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Stack(
        children: [
          // Top Decorative Wave (Coral)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(size.width, 160),
              painter: _TopWavePainter(),
            ),
          ),

          // Bottom Decorative Wave (Navy & Coral)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(size.width, 180),
              painter: _BottomWavePainter(),
            ),
          ),

          // Main Welcome Content
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CasamaSpacing.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(flex: 2),

                            // Brand Logo
                            Image.asset(
                              'assets/images/cas/casama_logo.png',
                              width: 200,
                              errorBuilder: (context, error, stackTrace) =>
                                  _fallbackLogo(),
                            ),
                            const SizedBox(height: CasamaSpacing.sm),

                            // Original Casama Owl Mascot (Hero Pose)
                            Container(
                              height: 160,
                              alignment: Alignment.center,
                              child: Image.asset(
                                'assets/images/cas/cas_hero.png',
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.home_rounded,
                                      size: 80,
                                      color: CasamaColors.primaryCoral,
                                    ),
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.md),

                            // Application Name
                            Text(
                              'Casama',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: context.textColor,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Tagline
                            Text(
                              'Making shared living\nsimpler, warmer, and more coordinated.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: context.textSecondaryColor,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const Spacer(flex: 3),

                            // Action Buttons
                            if (isReturningUser) ...[
                              CasamaButton(
                                label:
                                    'Continue as ${repo.currentUser.effectiveGreetingName}',
                                onPressed: () => context.go('/dashboard'),
                                isPill: true,
                                height: 52,
                              ),
                              const SizedBox(height: CasamaSpacing.sm),
                              CasamaButton(
                                label: 'Switch Account / Start Fresh',
                                style: CasamaButtonStyle.ghost,
                                onPressed: () => context.push('/auth'),
                                height: 44,
                              ),
                            ] else ...[
                              CasamaButton(
                                label: 'Get Started',
                                onPressed: () => context.push('/auth'),
                                isPill: true,
                                height: 52,
                              ),
                              const SizedBox(height: CasamaSpacing.sm),
                              CasamaButton(
                                label: 'I already have an account',
                                style: CasamaButtonStyle.ghost,
                                onPressed: () =>
                                    context.push('/auth?tab=login'),
                                height: 44,
                              ),
                            ],

                            const SizedBox(height: CasamaSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: CasamaColors.white,
            borderRadius: CasamaSpacing.roundedXl,
            border: Border.all(color: CasamaColors.primaryCoral, width: 2),
          ),
          child: const Icon(
            Icons.home_rounded,
            size: 42,
            color: CasamaColors.primaryCoral,
          ),
        ),
      ],
    );
  }
}

class _TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CasamaColors.primaryCoral.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.45)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.9,
        0,
        size.height * 0.4,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintNavy = Paint()
      ..color = CasamaColors.midnightNavy.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final pathNavy = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.4, 0, size.width, size.height * 0.35)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(pathNavy, paintNavy);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
