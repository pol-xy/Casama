import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';

class BoardsScreen extends StatelessWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(title: const Text('Household Boards')),
      body: ListView(
        padding: const EdgeInsets.all(CasamaSpacing.lg),
        children: [
          _BoardHubCard(
            title: 'Parcels & Deliveries',
            subtitle: 'Coordinate arrivals, roommate availability & COD',
            icon: Icons.inventory_2_outlined,
            iconColor: CasamaColors.primaryCoral,
            bgColor: context.isDark
                ? CasamaColors.darkTileParcels
                : CasamaColors.tileParcels,
            onTap: () => context.push('/parcels'),
          ),
          const SizedBox(height: 16),
          _BoardHubCard(
            title: 'Lost & Found Items',
            subtitle:
                'Report missing items, claim found goods, share housewares',
            icon: Icons.search_rounded,
            iconColor: CasamaColors.deepTeal,
            bgColor: context.isDark
                ? CasamaColors.darkTileLostFound
                : CasamaColors.tileLostFound,
            onTap: () => context.push('/lost-found'),
          ),
          const SizedBox(height: 16),
          _BoardHubCard(
            title: 'Maintenance & Restock',
            subtitle: 'Track repairs, cleaning tasks, and household supplies',
            icon: Icons.build_outlined,
            iconColor: const Color(0xFF1E88E5),
            bgColor: context.isDark
                ? CasamaColors.darkTileMaintenance
                : CasamaColors.tileMaintenance,
            onTap: () => context.push('/maintenance'),
          ),
          const SizedBox(height: 16),
          _BoardHubCard(
            title: 'Chore Roulette',
            subtitle: "Spin the wheel to settle chore duties fairly!",
            icon: Icons.casino_outlined,
            iconColor: const Color(0xFFE91E63),
            bgColor: context.isDark
                ? CasamaColors.darkTileChoreRoulette
                : CasamaColors.tileChoreRoulette,
            onTap: () => context.push('/roulette'),
          ),
          const SizedBox(height: 16),
          _BoardHubCard(
            title: 'Bills & Payments',
            subtitle: 'Track household bills, set reminders, and never miss a deadline',
            icon: Icons.receipt_long_outlined,
            iconColor: CasamaColors.tileBillsIcon,
            bgColor: context.isDark
                ? CasamaColors.darkTileBills
                : CasamaColors.tileBills,
            onTap: () => context.push('/bills'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _BoardHubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _BoardHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cardColor,
      borderRadius: CasamaSpacing.roundedLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: CasamaSpacing.roundedLg,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: CasamaSpacing.roundedLg,
            border: Border.all(color: context.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: CasamaSpacing.roundedMd,
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textMutedColor),
            ],
          ),
        ),
      ),
    );
  }
}
