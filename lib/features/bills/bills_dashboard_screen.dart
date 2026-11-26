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
import 'widgets/edit_billings_sheet.dart';

class BillsDashboardScreen extends ConsumerWidget {
  const BillsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Bills & Payments',
              subtitle:
                  '${repo.currentHousehold.name} • Shared utilities & due dates',
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                CasamaHeaderActionPill(
                  icon: Icons.edit_note_rounded,
                  label: 'Edit billings',
                  onTap: () => showEditBillingsSheet(context),
                ),
              ],
            ),
            const Expanded(child: BillsBoardView(bottomPadding: 96)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showEditBillingsSheet(context),
        backgroundColor: pal.coralFab,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Bill',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Reusable Bills board tab body shared by [BoardsScreen] and standalone [BillsDashboardScreen].
class BillsBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const BillsBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<BillsBoardView> createState() => _BillsBoardViewState();
}

class _BillsBoardViewState extends ConsumerState<BillsBoardView> {
  String _selectedFilter = 'All'; // 'All', 'Overdue', 'Unpaid', 'Paid'

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final allBills = repo.bills;

    final overdueBills = allBills
        .where((b) => b.effectiveStatus == BillStatus.overdue)
        .toList();
    final unpaidBills = allBills
        .where((b) => b.effectiveStatus == BillStatus.unpaid)
        .toList();
    final paidBills = allBills
        .where((b) => b.effectiveStatus == BillStatus.paid)
        .toList();

    final outstandingBills = allBills
        .where((b) => b.effectiveStatus != BillStatus.paid)
        .toList();
    final totalDueAmount = outstandingBills.fold<double>(
      0,
      (sum, b) => sum + (b.amount ?? 0),
    );

    final filtered = switch (_selectedFilter) {
      'Overdue' => overdueBills,
      'Unpaid' => unpaidBills,
      'Paid' => paidBills,
      _ => allBills,
    };

    final filters = [
      const CasamaFilterOption(value: 'All', label: 'All'),
      CasamaFilterOption(
        value: 'Overdue',
        label: 'Overdue',
        isUrgent: overdueBills.isNotEmpty,
      ),
      const CasamaFilterOption(value: 'Unpaid', label: 'Unpaid'),
      const CasamaFilterOption(value: 'Paid', label: 'Paid'),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 46, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.chatting,
            leftTitle: '₱${NumberFormat('#,##0.00').format(totalDueAmount)} Due',
            leftSubtitle:
                '${outstandingBills.length} unpaid bill${outstandingBills.length == 1 ? '' : 's'}',
            rightTitle: '${overdueBills.length} Overdue',
            rightSubtitle: overdueBills.isNotEmpty
                ? overdueBills.first.effectiveBillName
                : 'No overdue bills',
            rightTitleColor:
                overdueBills.isNotEmpty ? pal.dangerFg : pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaPillFilterRail<String>(
            options: filters,
            selectedValue: _selectedFilter,
            onSelected: (val) => setState(() => _selectedFilter = val),
          ),
          const SizedBox(height: CasamaSpacing.xs),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CasamaSpacing.md,
                vertical: CasamaSpacing.xl,
              ),
              child: CasamaCard(
                padding: const EdgeInsets.all(CasamaSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: pal.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFilter == 'All'
                          ? 'No household bills yet'
                          : 'No $_selectedFilter bills',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap "Edit billings" to record utilities and shared due dates.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
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
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _BillCard(bill: filtered[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BillCard extends ConsumerWidget {
  final HouseholdBill bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final effectiveStatus = bill.effectiveStatus;
    final dateStr = DateFormat('MMM dd, yyyy').format(bill.deadline);
    final isOverdue = effectiveStatus == BillStatus.overdue;
    final isPaid = effectiveStatus == BillStatus.paid;

    final Color statusColor;
    final Color statusBg;
    switch (effectiveStatus) {
      case BillStatus.paid:
        statusColor = pal.successFg;
        statusBg = pal.successBg;
      case BillStatus.overdue:
        statusColor = pal.dangerFg;
        statusBg = pal.dangerBg;
      case BillStatus.unpaid:
        statusColor = pal.amberFg;
        statusBg = pal.amberBg;
    }

    final (IconData catIcon, Color catBg, Color catFg) = switch (bill.category) {
      BillCategory.electricity => (Icons.bolt_rounded, pal.amberBg, pal.amberFg),
      BillCategory.water => (Icons.water_drop_outlined, pal.infoBg, pal.infoFg),
      BillCategory.internet => (Icons.wifi_rounded, pal.softSage, pal.forestTeal),
      BillCategory.rent => (Icons.home_work_outlined, pal.softBlush, pal.primaryCoral),
      BillCategory.gas => (Icons.local_fire_department_outlined, pal.softBlush, pal.primaryCoral),
      _ => (Icons.receipt_long_outlined, pal.track, pal.forestTeal),
    };

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      borderSide: isOverdue
          ? BorderSide(color: pal.dangerFg.withValues(alpha: 0.45), width: 1.5)
          : null,
      onTap: () {
        if (GoRouter.maybeOf(context) != null) {
          context.push('/bill-detail?id=${bill.id}');
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: catBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(catIcon, color: catFg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.effectiveBillName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    Text(
                      '${bill.effectiveCategoryLabel} • Added by ${bill.creatorName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  effectiveStatus.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Edit ${bill.effectiveBillName}',
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: pal.textSecondary,
                ),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                onPressed: () => showEditBillingsSheet(
                  context,
                  initialBill: bill,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(height: 1, color: pal.border),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.amount != null
                          ? '₱${NumberFormat('#,##0.00').format(bill.amount)}'
                          : 'Shared record',
                      style: theme.textTheme.titleMedium?.tabular.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPaid
                          ? 'Settled${bill.paidByName != null ? ' by ${bill.paidByName}' : ''}'
                          : 'Due $dateStr${bill.reminderEnabled ? ' • ${bill.reminderTiming.label}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isOverdue
                            ? pal.dangerFg
                            : (isPaid ? pal.forestTeal : pal.textSecondary),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (!isPaid)
                CasamaButton(
                  label: 'Mark Paid',
                  icon: Icons.check_rounded,
                  style: isOverdue
                      ? CasamaButtonStyle.primary
                      : CasamaButtonStyle.secondary,
                  isFullWidth: false,
                  height: 44,
                  onPressed: () {
                    ref.read(repositoryProvider).markBillPaid(bill.id);
                    showCasamaToast(
                      context,
                      '${bill.effectiveBillName} marked paid',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  },
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.done_all_rounded, size: 17, color: pal.forestTeal),
                    const SizedBox(width: 4),
                    Text(
                      'Paid',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: pal.forestTeal,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
