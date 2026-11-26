import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

/// Opens the unified slide-up Plan a Meet-up sheet matching
/// `casama-app-mockup.html` while keeping repository message posting identical.
Future<void> showCreateMeetupSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.calendar_month_rounded,
    title: 'Plan a Meet-up',
    subtitle: 'Suggest a time & spot for your household',
    builder: (sheetCtx) => _CreateMeetupSheetBody(hostContext: context),
  );
}

class _CreateMeetupSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _CreateMeetupSheetBody({required this.hostContext});

  @override
  ConsumerState<_CreateMeetupSheetBody> createState() =>
      _CreateMeetupSheetBodyState();
}

class _CreateMeetupSheetBodyState
    extends ConsumerState<_CreateMeetupSheetBody> {
  final _activityController = TextEditingController(text: 'Study Session 🎓');
  final _locationController = TextEditingController(text: 'Dorm Common Area');
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 19, minute: 0);
  final Set<String> _selectedInvitees = {'all'};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
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

  void _toggleInvitee(String key) {
    setState(() {
      if (key == 'all') {
        _selectedInvitees
          ..clear()
          ..add('all');
      } else {
        _selectedInvitees.remove('all');
        if (_selectedInvitees.contains(key)) {
          _selectedInvitees.remove(key);
        } else {
          _selectedInvitees.add(key);
        }
        if (_selectedInvitees.isEmpty) {
          _selectedInvitees.add('all');
        }
      }
    });
  }

  void _submit() {
    final activity = _activityController.text.trim();
    final location = _locationController.text.trim();
    if (activity.isEmpty || location.isEmpty) {
      showCasamaToast(
        widget.hostContext,
        'Please enter an activity and location.',
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

    ref.read(repositoryProvider).createMeetUp(
      activity: activity,
      location: location,
      scheduledTime: scheduledTime,
    );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Meet-up invitation sent to housemates!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final otherMembers = repo.members
        .where((m) => m.profile.id != repo.currentUser.id)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CasamaTextField(
          controller: _activityController,
          label: 'Activity Title',
          hint: 'e.g., Dinner, Study Session, Movie Night',
          prefixIcon: Icons.event_note_outlined,
          textCapitalization: TextCapitalization.sentences,
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
          label: 'Location / Shared Spot',
          hint: 'e.g., Dorm Common Area, Kitchen',
          prefixIcon: Icons.location_on_outlined,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: CasamaSpacing.sm),

        Row(
          children: [
            Icon(Icons.verified_user_outlined, size: 15, color: pal.forestTeal),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Manual spot label only — zero GPS tracking used.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        Text(
          'INVITEES',
          style: theme.textTheme.labelSmall?.copyWith(
            color: pal.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: CasamaSpacing.xs),
        Wrap(
          spacing: CasamaSpacing.xs,
          runSpacing: CasamaSpacing.xs,
          children: [
            _InviteeChip(
              label: 'All Housemates',
              selected: _selectedInvitees.contains('all'),
              onTap: () => _toggleInvitee('all'),
            ),
            for (final m in otherMembers)
              _InviteeChip(
                label: m.profile.displayName,
                avatarUrl: m.profile.avatarUrl,
                selected: _selectedInvitees.contains(m.profile.id),
                onTap: () => _toggleInvitee(m.profile.id),
              ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Send Invitation',
          icon: Icons.send_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _InviteeChip extends StatelessWidget {
  final String label;
  final String? avatarUrl;
  final bool selected;
  final VoidCallback onTap;

  const _InviteeChip({
    required this.label,
    this.avatarUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: CasamaSpacing.minTouchTarget,
          ),
          padding: EdgeInsets.only(
            left: avatarUrl != null ? 6 : 14,
            right: 14,
            top: 6,
            bottom: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? pal.forestTeal : pal.track,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: selected ? pal.forestTeal : pal.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatarUrl != null || label != 'All Housemates') ...[
                CasamaAvatar(
                  avatarUrl: avatarUrl,
                  radius: 13,
                  name: label,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? pal.onForestTeal : pal.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
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
