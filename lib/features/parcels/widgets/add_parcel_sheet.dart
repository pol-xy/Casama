import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';

/// Opens the unified slide-up Add Parcel sheet matching `casama-app-mockup.html`
/// while preserving all repository bindings and form fields.
Future<void> showAddParcelSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.inventory_2_outlined,
    title: 'Add Expected Parcel',
    subtitle: 'Tell housemates what is arriving soon',
    builder: (sheetContext) => _AddParcelSheetBody(hostContext: context),
  );
}

class _AddParcelSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _AddParcelSheetBody({required this.hostContext});

  @override
  ConsumerState<_AddParcelSheetBody> createState() =>
      _AddParcelSheetBodyState();
}

class _AddParcelSheetBodyState extends ConsumerState<_AddParcelSheetBody> {
  String _courier = CasamaCouriers.defaultCourier;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 16, minute: 0);
  ParcelPaymentType _paymentType = ParcelPaymentType.cod;
  late final TextEditingController _codController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _codController = TextEditingController(text: '350');
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _codController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null && mounted) {
      setState(() => _selectedDate = d);
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (t != null && mounted) {
      setState(() => _selectedTime = t);
    }
  }

  void _save() {
    final arrival = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final cod = _paymentType == ParcelPaymentType.cod
        ? (double.tryParse(_codController.text.trim()) ?? 0.0)
        : null;

    ref
        .read(repositoryProvider)
        .addParcel(
          courier: _courier,
          arrival: arrival,
          paymentType: _paymentType,
          codAmount: cod,
          notes: _notesController.text.trim(),
        );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Added expected delivery from $_courier',
        icon: Icons.local_shipping_outlined,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _courier,
          decoration: const InputDecoration(labelText: 'Courier'),
          items: CasamaCouriers.options
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _courier = val);
          },
        ),
        const SizedBox(height: CasamaSpacing.md),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: pal.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: CasamaSpacing.roundedLg,
                  ),
                ),
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: pal.forestTeal,
                ),
                label: Text(
                  DateFormat('MMM dd').format(_selectedDate),
                  style: TextStyle(color: pal.textPrimary),
                ),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: pal.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: CasamaSpacing.roundedLg,
                  ),
                ),
                icon: Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: pal.forestTeal,
                ),
                label: Text(
                  _selectedTime.format(context),
                  style: TextStyle(color: pal.textPrimary),
                ),
                onPressed: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Cash on Delivery (COD)'),
              selected: _paymentType == ParcelPaymentType.cod,
              onSelected: (_) =>
                  setState(() => _paymentType = ParcelPaymentType.cod),
              selectedColor: pal.softBlush,
              backgroundColor: pal.track,
              side: BorderSide(
                color: _paymentType == ParcelPaymentType.cod
                    ? pal.primaryCoral
                    : pal.border,
              ),
              labelStyle: TextStyle(
                color: _paymentType == ParcelPaymentType.cod
                    ? pal.primaryCoral
                    : pal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            ChoiceChip(
              label: const Text('Paid Online'),
              selected: _paymentType == ParcelPaymentType.paid,
              onSelected: (_) =>
                  setState(() => _paymentType = ParcelPaymentType.paid),
              selectedColor: pal.successBg,
              backgroundColor: pal.track,
              side: BorderSide(
                color: _paymentType == ParcelPaymentType.paid
                    ? pal.successFg
                    : pal.border,
              ),
              labelStyle: TextStyle(
                color: _paymentType == ParcelPaymentType.paid
                    ? pal.successFg
                    : pal.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        if (_paymentType == ParcelPaymentType.cod) ...[
          const SizedBox(height: CasamaSpacing.md),
          TextField(
            controller: _codController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'COD Amount (₱)',
              prefixText: '₱ ',
            ),
          ),
        ],

        const SizedBox(height: CasamaSpacing.md),
        TextField(
          controller: _notesController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Instructions / Notes',
            hintText: 'e.g., Fragile, Leave at guard, Call on arrival',
          ),
        ),

        const SizedBox(height: CasamaSpacing.lg),
        CasamaButton(
          label: 'Save Parcel',
          isPill: true,
          height: 50,
          onPressed: _save,
        ),
      ],
    );
  }
}
