import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';

class CasamaFilterOption<T> {
  final T value;
  final String label;
  final bool isUrgent;

  const CasamaFilterOption({
    required this.value,
    required this.label,
    this.isUrgent = false,
  });
}

/// Horizontally scrollable `36dp` visual pill rail inside `48dp` tap targets,
/// matching `core_screens.html` & `casama-app-mockup.html`.
class CasamaPillFilterRail<T> extends StatelessWidget {
  final List<CasamaFilterOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;

  const CasamaPillFilterRail({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);

    return SizedBox(
      height: CasamaSpacing.minTouchTarget,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: CasamaSpacing.xs),
        itemBuilder: (context, index) {
          final opt = options[index];
          final selected = opt.value == selectedValue;

          final Color bg;
          final Color fg;
          final Color borderColor;

          if (selected) {
            bg = opt.isUrgent ? pal.dangerFg : pal.headerDeep;
            fg = Colors.white;
            borderColor = bg;
          } else if (opt.isUrgent) {
            bg = pal.dangerBg;
            fg = pal.dangerFg;
            borderColor = pal.dangerFg.withValues(alpha: 0.25);
          } else {
            bg = pal.surface;
            fg = pal.textPrimary;
            borderColor = pal.border;
          }

          return Semantics(
            button: true,
            selected: selected,
            label: opt.label,
            child: CasamaPressable(
              onTap: () => onSelected(opt.value),
              enableHaptic: true,
              child: Container(
                height: CasamaSpacing.minTouchTarget,
                alignment: Alignment.center,
                child: AnimatedContainer(
                  duration: reduced ? Duration.zero : CasamaMotion.press,
                  curve: CasamaMotion.easeOut,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Text(
                    opt.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// `48dp` rounded segmented pill track (`#EAE6DF` / `#223846`) with `#FFFFFF` /
/// `#1A2C37` elevated active pill thumb (`Parcels` Upcoming/History, `Items`).
class CasamaSegmentedTrack<T> extends StatelessWidget {
  final List<CasamaFilterOption<T>> segments;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry margin;

  const CasamaSegmentedTrack({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onSelected,
    this.margin = const EdgeInsets.symmetric(
      horizontal: CasamaSpacing.md,
      vertical: CasamaSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);

    return Padding(
      padding: margin,
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: pal.track,
          borderRadius: CasamaSpacing.roundedPill,
          border: Border.all(color: pal.border, width: 1),
        ),
        child: Row(
          children: segments.map((seg) {
            final selected = seg.value == selectedValue;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: seg.label,
                child: CasamaPressable(
                  onTap: () => onSelected(seg.value),
                  enableHaptic: true,
                  child: AnimatedContainer(
                    duration: reduced ? Duration.zero : CasamaMotion.press,
                    curve: CasamaMotion.easeOut,
                    decoration: BoxDecoration(
                      color: selected ? pal.card : Colors.transparent,
                      borderRadius: CasamaSpacing.roundedPill,
                      border: selected
                          ? Border.all(color: pal.border, width: 1)
                          : null,
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.25 : 0.06,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      seg.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? pal.textPrimary : pal.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
