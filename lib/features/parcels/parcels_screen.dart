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
import '../../shared/widgets/casama_inline_user_badge.dart';
import '../../shared/widgets/casama_no_household_card.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/add_parcel_sheet.dart';
import 'widgets/courier_logo.dart';

class ParcelsScreen extends ConsumerStatefulWidget {
  final bool initialOpenAddModal;

  const ParcelsScreen({super.key, this.initialOpenAddModal = false});

  @override
  ConsumerState<ParcelsScreen> createState() => _ParcelsScreenState();
}

class _ParcelsScreenState extends ConsumerState<ParcelsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialOpenAddModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(repositoryProvider).hasActiveHousehold) {
          showAddParcelSheet(context);
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
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Parcels & Deliveries',
              subtitle: repo.hasActiveHousehold
                  ? '${repo.currentHousehold.name} • Coordinate arrivals & COD'
                  : 'No household yet • Coordinate arrivals & COD',
              titleMascotPose: CasPose.deliveries,
              extendedWave: true,
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                if (repo.hasActiveHousehold)
                  CasamaHeaderActionPill(
                    icon: Icons.add_box_outlined,
                    label: 'Add parcel',
                    onTap: () => showAddParcelSheet(context),
                  ),
              ],
            ),
            const Expanded(
              child: ParcelsBoardView(bottomPadding: 104),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable Parcels board tab body shared by [BoardsScreen] and standalone [ParcelsScreen].
class ParcelsBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const ParcelsBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<ParcelsBoardView> createState() => _ParcelsBoardViewState();
}

class _ParcelsBoardViewState extends ConsumerState<ParcelsBoardView> {
  int _selectedSegment = 1; // 0 = My Parcels, 1 = Today, 2 = Upcoming, 3 = History
  int _previousSegment = 1;
  String? _expandedParcelId;

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
              'Coordinate parcel arrivals and COD handoffs once you join or create a household.',
          mascotPose: CasPose.deliveries,
        ),
      );
    }
    final currentUserId = repo.currentUser.id;
    final nowLocal = DateTime.now().toLocal();
    final startOfTomorrow = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + 1,
    );

    final unsettledParcels = repo.parcels
        .where((p) => p.status != ParcelStatus.cancelled && !p.isSettled)
        .toList();

    final myParcels = unsettledParcels
        .where((p) => p.buyerId == currentUserId)
        .toList()
      ..sort((a, b) {
        if (a.isUnsettledClaim != b.isUnsettledClaim) {
          return a.isUnsettledClaim ? -1 : 1;
        }
        return a.expectedArrival.toLocal().compareTo(b.expectedArrival.toLocal());
      });

    final todayParcels = unsettledParcels
        .where((p) => p.expectedArrival.toLocal().isBefore(startOfTomorrow))
        .toList()
      ..sort((a, b) {
        if (a.isUnsettledClaim != b.isUnsettledClaim) {
          return a.isUnsettledClaim ? -1 : 1;
        }
        final aArrived = a.status == ParcelStatus.arrived && !a.isClaimed;
        final bArrived = b.status == ParcelStatus.arrived && !b.isClaimed;
        if (aArrived != bArrived) {
          return aArrived ? -1 : 1;
        }
        return a.expectedArrival.toLocal().compareTo(b.expectedArrival.toLocal());
      });

    final upcomingParcels = unsettledParcels
        .where((p) => !p.expectedArrival.toLocal().isBefore(startOfTomorrow))
        .toList()
      ..sort((a, b) {
        final aArrived = a.status == ParcelStatus.arrived && !a.isClaimed;
        final bArrived = b.status == ParcelStatus.arrived && !b.isClaimed;
        if (aArrived != bArrived) {
          return aArrived ? -1 : 1;
        }
        return a.expectedArrival.toLocal().compareTo(b.expectedArrival.toLocal());
      });

    final historyParcels = repo.parcels.where((p) => p.isSettled).toList()
      ..sort((a, b) {
        final aTime = (a.settledAt ?? a.claimedAt ?? a.expectedArrival).toLocal();
        final bTime = (b.settledAt ?? b.claimedAt ?? b.expectedArrival).toLocal();
        return bTime.compareTo(aTime);
      });

    final expectedUnclaimed = unsettledParcels.where((p) => !p.isClaimed).toList();
    final arrivingToday = todayParcels.where((p) => !p.isClaimed).length;

    final codTotal = unsettledParcels.fold<double>(
      0,
      (sum, p) =>
          p.paymentType == ParcelPaymentType.cod ? sum + (p.codAmount ?? 0) : sum,
    );

    final currentList = switch (_selectedSegment) {
      0 => myParcels,
      1 => todayParcels,
      2 => upcomingParcels,
      _ => historyParcels,
    };
    final tabMode = switch (_selectedSegment) {
      0 => _ParcelTabMode.myParcels,
      1 => _ParcelTabMode.today,
      2 => _ParcelTabMode.upcoming,
      _ => _ParcelTabMode.history,
    };
    final emptyTitle = switch (_selectedSegment) {
      0 => 'No active parcels of yours',
      1 => 'No deliveries arriving today',
      2 => 'No upcoming deliveries',
      _ => 'No settled parcels yet',
    };
    final emptySubtitle = switch (_selectedSegment) {
      0 => 'Post a parcel you are expecting or settle claimed deliveries here.',
      1 => 'Deliveries scheduled for today or awaiting handoff show up here.',
      2 => 'Add a delivery when expecting a package.',
      _ => 'Completed & settled deliveries appear here.',
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Peeking summary card w/ unframed transparent mascot tucked behind edge
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.deliveries,
            leftTitle: '${expectedUnclaimed.length} Expected',
            leftSubtitle: '$arrivingToday arriving today',
            rightTitle: '₱${NumberFormat('#,##0.00').format(codTotal)} COD',
            rightSubtitle: codTotal > 0 ? 'Cash needed today' : 'All prepaid',
            rightTitleColor: codTotal > 0 ? pal.dangerFg : pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaSegmentedTrack<int>(
            selectedValue: _selectedSegment,
            onSelected: (next) => setState(() {
              _previousSegment = _selectedSegment;
              _selectedSegment = next;
              _expandedParcelId = null;
            }),
            segments: const [
              CasamaFilterOption(value: 0, label: 'My Parcels'),
              CasamaFilterOption(value: 1, label: 'Today'),
              CasamaFilterOption(value: 2, label: 'Upcoming'),
              CasamaFilterOption(value: 3, label: 'History'),
            ],
          ),

          CasamaDirectionalSwitcher(
            index: _selectedSegment,
            previousIndex: _previousSegment,
            child: currentList.isEmpty
                ? Padding(
                    key: ValueKey('parcels_empty_$_selectedSegment'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                      vertical: CasamaSpacing.xl,
                    ),
                    child: CasamaCard(
                      padding: const EdgeInsets.all(CasamaSpacing.xl),
                      child: Column(
                        children: [
                          const CasMascotView(
                            pose: CasPose.deliveriesEmpty,
                            width: 112,
                            height: 112,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            emptyTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: pal.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            emptySubtitle,
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
                    key: ValueKey('parcels_list_$_selectedSegment'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < currentList.length; i++) ...[
                          if (i > 0) const SizedBox(height: CasamaSpacing.xs),
                          _ParcelCard(
                            parcel: currentList[i],
                            tabMode: tabMode,
                            isExpanded: _expandedParcelId == currentList[i].id,
                            onToggleExpand: () {
                              setState(() {
                                final id = currentList[i].id;
                                _expandedParcelId =
                                    _expandedParcelId == id ? null : id;
                              });
                            },
                            onCollapse: () {
                              if (_expandedParcelId == currentList[i].id) {
                                setState(() => _expandedParcelId = null);
                              }
                            },
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

enum _ParcelTabMode { myParcels, today, upcoming, history }

class _ParcelCard extends ConsumerWidget {
  final ParcelItem parcel;
  final _ParcelTabMode tabMode;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onCollapse;

  const _ParcelCard({
    required this.parcel,
    required this.tabMode,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onCollapse,
  });

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final pal = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete parcel?'),
        content: Text(
          'This will permanently remove the ${parcel.courier} parcel posting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('parcel_confirm_delete_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: pal.dangerFg),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(repositoryProvider).deleteParcel(parcel.id);
      onCollapse();
      if (context.mounted) {
        showCasamaToast(
          context,
          'Parcel deleted',
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showCasamaToast(
          context,
          'Could not delete parcel. Please try again.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final isCreator = parcel.buyerId == repo.currentUser.id;
    final buyerName = repo.resolveHousemateName(
      parcel.buyerId,
      fallback: parcel.buyerName,
    );
    final posterLabel = isCreator ? 'You' : buyerName;
    final buyerAvatarUrl = repo.resolveHousemateAvatarUrl(parcel.buyerId);

    final claimerName = repo.resolveHousemateName(
      parcel.claimedById,
      fallback: parcel.claimedByName ?? 'Housemate',
    );
    final claimerLabel = repo.resolveHousemateName(
      parcel.claimedById,
      fallback: parcel.claimedByName ?? 'Housemate',
      useYouForCurrentUser: true,
    );
    final claimerAvatarUrl = repo.resolveHousemateAvatarUrl(parcel.claimedById);

    final nowLocal = DateTime.now().toLocal();
    final startOfToday = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final startOfTomorrow = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + 1,
    );
    final arrivalLocal = parcel.expectedArrival.toLocal();
    final isPastToday = arrivalLocal.isBefore(startOfToday);
    final isToday = !isPastToday && arrivalLocal.isBefore(startOfTomorrow);
    final isArrivingTodayOrPast = arrivalLocal.isBefore(startOfTomorrow);
    final isArrivedNow =
        parcel.status == ParcelStatus.arrived && !parcel.isClaimed;
    final canClaim = isArrivedNow || isArrivingTodayOrPast;

    final isUnsettled =
        !parcel.isSettled && parcel.status != ParcelStatus.cancelled;
    final showScheduledYesterday =
        isUnsettled &&
        isPastToday &&
        (tabMode == _ParcelTabMode.myParcels || !parcel.isClaimed);
    final showPastMyParcelHelper =
        tabMode == _ParcelTabMode.myParcels && isUnsettled && isPastToday;
    final showScheduledToday =
        isUnsettled &&
        !parcel.isClaimed &&
        !showScheduledYesterday &&
        (isToday || isArrivedNow);

    final isCod = parcel.paymentType == ParcelPaymentType.cod;
    final paymentText = isCod
        ? 'COD • ₱${parcel.codAmount?.toStringAsFixed(0) ?? '0'}'
        : 'Paid';
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      color: pal.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    final bool hasStatusRow =
        showScheduledYesterday ||
        showScheduledToday ||
        tabMode == _ParcelTabMode.history ||
        parcel.isSettled ||
        parcel.isUnsettledClaim ||
        showPastMyParcelHelper;

    final headerContent = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: CasamaSpacing.minTouchTarget,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CasamaCourierLogo(
            key: ValueKey('parcel_courier_logo_${parcel.id}'),
            courier: parcel.courier,
            size: 46,
            borderRadius: 12,
            padding: 5,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1: Courier name + Payment pill + Expand chevron
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        parcel.courier,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: paymentText,
                      variant: isCod ? ChipVariant.cod : ChipVariant.paid,
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: animDuration,
                      curve: CasamaMotion.easeOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: isExpanded ? pal.forestTeal : pal.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: Full-width poster badge + formatted arrival date/time
                CasamaInlineUserBadge(
                  avatarKey: ValueKey('parcel_poster_avatar_${parcel.id}'),
                  prefix: 'For ',
                  displayName: posterLabel,
                  avatarName: buyerName,
                  avatarUrl: buyerAvatarUrl,
                  suffix: ' • ${_formatArrival(parcel.expectedArrival)}',
                  avatarSize: 18,
                  maxLines: 2,
                  baseStyle: metaStyle,
                  nameStyle: metaStyle?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
                // Row 3: Status pill + past-today My Parcels helper note
                if (hasStatusRow) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showScheduledYesterday)
                        StatusChip(
                          key: ValueKey('parcel_scheduled_yesterday_${parcel.id}'),
                          label: 'Scheduled Yesterday',
                          icon: Icons.schedule_rounded,
                          variant: ChipVariant.cod,
                        )
                      else if (showScheduledToday)
                        StatusChip(
                          key: ValueKey('parcel_scheduled_today_${parcel.id}'),
                          label: 'Scheduled Today',
                          icon: Icons.local_shipping_rounded,
                          variant: ChipVariant.unclaimed,
                        )
                      else if (tabMode == _ParcelTabMode.history ||
                          parcel.isSettled)
                        const StatusChip(
                          label: 'Settled',
                          variant: ChipVariant.returned,
                        )
                      else if (parcel.isUnsettledClaim)
                        const StatusChip(
                          label: 'Unsettled',
                          variant: ChipVariant.cod,
                        ),
                      if (showPastMyParcelHelper)
                        Text(
                          'Expand to edit or delete listing',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

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
          Semantics(
            button: true,
            expanded: isExpanded,
            label:
                '${parcel.courier}, For $posterLabel, ${_formatArrival(parcel.expectedArrival)}',
            child: CasamaPressable(
              key: ValueKey('parcel_card_header_${parcel.id}'),
              onTap: onToggleExpand,
              enableHaptic: false,
              child: headerContent,
            ),
          ),
          if (reduceMotion) ...[
            if (isExpanded)
              _buildExpandedTray(
                context: context,
                ref: ref,
                pal: pal,
                theme: theme,
                isCreator: isCreator,
                claimerName: claimerName,
                claimerLabel: claimerLabel,
                claimerAvatarUrl: claimerAvatarUrl,
                canClaim: canClaim,
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
                    ? _buildExpandedTray(
                        context: context,
                        ref: ref,
                        pal: pal,
                        theme: theme,
                        isCreator: isCreator,
                        claimerName: claimerName,
                        claimerLabel: claimerLabel,
                        claimerAvatarUrl: claimerAvatarUrl,
                        canClaim: canClaim,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedTray({
    required BuildContext context,
    required WidgetRef ref,
    required CasamaPalette pal,
    required ThemeData theme,
    required bool isCreator,
    required String claimerName,
    required String claimerLabel,
    required String? claimerAvatarUrl,
    required bool canClaim,
  }) {
    final notes = parcel.notes?.trim() ?? '';
    final isHistory = tabMode == _ParcelTabMode.history || parcel.isSettled;
    final showClaimedInfo = parcel.isUnsettledClaim || isHistory;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),

          if (notes.isNotEmpty) ...[
            Text(
              notes,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: pal.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (showClaimedInfo) ...[
            CasamaInlineUserBadge(
              avatarKey: ValueKey('parcel_claimer_avatar_${parcel.id}'),
              prefix: 'Claimed by ',
              displayName: claimerLabel,
              avatarName: claimerName,
              avatarUrl: claimerAvatarUrl,
              suffix: isHistory
                  ? '${parcel.claimedAt != null ? ' • ${DateFormat('MMM d').format(parcel.claimedAt!.toLocal())}' : ''} • Settled${parcel.settledAt != null ? ' • ${DateFormat('MMM d').format(parcel.settledAt!.toLocal())}' : ''}'
                  : (parcel.claimedAt != null
                        ? ' • ${DateFormat('MMM d, h:mm a').format(parcel.claimedAt!.toLocal())}'
                        : ''),
              avatarSize: 16,
              baseStyle: theme.textTheme.bodySmall?.copyWith(
                color: isHistory ? pal.textSecondary : pal.forestTeal,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              nameStyle: theme.textTheme.bodySmall?.copyWith(
                color: isHistory ? pal.textPrimary : pal.forestTeal,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 10),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isCreator)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Delete parcel',
                      child: IconButton(
                        key: ValueKey('parcel_delete_btn_${parcel.id}'),
                        tooltip: 'Delete parcel',
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: pal.dangerFg.withValues(alpha: 0.8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: CasamaSpacing.minTouchTarget,
                          minHeight: CasamaSpacing.minTouchTarget,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () => _confirmAndDelete(context, ref),
                      ),
                    ),
                    if (!parcel.isClaimed && tabMode != _ParcelTabMode.history)
                      Semantics(
                        button: true,
                        label: 'Edit parcel',
                        child: IconButton(
                          key: ValueKey('parcel_edit_btn_${parcel.id}'),
                          tooltip: 'Edit parcel',
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 20,
                            color: pal.forestTeal,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: CasamaSpacing.minTouchTarget,
                            minHeight: CasamaSpacing.minTouchTarget,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => showAddParcelSheet(
                            context,
                            existingParcel: parcel,
                          ),
                        ),
                      ),
                  ],
                )
              else
                const SizedBox.shrink(),
              if (isCreator) const SizedBox(width: 8),
              Flexible(
                child: _buildTrailingAction(
                  context: context,
                  ref: ref,
                  pal: pal,
                  theme: theme,
                  isCreator: isCreator,
                  claimerName: claimerName,
                  claimerLabel: claimerLabel,
                  claimerAvatarUrl: claimerAvatarUrl,
                  canClaim: canClaim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingAction({
    required BuildContext context,
    required WidgetRef ref,
    required CasamaPalette pal,
    required ThemeData theme,
    required bool isCreator,
    required String claimerName,
    required String claimerLabel,
    required String? claimerAvatarUrl,
    required bool canClaim,
  }) {
    if (tabMode == _ParcelTabMode.history || parcel.isSettled) {
      return const StatusChip(
        label: 'Settled',
        variant: ChipVariant.returned,
      );
    }

    if (parcel.isUnsettledClaim) {
      if (isCreator) {
        return Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const StatusChip(
              label: 'Unsettled',
              variant: ChipVariant.cod,
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: pal.forestTeal,
                side: BorderSide(color: pal.forestTeal),
                shape: const StadiumBorder(),
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () {
                ref.read(repositoryProvider).settleParcelClaim(parcel.id);
                onCollapse();
                showCasamaToast(
                  context,
                  'Parcel marked as settled!',
                  icon: Icons.check_circle_outline_rounded,
                );
              },
              child: const Text(
                'Mark Settled',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: pal.amberBg,
          borderRadius: CasamaSpacing.roundedPill,
          border: Border.all(
            color: pal.amberFg.withValues(alpha: 0.35),
          ),
        ),
        child: CasamaInlineUserBadge(
          prefix: 'Claimed by ',
          displayName: claimerLabel,
          avatarName: claimerName,
          avatarUrl: claimerAvatarUrl,
          suffix: ' • Unsettled',
          avatarSize: 15,
          baseStyle: theme.textTheme.labelSmall?.copyWith(
            color: pal.amberFg,
            fontWeight: FontWeight.w700,
            fontSize: 11.5,
          ),
          nameStyle: theme.textTheme.labelSmall?.copyWith(
            color: pal.amberFg,
            fontWeight: FontWeight.w800,
            fontSize: 11.5,
          ),
        ),
      );
    }

    if (canClaim) {
      return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: pal.primaryCoral,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: () {
          final repo = ref.read(repositoryProvider);
          final isSelfClaim = parcel.buyerId == repo.currentUser.id;
          repo.receiveParcel(parcel.id);
          onCollapse();
          showCasamaToast(
            context,
            isSelfClaim
                ? 'Parcel marked as received.'
                : "Parcel claimed! You'll earn +5 pts once the owner marks it settled.",
            icon: Icons.check_circle_outline_rounded,
          );
        },
        child: const Text(
          'I Got It',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return StatusChip(
      label: 'Expected',
      icon: Icons.schedule_rounded,
      variant: ChipVariant.custom,
      customBgColor: pal.track,
      customTextColor: pal.textSecondary,
    );
  }

  String _formatArrival(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now().toLocal();
    if (local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return 'Today, ${DateFormat('h:mm a').format(local)}';
    }
    return DateFormat('MMM d, h:mm a').format(local);
  }
}
