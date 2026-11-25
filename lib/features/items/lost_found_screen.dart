import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/report_item_sheet.dart';

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
      body: CasamaAmbientCanvas(
        child: Stack(
          children: [
            Column(
              children: [
                CasamaWaveHeader(
                  title: 'Lost & Found',
                  subtitle:
                      '${repo.currentHousehold.name} • Missing, found & shared items',
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
                const Expanded(child: ItemsBoardView(bottomPadding: 96)),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: CasamaButton(
                label: 'Post an Item',
                icon: Icons.photo_camera_outlined,
                onPressed: () => showReportItemSheet(context),
                isPill: true,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable Lost / Found / Shared board tab body shared by [BoardsScreen] and standalone [LostFoundScreen].
class ItemsBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const ItemsBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<ItemsBoardView> createState() => _ItemsBoardViewState();
}

class _ItemsBoardViewState extends ConsumerState<ItemsBoardView> {
  int _selectedTab = 0; // 0 = Lost, 1 = Found, 2 = Shared
  int _previousTab = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);

    final lostItems = repo.items.where((i) => i.type == ItemType.lost).toList();
    final foundItems =
        repo.items.where((i) => i.type == ItemType.found).toList();
    final sharedItems =
        repo.items.where((i) => i.type == ItemType.shared).toList();

    final currentList = switch (_selectedTab) {
      1 => foundItems,
      2 => sharedItems,
      _ => lostItems,
    };

    final openReports =
        lostItems.where((i) => i.status == ItemStatus.open).length +
        foundItems.where((i) => i.status == ItemStatus.unclaimed).length;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 26, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.together,
            leftTitle: '$openReports Open Reports',
            leftSubtitle: '${lostItems.length} Lost • ${foundItems.length} Found',
            rightTitle: '${sharedItems.length} Shared Items',
            rightSubtitle: 'Live household tracker',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaSegmentedTrack<int>(
            selectedValue: _selectedTab,
            onSelected: (next) => setState(() {
              _previousTab = _selectedTab;
              _selectedTab = next;
            }),
            segments: const [
              CasamaFilterOption(value: 0, label: 'Lost'),
              CasamaFilterOption(value: 1, label: 'Found'),
              CasamaFilterOption(value: 2, label: 'Shared'),
            ],
          ),

          CasamaDirectionalSwitcher(
            index: _selectedTab,
            previousIndex: _previousTab,
            child: currentList.isEmpty
                ? Padding(
                    key: ValueKey('items_empty_$_selectedTab'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                      vertical: CasamaSpacing.xl,
                    ),
                    child: CasamaCard(
                      padding: const EdgeInsets.all(CasamaSpacing.xl),
                      child: Column(
                        children: [
                          const CasMascotView(
                            pose: CasPose.together,
                            width: 112,
                            height: 112,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedTab == 0
                                ? 'No lost items reported'
                                : (_selectedTab == 1
                                      ? 'No found items waiting'
                                      : 'No shared items listed'),
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: pal.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap "Report item" whenever something goes missing or needs sharing.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    key: ValueKey('items_list_$_selectedTab'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < currentList.length; i++) ...[
                          if (i > 0) const SizedBox(height: 12),
                          _ItemCard(
                            item: currentList[i],
                            onOpenDetail: () => _showItemDetailsSheet(
                              context,
                              currentList[i],
                              repo,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showItemDetailsSheet(
    BuildContext context,
    LostFoundItem item,
    CasamaRepository repo,
  ) {
    showCasamaSheet<void>(
      context,
      icon: Icons.sell_outlined,
      title: item.title,
      subtitle: 'Reported by ${item.reportedByName}',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: CasamaSpacing.roundedLg,
              child: Container(
                height: 180,
                width: double.infinity,
                color: pal.track,
                child: _buildItemImage(item.imageUrl, pal.textMuted, iconSize: 48),
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),
            Text(
              item.description?.isNotEmpty == true
                  ? item.description!
                  : 'No additional details provided.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: pal.textPrimary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: CasamaSpacing.lg),

            if (item.type == ItemType.found &&
                item.status == ItemStatus.unclaimed) ...[
              CasamaButton(
                label: "That's Mine (Claim)",
                icon: Icons.check_circle_outline_rounded,
                onPressed: () {
                  repo.claimItem(item.id);
                  Navigator.of(ctx).pop();
                  showCasamaToast(
                    context,
                    'Item marked as claimed',
                    icon: Icons.check_circle_outline_rounded,
                  );
                },
              ),
              const SizedBox(height: 10),
            ] else if (item.type == ItemType.shared) ...[
              if (item.status == ItemStatus.open)
                CasamaButton(
                  label: 'Borrow Item',
                  icon: Icons.handshake_outlined,
                  onPressed: () {
                    repo.borrowItem(item.id);
                    Navigator.of(ctx).pop();
                    showCasamaToast(
                      context,
                      'Item marked as borrowed',
                      icon: Icons.handshake_outlined,
                    );
                  },
                )
              else if (item.status == ItemStatus.claimed)
                CasamaButton(
                  label: 'Return Item',
                  icon: Icons.assignment_return_outlined,
                  onPressed: () {
                    repo.returnItem(item.id);
                    Navigator.of(ctx).pop();
                    showCasamaToast(
                      context,
                      'Item returned — thank you',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  },
                ),
              const SizedBox(height: 10),
            ] else if (item.type == ItemType.lost &&
                item.status == ItemStatus.open) ...[
              CasamaButton(
                label: 'I Found It',
                icon: Icons.check_rounded,
                onPressed: () {
                  repo.claimItem(item.id);
                  Navigator.of(ctx).pop();
                  showCasamaToast(
                    context,
                    'Marked as found',
                    icon: Icons.check_circle_outline_rounded,
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            CasamaButton(
              label: 'Message ${item.reportedByName}',
              icon: Icons.chat_bubble_outline_rounded,
              style: CasamaButtonStyle.secondary,
              height: 48,
              onPressed: () {
                Navigator.of(ctx).pop();
                if (GoRouter.maybeOf(context) != null) {
                  context.push(
                    '/direct-chat?contact=${item.reportedByName.toLowerCase()}&name=${Uri.encodeComponent(item.reportedByName)}',
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

class _ItemCard extends ConsumerWidget {
  final LostFoundItem item;
  final VoidCallback onOpenDetail;

  const _ItemCard({required this.item, required this.onOpenDetail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.read(repositoryProvider);

    final (ChipVariant variant, String statusLabel) = switch (item.status) {
      ItemStatus.open => (
        ChipVariant.open,
        item.type == ItemType.shared ? 'Available' : 'Open',
      ),
      ItemStatus.unclaimed => (ChipVariant.unclaimed, 'Unclaimed'),
      ItemStatus.claimed => (
        ChipVariant.medium,
        item.type == ItemType.shared ? 'In Use' : 'Claimed',
      ),
      ItemStatus.returned => (ChipVariant.returned, 'Returned'),
    };

    final hoursAgo = DateTime.now().difference(item.createdAt).inHours;

    return CasamaCard(
      padding: const EdgeInsets.all(14),
      onTap: onOpenDetail,
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: CasamaSpacing.roundedMd,
                child: Container(
                  width: 64,
                  height: 64,
                  color: pal.track,
                  child: _buildItemImage(item.imageUrl, pal.textMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.description ?? 'No details provided',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hoursAgo}h ago • by ${item.reportedByName}',
                      style: theme.textTheme.labelSmall?.tabular.copyWith(
                        color: pal.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(label: statusLabel, variant: variant),
            ],
          ),
          if ((item.type == ItemType.found &&
                  item.status == ItemStatus.unclaimed) ||
              (item.type == ItemType.lost && item.status == ItemStatus.open) ||
              item.type == ItemType.shared) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: pal.border),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (item.type == ItemType.found &&
                    item.status == ItemStatus.unclaimed)
                  _QuickActionButton(
                    label: "That's Mine",
                    color: pal.primaryCoral,
                    onTap: () {
                      repo.claimItem(item.id);
                      showCasamaToast(
                        context,
                        'Claimed ${item.title}',
                        icon: Icons.check_circle_outline_rounded,
                      );
                    },
                  )
                else if (item.type == ItemType.lost &&
                    item.status == ItemStatus.open)
                  _QuickActionButton(
                    label: 'I Found It',
                    color: pal.forestTeal,
                    onTap: () {
                      repo.claimItem(item.id);
                      showCasamaToast(
                        context,
                        'Marked ${item.title} found',
                        icon: Icons.check_circle_outline_rounded,
                      );
                    },
                  )
                else if (item.type == ItemType.shared &&
                    item.status == ItemStatus.open)
                  _QuickActionButton(
                    label: 'Borrow',
                    color: pal.forestTeal,
                    onTap: () {
                      repo.borrowItem(item.id);
                      showCasamaToast(
                        context,
                        'Borrowed ${item.title}',
                        icon: Icons.handshake_outlined,
                      );
                    },
                  )
                else if (item.type == ItemType.shared &&
                    item.status == ItemStatus.claimed)
                  _QuickActionButton(
                    label: 'Return',
                    color: pal.primaryCoral,
                    onTap: () {
                      repo.returnItem(item.id);
                      showCasamaToast(
                        context,
                        'Returned ${item.title}',
                        icon: Icons.assignment_return_outlined,
                      );
                    },
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        enableHaptic: true,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: CasamaSpacing.roundedPill,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildItemImage(String? imageUrl, Color fallbackColor, {double iconSize = 28}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return Center(
      child: Icon(Icons.image_outlined, color: fallbackColor, size: iconSize),
    );
  }
  if (imageUrl.startsWith('data:image')) {
    return Image.memory(
      base64Decode(imageUrl.split(',').last),
      fit: BoxFit.cover,
    );
  }
  return Image.network(
    imageUrl,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Center(
      child: Icon(Icons.image_outlined, color: fallbackColor, size: iconSize),
    ),
  );
}
