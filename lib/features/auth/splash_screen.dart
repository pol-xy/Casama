import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/router/app_router.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final isReturningUser =
        repo.isAuthenticated && repo.currentUser.hasCompletedOnboarding;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final topMinHeight = math.max(304.0, constraints.maxHeight - 280.0);
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Forest Teal Brand Stage + Mascot + Stepped Organic Waves
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: topMinHeight),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SplashTopPainter(
                              deep: pal.headerDeep,
                              mid: pal.headerMid,
                              light: pal.headerLight,
                              surface: pal.scaffoldBg,
                              ornament: pal.headerOrnament,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            CasamaSpacing.xl,
                            topInset + CasamaSpacing.md,
                            CasamaSpacing.xl,
                            0,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // House Emblem + Single Wordmark
                              const SizedBox(
                                width: 48,
                                height: 48,
                                child: CustomPaint(
                                  painter: _CasamaHouseMarkPainter(),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Casama',
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontSize: 28,
                                  color: const Color(0xFFFFF8F1),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: CasamaSpacing.md),
                              // Transparent Mascot resting directly over waves
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: CasMascotView(
                                  pose: CasPose.hero,
                                  width: 168,
                                  height: 168,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom 28dp Rounded White/Surface Sheet Card
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: pal.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: context.isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          CasamaSpacing.xl,
                          28,
                          CasamaSpacing.xl,
                          24 + bottomInset,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Your shared home, simplified.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 23,
                                color: pal.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 300),
                              child: Text(
                                'Making shared living simpler, warmer, and more coordinated.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: pal.textSecondary,
                                  fontSize: 14,
                                  height: 1.45,
                                ),
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xl),
                            if (isReturningUser) ...[
                              CasamaButton(
                                label:
                                    'Continue as ${repo.currentUser.effectiveGreetingName}',
                                icon: Icons.arrow_forward_rounded,
                                iconAfterLabel: true,
                                onPressed: () => context.go(
                                  resolveAuthenticatedDestination(
                                    repo.currentUser,
                                  ),
                                ),
                                height: 52,
                              ),
                              const SizedBox(height: CasamaSpacing.sm),
                              Semantics(
                                button: true,
                                label: 'Switch Account or Sign In',
                                child: CasamaPressable(
                                  onTap: () => context.push('/auth?tab=login'),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: CasamaSpacing.minTouchTarget,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Switch Account',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: pal.forestTeal,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              CasamaButton(
                                label: 'Get Started',
                                icon: Icons.arrow_forward_rounded,
                                iconAfterLabel: true,
                                onPressed: () => context.push('/auth'),
                                height: 52,
                              ),
                              const SizedBox(height: CasamaSpacing.sm),
                              Semantics(
                                button: true,
                                label: 'I already have an account',
                                child: CasamaPressable(
                                  onTap: () => context.push('/auth?tab=login'),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      minHeight: CasamaSpacing.minTouchTarget,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'I already have an account',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: pal.forestTeal,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CasamaHouseMarkPainter extends CustomPainter {
  const _CasamaHouseMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;
    final cream = Paint()..color = const Color(0xFFFFF8F1);
    final coral = Paint()..color = const Color(0xFFE87968);

    // Roof + house body
    final house = Path()
      ..moveTo(24 * s, 10 * s)
      ..lineTo(38.5 * s, 22.5 * s)
      ..lineTo(36 * s, 22.5 * s)
      ..lineTo(36 * s, 40 * s)
      ..lineTo(12 * s, 40 * s)
      ..lineTo(12 * s, 22.5 * s)
      ..lineTo(9.5 * s, 22.5 * s)
      ..close();
    canvas.drawPath(house, cream);

    // 4-pane window
    for (final rect in [
      Rect.fromLTWH(19 * s, 24 * s, 4.4 * s, 4.4 * s),
      Rect.fromLTWH(24.6 * s, 24 * s, 4.4 * s, 4.4 * s),
      Rect.fromLTWH(19 * s, 29.6 * s, 4.4 * s, 4.4 * s),
      Rect.fromLTWH(24.6 * s, 29.6 * s, 4.4 * s, 4.4 * s),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(1 * s)),
        coral,
      );
    }

    // Sparkle star top-right
    final cx = 37 * s;
    final cy = 11 * s;
    final star = Path()
      ..moveTo(cx, cy - 4 * s)
      ..lineTo(cx + 1.2 * s, cy - 1.2 * s)
      ..lineTo(cx + 4 * s, cy)
      ..lineTo(cx + 1.2 * s, cy + 1.2 * s)
      ..lineTo(cx, cy + 4 * s)
      ..lineTo(cx - 1.2 * s, cy + 1.2 * s)
      ..lineTo(cx - 4 * s, cy)
      ..lineTo(cx - 1.2 * s, cy - 1.2 * s)
      ..close();
    canvas.drawPath(star, cream);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SplashTopPainter extends CustomPainter {
  final Color deep;
  final Color mid;
  final Color light;
  final Color surface;
  final Color ornament;

  const _SplashTopPainter({
    required this.deep,
    required this.mid,
    required this.light,
    required this.surface,
    required this.ornament,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = deep);

    // Delicate gold ring ornament top-right
    final ring = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset(w - 16, 22), 44, ring);
    canvas.drawCircle(Offset(w - 16, 22), 24, ring);
    canvas.drawCircle(Offset(w - 42, 48), 3, Paint()..color = ornament);

    // Layered stepped waves near bottom
    final p1 = Path()
      ..moveTo(0, h - 78)
      ..cubicTo(w * 0.25, h - 98, w * 0.65, h - 58, w, h - 82)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p1, Paint()..color = mid);

    final p2 = Path()
      ..moveTo(0, h - 48)
      ..cubicTo(w * 0.30, h - 68, w * 0.72, h - 32, w, h - 50)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p2, Paint()..color = light);

    final p3 = Path()
      ..moveTo(0, h - 20)
      ..cubicTo(w * 0.35, h - 36, w * 0.75, h - 10, w, h - 22)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(p3, Paint()..color = surface);
  }

  @override
  bool shouldRepaint(covariant _SplashTopPainter oldDelegate) =>
      oldDelegate.deep != deep ||
      oldDelegate.mid != mid ||
      oldDelegate.light != light ||
      oldDelegate.surface != surface ||
      oldDelegate.ornament != ornament;
}
