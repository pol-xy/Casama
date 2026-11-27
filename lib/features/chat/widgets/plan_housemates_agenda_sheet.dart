import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

/// Opens the unified slide-up Plan Housemates Agenda sheet for online or
/// in-person household plans.
Future<void> showPlanHousematesAgendaSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.calendar_month_rounded,
    title: 'Plan Housemates Agenda',
    subtitle: 'Suggest an activity, link, or spot for your household',
    builder: (sheetCtx) => PlanHousematesAgendaSheet(hostContext: context),
  );
}

class PlanHousematesAgendaSheet extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const PlanHousematesAgendaSheet({super.key, required this.hostContext});

  @override
  ConsumerState<PlanHousematesAgendaSheet> createState() =>
      _PlanHousematesAgendaSheetState();
}

class _PlanHousematesAgendaSheetState
    extends ConsumerState<PlanHousematesAgendaSheet> {
  static const List<String> _activitySuggestions = [
    'Study Session',
    'Online Hangout / Call',
    'Dinner',
    'Movie Night',
    'House Sync',
  ];

  static const List<String> _locationSuggestions = [
    'Online / Discord',
    'Dorm Common Area',
    'Kitchen',
    'Living Room',
    'Study Room',
  ];

  final _activityController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    final defaultDateTime = DateTime.now().add(const Duration(hours: 3));
    _selectedDate = DateTime(
      defaultDateTime.year,
      defaultDateTime.month,
      defaultDateTime.day,
    );
    _selectedTime = TimeOfDay(
      hour: defaultDateTime.hour,
      minute: defaultDateTime.minute,
    );
  }

  @override
  void dispose() {
    _activityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == tomorrow) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(date);
  }

  String _formatTime(TimeOfDay time) {
    return DateFormat('h:mm a').format(
      DateTime(2026, 1, 1, time.hour, time.minute),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && mounted) {
      setState(() => _selectedTime = picked);
    }
  }

  void _applySuggestion(TextEditingController controller, String value) {
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
    setState(() {
      if (_validationError != null) {
        _validationError = null;
      }
    });
  }

  void _submit() {
    final activity = _activityController.text.trim();
    final location = _locationController.text.trim();
    if (activity.isEmpty || location.isEmpty) {
      setState(() {
        _validationError = 'Please enter an activity and location or link.';
      });
      showCasamaToast(
        widget.hostContext,
        'Please enter an activity and location or link.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final scheduledTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    ref.read(repositoryProvider).createHousematesAgendaInvitation(
      activity: activity,
      location: location,
      scheduledTime: scheduledTime,
    );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Housemates agenda sent to household!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CasamaTextField(
          controller: _activityController,
          label: 'Activity',
          hint: "What's the agenda?",
          prefixIcon: Icons.event_note_outlined,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_validationError != null) {
              setState(() => _validationError = null);
            }
          },
        ),
        const SizedBox(height: CasamaSpacing.xs),
        _SuggestionPillRow(
          suggestions: _activitySuggestions,
          selectedValue: _activityController.text.trim(),
          onSelected: (value) => _applySuggestion(_activityController, value),
        ),
        const SizedBox(height: CasamaSpacing.md),

        Row(
          children: [
            Expanded(
              child: _PickerFieldTile(
                label: 'Date',
                value: _formatDate(_selectedDate),
                icon: Icons.calendar_today_rounded,
                semanticsLabel: 'Select Date',
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: CasamaSpacing.sm),
            Expanded(
              child: _PickerFieldTile(
                label: 'Time',
                value: _formatTime(_selectedTime),
                icon: Icons.schedule_rounded,
                semanticsLabel: 'Select Time',
                onTap: _pickTime,
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        CasamaTextField(
          controller: _locationController,
          label: 'Location / Link',
          hint: 'Where or what link? (e.g. Discord, Kitchen)',
          prefixIcon: Icons.location_on_outlined,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) {
            if (_validationError != null) {
              setState(() => _validationError = null);
            }
          },
        ),
        const SizedBox(height: CasamaSpacing.xs),
        _SuggestionPillRow(
          suggestions: _locationSuggestions,
          selectedValue: _locationController.text.trim(),
          onSelected: (value) => _applySuggestion(_locationController, value),
        ),
        const SizedBox(height: CasamaSpacing.sm),

        Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 15, color: pal.forestTeal),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Manual location or link label only — zero GPS tracking used.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        if (_validationError != null) ...[
          const SizedBox(height: CasamaSpacing.sm),
          Text(
            _validationError!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.dangerFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Send Agenda',
          icon: Icons.send_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _SuggestionPillRow extends StatelessWidget {
  final List<String> suggestions;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  const _SuggestionPillRow({
    required this.suggestions,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Semantics(
              button: true,
              label: suggestions[i],
              child: CasamaPressable(
                onTap: () => onSelected(suggestions[i]),
                enableHaptic: true,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selectedValue == suggestions[i]
                          ? pal.softSage
                          : pal.surface,
                      borderRadius: CasamaSpacing.roundedPill,
                      border: Border.all(
                        color: selectedValue == suggestions[i]
                            ? pal.forestTeal
                            : pal.border,
                      ),
                    ),
                    child: Text(
                      suggestions[i],
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: selectedValue == suggestions[i]
                            ? pal.forestTeal
                            : pal.textPrimary,
                        fontWeight: selectedValue == suggestions[i]
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerFieldTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _PickerFieldTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          button: true,
          label: semanticsLabel,
          value: value,
          child: CasamaPressable(
            onTap: onTap,
            enableHaptic: true,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: CasamaSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(color: pal.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: pal.forestTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: pal.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
