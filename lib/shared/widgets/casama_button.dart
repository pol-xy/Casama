import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';

enum CasamaButtonStyle { primary, navy, secondary, ghost, destructive }

class CasamaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool iconAfterLabel;
  final CasamaButtonStyle style;
  final bool isLoading;
  final bool isFullWidth;
  final double? height;
  final bool isPill;

  const CasamaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconAfterLabel = false,
    this.style = CasamaButtonStyle.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.height = 50,
    this.isPill = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final disabled = onPressed == null && !isLoading;

    Color bgColor;
    Color fgColor;
    BorderSide? border;

    switch (style) {
      case CasamaButtonStyle.primary:
        bgColor = pal.primaryCoral;
        fgColor = pal.onPrimaryCoral;
        border = null;
        break;
      case CasamaButtonStyle.navy:
        bgColor = pal.forestTeal;
        fgColor = pal.onForestTeal;
        border = null;
        break;
      case CasamaButtonStyle.secondary:
        bgColor = pal.surface;
        fgColor = pal.textPrimary;
        border = BorderSide(color: pal.border, width: 1.2);
        break;
      case CasamaButtonStyle.destructive:
        bgColor = pal.dangerBg;
        fgColor = pal.dangerFg;
        border = BorderSide(
          color: pal.dangerFg.withValues(alpha: 0.28),
          width: 1,
        );
        break;
      case CasamaButtonStyle.ghost:
        bgColor = Colors.transparent;
        fgColor = pal.primaryCoral;
        border = null;
        break;
    }

    final effectiveFg = disabled ? fgColor.withValues(alpha: 0.45) : fgColor;
    final effectiveBg = disabled && style != CasamaButtonStyle.ghost
        ? bgColor.withValues(alpha: 0.5)
        : bgColor;

    final OutlinedBorder shape = isPill
        ? StadiumBorder(side: border ?? BorderSide.none)
        : RoundedRectangleBorder(
            borderRadius: CasamaSpacing.roundedInput,
            side: border ?? BorderSide.none,
          );

    final minH = (height ?? CasamaSpacing.minTouchTarget).clamp(44.0, 72.0);
    final reduced = CasamaMotion.reduceMotion(context);

    final Widget content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: reduced
                ? Icon(Icons.hourglass_top_rounded, color: effectiveFg, size: 20)
                : CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
                  ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null && !iconAfterLabel) ...[
                Icon(icon, size: 18, color: effectiveFg),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: effectiveFg,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (icon != null && iconAfterLabel) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 18, color: effectiveFg),
              ],
            ],
          );

    final button = Semantics(
      button: true,
      enabled: !disabled && !isLoading,
      label: isLoading ? '$label, loading' : label,
      child: CasamaPressable(
        onTap: (disabled || isLoading) ? null : onPressed,
        child: Material(
          color: effectiveBg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minH),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              alignment: Alignment.center,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
