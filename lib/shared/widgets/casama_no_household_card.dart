import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../features/household/create_household_sheet.dart';
import 'cas_mascot_view.dart';
import 'casama_button.dart';
import 'casama_wave_header.dart';

/// Shared prompt card shown across Home, Boards, CASnap, and Chat when the
/// signed-in user does not belong to an active household yet.
class CasamaNoHouseholdPrompt extends StatelessWidget {
  final String title;
  final String subtitle;
  final String joinLabel;
  final String createLabel;
  final CasPose mascotPose;
  final bool darkSurface;

  const CasamaNoHouseholdPrompt({
    super.key,
    this.title = 'Join a household',
    this.subtitle =
        'Join your housemates with an invite code or create your own Casa to unlock shared features.',
    this.joinLabel = 'Join with Invite Code',
    this.createLabel = 'Create Household',
    this.mascotPose = CasPose.hero,
    this.darkSurface = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final titleColor = darkSurface ? Colors.white : pal.textPrimary;
    final bodyColor = darkSurface ? Colors.white70 : pal.textSecondary;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: CasMascotView(
            pose: mascotPose,
            width: 108,
            height: 108,
          ),
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: bodyColor,
            height: 1.45,
          ),
        ),
        const SizedBox(height: CasamaSpacing.lg),
        CasamaButton(
          key: const Key('no_household_join_button'),
          label: joinLabel,
          icon: Icons.vpn_key_outlined,
          isPill: true,
          height: 50,
          onPressed: () => showJoinHouseholdSheet(context),
        ),
        const SizedBox(height: CasamaSpacing.sm),
        CasamaButton(
          key: const Key('no_household_create_button'),
          label: createLabel,
          icon: Icons.add_home_work_outlined,
          style: CasamaButtonStyle.navy,
          isPill: true,
          height: 50,
          onPressed: () => showCreateHouseholdSheet(context),
        ),
      ],
    );

    if (darkSurface) {
      return Container(
        padding: const EdgeInsets.all(CasamaSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF141B29),
          borderRadius: CasamaSpacing.roundedCard,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: content,
      );
    }

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.lg),
      child: content,
    );
  }
}
