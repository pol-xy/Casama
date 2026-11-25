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
        if (mounted) showAddParcelSheet(context);
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
              subtitle:
                  '${repo.currentHousehold.name} • Coordinate arrivals & COD',
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
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
  int _selectedSegment = 0; // 0 = Upcoming, 1 = History
  int _previousSegment = 0;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final upcomingParcels = repo.parcels
        .where((p) => p.status == ParcelStatus.expected)
        .toList();
    final historyParcels = repo.parcels
        .where((p) => p.status == ParcelStatus.received)
        .toList();

    final codTotal = upcomingParcels.fold<double>(
      0,
      (sum, p) =>
          p.paymentType == ParcelPaymentType.cod ? sum + (p.codAmount ?? 0) : sum,
    );
    final arrivingToday = upcomingParcels.where((p) {
      final now = DateTime.now();
      return p.expectedArrival.year == now.year &&
          p.expectedArrival.month == now.month &&
          p.expectedArrival.day == now.day;
    }).length;

    final currentList = _selectedSegment == 0 ? upcomingParcels : historyParcels;

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 26, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Peeking summary card w/ unframed transparent mascot tucked behind edge
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.deliveries,
            leftTitle: '${upcomingParcels.length} Expected',
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
              CasamaFilterOption(value: 0, label: 'Upcoming'),
              CasamaFilterOption(value: 1, label: 'History'),
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
                            _selectedSegment == 1
                                ? 'No past parcels'
                                : 'No upcoming deliveries',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: pal.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Add a delivery when expecting a package.',
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
                            isHistory: _selectedSegment == 1,
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

class _ParcelCard extends ConsumerWidget {
  final ParcelItem parcel;
  final bool isHistory;

  const _ParcelCard({required this.parcel, required this.isHistory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final isShopee = parcel.courier.toLowerCase().contains('shopee');
    final isLazada = parcel.courier.toLowerCase().contains('lazada');

    final Color courierBg;
    final Color courierColor;
    if (isShopee) {
      courierBg = pal.softBlush;
      courierColor = pal.primaryCoral;
    } else if (isLazada) {
      courierBg = pal.infoBg;
      courierColor = pal.infoFg;
    } else {
      courierBg = pal.softSage;
      courierColor = pal.forestTeal;
    }

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
                decoration: BoxDecoration(
                  color: courierBg,
                  borderRadius: CasamaSpacing.roundedMd,
                ),
                alignment: Alignment.center,
                child: Text(
                  parcel.courier.isNotEmpty ? parcel.courier[0] : 'P',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: courierColor,
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
                      'For ${parcel.buyerName} • ${_formatArrival(parcel.expectedArrival)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
              if (!isHistory)
                if (isShopee)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: pal.primaryCoral,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () {
                      ref.read(repositoryProvider).receiveParcel(parcel.id);
                      _showPointsCelebrationDialog(
                        context,
                        5,
                        'Parcel Received!',
                      );
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
                      minimumSize: const Size(0, 44),
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
                  )
              else
                const StatusChip(
                  label: 'Received',
                  variant: ChipVariant.returned,
                ),
            ],
          ),
        ],
      ),
    );
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
