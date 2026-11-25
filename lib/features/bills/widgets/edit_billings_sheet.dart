import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';

/// Opens the unified slide-up Edit Billings / Add Bill sheet matching
/// `casama-app-mockup.html` ("Edit Billings"), supporting both creation and editing.
Future<void> showEditBillingsSheet(
  BuildContext context, {
  HouseholdBill? initialBill,
}) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.receipt_long_outlined,
    title: 'Edit Billings',
    subtitle: initialBill == null
        ? 'Add a shared household bill or utility due date'
        : 'Update ${initialBill.effectiveBillName} details',
    builder: (sheetCtx) =>
        _EditBillingsSheetBody(hostContext: context, initialBill: initialBill),
  );
}

class _EditBillingsSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final HouseholdBill? initialBill;

  const _EditBillingsSheetBody({
    required this.hostContext,
    this.initialBill,
  });

  @override
  ConsumerState<_EditBillingsSheetBody> createState() =>
      _EditBillingsSheetBodyState();
}

class _EditBillingsSheetBodyState
    extends ConsumerState<_EditBillingsSheetBody> {
  late BillCategory _category;
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late DateTime _deadline;
  late ReminderTiming _reminderTiming;
  String? _responsibleMember;

  static const _quickCategories = [
    BillCategory.internet,
    BillCategory.electricity,
    BillCategory.water,
    BillCategory.gas,
    BillCategory.rent,
    BillCategory.other,
  ];

  static const _quickReminders = [
    ReminderTiming.oneDayBefore,
    ReminderTiming.threeDaysBefore,
    ReminderTiming.onDueDate,
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.initialBill;
    _category = b?.category ?? BillCategory.internet;
    _nameController = TextEditingController(text: b?.billName ?? '');
    _amountController = TextEditingController(
      text: b?.amount != null ? b!.amount!.toStringAsFixed(2) : '',
    );
    _deadline = b?.deadline ?? DateTime.now().add(const Duration(days: 7));
    _reminderTiming = b?.reminderTiming ?? ReminderTiming.oneDayBefore;
    _responsibleMember = b?.responsibleMember;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(now.year - 1),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d != null && mounted) {
      setState(() => _deadline = d);
    }
  }

  void _save() {
    final billName = _nameController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = amountText.isEmpty ? null : double.tryParse(amountText);
    if (amountText.isNotEmpty && (amount == null || amount < 0)) {
      showCasamaToast(
        widget.hostContext,
        'Enter a valid billing amount',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final repo = ref.read(repositoryProvider);
    final existing = widget.initialBill;
    if (existing != null) {
      repo.updateBill(
        billId: existing.id,
        category: _category,
        billName: billName.isNotEmpty ? billName : existing.effectiveBillName,
        amount: amount,
        deadline: _deadline,
        reminderTiming: _reminderTiming,
        responsibleMember: _responsibleMember,
      );
    } else {
      repo.addBill(
        category: _category,
        billName: billName.isNotEmpty ? billName : _category.label,
        amount: amount,
        deadline: _deadline,
        reminderEnabled: true,
        reminderTiming: _reminderTiming,
        recipientType: BillRecipientType.allMembers,
        responsibleMember: _responsibleMember,
      );
    }

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        existing != null ? 'Billing updated' : 'Bill added to household board',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final memberOptions = repo.members
        .map((m) => m.profile.displayName)
        .toSet()
        .toList();
    if (memberOptions.isEmpty) {
      memberOptions.add(repo.currentUser.displayName);
    }
    if (_responsibleMember == null ||
        !memberOptions.contains(_responsibleMember)) {
      _responsibleMember = memberOptions.first;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bill category',
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickCategories.map((cat) {
            final selected = _category == cat;
            return ChoiceChip(
              label: Text(cat.label),
              selected: selected,
              onSelected: (_) => setState(() => _category = cat),
              selectedColor: pal.forestTeal,
              backgroundColor: pal.track,
              side: BorderSide(color: selected ? pal.forestTeal : pal.border),
              labelStyle: TextStyle(
                color: selected ? Colors.white : pal.textPrimary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: CasamaSpacing.md),

        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Bill Name',
            hintText: 'e.g., PLDT Fiber, Meralco, Rent',
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: theme.textTheme.bodyMedium?.tabular.copyWith(
                  color: pal.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Amount Due (₱)',
                  hintText: '0.00',
                  prefixText: '₱ ',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Select due date',
                child: CasamaPressable(
                  onTap: _pickDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Due Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 17),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_deadline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.tabular.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        DropdownButtonFormField<String>(
          initialValue: _responsibleMember,
          decoration: const InputDecoration(labelText: 'Responsible Member'),
          items: memberOptions
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _responsibleMember = val);
          },
        ),
        const SizedBox(height: CasamaSpacing.md),

        Text(
          'Due reminder',
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickReminders.map((timing) {
            final selected = _reminderTiming == timing;
            return ChoiceChip(
              label: Text(timing.label),
              selected: selected,
              onSelected: (_) => setState(() => _reminderTiming = timing),
              selectedColor: pal.forestTeal,
              backgroundColor: pal.track,
              side: BorderSide(color: selected ? pal.forestTeal : pal.border),
              labelStyle: TextStyle(
                color: selected ? Colors.white : pal.textPrimary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: CasamaSpacing.md),

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.softSage,
            borderRadius: CasamaSpacing.roundedLg,
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 18,
                color: pal.forestTeal,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Shared household record only — no bank or payment details stored.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Save Billings',
          isPill: true,
          height: 50,
          onPressed: _save,
        ),
      ],
    );
  }
}
