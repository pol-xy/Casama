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
import 'courier_logo.dart';

/// Returns `true` if [localArrival] (date + hour + minute) is strictly before
/// the current local minute.
bool isParcelArrivalInPast(DateTime localArrival, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final currentMinute = DateTime(
    current.year,
    current.month,
    current.day,
    current.hour,
    current.minute,
  );
  final candidateMinute = DateTime(
    localArrival.year,
    localArrival.month,
    localArrival.day,
    localArrival.hour,
    localArrival.minute,
  );
  return candidateMinute.isBefore(currentMinute);
}

/// Opens the unified slide-up Add / Edit Parcel sheet matching
/// `casama-app-mockup.html` while preserving all repository bindings and
/// past-time validation.
Future<void> showAddParcelSheet(
  BuildContext context, {
  ParcelItem? existingParcel,
  DateTime Function()? nowProvider,
}) {
  final isEdit = existingParcel != null;
  return showCasamaSheet<void>(
    context,
    icon: isEdit ? Icons.edit_outlined : Icons.inventory_2_outlined,
    title: isEdit ? 'Edit Parcel' : 'Add Expected Parcel',
    subtitle: isEdit
        ? 'Update courier, arrival time, payment, or notes'
        : 'Tell housemates what is arriving soon',
    builder: (sheetContext) => _AddParcelSheetBody(
      hostContext: context,
      existingParcel: existingParcel,
      nowProvider: nowProvider,
    ),
  );
}

class _AddParcelSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final ParcelItem? existingParcel;
  final DateTime Function()? nowProvider;

  const _AddParcelSheetBody({
    required this.hostContext,
    this.existingParcel,
    this.nowProvider,
  });

  @override
  ConsumerState<_AddParcelSheetBody> createState() =>
      _AddParcelSheetBodyState();
}

class _AddParcelSheetBodyState extends ConsumerState<_AddParcelSheetBody> {
  static const String _pastDateTimeMessage =
      'Please choose a date and time from now onward.';

  late String _courier;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late ParcelPaymentType _paymentType;
  late final TextEditingController _codController;
  late final TextEditingController _notesController;
  String? _dateTimeError;
  String? _codError;
  bool _isSaving = false;

  bool get _isEdit => widget.existingParcel != null;

  DateTime _now() => (widget.nowProvider?.call() ?? DateTime.now()).toLocal();

  DateTime get _combinedArrival => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _selectedTime.hour,
    _selectedTime.minute,
  );

  @override
  void initState() {
    super.initState();
    final existing = widget.existingParcel;
    if (existing != null) {
      final localArrival = existing.expectedArrival.toLocal();
      _courier = existing.courier;
      _selectedDate = DateTime(
        localArrival.year,
        localArrival.month,
        localArrival.day,
      );
      _selectedTime = TimeOfDay(
        hour: localArrival.hour,
        minute: localArrival.minute,
      );
      _paymentType = existing.paymentType;
      final cod = existing.codAmount;
      final codText = cod == null
          ? '350'
          : (cod == cod.roundToDouble()
                ? cod.toInt().toString()
                : cod.toStringAsFixed(2));
      _codController = TextEditingController(text: codText);
      _notesController = TextEditingController(text: existing.notes ?? '');
      if (isParcelArrivalInPast(_combinedArrival, now: _now())) {
        _dateTimeError = _pastDateTimeMessage;
      }
    } else {
      final defaultArrival = _now().add(const Duration(hours: 1));
      _courier = CasamaCouriers.defaultCourier;
      _selectedDate = DateTime(
        defaultArrival.year,
        defaultArrival.month,
        defaultArrival.day,
      );
      _selectedTime = TimeOfDay(
        hour: defaultArrival.hour,
        minute: defaultArrival.minute,
      );
      _paymentType = ParcelPaymentType.cod;
      _codController = TextEditingController(text: '350');
      _notesController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _codController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _revalidateDateTime() {
    _dateTimeError = isParcelArrivalInPast(_combinedArrival, now: _now())
        ? _pastDateTimeMessage
        : null;
  }

  Future<void> _pickDate() async {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
    );
    if (d != null && mounted) {
      setState(() {
        _selectedDate = DateTime(d.year, d.month, d.day);
        _revalidateDateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (t != null && mounted) {
      setState(() {
        _selectedTime = t;
        _revalidateDateTime();
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final arrival = _combinedArrival;
    if (isParcelArrivalInPast(arrival, now: _now())) {
      setState(() {
        _dateTimeError = _pastDateTimeMessage;
      });
      return;
    }

    double? cod;
    if (_paymentType == ParcelPaymentType.cod) {
      cod = double.tryParse(_codController.text.trim());
      if (cod == null || cod <= 0) {
        setState(() {
          _codError = 'Please enter a COD amount greater than 0.';
        });
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _dateTimeError = null;
      _codError = null;
    });

    final repo = ref.read(repositoryProvider);
    final trimmedNotes = _notesController.text.trim();

    if (_isEdit) {
      try {
        await repo.updateParcel(
          parcelId: widget.existingParcel!.id,
          courier: _courier,
          arrival: arrival,
          paymentType: _paymentType,
          codAmount: cod,
          notes: trimmedNotes,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        if (widget.hostContext.mounted) {
          showCasamaToast(
            widget.hostContext,
            'Parcel updated',
            icon: Icons.check_circle_outline_rounded,
          );
        }
      } catch (_) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        showCasamaToast(
          context,
          'Could not update parcel. Please try again.',
          icon: Icons.error_outline_rounded,
        );
      }
      return;
    }

    repo.addParcel(
      courier: _courier,
      arrival: arrival,
      paymentType: _paymentType,
      codAmount: cod,
      notes: trimmedNotes.isEmpty ? null : trimmedNotes,
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
    final theme = Theme.of(context);
    final courierOptions = CasamaCouriers.options.contains(_courier)
        ? CasamaCouriers.options
        : [_courier, ...CasamaCouriers.options];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _courier,
          decoration: const InputDecoration(labelText: 'Courier'),
          items: courierOptions
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CasamaCourierLogo(
                        courier: c,
                        size: 22,
                        borderRadius: 6,
                        padding: 2,
                      ),
                      const SizedBox(width: 8),
                      Text(c),
                    ],
                  ),
                ),
              )
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
                key: const Key('parcel_date_picker_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(
                    color: _dateTimeError != null ? pal.dangerFg : pal.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: CasamaSpacing.roundedLg,
                  ),
                ),
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: _dateTimeError != null ? pal.dangerFg : pal.forestTeal,
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
                key: const Key('parcel_time_picker_button'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(
                    color: _dateTimeError != null ? pal.dangerFg : pal.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: CasamaSpacing.roundedLg,
                  ),
                ),
                icon: Icon(
                  Icons.access_time_rounded,
                  size: 16,
                  color: _dateTimeError != null ? pal.dangerFg : pal.forestTeal,
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
        if (_dateTimeError != null) ...[
          const SizedBox(height: 8),
          Row(
            key: const Key('parcel_datetime_error'),
            children: [
              Icon(Icons.error_outline_rounded, size: 15, color: pal.dangerFg),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _dateTimeError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.dangerFg,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: CasamaSpacing.md),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Cash on Delivery (COD)'),
              selected: _paymentType == ParcelPaymentType.cod,
              onSelected: (_) => setState(() {
                _paymentType = ParcelPaymentType.cod;
              }),
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
              onSelected: (_) => setState(() {
                _paymentType = ParcelPaymentType.paid;
                _codError = null;
              }),
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
            onChanged: (_) {
              if (_codError != null) {
                setState(() => _codError = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'COD Amount (₱)',
              prefixText: '₱ ',
              errorText: _codError,
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
          key: const Key('parcel_save_button'),
          label: _isEdit ? 'Save Changes' : 'Save Parcel',
          isPill: true,
          height: 50,
          isLoading: _isSaving,
          onPressed: (_isSaving || _dateTimeError != null) ? null : _save,
        ),
      ],
    );
  }
}
