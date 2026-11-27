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
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_lost_found_icon.dart';
import '../../shared/widgets/casama_no_household_card.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/report_item_sheet.dart';
import 'widgets/submit_found_match_sheet.dart';

enum _ItemSubTab { myActivity, lost, found, resolved }

enum _MyActivityFilter { all, myLost, myFound, interactions }

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
        if (mounted && ref.read(repositoryProvider).hasActiveHousehold) {
          showReportItemSheet(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      floatingActionButton: repo.hasActiveHousehold
          ? FloatingActionButton.extended(
              onPressed: () => showReportItemSheet(context),
              backgroundColor: pal.coralFab,
              foregroundColor: Colors.white,
              icon: const CasamaLostFoundIcon(size: 20, color: Colors.white),
              label: const Text(
                'Report item',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Lost & Found',
              subtitle: repo.hasActiveHousehold
                  ? '${repo.currentHousehold.name} • Missing & found items'
                  : 'No household yet • Missing & found items',
              titleMascotPose: CasPose.lostFound,
              extendedWave: true,
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                if (repo.hasActiveHousehold)
                  CasamaHeaderActionPill(
                    iconWidget: const CasamaLostFoundIcon(size: 16),
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
  int _previousTabIndex = _ItemSubTab.lost.index;
  _MyActivityFilter _activityFilter = _MyActivityFilter.all;
  String? _expandedItemId;

  Future<void> _handleAcceptFind(LostFoundItem submission) async {
    final repo = ref.read(repositoryProvider);
    final err = await repo.acceptLostItemFind(submission.id);
    if (!mounted) return;
    final finder = repo.resolveHousemateName(
      submission.reportedBy,
      fallback: submission.reportedByName,
    );
    showCasamaToast(
      context,
      err ?? 'Confirmed! $finder earned +5 pts.',
      icon: err != null
          ? Icons.info_outline_rounded
          : Icons.verified_rounded,
    );
  }

  Future<void> _handleRejectFind(LostFoundItem submission) async {
    final repo = ref.read(repositoryProvider);
    final err = await repo.rejectLostItemFind(submission.id);
    if (!mounted) return;
    final finder = repo.resolveHousemateName(
      submission.reportedBy,
      fallback: submission.reportedByName,
    );
    showCasamaToast(
      context,
      err ?? 'Marked find from $finder as not a match.',
      icon: Icons.info_outline_rounded,
    );
  }

  Future<void> _handleResolveOwnLost(LostFoundItem lostItem) async {
    final err = await ref
        .read(repositoryProvider)
        .resolveOwnLostItem(lostItem.id);
    if (!mounted) return;
    if (_expandedItemId == lostItem.id && err == null) {
      setState(() => _expandedItemId = null);
    }
    showCasamaToast(
      context,
      err ?? 'Marked "${lostItem.title}" as resolved.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  Future<void> _handleClaimStandaloneFound(LostFoundItem foundItem) async {
    final repo = ref.read(repositoryProvider);
    final err = await repo.claimStandaloneFoundItem(foundItem.id);
    if (!mounted) return;
    if (_expandedItemId == foundItem.id && err == null) {
      setState(() => _expandedItemId = null);
    }
    final finder = repo.resolveHousemateName(
      foundItem.reportedBy,
      fallback: foundItem.reportedByName,
    );
    showCasamaToast(
      context,
      err ?? 'Claimed "${foundItem.title}"! $finder earned +2 pts.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    if (!repo.hasActiveHousehold) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          CasamaSpacing.md,
          CasamaSpacing.md,
          CasamaSpacing.md,
          widget.bottomPadding,
        ),
        child: const CasamaNoHouseholdPrompt(
          title: 'Join a household',
          subtitle:
              'Post missing or found items and reunite belongings with housemates once you join or create a household.',
          mascotPose: CasPose.together,
        ),
      );
    }
    final currentUserId = repo.currentUser.id;
    final items = repo.items;

    final allLost = items.where((i) => i.type == ItemType.lost).toList();
    final allLinkedFinds = items
        .where((i) => i.type == ItemType.found && i.isLinkedToLost)
        .toList();
    final standaloneFound = items
        .where((i) => i.type == ItemType.found && i.isStandalone)
        .toList();

    final Map<String, List<LostFoundItem>> findsByLostId = {};
    for (final find in allLinkedFinds) {
      final lid = find.lostItemId!;
      findsByLostId.putIfAbsent(lid, () => []).add(find);
    }
    for (final list in findsByLostId.values) {
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    final openLost = allLost.where((i) => i.status == ItemStatus.open).toList()
      ..sort((a, b) {
        final aPending = (findsByLostId[a.id] ?? const [])
            .any((f) => f.status == ItemStatus.pending);
        final bPending = (findsByLostId[b.id] ?? const [])
            .any((f) => f.status == ItemStatus.pending);
        if (aPending != bPending) return aPending ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    final unclaimedFound = standaloneFound
        .where((i) => i.status == ItemStatus.unclaimed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // My Activity sets
    final myLost = allLost
        .where((i) => i.reportedBy == currentUserId)
        .toList();
    final myFound = standaloneFound
        .where((i) => i.reportedBy == currentUserId)
        .toList();
    final myLostInteractions = allLost.where((lost) {
      if (lost.reportedBy == currentUserId) return false;
      final finds = findsByLostId[lost.id] ?? const [];
      return finds.any((f) => f.reportedBy == currentUserId);
    }).toList();
    final myFoundClaims = standaloneFound
        .where(
          (f) => f.reportedBy != currentUserId && f.claimedById == currentUserId,
        )
        .toList();
    final interactionItems = <LostFoundItem>[
      ...myLostInteractions,
      ...myFoundClaims,
    ];

    final List<LostFoundItem> myActivityDisplayed = switch (_activityFilter) {
      _MyActivityFilter.all => {
        for (final item in [...myLost, ...myFound, ...interactionItems])
          item.id: item,
      }.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      _MyActivityFilter.myLost => myLost
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      _MyActivityFilter.myFound => myFound
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      _MyActivityFilter.interactions => interactionItems
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    };

    final List<LostFoundItem> resolvedItems = [
      ...allLost.where((i) => i.status == ItemStatus.resolved),
      ...standaloneFound.where((i) => i.status == ItemStatus.resolved),
    ]..sort((a, b) {
        final aDate = a.returnedAt ?? a.claimedAt ?? a.createdAt;
        final bDate = b.returnedAt ?? b.claimedAt ?? b.createdAt;
        return bDate.compareTo(aDate);
      });

    final List<LostFoundItem> displayed = switch (_selectedTab) {
      _ItemSubTab.lost => openLost,
      _ItemSubTab.found => unclaimedFound,
      _ItemSubTab.myActivity => myActivityDisplayed,
      _ItemSubTab.resolved => resolvedItems,
    };

    final (String emptyTitle, String emptySubtitle) = switch (_selectedTab) {
      _ItemSubTab.lost => (
        'No missing items reported',
        'Tap "Report item" below to post to the household board.',
      ),
      _ItemSubTab.found => (
        'No found items waiting',
        'Standalone found items waiting to be claimed will appear here.',
      ),
      _ItemSubTab.resolved => (
        'No resolved items yet',
        'Completed Lost & Found recoveries across the household will appear here.',
      ),
      _ItemSubTab.myActivity => switch (_activityFilter) {
        _MyActivityFilter.all => (
          'No activity yet',
          'Lost posts, found reports, and your find interactions appear here.',
        ),
        _MyActivityFilter.myLost => (
          'No lost reports from you',
          'Missing items you post will appear here with claim history.',
        ),
        _MyActivityFilter.myFound => (
          'No found posts from you',
          'Found items you report for housemates appear here.',
        ),
        _MyActivityFilter.interactions => (
          'No housemate interactions yet',
          'Lost items you helped find or found items you claimed appear here.',
        ),
      },
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.lostFound,
            leftTitle: '${openLost.length} Lost',
            leftSubtitle: 'Open missing reports',
            rightTitle: '${unclaimedFound.length} Found',
            rightSubtitle: 'Waiting to be claimed',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaSegmentedTrack<int>(
            selectedValue: _selectedTab.index,
            onSelected: (idx) {
              setState(() {
                _previousTabIndex = _selectedTab.index;
                _selectedTab = _ItemSubTab.values[idx];
                _expandedItemId = null;
              });
            },
            segments: const [
              CasamaFilterOption(value: 0, label: 'My Activity'),
              CasamaFilterOption(value: 1, label: 'Lost'),
              CasamaFilterOption(value: 2, label: 'Found'),
              CasamaFilterOption(value: 3, label: 'Resolved'),
            ],
          ),

          CasamaDirectionalSwitcher(
            index: _selectedTab.index,
            previousIndex: _previousTabIndex,
            child: Column(
              key: ValueKey('items_tab_${_selectedTab.index}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedTab == _ItemSubTab.myActivity) ...[
                  _MyActivityFilterPillBar(
                    selected: _activityFilter,
                    onSelected: (next) => setState(() {
                      _activityFilter = next;
                      _expandedItemId = null;
                    }),
                  ),
                  const SizedBox(height: CasamaSpacing.xs),
                ] else
                  const SizedBox(height: CasamaSpacing.xs),

                if (displayed.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: CasamaCard(
                      padding: const EdgeInsets.all(CasamaSpacing.xl),
                      child: Column(
                        children: [
                          CasMascotView(
                            pose: CasPose.lostFoundEmpty,
                            height: 88,
                            semanticLabel: 'Lost and Found Mascot',
                          ),
                          const SizedBox(height: CasamaSpacing.sm),
                          Text(
                            emptyTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emptySubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (final item in displayed) ...[
                          _ExpandableItemCard(
                            item: item,
                            tab: _selectedTab,
                            currentUserId: currentUserId,
                            linkedFinds:
                                findsByLostId[item.id] ?? const <LostFoundItem>[],
                            isExpanded: _expandedItemId == item.id,
                            onToggleExpand: () {
                              setState(() {
                                _expandedItemId = _expandedItemId == item.id
                                    ? null
                                    : item.id;
                              });
                            },
                            onReportFoundMatch: () => showSubmitFoundMatchSheet(
                              context,
                              lostItem: item,
                            ),
                            onResolveOwnLost: () => _handleResolveOwnLost(item),
                            onAcceptFind: _handleAcceptFind,
                            onRejectFind: _handleRejectFind,
                            onClaimStandaloneFound: () =>
                                _handleClaimStandaloneFound(item),
                          ),
                          const SizedBox(height: CasamaSpacing.xs),
                        ],
                      ],
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

class _MyActivityFilterPillBar extends StatelessWidget {
  final _MyActivityFilter selected;
  final ValueChanged<_MyActivityFilter> onSelected;

  const _MyActivityFilterPillBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final reduced = CasamaMotion.reduceMotion(context);
    const options = [
      (_MyActivityFilter.all, 'All'),
      (_MyActivityFilter.myLost, 'My Lost'),
      (_MyActivityFilter.myFound, 'My Found'),
      (_MyActivityFilter.interactions, 'Interactions'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _ActivityFilterPill(
              label: options[i].$2,
              isSelected: selected == options[i].$1,
              onTap: () => onSelected(options[i].$1),
              pal: pal,
              theme: theme,
              reduced: reduced,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final CasamaPalette pal;
  final ThemeData theme;
  final bool reduced;

  const _ActivityFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.pal,
    required this.theme,
    required this.reduced,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          height: CasamaSpacing.minTouchTarget,
          alignment: Alignment.center,
          child: AnimatedContainer(
            duration: reduced ? Duration.zero : CasamaMotion.press,
            curve: CasamaMotion.easeOut,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? pal.headerDeep : pal.surface,
              borderRadius: CasamaSpacing.roundedPill,
              border: Border.all(
                color: isSelected ? pal.headerDeep : pal.border,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : pal.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableItemCard extends ConsumerWidget {
  final LostFoundItem item;
  final _ItemSubTab tab;
  final String currentUserId;
  final List<LostFoundItem> linkedFinds;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onReportFoundMatch;
  final VoidCallback onResolveOwnLost;
  final ValueChanged<LostFoundItem> onAcceptFind;
  final ValueChanged<LostFoundItem> onRejectFind;
  final VoidCallback onClaimStandaloneFound;

  const _ExpandableItemCard({
    required this.item,
    required this.tab,
    required this.currentUserId,
    required this.linkedFinds,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onReportFoundMatch,
    required this.onResolveOwnLost,
    required this.onAcceptFind,
    required this.onRejectFind,
    required this.onClaimStandaloneFound,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final reporterName = repo.resolveHousemateName(
      item.reportedBy,
      fallback: item.reportedByName,
    );
    final finderName = repo.resolveHousemateName(
      item.foundById,
      fallback: item.foundByName ?? 'Housemate',
    );
    final claimerName = repo.resolveHousemateName(
      item.claimedById,
      fallback: item.claimedByName ?? 'Housemate',
    );
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final isLost = item.type == ItemType.lost;
    final isResolvedTab = tab == _ItemSubTab.resolved;
    final isOwnerOrFinder = item.reportedBy == currentUserId;
    final isResolved = item.isResolved;
    final pendingFinds = linkedFinds
        .where((f) => f.status == ItemStatus.pending)
        .toList();
    final hasPhoto = item.imageUrl != null && item.imageUrl!.trim().isNotEmpty;

    final locSuffix =
        item.location != null && item.location!.trim().isNotEmpty
        ? ' • ${item.location!.trim()}'
        : '';
    final shortDate = DateFormat('MMM d').format(item.createdAt);
    final resolvedShortDate = DateFormat(
      'MMM d',
    ).format(item.returnedAt ?? item.claimedAt ?? item.createdAt);
    final metaLine = isResolvedTab
        ? (isLost
              ? 'Lost by $reporterName • Resolved $resolvedShortDate'
              : 'Found by $reporterName • Resolved $resolvedShortDate')
        : 'By $reporterName$locSuffix • $shortDate';

    final (String pillLabel, ChipVariant pillVariant, Color? customBg, Color? customFg) =
        _statusPill(pal, isLost, pendingFinds.length, isResolvedTab: isResolvedTab);

    return CasamaCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderSide: isExpanded
          ? BorderSide(
              color: pal.forestTeal.withValues(alpha: 0.45),
              width: 1.4,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (hasPhoto)
                Semantics(
                  button: true,
                  label: 'View ${item.title} photo',
                  child: CasamaPressable(
                    onTap: () => _showItemPhotoLightbox(
                      context,
                      item.imageUrl!,
                      item.title,
                    ),
                    enableHaptic: false,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: _buildItemImage(item.imageUrl!, pal),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isLost ? pal.dangerBg : pal.softSage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: CasamaLostFoundIcon(
                    size: 24,
                    color: isLost ? pal.dangerFg : pal.forestTeal,
                  ),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  expanded: isExpanded,
                  label: '${item.title}, $metaLine',
                  child: CasamaPressable(
                    onTap: onToggleExpand,
                    enableHaptic: false,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: CasamaSpacing.minTouchTarget,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isResolved && !isResolvedTab
                                        ? pal.textMuted
                                        : pal.textPrimary,
                                    decoration: isResolved && !isResolvedTab
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  metaLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusChip(
                            label: pillLabel,
                            variant: pillVariant,
                            customBgColor: customBg,
                            customTextColor: customFg,
                          ),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: animDuration,
                            curve: CasamaMotion.easeOut,
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 22,
                              color: isExpanded
                                  ? pal.forestTeal
                                  : pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (reduceMotion) ...[
            if (isExpanded)
              isResolvedTab
                  ? _buildResolvedExpandedBody(
                      context,
                      pal,
                      theme,
                      isLost: isLost,
                      hasPhoto: hasPhoto,
                      reporterName: reporterName,
                      claimerName: claimerName,
                    )
                  : _buildExpandedBody(
                      context,
                      pal,
                      theme,
                      isLost: isLost,
                      isOwnerOrFinder: isOwnerOrFinder,
                      hasPhoto: hasPhoto,
                      finderName: finderName,
                      claimerName: claimerName,
                    ),
          ] else
            AnimatedSize(
              duration: animDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedOpacity(
                duration: animDuration,
                opacity: isExpanded ? 1.0 : 0.0,
                child: isExpanded
                    ? (isResolvedTab
                          ? _buildResolvedExpandedBody(
                              context,
                              pal,
                              theme,
                              isLost: isLost,
                              hasPhoto: hasPhoto,
                              reporterName: reporterName,
                              claimerName: claimerName,
                            )
                          : _buildExpandedBody(
                              context,
                              pal,
                              theme,
                              isLost: isLost,
                              isOwnerOrFinder: isOwnerOrFinder,
                              hasPhoto: hasPhoto,
                              finderName: finderName,
                              claimerName: claimerName,
                            ))
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  (String, ChipVariant, Color?, Color?) _statusPill(
    CasamaPalette pal,
    bool isLost,
    int pendingCount, {
    bool isResolvedTab = false,
  }) {
    if (isResolvedTab) {
      return ('Resolved', ChipVariant.paid, null, null);
    }
    if (isLost) {
      if (item.isResolved) {
        return ('Resolved', ChipVariant.paid, null, null);
      }
      if (pendingCount > 0) {
        return (
          '$pendingCount Pending',
          ChipVariant.custom,
          pal.warningBg,
          pal.warningFg,
        );
      }
      return ('Open', ChipVariant.urgent, null, null);
    }

    if (item.isResolved) {
      return ('Claimed', ChipVariant.paid, null, null);
    }
    return ('Unclaimed', ChipVariant.low, null, null);
  }

  Widget _buildExpandedBody(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme, {
    required bool isLost,
    required bool isOwnerOrFinder,
    required bool hasPhoto,
    required String finderName,
    required String claimerName,
  }) {
    final desc = item.description?.trim() ?? '';
    final loc = item.location?.trim() ?? '';
    final isInteractionLost =
        tab == _ItemSubTab.myActivity && isLost && !isOwnerOrFinder;

    final visibleTimeline = isInteractionLost
        ? linkedFinds.where((f) => f.reportedBy == currentUserId).toList()
        : linkedFinds;

    final viewerHasPending = linkedFinds.any(
      (f) => f.reportedBy == currentUserId && f.status == ItemStatus.pending,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),

          if (desc.isNotEmpty) ...[
            Text(
              desc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (loc.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: pal.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isLost ? 'Last seen: $loc' : 'Found at: $loc',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (hasPhoto) ...[
            Semantics(
              button: true,
              label: 'Enlarge ${item.title} photo',
              child: CasamaPressable(
                onTap: () => _showItemPhotoLightbox(
                  context,
                  item.imageUrl!,
                  item.title,
                ),
                child: ClipRRect(
                  borderRadius: CasamaSpacing.roundedMd,
                  child: SizedBox(
                    height: 136,
                    width: double.infinity,
                    child: _buildItemImage(item.imageUrl!, pal),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Contextual actions
          if (isLost) ...[
            if (!item.isResolved && !isOwnerOrFinder) ...[
              if (viewerHasPending)
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(
                    label: 'Awaiting owner review',
                    icon: Icons.schedule_rounded,
                    variant: ChipVariant.medium,
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionPillButton(
                    label: 'I Found It',
                    icon: Icons.check_circle_outline_rounded,
                    bg: pal.forestTeal,
                    fg: pal.onForestTeal,
                    onTap: onReportFoundMatch,
                  ),
                ),
            ] else if (!item.isResolved && isOwnerOrFinder) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: _ActionPillButton(
                  label: 'Found It Myself',
                  icon: Icons.done_all_rounded,
                  bg: pal.track,
                  fg: pal.textPrimary,
                  borderColor: pal.border,
                  onTap: onResolveOwnLost,
                ),
              ),
            ] else if (item.isResolved) ...[
              _ResolutionCallout(
                pal: pal,
                theme: theme,
                text: item.foundByName != null &&
                        item.foundByName!.trim().isNotEmpty
                    ? isInteractionLost && item.foundById != currentUserId
                          ? 'Resolved by $finderName'
                          : 'Returned by $finderName • +5 pts awarded'
                    : 'Resolved by owner (0 pts)',
              ),
            ],
          ] else ...[
            // Standalone Found Item
            if (!item.isResolved && !isOwnerOrFinder)
              Align(
                alignment: Alignment.centerLeft,
                child: _ActionPillButton(
                  label: "That's Mine",
                  icon: Icons.pan_tool_alt_outlined,
                  bg: pal.forestTeal,
                  fg: pal.onForestTeal,
                  onTap: onClaimStandaloneFound,
                ),
              )
            else if (!item.isResolved && isOwnerOrFinder)
              Text(
                'Posted by you • Waiting for a housemate to claim',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (item.isResolved)
              _ResolutionCallout(
                pal: pal,
                theme: theme,
                text: item.claimedById == currentUserId
                    ? 'You claimed this item • ${_formatShortDateTime(item.claimedAt ?? item.returnedAt ?? item.createdAt)}'
                    : 'Claimed by $claimerName • ${_formatShortDateTime(item.claimedAt ?? item.returnedAt ?? item.createdAt)} • +2 pts earned',
              ),
          ],

          // Chronological linked-find history timeline
          if (isLost && visibleTimeline.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              isInteractionLost ? 'Your Submissions' : 'Find Submissions History',
              style: theme.textTheme.labelSmall?.copyWith(
                color: pal.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < visibleTimeline.length; i++)
              _TimelineEntryRow(
                submission: visibleTimeline[i],
                canReview:
                    isOwnerOrFinder &&
                    !item.isResolved &&
                    visibleTimeline[i].status == ItemStatus.pending,
                isLast: i == visibleTimeline.length - 1,
                onAccept: () => onAcceptFind(visibleTimeline[i]),
                onReject: () => onRejectFind(visibleTimeline[i]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildResolvedExpandedBody(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme, {
    required bool isLost,
    required bool hasPhoto,
    required String reporterName,
    required String claimerName,
  }) {
    final desc = item.description?.trim() ?? '';
    final loc = item.location?.trim() ?? '';
    final isSelfResolved =
        isLost && item.resolvedFoundItemId == null && item.foundById == null;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),
          if (desc.isNotEmpty) ...[
            Text(
              desc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (loc.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 14,
                  color: pal.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    isLost ? 'Last seen: $loc' : 'Found at: $loc',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Posted ${_formatShortDateTime(item.createdAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: pal.textMuted,
              fontSize: 11.5,
            ),
          ),
          if (hasPhoto) ...[
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'Enlarge ${item.title} photo',
              child: CasamaPressable(
                onTap: () => _showItemPhotoLightbox(
                  context,
                  item.imageUrl!,
                  item.title,
                ),
                child: ClipRRect(
                  borderRadius: CasamaSpacing.roundedMd,
                  child: SizedBox(
                    height: 136,
                    width: double.infinity,
                    child: _buildItemImage(item.imageUrl!, pal),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),
          Text(
            'Resolution History',
            style: theme.textTheme.labelSmall?.copyWith(
              color: pal.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          if (isLost) ...[
            _ResolutionMilestoneRow(
              title:
                  '$reporterName reported item lost • ${_formatShortDateTime(item.createdAt)}',
              dotColor: pal.forestTeal,
              isLast: linkedFinds.isEmpty && !isSelfResolved,
            ),
            for (var i = 0; i < linkedFinds.length; i++)
              _TimelineEntryRow(
                submission: linkedFinds[i],
                canReview: false,
                isLast: !isSelfResolved && i == linkedFinds.length - 1,
                confirmedByLabel:
                    (linkedFinds[i].id == item.resolvedFoundItemId ||
                            linkedFinds[i].status == ItemStatus.resolved)
                        ? 'Confirmed by $reporterName • ${_formatShortDateTime(item.returnedAt ?? linkedFinds[i].returnedAt ?? linkedFinds[i].createdAt)}'
                        : null,
                onAccept: () {},
                onReject: () {},
              ),
            if (isSelfResolved)
              _ResolutionMilestoneRow(
                title:
                    '$reporterName found it themselves • ${_formatShortDateTime(item.returnedAt ?? item.createdAt)}',
                badgeText: 'Self-resolved • 0 pts',
                badgeBg: pal.neutralBg,
                badgeFg: pal.neutralFg,
                dotColor: pal.textMuted,
                isLast: true,
              ),
          ] else ...[
            _ResolutionMilestoneRow(
              title:
                  '$reporterName posted found item • ${_formatShortDateTime(item.createdAt)}',
              subtitle: loc.isNotEmpty ? 'Found at: $loc' : null,
              dotColor: pal.forestTeal,
              isLast: false,
            ),
            _ResolutionMilestoneRow(
              title:
                  'Claimed by $claimerName ("That\'s Mine") • ${_formatShortDateTime(item.claimedAt ?? item.returnedAt ?? item.createdAt)}',
              badgeText: '+2 pts to $reporterName',
              badgeBg: pal.successBg,
              badgeFg: pal.successFg,
              dotColor: pal.successFg,
              isLast: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolutionCallout extends StatelessWidget {
  final CasamaPalette pal;
  final ThemeData theme;
  final String text;

  const _ResolutionCallout({
    required this.pal,
    required this.theme,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: pal.successBg,
        borderRadius: CasamaSpacing.roundedMd,
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, size: 16, color: pal.successFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: pal.successFg,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionMilestoneRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? badgeText;
  final Color? badgeBg;
  final Color? badgeFg;
  final Color dotColor;
  final bool isLast;

  const _ResolutionMilestoneRow({
    required this.title,
    this.subtitle,
    this.badgeText,
    this.badgeBg,
    this.badgeFg,
    required this.dotColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: badgeText != null || subtitle != null ? 44 : 28,
                  margin: const EdgeInsets.only(top: 4),
                  color: pal.divider,
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.track,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(color: pal.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (badgeText != null) ...[
                    const SizedBox(height: 6),
                    StatusChip(
                      label: badgeText!,
                      variant: ChipVariant.custom,
                      customBgColor: badgeBg ?? pal.neutralBg,
                      customTextColor: badgeFg ?? pal.neutralFg,
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
}

class _TimelineEntryRow extends ConsumerWidget {
  final LostFoundItem submission;
  final bool canReview;
  final bool isLast;
  final String? confirmedByLabel;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _TimelineEntryRow({
    required this.submission,
    required this.canReview,
    required this.isLast,
    this.confirmedByLabel,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final subReporterName = repo.resolveHousemateName(
      submission.reportedBy,
      fallback: submission.reportedByName,
    );
    final hasThumb =
        submission.imageUrl != null && submission.imageUrl!.trim().isNotEmpty;

    final (String badgeText, Color badgeBg, Color badgeFg, Color dotColor) =
        switch (submission.status) {
          ItemStatus.pending => (
            'Pending Review',
            pal.warningBg,
            pal.warningFg,
            pal.amberFg,
          ),
          ItemStatus.rejected => (
            'Rejected by Poster',
            pal.dangerBg,
            pal.dangerFg,
            pal.dangerFg,
          ),
          ItemStatus.resolved => (
            'Accepted • +5 pts',
            pal.successBg,
            pal.successFg,
            pal.successFg,
          ),
          _ => (
            'Submitted',
            pal.track,
            pal.textSecondary,
            pal.textMuted,
          ),
        };

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: canReview ? 86 : 44,
                  margin: const EdgeInsets.only(top: 4),
                  color: pal.divider,
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.track,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(color: pal.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$subReporterName • ${_formatShortDateTime(submission.createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusChip(
                        label: badgeText,
                        variant: ChipVariant.custom,
                        customBgColor: badgeBg,
                        customTextColor: badgeFg,
                      ),
                    ],
                  ),
                  if (submission.location != null &&
                      submission.location!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Location: ${submission.location!.trim()}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (submission.description != null &&
                      submission.description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      submission.description!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (submission.status == ItemStatus.rejected &&
                      submission.rejectedAt != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Rejected ${_formatShortDateTime(submission.rejectedAt!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pal.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (confirmedByLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      confirmedByLabel!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: pal.successFg,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  if (hasThumb) ...[
                    const SizedBox(height: 6),
                    CasamaPressable(
                      onTap: () => _showItemPhotoLightbox(
                        context,
                        submission.imageUrl!,
                        '$subReporterName find photo',
                      ),
                      child: ClipRRect(
                        borderRadius: CasamaSpacing.roundedSm,
                        child: SizedBox(
                          width: 64,
                          height: 48,
                          child: _buildItemImage(submission.imageUrl!, pal),
                        ),
                      ),
                    ),
                  ],
                  if (canReview) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionPillButton(
                            label: 'Confirm (+5 pts)',
                            icon: Icons.verified_outlined,
                            bg: pal.forestTeal,
                            fg: pal.onForestTeal,
                            height: 44,
                            onTap: onAccept,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ActionPillButton(
                          label: 'Reject',
                          icon: Icons.close_rounded,
                          bg: pal.dangerBg,
                          fg: pal.dangerFg,
                          borderColor: pal.dangerFg.withValues(alpha: 0.25),
                          height: 44,
                          onTap: onReject,
                        ),
                      ],
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
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final double height;
  final VoidCallback onTap;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    this.borderColor,
    this.height = 44,
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
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CasamaSpacing.roundedPill,
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatShortDateTime(DateTime dt) =>
    DateFormat('MMM d, h:mm a').format(dt.toLocal());

void _showItemPhotoLightbox(
  BuildContext context,
  String imageUrl,
  String label,
) {
  final reduced = CasamaMotion.reduceMotion(context);
  final pal = context.palette;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close $label preview',
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: reduced ? Duration.zero : CasamaMotion.lightbox,
    pageBuilder: (ctx, _, _) {
      return Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: _buildItemImage(imageUrl, pal, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Semantics(
                  button: true,
                  label: 'Close photo preview',
                  child: IconButton(
                    iconSize: 28,
                    constraints: const BoxConstraints(
                      minWidth: CasamaSpacing.minTouchTarget,
                      minHeight: CasamaSpacing.minTouchTarget,
                    ),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      if (reduced) return child;
      return FadeTransition(opacity: anim, child: child);
    },
  );
}

Widget _buildItemImage(
  String imageUrl,
  CasamaPalette pal, {
  BoxFit fit = BoxFit.cover,
}) {
  if (imageUrl.startsWith('data:image')) {
    try {
      final base64Str = imageUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64Str);
      return Image.memory(
        bytes,
        fit: fit,
        errorBuilder: (_, _, _) => _fallbackImage(pal),
      );
    } catch (_) {
      return _fallbackImage(pal);
    }
  }
  return Image.network(
    imageUrl,
    fit: fit,
    errorBuilder: (_, _, _) => _fallbackImage(pal),
  );
}

Widget _fallbackImage(CasamaPalette pal) {
  return Container(
    color: pal.track,
    alignment: Alignment.center,
    child: Icon(Icons.image_outlined, size: 28, color: pal.textMuted),
  );
}
