import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import 'casama_avatar.dart';
import 'status_chip.dart';

class AvatarChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isHome;
  final bool isCurrentUser;
  final String? note;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? dotBorderColor;

  const AvatarChip({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.isHome,
    this.isCurrentUser = false,
    this.note,
    this.onTap,
    this.labelColor,
    this.dotBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final cleanName = name.trim();
    final cleanNote = note?.trim() ?? '';
    final hasNote = cleanNote.isNotEmpty;
    final displayLabel = isCurrentUser
        ? 'You'
        : (cleanName.isNotEmpty ? cleanName : 'Housemate');

    return Semantics(
      button: onTap != null,
      label: hasNote
          ? '$displayLabel, ${isHome ? 'Home' : 'Out'}, Note: $cleanNote'
          : '$displayLabel, ${isHome ? 'Home' : 'Out'}',
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: CasamaSpacing.minTouchTarget,
            minHeight: CasamaSpacing.minTouchTarget,
            maxWidth: 96,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasNote) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    cleanNote,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Transform.translate(
                  offset: const Offset(-6, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: pal.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.border, width: 1),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Transform.translate(
                        offset: const Offset(4, 0),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: pal.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: pal.border, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Stack(
                children: [
                  CasamaAvatar(
                    avatarUrl: avatarUrl,
                    radius: 22,
                    name: cleanName,
                    borderWidth: isCurrentUser ? 2 : 0,
                    borderColor: pal.coralFab,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isHome ? pal.successFg : pal.neutralFg,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: dotBorderColor ?? pal.card,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CasamaSpacing.xxs + 2),
              Text(
                displayLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                  color: labelColor ?? pal.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: CasamaSpacing.xxs),
              StatusChip(
                label: isHome ? 'Home' : 'Out',
                variant: isHome ? ChipVariant.home : ChipVariant.out,
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
