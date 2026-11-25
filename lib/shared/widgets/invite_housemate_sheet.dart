import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import 'casama_button.dart';
import 'casama_sheet_scaffold.dart';

/// Centralized Household Invitation Bottom Sheet (`showCasamaSheet` slide-up).
Future<void> showInviteHousemateSheet(
  BuildContext context, {
  required String householdName,
  required String inviteCode,
}) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.group_add_rounded,
    title: 'Invite Your Housemates 🏡',
    subtitle: 'Invite-only access to $householdName',
    builder: (ctx) {
      final pal = ctx.palette;
      final theme = Theme.of(ctx);

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Share this unique household invite code with your roommates so they can join $householdName on Casama.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: CasamaSpacing.md),

          // Invite code pill card
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CasamaSpacing.md,
              vertical: CasamaSpacing.md,
            ),
            decoration: BoxDecoration(
              color: pal.track,
              borderRadius: CasamaSpacing.roundedCard,
              border: Border.all(color: pal.border),
            ),
            child: Column(
              children: [
                Text(
                  'HOUSEHOLD CODE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.2,
                    color: pal.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      inviteCode,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      button: true,
                      label: 'Copy invite code',
                      child: CasamaPressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          showCasamaToast(
                            ctx,
                            'Copied invite code "$inviteCode"!',
                            icon: Icons.copy_rounded,
                          );
                        },
                        child: Container(
                          width: CasamaSpacing.minTouchTarget,
                          height: CasamaSpacing.minTouchTarget,
                          decoration: BoxDecoration(
                            color: pal.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: pal.border),
                          ),
                          child: Icon(
                            Icons.copy_rounded,
                            color: pal.primaryCoral,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.md),

          // Privacy & benefits card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.softSage,
              borderRadius: CasamaSpacing.roundedMd,
              border: Border.all(color: pal.forestTeal.withValues(alpha: 0.25)),
            ),
            child: const Column(
              children: [
                _BenefitRow(
                  icon: Icons.verified_user_outlined,
                  text: 'Zero background GPS tracking — manual presence only',
                ),
                SizedBox(height: 8),
                _BenefitRow(
                  icon: Icons.inventory_2_outlined,
                  text: 'Deliveries & COD advance coordination',
                ),
                SizedBox(height: 8),
                _BenefitRow(
                  icon: Icons.stars_rounded,
                  text: 'Earn Good Kasama points for chores',
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaButton(
            label: 'Copy Full Invitation Message',
            icon: Icons.share_rounded,
            onPressed: () {
              final message =
                  'Hey! Join our household "$householdName" on Casama using invite code: $inviteCode. Download the app to coordinate deliveries, chores, and housemate plans!';
              Clipboard.setData(ClipboardData(text: message));
              Navigator.pop(ctx);
              showCasamaToast(
                context,
                'Invitation message copied! Share it with your housemates.',
                icon: Icons.check_circle_outline_rounded,
              );
            },
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaButton(
            label: 'Close',
            style: CasamaButtonStyle.ghost,
            onPressed: () => Navigator.pop(ctx),
            height: 44,
          ),
        ],
      );
    },
  );
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Row(
      children: [
        Icon(icon, size: 17, color: pal.forestTeal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: pal.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
