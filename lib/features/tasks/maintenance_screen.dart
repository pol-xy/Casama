import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import '../chore_roulette/widgets/task_roulette_sheet.dart';
import 'widgets/add_task_sheet.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  final bool initialOpenAddModal;

  const MaintenanceScreen({super.key, this.initialOpenAddModal = false});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.initialOpenAddModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showNewTaskSheet(context);
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
        child: Stack(
          children: [
            Column(
              children: [
                CasamaWaveHeader(
                  title: 'Household Tasks',
                  subtitle:
                      '${repo.currentHousehold.name} • Repairs, chores & restocks',
                  compact: true,
                  onBackTap: () =>
                      context.canPop() ? context.pop() : context.go('/boards'),
                  rightActions: [
                    CasamaHeaderActionPill(
                      icon: Icons.casino_outlined,
                      label: 'Spin Roulette',
                      onTap: () => showTaskRouletteSheet(context),
                    ),
                  ],
                ),
                const Expanded(child: TasksBoardView(bottomPadding: 96)),
              ],
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: MediaQuery.paddingOf(context).bottom + 18,
              child: CasamaButton(
                label: 'Add a Task',
                icon: Icons.add_rounded,
                style: context.isDark
                    ? CasamaButtonStyle.primary
                    : CasamaButtonStyle.navy,
                onPressed: () => showNewTaskSheet(context),
                isPill: true,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable Tasks board tab body shared by [BoardsScreen] and standalone [MaintenanceScreen].
class TasksBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const TasksBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<TasksBoardView> createState() => _TasksBoardViewState();
}

class _TasksBoardViewState extends ConsumerState<TasksBoardView> {
  int _selectedFilter = 0; // 0 = All, 1 = To Do, 2 = In Progress, 3 = Done

  static const _filters = [
    CasamaFilterOption(value: 0, label: 'All'),
    CasamaFilterOption(value: 1, label: 'To Do'),
    CasamaFilterOption(value: 2, label: 'In Progress'),
    CasamaFilterOption(value: 3, label: 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final allTasks = repo.tasks;

    final activeTasks = allTasks
        .where((t) => t.status != TaskStatus.done)
        .toList();
    final urgentCount = activeTasks
        .where((t) => t.urgency == TaskUrgency.urgent)
        .length;
    final inProgressCount = activeTasks
        .where((t) => t.status == TaskStatus.inProgress)
        .length;

    final filtered = switch (_selectedFilter) {
      1 => allTasks.where((t) => t.status == TaskStatus.open).toList(),
      2 => allTasks.where((t) => t.status == TaskStatus.inProgress).toList(),
      3 => allTasks.where((t) => t.status == TaskStatus.done).toList(),
      _ => allTasks,
    };

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 26, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.tasks,
            leftTitle: '${activeTasks.length} Active Tasks',
            leftSubtitle: '$urgentCount Urgent • $inProgressCount In Progress',
            rightTitle: '+5 / +2 pts',
            rightSubtitle: 'Task & restock rewards',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaPillFilterRail<int>(
            options: _filters,
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
                    const CasMascotView(
                      pose: CasPose.tasks,
                      width: 112,
                      height: 112,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All tasks are clear!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enjoy a clean, well-coordinated home.',
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
                    if (i > 0) const SizedBox(height: 10),
                    _TaskCard(task: filtered[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final MaintenanceTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final reduced = CasamaMotion.reduceMotion(context);
    final isDone = task.status == TaskStatus.done;

    final IconData categoryIcon;
    final Color iconBg;
    final Color iconColor;
    final String categoryLabel;

    switch (task.category) {
      case TaskCategory.landlord:
        categoryIcon = Icons.build_outlined;
        iconBg = pal.softBlush;
        iconColor = pal.primaryCoral;
        categoryLabel = 'Landlord / Admin';
      case TaskCategory.restock:
        categoryIcon = Icons.shopping_bag_outlined;
        iconBg = pal.infoBg;
        iconColor = pal.infoFg;
        categoryLabel = 'Household Restock';
      case TaskCategory.diy:
        categoryIcon = Icons.cleaning_services_outlined;
        iconBg = pal.amberBg;
        iconColor = pal.amberFg;
        categoryLabel = 'DIY / Roommate';
    }

    final ChipVariant chipVariant;
    final String chipLabel;
    if (isDone) {
      chipVariant = ChipVariant.returned;
      chipLabel = 'Done';
    } else if (task.category == TaskCategory.restock) {
      chipVariant = ChipVariant.toBuy;
      chipLabel = 'To Buy';
    } else {
      chipVariant = switch (task.urgency) {
        TaskUrgency.urgent => ChipVariant.urgent,
        TaskUrgency.medium => ChipVariant.medium,
        TaskUrgency.low => ChipVariant.low,
      };
      chipLabel = task.urgency.label;
    }

    final isUnassignedOpen =
        !isDone && (task.assigneeName == null || task.assigneeName!.isEmpty);
    final pointsReward = task.category == TaskCategory.restock ? 2 : 5;
    final assigneePart = task.assigneeName?.isNotEmpty == true
        ? task.assigneeName!
        : 'Unassigned';

    void completeThisTask() {
      if (isDone) return;
      ref.read(repositoryProvider).completeTask(task.id);
      _showTaskCompletedDialog(context, pointsReward);
    }

    return CasamaCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // Tactile strikethrough checkbox (48x48dp hit area)
          Semantics(
            checked: isDone,
            label: 'Complete ${task.title}',
            child: CasamaPressable(
              enableHaptic: true,
              onTap: completeThisTask,
              child: SizedBox(
                width: 40,
                height: 48,
                child: Center(
                  child: AnimatedContainer(
                    duration: reduced ? Duration.zero : CasamaMotion.press,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isDone ? pal.forestTeal : pal.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone ? pal.forestTeal : pal.textMuted,
                        width: 1.6,
                      ),
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),

          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(categoryIcon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: reduced ? Duration.zero : CasamaMotion.press,
                  style: (theme.textTheme.titleMedium ?? const TextStyle())
                      .copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDone ? pal.textSecondary : pal.textPrimary,
                        decoration: isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                      ),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$categoryLabel • $assigneePart',
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

          if (isUnassignedOpen)
            Semantics(
              button: true,
              label: 'Spin Task Roulette for ${task.title}',
              child: CasamaPressable(
                enableHaptic: true,
                onTap: () => showTaskRouletteSheet(context, task: task),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: pal.softBlush,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(
                      color: pal.primaryCoral.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.casino_outlined,
                        size: 14,
                        color: pal.primaryCoral,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Spin',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pal.primaryCoral,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusChip(label: chipLabel, variant: chipVariant),
                if (task.assigneeName != null &&
                    task.assigneeName!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  CasamaAvatar(
                    radius: 15,
                    avatarUrl: task.assigneeAvatar,
                    name: task.assigneeName,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _showTaskCompletedDialog(BuildContext context, int points) {
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
                pose: CasPose.tasks,
                width: 118,
                height: 118,
              ),
              const SizedBox(height: 10),
              Text(
                '+$points Kasama Points!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Task marked as completed. Thank you for looking out for the household.',
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
