import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import 'cas_mascot_view.dart';
import 'casama_notifications_sheet.dart';

/// Stepped Forest-Teal-to-Warm-Beige organic wave header matching
/// `core_screens.html` & `casama-app-mockup.html`, with celestial gold rings,
/// `48x48dp` circular utility controls, optional board tabs, and hero slots.
class CasamaWaveHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onMenuTap;
  final VoidCallback? onBackTap;
  final VoidCallback? onNotificationTap;
  final int unreadNotificationCount;
  final bool showNotificationBell;
  final List<Widget> rightActions;
  final Widget? embeddedTabBar;
  final Widget? bottomHero;
  final CasPose? titleMascotPose;
  final double titleMascotSize;
  final bool extendedWave;
  final bool compact;
  final double bottomPaddingOffset;

  const CasamaWaveHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onMenuTap,
    this.onBackTap,
    this.onNotificationTap,
    this.unreadNotificationCount = 0,
    this.showNotificationBell = false,
    this.rightActions = const [],
    this.embeddedTabBar,
    this.bottomHero,
    this.titleMascotPose,
    this.titleMascotSize = 60,
    this.extendedWave = false,
    this.compact = false,
    this.bottomPaddingOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final reduced = CasamaMotion.reduceMotion(context);
    final double bottomPad = ((extendedWave || embeddedTabBar != null)
            ? 44.0
            : (compact ? 26.0 : 38.0)) +
        bottomPaddingOffset;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Stepped Organic Wave Canvas + Celestial Gold Ring
        Positioned.fill(
          child: CustomPaint(
            painter: _SteppedWaveHeaderPainter(
              deep: pal.headerDeep,
              mid: pal.headerMid,
              light: pal.headerLight,
              bottomBg: pal.scaffoldBg,
              ornament: pal.headerOrnament,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            CasamaSpacing.md,
            topPad + 12,
            CasamaSpacing.md,
            bottomPad,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top 48x48dp Utility Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (onBackTap != null)
                    CasamaCircleIconButton(
                      icon: Icons.adaptive.arrow_back,
                      semanticLabel: 'Go back',
                      onTap: onBackTap!,
                    )
                  else if (onMenuTap != null)
                    CasamaCircleIconButton(
                      semanticLabel: 'Open menu',
                      onTap: onMenuTap!,
                      customIcon: _TwoLineMenuIcon(color: pal.textPrimary),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < rightActions.length; i++) ...[
                        if (i > 0) const SizedBox(width: CasamaSpacing.xs),
                        rightActions[i],
                      ],
                      if (rightActions.isNotEmpty &&
                          (showNotificationBell || onNotificationTap != null))
                        const SizedBox(width: CasamaSpacing.xs),
                      if (showNotificationBell)
                        const CasamaNotificationBellButton()
                      else if (onNotificationTap != null)
                        CasamaCircleIconButton(
                          icon: Icons.notifications_none_rounded,
                          semanticLabel: unreadNotificationCount > 0
                              ? 'Notifications, $unreadNotificationCount unread'
                              : 'Notifications',
                          showDot: unreadNotificationCount > 0,
                          onTap: onNotificationTap!,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Heading + Leveled Mascot Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.headerSubtitle,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (titleMascotPose != null) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: titleMascotSize,
                      height: titleMascotSize,
                      child: AnimatedSwitcher(
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        child: CasMascotView(
                          key: ValueKey(titleMascotPose),
                          pose: titleMascotPose!,
                          width: titleMascotSize,
                          height: titleMascotSize,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (embeddedTabBar != null) ...[
                const SizedBox(height: 12),
                embeddedTabBar!,
              ],
              if (bottomHero != null) ...[
                const SizedBox(height: CasamaSpacing.sm),
                bottomHero!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Pure `48x48dp` white/surface circular icon control with subtle hairline border
/// matching `core_screens.html`.
class CasamaCircleIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final String semanticLabel;
  final VoidCallback onTap;
  final bool showDot;
  final Color? backgroundColor;
  final Color? iconColor;

  const CasamaCircleIconButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.semanticLabel,
    required this.onTap,
    this.showDot = false,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: CasamaPressable(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor ?? pal.surface,
            shape: BoxShape.circle,
            border: Border.all(color: pal.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              customIcon ??
                  Icon(
                    icon ?? Icons.circle,
                    size: 21,
                    color: iconColor ?? pal.textPrimary,
                  ),
              if (showDot)
                Positioned(
                  top: 11,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: pal.coralFab,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact pill button used inside `CasamaWaveHeader.rightActions` (e.g.,
/// `Add Housemate`, `Plan Agenda`) with minimum `44dp` height and press feedback.
class CasamaHeaderActionPill extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final Color? iconColor;
  final VoidCallback onTap;

  const CasamaHeaderActionPill({
    super.key,
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onTap,
    this.iconColor,
  }) : assert(icon != null || iconWidget != null);

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: pal.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.22 : 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconWidget != null)
                IconTheme(
                  data: IconThemeData(
                    color: iconColor ?? pal.forestTeal,
                    size: 16,
                  ),
                  child: iconWidget!,
                )
              else
                Icon(icon!, size: 16, color: iconColor ?? pal.forestTeal),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: pal.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TwoLineMenuIcon extends StatelessWidget {
  final Color color;

  const _TwoLineMenuIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 19,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 13,
          height: 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _SteppedWaveHeaderPainter extends CustomPainter {
  final Color deep;
  final Color mid;
  final Color light;
  final Color bottomBg;
  final Color ornament;

  const _SteppedWaveHeaderPainter({
    required this.deep,
    required this.mid,
    required this.light,
    required this.bottomBg,
    required this.ornament,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base Forest Teal fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = deep,
    );

    // 2. Top-right celestial gold orbital ornament
    final center = Offset(w - 36, 48);
    final ringPaint = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    canvas.drawCircle(center, 44, ringPaint);
    canvas.drawCircle(
      center,
      28,
      ringPaint..color = ornament.withValues(alpha: ornament.a * 0.75),
    );
    canvas.drawCircle(
      center + const Offset(-18, 22),
      2.6,
      Paint()..color = ornament,
    );

    // 3. Wave Band 1: Muted Sage-Teal (#688C83)
    final wave1 = Path()
      ..moveTo(0, h - 42)
      ..cubicTo(w * 0.36, h - 54, w * 0.68, h - 22, w, h - 42)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave1, Paint()..color = mid);

    // 4. Wave Band 2: Pale Misty Sage (#A5B9B0)
    final wave2 = Path()
      ..moveTo(0, h - 26)
      ..cubicTo(w * 0.40, h - 40, w * 0.72, h - 8, w, h - 26)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(wave2, Paint()..color = light);

    // 5. Step cleanly into Soft Warm Beige (#EAE4D7 / dark bg)
    final wave3 = Path()
      ..moveTo(0, h - 12)
      ..cubicTo(w * 0.42, h - 22, w * 0.74, h + 2, w, h - 12)
      ..lineTo(w, h + 2)
      ..lineTo(0, h + 2)
      ..close();
    canvas.drawPath(wave3, Paint()..color = bottomBg);
  }

  @override
  bool shouldRepaint(covariant _SteppedWaveHeaderPainter oldDelegate) {
    return oldDelegate.deep != deep ||
        oldDelegate.mid != mid ||
        oldDelegate.light != light ||
        oldDelegate.bottomBg != bottomBg ||
        oldDelegate.ornament != ornament;
  }
}

/// Ambient canvas wrapper rendering subtle `6%` & `9%` Forest Teal curves over
/// Warm Beige (`#EAE4D7`) / nocturnal dark background.
class CasamaAmbientCanvas extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const CasamaAmbientCanvas({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return ColoredBox(
      color: backgroundColor ?? pal.scaffoldBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: _AmbientWavePainter(
                weak: pal.ambientWaveWeak,
                strong: pal.ambientWaveStrong,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _AmbientWavePainter extends CustomPainter {
  final Color weak;
  final Color strong;

  const _AmbientWavePainter({required this.weak, required this.strong});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final upper = Path()
      ..moveTo(0, h * 0.48)
      ..cubicTo(w * 0.28, h * 0.43, w * 0.68, h * 0.54, w, h * 0.47)
      ..lineTo(w, h * 0.64)
      ..cubicTo(w * 0.66, h * 0.69, w * 0.34, h * 0.60, 0, h * 0.64)
      ..close();
    canvas.drawPath(upper, Paint()..color = strong);

    final lower = Path()
      ..moveTo(0, h * 0.78)
      ..cubicTo(w * 0.24, h * 0.74, w * 0.55, h * 0.84, w, h * 0.77)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(lower, Paint()..color = weak);
  }

  @override
  bool shouldRepaint(covariant _AmbientWavePainter oldDelegate) =>
      oldDelegate.weak != weak || oldDelegate.strong != strong;
}

/// Pure `20dp` hairline-bordered card matching `core_screens.html`.
class CasamaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderSide? borderSide;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;

  const CasamaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CasamaSpacing.md),
    this.borderSide,
    this.color,
    this.radius = CasamaSpacing.radiusCard,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    final box = Container(
      decoration: BoxDecoration(
        color: color ?? pal.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.fromBorderSide(
          borderSide ?? BorderSide(color: pal.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      return CasamaPressable.card(onTap: onTap, child: box);
    }
    return box;
  }
}

/// 2-metric Boards summary bar with a transparent `CasMascotView` tucked
/// cleanly *behind* the opaque summary card's upper-right edge (no borders or
/// shadow box around the mascot).
class CasamaPeekingSummaryBar extends StatelessWidget {
  final CasPose? mascotPose;
  final bool showPeekingMascot;
  final String leftTitle;
  final String leftSubtitle;
  final Widget? leftSubtitleWidget;
  final String rightTitle;
  final String rightSubtitle;
  final Color? rightTitleColor;
  final Color? rightSubtitleColor;
  final double? rightTitleFontSize;

  const CasamaPeekingSummaryBar({
    super.key,
    this.mascotPose,
    this.showPeekingMascot = false,
    required this.leftTitle,
    this.leftSubtitle = '',
    this.leftSubtitleWidget,
    required this.rightTitle,
    required this.rightSubtitle,
    this.rightTitleColor,
    this.rightSubtitleColor,
    this.rightTitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (showPeekingMascot && mascotPose != null)
            Positioned(
              right: 18,
              top: -46,
              child: IgnorePointer(
                child: CasMascotView(
                  pose: mascotPose!,
                  width: 76,
                  height: 76,
                ),
              ),
            ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: CasamaSpacing.roundedSummary,
              border: Border.all(color: pal.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.22 : 0.04,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        leftTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.tabular.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (leftSubtitleWidget != null)
                        leftSubtitleWidget!
                      else
                        Text(
                          leftSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: pal.border,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rightTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.tabular.copyWith(
                          fontSize: rightTitleFontSize ?? 17,
                          fontWeight: FontWeight.w700,
                          color: rightTitleColor ?? pal.forestTeal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rightSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.tabular.copyWith(
                          fontSize: 11.5,
                          color: rightSubtitleColor ?? pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Split Mascot + Status Card Hero used on Home Dashboard & Chat Directory.
class CasamaSplitHero extends StatelessWidget {
  final CasPose mascotPose;
  final String kicker;
  final String headline;
  final String subtitle;
  final Color? kickerDotColor;

  const CasamaSplitHero({
    super.key,
    required this.mascotPose,
    required this.kicker,
    required this.headline,
    required this.subtitle,
    this.kickerDotColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: CasMascotView(
              pose: mascotPose,
              width: 112,
              height: 112,
            ),
          ),
          const SizedBox(width: CasamaSpacing.sm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: CasamaCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kickerDotColor != null) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: kickerDotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            kicker.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: pal.textSecondary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.tabular.copyWith(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
