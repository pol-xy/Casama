import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';

enum ChipVariant {
  home,
  out,
  paid,
  cod,
  urgent,
  medium,
  low,
  toBuy,
  open,
  unclaimed,
  returned,
  custom,
}

class StatusChip extends StatelessWidget {
  final String label;
  final ChipVariant variant;
  final Color? customBgColor;
  final Color? customTextColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusChip({
    super.key,
    required this.label,
    this.variant = ChipVariant.custom,
    this.customBgColor,
    this.customTextColor,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final effectiveFontSize = fontSize < 11 ? 11.0 : fontSize;

    Color bg;
    Color fg;

    switch (variant) {
      case ChipVariant.home:
      case ChipVariant.paid:
      case ChipVariant.low:
      case ChipVariant.returned:
        bg = pal.successBg;
        fg = pal.successFg;
        break;
      case ChipVariant.out:
        bg = pal.neutralBg;
        fg = pal.neutralFg;
        break;
      case ChipVariant.cod:
        bg = pal.softBlush;
        fg = pal.primaryCoral;
        break;
      case ChipVariant.urgent:
      case ChipVariant.open:
        bg = pal.dangerBg;
        fg = pal.dangerFg;
        break;
      case ChipVariant.medium:
        bg = pal.warningBg;
        fg = pal.warningFg;
        break;
      case ChipVariant.toBuy:
        bg = pal.infoBg;
        fg = pal.infoFg;
        break;
      case ChipVariant.unclaimed:
        bg = pal.amberBg;
        fg = pal.amberFg;
        break;
      case ChipVariant.custom:
        bg = customBgColor ?? pal.track;
        fg = customTextColor ?? pal.textPrimary;
        break;
    }

    return Semantics(
      label: label,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: CasamaSpacing.roundedPill,
          border: Border.all(color: fg.withValues(alpha: 0.18), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: effectiveFontSize + 2, color: fg),
              const SizedBox(width: CasamaSpacing.xxs),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: effectiveFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
