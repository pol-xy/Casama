import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';

/// Opens a unified slide-up bottom sheet matching `casama-app-mockup.html`
/// & `core_screens.html`: `280ms` ease-out rise, `200ms` `#1C2E4A` `45%` scrim,
/// `28dp` top radius, drag handle, `44dp` sage header icon, `48x48dp` close
/// button, `SafeArea`, `SingleChildScrollView`, and keyboard `viewInsets` padding.
Future<T?> showCasamaSheet<T>(
  BuildContext context, {
  IconData? icon,
  Widget? iconWidget,
  required String title,
  required String subtitle,
  Widget Function(BuildContext sheetContext)? subtitleBuilder,
  required Widget Function(BuildContext sheetContext) builder,
  Color? iconBackgroundColor,
  Color? iconColor,
  Color? sheetBackgroundColor,
  bool darkSurfaceOverride = false,
  bool scrollable = true,
}) {
  assert(icon != null || iconWidget != null);
  final reduced = CasamaMotion.reduceMotion(context);
  final pal = context.palette;

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss $title',
    barrierColor: pal.scrim,
    transitionDuration: reduced ? Duration.zero : CasamaMotion.sheet,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return _CasamaSheetHost(
        icon: icon,
        iconWidget: iconWidget,
        title: title,
        subtitle: subtitle,
        subtitleBuilder: subtitleBuilder,
        iconBackgroundColor: iconBackgroundColor,
        iconColor: iconColor,
        sheetBackgroundColor: sheetBackgroundColor,
        darkSurfaceOverride: darkSurfaceOverride,
        scrollable: scrollable,
        builder: builder,
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      if (reduced) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: CasamaMotion.easeOut,
        reverseCurve: CasamaMotion.easeIn,
      );
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 2.0 * curved.value,
          sigmaY: 2.0 * curved.value,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _CasamaSheetHost extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final Widget Function(BuildContext sheetContext)? subtitleBuilder;
  final Color? iconBackgroundColor;
  final Color? iconColor;
  final Color? sheetBackgroundColor;
  final bool darkSurfaceOverride;
  final bool scrollable;
  final Widget Function(BuildContext sheetContext) builder;

  const _CasamaSheetHost({
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    this.subtitleBuilder,
    required this.builder,
    this.iconBackgroundColor,
    this.iconColor,
    this.sheetBackgroundColor,
    this.darkSurfaceOverride = false,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final mq = MediaQuery.of(context);

    final sheetBg = sheetBackgroundColor ??
        (darkSurfaceOverride ? const Color(0xFF141B29) : pal.surface);
    final titleColor = darkSurfaceOverride ? Colors.white : pal.textPrimary;
    final subColor = darkSurfaceOverride
        ? Colors.white.withValues(alpha: 0.65)
        : pal.textSecondary;
    final closeBg = darkSurfaceOverride
        ? Colors.white.withValues(alpha: 0.12)
        : pal.track;
    final dividerCol = darkSurfaceOverride
        ? Colors.white.withValues(alpha: 0.10)
        : pal.divider;
    final badgeBg = iconBackgroundColor ??
        (darkSurfaceOverride ? const Color(0x33E87461) : pal.softSage);
    final badgeFg = iconColor ??
        (darkSurfaceOverride ? CasamaColors.warmCoralFab : pal.forestTeal);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: CasamaBreakpoints.maxSheetWidth,
          maxHeight: mq.size.height * 0.92,
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
          child: Material(
            color: sheetBg,
            borderRadius: CasamaSpacing.roundedSheetTop,
            clipBehavior: Clip.antiAlias,
            elevation: 16,
            shadowColor: const Color(0x2E1C2E4A),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: darkSurfaceOverride
                          ? Colors.white.withValues(alpha: 0.25)
                          : pal.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Header row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.lg,
                    ),
                    child: Container(
                      padding: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: dividerCol, width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: badgeBg,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: iconWidget != null
                                ? IconTheme(
                                    data: IconThemeData(
                                      color: badgeFg,
                                      size: 24,
                                    ),
                                    child: iconWidget!,
                                  )
                                : Icon(icon!, color: badgeFg, size: 22),
                          ),
                          const SizedBox(width: CasamaSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: titleColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (subtitleBuilder != null)
                                  DefaultTextStyle(
                                    style:
                                        (theme.textTheme.bodySmall ??
                                                const TextStyle())
                                            .copyWith(
                                              color: subColor,
                                              fontSize: 12.5,
                                            ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    child: subtitleBuilder!(context),
                                  )
                                else
                                  Text(
                                    subtitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: subColor,
                                      fontSize: 12.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: CasamaSpacing.xs),
                          Semantics(
                            button: true,
                            label: 'Close $title',
                            child: CasamaPressable(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                width: CasamaSpacing.minTouchTarget,
                                height: CasamaSpacing.minTouchTarget,
                                decoration: BoxDecoration(
                                  color: closeBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: titleColor,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: scrollable
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(
                              CasamaSpacing.lg,
                              CasamaSpacing.md,
                              CasamaSpacing.lg,
                              CasamaSpacing.xl,
                            ),
                            child: builder(context),
                          )
                        : builder(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
