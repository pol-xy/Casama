import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../shared/widgets/cas_mascot_view.dart';
import '../../../shared/widgets/casama_wave_header.dart';

/// Shared `starting.html` split-tone Forest-Teal-to-Warm-Cream wave header with
/// optional translucent step pill, adaptive back/skip controls, peeking
/// `CasMascotView`, and overlapping `28dp` rounded-top surface card.
class CasamaAuthShell extends StatelessWidget {
  final String? stepLabel;
  final VoidCallback? onBack;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final CasPose mascotPose;
  final Alignment mascotAlignment;
  final Widget child;
  final Widget? topCenterBadge;

  const CasamaAuthShell({
    super.key,
    this.stepLabel,
    this.onBack,
    this.skipLabel,
    this.onSkip,
    this.mascotPose = CasPose.waving,
    this.mascotAlignment = Alignment.bottomRight,
    required this.child,
    this.topCenterBadge,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isLeftMascot = mascotAlignment == Alignment.bottomLeft;
    final heroHeight = 176.0 + topInset;
    final cardTopOffset = heroHeight - 28.0;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cardMinHeight = math.max(
            0.0,
            constraints.maxHeight - cardTopOffset,
          );
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Stack(
              children: [
                // Top organic stepped wave hero anchored across full viewport width
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: heroHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _AuthWavePainter(
                            deep: pal.headerDeep,
                            mid: pal.headerMid,
                            bottomFill: pal.authScaffoldBg,
                            ornament: pal.headerOrnament,
                            flipWave: isLeftMascot,
                          ),
                        ),
                      ),
                      // Top Utility Controls Bar
                      Positioned(
                        top: topInset + 10,
                        left: 16,
                        right: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (onBack != null)
                              CasamaCircleIconButton(
                                icon: Icons.adaptive.arrow_back,
                                semanticLabel: 'Go back',
                                backgroundColor: pal.surface.withValues(
                                  alpha: context.isDark ? 0.90 : 0.85,
                                ),
                                onTap: onBack!,
                              )
                            else
                              const SizedBox(width: 48, height: 48),
                            if (topCenterBadge != null)
                              topCenterBadge!
                            else if (stepLabel != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  borderRadius: CasamaSpacing.roundedPill,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: CasamaColors.warmCoralFab,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      stepLabel!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.3,
                                          ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                            if (onSkip != null && skipLabel != null)
                              Semantics(
                                button: true,
                                label: skipLabel,
                                child: CasamaPressable(
                                  onTap: onSkip,
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: context.isDark ? 0.12 : 0.18,
                                      ),
                                      borderRadius: CasamaSpacing.roundedPill,
                                    ),
                                    child: Text(
                                      skipLabel!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelMedium
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 48, height: 48),
                          ],
                        ),
                      ),
                      // Transparent Mascot peeking cleanly behind top of card
                      Positioned(
                        bottom: 10,
                        right: isLeftMascot ? null : 24,
                        left: isLeftMascot ? 24 : null,
                        child: IgnorePointer(
                          child: CasMascotView(
                            pose: mascotPose,
                            width: 122,
                            height: 122,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Overlapping pure 28dp rounded-top surface card (scrolls naturally)
                Padding(
                  padding: EdgeInsets.only(top: cardTopOffset),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxW,
                        minHeight: cardMinHeight,
                      ),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: pal.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(color: pal.border, width: 1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: context.isDark ? 0.28 : 0.05,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.fromLTRB(
                          CasamaSpacing.xl,
                          CasamaSpacing.xl,
                          CasamaSpacing.xl,
                          CasamaSpacing.xl + bottomInset,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AuthWavePainter extends CustomPainter {
  final Color deep;
  final Color mid;
  final Color bottomFill;
  final Color ornament;
  final bool flipWave;

  const _AuthWavePainter({
    required this.deep,
    required this.mid,
    required this.bottomFill,
    required this.ornament,
    this.flipWave = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Warm base underneath waves
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = bottomFill,
    );

    // Muted sage lower curve
    final backWave = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, flipWave ? h * 0.68 : h * 0.60)
      ..cubicTo(
        w * 0.68,
        h * 0.78,
        w * 0.34,
        h * 0.56,
        0,
        flipWave ? h * 0.76 : h * 0.88,
      )
      ..close();
    canvas.drawPath(backWave, Paint()..color = mid.withValues(alpha: 0.60));

    // Primary Forest Teal foreground curve
    final frontWave = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, flipWave ? h * 0.54 : h * 0.42)
      ..cubicTo(
        w * 0.65,
        h * 0.64,
        w * 0.32,
        h * 0.54,
        0,
        flipWave ? h * 0.66 : h * 0.78,
      )
      ..close();
    canvas.drawPath(frontWave, Paint()..color = deep);

    // Delicate Warm Ochre geometric rings
    final ringCenter = Offset(w - 46, 52);
    final ringPaint = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(ringCenter, 22, ringPaint);
    canvas.drawCircle(
      ringCenter + const Offset(-18, 16),
      3,
      Paint()..color = ornament,
    );
  }

  @override
  bool shouldRepaint(covariant _AuthWavePainter oldDelegate) {
    return oldDelegate.deep != deep ||
        oldDelegate.mid != mid ||
        oldDelegate.bottomFill != bottomFill ||
        oldDelegate.ornament != ornament ||
        oldDelegate.flipWave != flipWave;
  }
}
