import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_no_household_card.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/add_parcel_sheet.dart';

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
              child: ParcelsBoardView(bottomPadding: 28),
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
  int _selectedSegment = 1; // 0 = My Parcels, 1 = Upcoming, 2 = History
  int _previousSegment = 1;

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
        return a.expectedArrival.compareTo(b.expectedArrival);
      });

    final upcomingParcels = [
      ...unsettledParcels.where(
        (p) => p.status == ParcelStatus.arrived && !p.isClaimed,
      ),
      ...unsettledParcels.where(
        (p) => !(p.status == ParcelStatus.arrived && !p.isClaimed),
      ),
    ];
    final historyParcels = repo.parcels.where((p) => p.isSettled).toList();
    final expectedUnclaimed = upcomingParcels.where((p) => !p.isClaimed).toList();

    final codTotal = unsettledParcels.fold<double>(
      0,
      (sum, p) =>
          p.paymentType == ParcelPaymentType.cod ? sum + (p.codAmount ?? 0) : sum,
    );
    final arrivingToday = expectedUnclaimed.where((p) {
      if (p.status == ParcelStatus.arrived) return true;
      final now = DateTime.now();
      return p.expectedArrival.year == now.year &&
          p.expectedArrival.month == now.month &&
          p.expectedArrival.day == now.day;
    }).length;

    final currentList = switch (_selectedSegment) {
      0 => myParcels,
      1 => upcomingParcels,
      _ => historyParcels,
    };
    final tabMode = switch (_selectedSegment) {
      0 => _ParcelTabMode.myParcels,
      1 => _ParcelTabMode.upcoming,
      _ => _ParcelTabMode.history,
    };
    final emptyTitle = switch (_selectedSegment) {
      0 => 'No active parcels of yours',
      1 => 'No upcoming deliveries',
      _ => 'No settled parcels yet',
    };
    final emptySubtitle = switch (_selectedSegment) {
      0 => 'Post a parcel you are expecting or settle claimed deliveries here.',
      1 => 'Add a delivery when expecting a package.',
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
            }),
            segments: const [
              CasamaFilterOption(value: 0, label: 'My Parcels'),
              CasamaFilterOption(value: 1, label: 'Upcoming'),
              CasamaFilterOption(value: 2, label: 'History'),
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
                            pose: CasPose.deliveries,
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
                          if (i > 0) const SizedBox(height: 12),
                          _ParcelCard(
                            parcel: currentList[i],
                            tabMode: tabMode,
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

enum _ParcelTabMode { myParcels, upcoming, history }

class _ParcelCard extends ConsumerWidget {
  final ParcelItem parcel;
  final _ParcelTabMode tabMode;

  const _ParcelCard({required this.parcel, required this.tabMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final buyerName = repo.resolveHousemateName(
      parcel.buyerId,
      fallback: parcel.buyerName,
    );
    final claimerName = repo.resolveHousemateName(
      parcel.claimedById,
      fallback: parcel.claimedByName ?? 'Housemate',
    );
    final (
      Color courierBg,
      Color courierColor,
      String courierMonogram,
    ) = _resolveCourierStyle(parcel.courier, pal);

    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final isArrivingTodayOrPast = !parcel.expectedArrival.isAfter(endOfToday);
    final isArrivedNow =
        parcel.status == ParcelStatus.arrived && !parcel.isClaimed;
    final canClaim = isArrivedNow || isArrivingTodayOrPast;

    final isCod = parcel.paymentType == ParcelPaymentType.cod;
    final paymentText = isCod
        ? 'COD • ₱${parcel.codAmount?.toStringAsFixed(0) ?? '0'}'
        : 'Paid';

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: courierBg,
                  borderRadius: CasamaSpacing.roundedMd,
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    courierMonogram,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: courierColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parcel.courier,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: courierColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'For $buyerName • ${_formatArrival(parcel.expectedArrival)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isArrivedNow) ...[
                      const SizedBox(height: 6),
                      StatusChip(
                        key: ValueKey('parcel_arriving_now_${parcel.id}'),
                        label: ParcelStatus.arrived.label,
                        icon: Icons.local_shipping_rounded,
                        variant: ChipVariant.unclaimed,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(
                label: paymentText,
                variant: isCod ? ChipVariant.cod : ChipVariant.paid,
              ),
            ],
          ),

          if (parcel.notes != null && parcel.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              parcel.notes!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 13,
                color: pal.textSecondary,
              ),
            ),
          ],

          if (tabMode == _ParcelTabMode.myParcels &&
              parcel.isUnsettledClaim) ...[
            const SizedBox(height: 8),
            Text(
              'Claimed by $claimerName${parcel.claimedAt != null ? ' • ${DateFormat('MMM d, h:mm a').format(parcel.claimedAt!)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.forestTeal,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ] else if (tabMode == _ParcelTabMode.history) ...[
            const SizedBox(height: 8),
            Text(
              'Claimed by $claimerName${parcel.claimedAt != null ? ' (${DateFormat('MMM d').format(parcel.claimedAt!)})' : ''} • Settled${parcel.settledAt != null ? ' ${DateFormat('MMM d').format(parcel.settledAt!)}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Divider(height: 1, color: pal.border),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  ...parcel.availableMemberNames.take(3).map(
                        (name) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: pal.forestTeal,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  if (parcel.availableMemberNames.length > 3)
                    Text(
                      '+${parcel.availableMemberNames.length - 3}',
                      style: theme.textTheme.labelSmall?.tabular.copyWith(
                        color: pal.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (tabMode == _ParcelTabMode.history)
                const StatusChip(
                  label: 'Settled',
                  variant: ChipVariant.returned,
                )
              else if (parcel.isUnsettledClaim)
                if (tabMode == _ParcelTabMode.myParcels)
                  Wrap(
                    spacing: 8,
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
                          ref
                              .read(repositoryProvider)
                              .settleParcelClaim(parcel.id);
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
                  )
                else
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: pal.amberBg,
                        borderRadius: CasamaSpacing.roundedPill,
                        border: Border.all(
                          color: pal.amberFg.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        'Claimed by $claimerName • Unsettled',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pal.amberFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  )
              else if (canClaim)
                ElevatedButton(
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
                    if (isSelfClaim) {
                      showCasamaToast(
                        context,
                        'Parcel received & settled!',
                        icon: Icons.check_circle_outline_rounded,
                      );
                    } else {
                      _showPointsCelebrationDialog(
                        context,
                        5,
                        'Parcel Received!',
                      );
                    }
                  },
                  child: const Text(
                    'I Got It',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pal.textPrimary,
                    side: BorderSide(color: pal.border),
                    shape: const StadiumBorder(),
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: () {
                    ref
                        .read(repositoryProvider)
                        .toggleParcelAvailability(parcel.id);
                    showCasamaToast(
                      context,
                      'Updated delivery availability',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  },
                  child: const Text(
                    'Mark Unavailable',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  (Color bg, Color fg, String monogram) _resolveCourierStyle(
    String courier,
    CasamaPalette pal,
  ) {
    final normalized = courier.trim().toLowerCase();
    if (normalized.contains('j&t')) {
      return (pal.softBlush, pal.primaryCoral, 'J&T');
    }
    if (normalized.contains('flash')) {
      return (pal.amberBg, pal.amberFg, 'FX');
    }
    if (normalized.contains('ninja')) {
      return (pal.softBlush, pal.dangerFg, 'NV');
    }
    if (normalized == 'lbc' || normalized.startsWith('lbc ')) {
      return (pal.softBlush, pal.primaryCoral, 'LBC');
    }
    if (normalized.contains('2go')) {
      return (pal.infoBg, pal.infoFg, '2GO');
    }
    if (normalized.contains('lalamove')) {
      return (pal.warningBg, pal.warningFg, 'LM');
    }
    if (normalized == 'spx' || normalized.contains('spx')) {
      return (pal.warningBg, pal.warningFg, 'SPX');
    }
    final fallback = courier.trim().isNotEmpty
        ? courier.trim()[0].toUpperCase()
        : 'P';
    return (pal.softSage, pal.forestTeal, fallback);
  }

  String _formatArrival(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'Today ${DateFormat('h:mm a').format(dt)}';
    }
    return DateFormat('MMM dd h:mm a').format(dt);
  }

  void _showPointsCelebrationDialog(
    BuildContext context,
    int points,
    String reason,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
          backgroundColor: pal.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CasMascotView(
                pose: CasPose.jumping,
                width: 118,
                height: 118,
              ),
              const SizedBox(height: 10),
              Text(
                '+$points Good Kasama Points!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Thank you for receiving the delivery: $reason',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CasamaButton(
                label: 'Awesome!',
                onPressed: () => Navigator.pop(ctx),
                height: 46,
              ),
            ],
          ),
        );
      },
    );
  }
}
