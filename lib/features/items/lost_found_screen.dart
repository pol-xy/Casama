import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/report_item_sheet.dart';

enum _ItemSubTab { lost, found }

/// Standalone Lost & Found route wrapper (`/lost-found`).
/// Reuses `ItemsBoardView` to guarantee visual parity with the unified
/// `Boards` hub's `Items` tab.
class LostFoundScreen extends ConsumerStatefulWidget {
  final bool initialOpenPostModal;

  const LostFoundScreen({super.key, this.initialOpenPostModal = false});

  @override
  ConsumerState<LostFoundScreen> createState() => _LostFoundScreenState();
}

class _LostFoundScreenState extends ConsumerState<LostFoundScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialOpenPostModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showReportItemSheet(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showReportItemSheet(context),
        backgroundColor: pal.coralFab,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.sell_outlined),
        label: const Text(
          'Report item',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Lost & Found',
              subtitle: '${repo.currentHousehold.name} • Missing & found items',
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                CasamaHeaderActionPill(
                  icon: Icons.sell_outlined,
                  label: 'Report item',
                  onTap: () => showReportItemSheet(context),
                ),
              ],
            ),
            const Expanded(
              child: ItemsBoardView(bottomPadding: 100),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared Lost & Found Board tab content (`Boards -> Items` + `/lost-found`).
class ItemsBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const ItemsBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<ItemsBoardView> createState() => _ItemsBoardViewState();
}

class _ItemsBoardViewState extends ConsumerState<ItemsBoardView> {
  _ItemSubTab _selectedTab = _ItemSubTab.lost;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final items = repo.items;

    final lostItems = items.where((i) => i.type == ItemType.lost).toList();
    final foundItems = items.where((i) => i.type == ItemType.found).toList();

    final openLostCount = lostItems
        .where(
          (i) =>
              i.status == ItemStatus.open || i.status == ItemStatus.unclaimed,
        )
        .length;
    final openFoundCount = foundItems
        .where(
          (i) =>
              i.status == ItemStatus.open || i.status == ItemStatus.unclaimed,
        )
        .length;

    final List<LostFoundItem> displayed = switch (_selectedTab) {
      _ItemSubTab.lost => lostItems,
      _ItemSubTab.found => foundItems,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 46, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.together,
            leftTitle: '$openLostCount Lost',
            leftSubtitle: 'Open missing reports',
            rightTitle: '$openFoundCount Found',
            rightSubtitle: 'Waiting to be claimed',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaSegmentedTrack<int>(
            selectedValue: _selectedTab.index,
            onSelected: (idx) {
              setState(() => _selectedTab = _ItemSubTab.values[idx]);
            },
            segments: const [
              CasamaFilterOption(value: 0, label: 'Lost'),
              CasamaFilterOption(value: 1, label: 'Found'),
            ],
          ),
          const SizedBox(height: CasamaSpacing.sm),

          if (displayed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
              child: CasamaCard(
                padding: const EdgeInsets.all(CasamaSpacing.xl),
                child: Column(
                  children: [
                    CasMascotView(
                      pose: CasPose.together,
                      height: 88,
                      semanticLabel: 'Lost and Found Mascot',
                    ),
                    const SizedBox(height: CasamaSpacing.sm),
                    Text(
                      _selectedTab == _ItemSubTab.lost
                          ? 'No missing items reported'
                          : 'No found items waiting',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Report item" below to post to the household board.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
              child: Column(
                children: [
                  for (final item in displayed) ...[
                    _ItemCard(
                      item: item,
                      onClaimOrFound: () {
                        repo.claimItem(item.id);
                        showCasamaToast(
                          context,
                          item.type == ItemType.lost
                              ? 'Marked "${item.title}" as found!'
                              : 'Claimed "${item.title}"!',
                          icon: Icons.check_circle_outline_rounded,
                        );
                      },
                      onMarkReturned: () {
                        repo.returnItem(item.id);
                        showCasamaToast(
                          context,
                          'Marked "${item.title}" as returned (+3 pts)!',
                          icon: Icons.verified_rounded,
                        );
                      },
                    ),
                    const SizedBox(height: CasamaSpacing.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final LostFoundItem item;
  final VoidCallback onClaimOrFound;
  final VoidCallback onMarkReturned;

  const _ItemCard({
    required this.item,
    required this.onClaimOrFound,
    required this.onMarkReturned,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final isReturned = item.status == ItemStatus.returned;
    final isInProgress =
        item.status == ItemStatus.found || item.status == ItemStatus.claimed;
    final isResolved = isReturned;
    final dateStr = DateFormat('MMM d').format(item.createdAt);

    final (Color badgeBg, Color badgeFg, String badgeLabel) =
        item.type == ItemType.lost
        ? (pal.dangerBg, pal.dangerFg, 'Lost')
        : (pal.softSage, pal.forestTeal, 'Found');

    final (String actionLabel, IconData actionIcon) = item.type == ItemType.lost
        ? ('I Found This', Icons.check_circle_outline_rounded)
        : ('Mine / Claim', Icons.pan_tool_alt_outlined);

    return CasamaCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(CasamaSpacing.radiusCard),
              ),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: _buildItemImage(item.imageUrl!, pal),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(CasamaSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CasamaAvatar(
                      radius: 15,
                      name: item.reportedByName,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.reportedByName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: pal.textMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: badgeLabel,
                      variant: ChipVariant.custom,
                      customBgColor: badgeBg,
                      customTextColor: badgeFg,
                    ),
                  ],
                ),
                const SizedBox(height: CasamaSpacing.sm),

                Text(
                  item.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isResolved ? pal.textMuted : pal.textPrimary,
                    decoration: isResolved ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.description != null &&
                    item.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: CasamaSpacing.sm),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isReturned)
                      const StatusChip(
                        label: 'Returned',
                        icon: Icons.verified_rounded,
                        variant: ChipVariant.paid,
                      )
                    else if (isInProgress) ...[
                      StatusChip(
                        label: item.type == ItemType.lost ? 'Found' : 'Claimed',
                        variant: ChipVariant.medium,
                      ),
                      const SizedBox(width: 8),
                      _QuickActionButton(
                        label: 'Mark Returned',
                        icon: Icons.verified_outlined,
                        color: pal.forestTeal,
                        bg: pal.softSage,
                        onTap: onMarkReturned,
                      ),
                    ] else
                      _QuickActionButton(
                        label: actionLabel,
                        icon: actionIcon,
                        color: pal.forestTeal,
                        bg: pal.softSage,
                        onTap: onClaimOrFound,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildItemImage(String imageUrl, CasamaPalette pal) {
  if (imageUrl.startsWith('data:image')) {
    try {
      final base64Str = imageUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackImage(pal),
      );
    } catch (_) {
      return _fallbackImage(pal);
    }
  }
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => _fallbackImage(pal),
  );
}

Widget _fallbackImage(CasamaPalette pal) {
  return Container(
    color: pal.track,
    alignment: Alignment.center,
    child: Icon(Icons.image_outlined, size: 36, color: pal.textMuted),
  );
}
