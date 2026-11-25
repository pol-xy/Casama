import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';

/// Opens the unified slide-up New Task sheet matching `casama-app-mockup.html`
/// while keeping test-covered labels and repository bindings intact.
Future<void> showNewTaskSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.checklist_rounded,
    title: 'Create Maintenance Task',
    subtitle: 'Repair, chore or restock for your household',
    builder: (sheetContext) => _AddTaskSheetBody(hostContext: context),
  );
}

class _AddTaskSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _AddTaskSheetBody({required this.hostContext});

  @override
  ConsumerState<_AddTaskSheetBody> createState() => _AddTaskSheetBodyState();
}

class _AddTaskSheetBodyState extends ConsumerState<_AddTaskSheetBody> {
  TaskCategory _category = TaskCategory.diy;
  TaskUrgency _urgency = TaskUrgency.medium;
  late final TextEditingController _titleController;
  String? _selectedAssignee;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showCasamaToast(
        widget.hostContext,
        'Please enter a task title',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    ref
        .read(repositoryProvider)
        .addTask(
          title: title,
          category: _category,
          urgency: _urgency,
          assigneeName: _selectedAssignee == 'Unassigned'
              ? null
              : _selectedAssignee,
        );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Added task "$title"',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final memberOptions = [
      ...repo.members.map((m) => m.profile.displayName).toSet(),
      'Unassigned',
    ];
    _selectedAssignee ??= memberOptions.first;
    if (!memberOptions.contains(_selectedAssignee)) {
      _selectedAssignee = memberOptions.first;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Task Title',
            hintText: 'e.g., Fix front door knob, Restock detergent',
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        DropdownButtonFormField<TaskCategory>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: const [
            DropdownMenuItem(
              value: TaskCategory.diy,
              child: Text('DIY / Roommate'),
            ),
            DropdownMenuItem(
              value: TaskCategory.landlord,
              child: Text('Landlord / Admin'),
            ),
            DropdownMenuItem(
              value: TaskCategory.restock,
              child: Text('Household Restock'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _category = val);
          },
        ),
        const SizedBox(height: CasamaSpacing.md),

        DropdownButtonFormField<TaskUrgency>(
          initialValue: _urgency,
          decoration: const InputDecoration(labelText: 'Urgency Level'),
          items: const [
            DropdownMenuItem(
              value: TaskUrgency.urgent,
              child: Text('Urgent (Immediate)'),
            ),
            DropdownMenuItem(
              value: TaskUrgency.medium,
              child: Text('Medium Priority'),
            ),
            DropdownMenuItem(
              value: TaskUrgency.low,
              child: Text('Low Priority'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _urgency = val);
          },
        ),
        const SizedBox(height: CasamaSpacing.md),

        DropdownButtonFormField<String>(
          initialValue: _selectedAssignee,
          decoration: const InputDecoration(labelText: 'Assign Housemate'),
          items: memberOptions
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedAssignee = val);
          },
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Add Task',
          style: context.isDark
              ? CasamaButtonStyle.primary
              : CasamaButtonStyle.navy,
          isPill: true,
          height: 50,
          onPressed: _submit,
        ),
      ],
    );
  }
}
