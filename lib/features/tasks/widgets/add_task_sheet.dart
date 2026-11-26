import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';
import '../task_ui_state_provider.dart';

/// Opens the unified slide-up Create Task sheet (`280ms` ease-out rise,
/// Light/Dark parity). Any household member can create and complete tasks.
Future<void> showNewTaskSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.build_outlined,
    title: 'Create Task',
    subtitle: 'Add a chore, repair, restock, or request',
    builder: (sheetCtx) => _AddTaskSheetBody(hostContext: context),
  );
}

class _AddTaskSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _AddTaskSheetBody({required this.hostContext});

  @override
  ConsumerState<_AddTaskSheetBody> createState() => _AddTaskSheetBodyState();
}

class _AddTaskSheetBodyState extends ConsumerState<_AddTaskSheetBody> {
  final TextEditingController _titleController = TextEditingController();
  CasamaTaskUiCategory _selectedCategory = CasamaTaskUiCategory.cleaning;
  TaskUrgency _selectedUrgency = TaskUrgency.medium;

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
        'Please enter a task title.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final repo = ref.read(repositoryProvider);
    final selectedUiCategory = _selectedCategory;
    repo.addTask(
      title: title,
      category: selectedUiCategory.backendCategory,
      urgency: _selectedUrgency,
    );

    final createdTask = repo.tasks.cast<MaintenanceTask?>().firstWhere(
      (t) => t?.title.trim() == title,
      orElse: () => null,
    );
    ref
        .read(taskUiOverridesProvider.notifier)
        .setCategoryForTask(
          taskId: createdTask?.id,
          title: title,
          category: selectedUiCategory,
        );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Task "$title" added to board!',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final previewPoints = MaintenanceTask.computePoints(
      _selectedCategory.backendCategory,
      _selectedUrgency,
    );
    const topRow = [
      CasamaTaskUiCategory.cleaning,
      CasamaTaskUiCategory.repair,
    ];
    const bottomRow = [
      CasamaTaskUiCategory.restock,
      CasamaTaskUiCategory.request,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CasamaTextField(
          controller: _titleController,
          label: 'Task Title',
          hint: 'e.g., Restock bathroom tissues',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CasamaSpacing.md),

        Text(
          'Category',
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: CasamaSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _CategoryOptionCard(
                category: topRow[0],
                selected: _selectedCategory == topRow[0],
                onTap: () => setState(() => _selectedCategory = topRow[0]),
              ),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            Expanded(
              child: _CategoryOptionCard(
                category: topRow[1],
                selected: _selectedCategory == topRow[1],
                onTap: () => setState(() => _selectedCategory = topRow[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _CategoryOptionCard(
                category: bottomRow[0],
                selected: _selectedCategory == bottomRow[0],
                onTap: () => setState(() => _selectedCategory = bottomRow[0]),
              ),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            Expanded(
              child: _CategoryOptionCard(
                category: bottomRow[1],
                selected: _selectedCategory == bottomRow[1],
                onTap: () => setState(() => _selectedCategory = bottomRow[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        Text(
          'Urgency Level',
          style: theme.textTheme.labelMedium?.copyWith(
            color: pal.textSecondary,
          ),
        ),
        const SizedBox(height: CasamaSpacing.xs),
        Row(
          children: [
            _UrgencyChip(
              label: 'Low',
              selected: _selectedUrgency == TaskUrgency.low,
              color: pal.forestTeal,
              bg: pal.softSage,
              onTap: () => setState(() => _selectedUrgency = TaskUrgency.low),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            _UrgencyChip(
              label: 'Medium',
              selected: _selectedUrgency == TaskUrgency.medium,
              color: pal.warningFg,
              bg: pal.warningBg,
              onTap: () =>
                  setState(() => _selectedUrgency = TaskUrgency.medium),
            ),
            const SizedBox(width: CasamaSpacing.xs),
            _UrgencyChip(
              label: 'Urgent',
              selected: _selectedUrgency == TaskUrgency.urgent,
              color: pal.dangerFg,
              bg: pal.dangerBg,
              onTap: () =>
                  setState(() => _selectedUrgency = TaskUrgency.urgent),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: pal.softSage,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: pal.forestTeal.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.stars_rounded, size: 18, color: pal.forestTeal),
              const SizedBox(width: 8),
              Text(
                'Task Reward: +$previewPoints pts',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: pal.forestTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Create Task',
          icon: Icons.add_task_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _CategoryOptionCard extends StatelessWidget {
  final CasamaTaskUiCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryOptionCard({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final (tintBg, tintFg) = category.badgeColors(pal);

    return Semantics(
      button: true,
      selected: selected,
      label: category.label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? tintBg : pal.track,
            borderRadius: CasamaSpacing.roundedMd,
            border: Border.all(
              color: selected ? tintFg : pal.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                category.icon,
                size: 18,
                color: selected ? tintFg : pal.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? tintFg : pal.textPrimary,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 12,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _UrgencyChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label urgency',
        child: CasamaPressable(
          onTap: onTap,
          enableHaptic: true,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: CasamaSpacing.minTouchTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? bg : pal.track,
              borderRadius: CasamaSpacing.roundedPill,
              border: Border.all(
                color: selected ? color : pal.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? color : pal.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
