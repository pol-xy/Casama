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
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? dotBorderColor;

  const AvatarChip({
    super.key,
    required this.name,
    this.avatarUrl,
    required this.isHome,
    this.isCurrentUser = false,
    this.onTap,
    this.labelColor,
    this.dotBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final cleanName = name.trim();
    final firstName = cleanName.isNotEmpty
        ? cleanName.split(RegExp(r'\s+')).first
        : 'Member';
    final displayLabel = isCurrentUser ? 'You' : firstName;

    return Semantics(
      button: onTap != null,
      label: '$displayLabel, ${isHome ? 'Home' : 'Out'}',
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: CasamaSpacing.minTouchTarget,
            minHeight: CasamaSpacing.minTouchTarget,
            maxWidth: 76,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
