import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../auth/widgets/auth_wave_header.dart';

class CasamaIntroScreen extends ConsumerWidget {
  const CasamaIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final greeting = repo.currentUser.effectiveGreetingName;

    return CasamaAuthShell(
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/permissions'),
      mascotPose: CasPose.waving,
      mascotAlignment: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome, $greeting!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Casama is your household\'s shared coordination hub, built to keep co-living calm, fair, and coordinated.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          _buildBenefitRow(
            context: context,
            icon: Icons.location_on_outlined,
            iconBg: pal.softBlush,
            iconColor: pal.primaryCoral,
            title: 'Manual Presence Awareness',
            desc:
                'Know who is home at a glance with zero intrusive background GPS tracking.',
          ),
          const SizedBox(height: CasamaSpacing.sm),

          _buildBenefitRow(
            context: context,
            icon: Icons.inventory_2_outlined,
            iconBg: pal.softSage,
            iconColor: pal.forestTeal,
            title: 'Delivery & COD Protection',
            desc:
                'Coordinate parcel handoffs and track Cash on Delivery reimbursements transparently.',
          ),
          const SizedBox(height: CasamaSpacing.sm),

          _buildBenefitRow(
            context: context,
            icon: Icons.casino_outlined,
            iconBg: pal.amberBg,
            iconColor: pal.amberFg,
            title: 'Fair Chores & Kasama Points',
            desc:
                'Spin Task Roulette when duties need an impartial pick and earn Good Kasama points.',
          ),
          const SizedBox(height: CasamaSpacing.sm),

          _buildBenefitRow(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: pal.infoBg,
            iconColor: pal.infoFg,
            title: 'Harmonious Housemate Connect',
            desc:
                'Coordinate in shared spaces, message housemates 1-on-1, and RSVP to household agendas.',
          ),
          const SizedBox(height: CasamaSpacing.xl),

          CasamaButton(
            label: "Let's Get Started",
            isPill: true,
            height: 50,
            onPressed: () => context.push('/interactive-tutorial'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: pal.textSecondary,
                    height: 1.4,
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
