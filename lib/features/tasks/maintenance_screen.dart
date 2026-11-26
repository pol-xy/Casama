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
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../../shared/widgets/status_chip.dart';
import '../chore_roulette/widgets/task_roulette_sheet.dart';
import 'task_ui_state_provider.dart';
import 'widgets/add_task_sheet.dart';

/// Standalone Household Tasks route wrapper (`/maintenance`).
/// Reuses `TasksBoardView` to guarantee identical visual parity with the
/// unified `Boards` hub's `Tasks` tab.
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewTaskSheet(context),
        backgroundColor: pal.coralFab,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'New task',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Household Tasks',
              subtitle: '${repo.currentHousehold.name} • Chores & requests',
              titleMascotPose: CasPose.tasks,
              extendedWave: true,
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                CasamaHeaderActionPill(
                  icon: Icons.add_task_rounded,
                  label: 'New task',
                  onTap: () => showNewTaskSheet(context),
                ),
              ],
            ),
            const Expanded(
              child: TasksBoardView(bottomPadding: 100),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared Household Tasks Board tab content (`Boards -> Tasks` + `/maintenance`).
class TasksBoardView extends ConsumerStatefulWidget {
  final double bottomPadding;

  const TasksBoardView({super.key, this.bottomPadding = 120});

  @override
  ConsumerState<TasksBoardView> createState() => _TasksBoardViewState();
}

class _TasksBoardViewState extends ConsumerState<TasksBoardView> {
  String? _expandedTaskId;
  int _selectedSegment = 0;
  int _previousSegment = 0;

  Future<void> _openRoulette(MaintenanceTask task) {
    return showTaskRouletteSheet(context, task: task);
  }

  void _completeTask(MaintenanceTask task) {
    if (task.status == TaskStatus.done) return;
    final repo = ref.read(repositoryProvider);
    final isOwnTask =
        task.createdBy.isNotEmpty && task.createdBy == repo.currentUser.id;
    repo.completeTask(task.id);
    if (_expandedTaskId == task.id) {
      setState(() => _expandedTaskId = null);
    }
    showCasamaToast(
      context,
      isOwnTask
          ? 'Task marked as done'
          : 'Completed "${task.title}" (+${task.computedPoints} pts)',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final overrides = ref.watch(taskUiOverridesProvider);
    final currentUserId = repo.currentUser.id;

    final tasks = repo.tasks;
    final ongoingTasks = tasks
        .where((t) => t.status != TaskStatus.done)
        .toList();
    final completedTasks = tasks
        .where((t) => t.status == TaskStatus.done)
        .toList();
    final lowCount = ongoingTasks
        .where((t) => t.urgency == TaskUrgency.low)
        .length;
    final mediumCount = ongoingTasks
        .where((t) => t.urgency == TaskUrgency.medium)
        .length;
    final urgentCount = ongoingTasks
        .where((t) => t.urgency == TaskUrgency.urgent)
        .length;
    final totalOngoingPoints = ongoingTasks.fold<int>(
      0,
      (sum, t) => sum + t.computedPoints,
    );
    final visibleTasks = _selectedSegment == 0 ? ongoingTasks : completedTasks;
    final emptyTitle = _selectedSegment == 0
        ? 'No ongoing requests'
        : 'No completed requests yet';
    final emptySubtitle = _selectedSegment == 0
        ? 'Tap "New task" to create a chore, repair, restock, or request.'
        : 'Finished household tasks and chores will appear here.';

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 4, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            leftTitle: '${ongoingTasks.length} Open Tasks',
            leftSubtitleWidget: Semantics(
              container: true,
              excludeSemantics: true,
              label: '$lowCount low, $mediumCount medium, $urgentCount urgent',
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _UrgencyCountBadge(
                    count: lowCount,
                    bg: pal.successBg,
                    fg: pal.successFg,
                  ),
                  _UrgencyCountBadge(
                    count: mediumCount,
                    bg: pal.warningBg,
                    fg: pal.warningFg,
                  ),
                  _UrgencyCountBadge(
                    count: urgentCount,
                    bg: pal.dangerBg,
                    fg: pal.dangerFg,
                  ),
                ],
              ),
            ),
            rightTitle: '$totalOngoingPoints pts',
            rightSubtitle: 'Across ongoing requests',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaSegmentedTrack<int>(
            selectedValue: _selectedSegment,
            onSelected: (next) => setState(() {
              _previousSegment = _selectedSegment;
              _selectedSegment = next;
              _expandedTaskId = null;
            }),
            segments: const [
              CasamaFilterOption(value: 0, label: 'Ongoing Requests'),
              CasamaFilterOption(value: 1, label: 'Completed Requests'),
            ],
          ),
          const SizedBox(height: CasamaSpacing.xs),

          CasamaDirectionalSwitcher(
            index: _selectedSegment,
            previousIndex: _previousSegment,
            child: visibleTasks.isEmpty
                ? Padding(
                    key: ValueKey('tasks_empty_$_selectedSegment'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: CasamaCard(
                      padding: const EdgeInsets.all(CasamaSpacing.xl),
                      child: Column(
                        children: [
                          CasMascotView(
                            pose: CasPose.tasks,
                            height: 88,
                            semanticLabel: 'Tasks Mascot',
                          ),
                          const SizedBox(height: CasamaSpacing.sm),
                          Text(
                            emptyTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emptySubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    key: ValueKey('tasks_list_$_selectedSegment'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      children: [
                        for (final task in visibleTasks) ...[
                          _TaskCard(
                            task: task,
                            uiCategory: overrides.resolveCategory(task),
                            isDone: task.status == TaskStatus.done,
                            isOwnTask:
                                task.createdBy.isNotEmpty &&
                                task.createdBy == currentUserId,
                            isExpanded:
                                task.status != TaskStatus.done &&
                                _expandedTaskId == task.id,
                            onToggleExpand: () {
                              if (task.status == TaskStatus.done) return;
                              setState(() {
                                _expandedTaskId = _expandedTaskId == task.id
                                    ? null
                                    : task.id;
                              });
                            },
                            onMarkDone: task.status == TaskStatus.done
                                ? null
                                : () => _completeTask(task),
                            onSpin: () => _openRoulette(task),
                          ),
                          const SizedBox(height: CasamaSpacing.xs),
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

class _UrgencyCountBadge extends StatelessWidget {
  final int count;
  final Color bg;
  final Color fg;

  const _UrgencyCountBadge({
    required this.count,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: CasamaSpacing.roundedPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: fg,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.tabular.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final MaintenanceTask task;
  final CasamaTaskUiCategory uiCategory;
  final bool isDone;
  final bool isOwnTask;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onMarkDone;
  final VoidCallback onSpin;

  const _TaskCard({
    required this.task,
    required this.uiCategory,
    required this.isDone,
    required this.isOwnTask,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onMarkDone,
    required this.onSpin,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Duration animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    final (Color catBg, Color catFg) = uiCategory.badgeColors(pal);
    final String subtitle;
    if (isDone) {
      final completer =
          task.completedByName != null &&
              task.completedByName!.trim().isNotEmpty
          ? task.completedByName!.trim()
          : 'Housemate';
      subtitle = '${uiCategory.shortLabel} • Completed by $completer';
    } else {
      final dueSuffix = task.dueDate != null
          ? ' • Due ${DateFormat('MMM d').format(task.dueDate!)}'
          : '';
      subtitle = '${uiCategory.shortLabel} • By ${task.createdByName}$dueSuffix';
    }

    final (ChipVariant urgVariant, String urgLabel) = switch (task.urgency) {
      TaskUrgency.low => (ChipVariant.low, 'Low'),
      TaskUrgency.medium => (ChipVariant.medium, 'Medium'),
      TaskUrgency.urgent => (ChipVariant.urgent, 'Urgent'),
    };

    final headerContent = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: CasamaSpacing.minTouchTarget,
      ),
      child: Row(
        children: [
          if (!isDone) ...[
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: animDuration,
              curve: CasamaMotion.easeOut,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: isExpanded ? pal.forestTeal : pal.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: catBg,
              borderRadius: CasamaSpacing.roundedSm,
            ),
            child: Icon(uiCategory.icon, size: 17, color: catFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? pal.textMuted : pal.textPrimary,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(
            label: isDone ? 'Done' : urgLabel,
            variant: isDone ? ChipVariant.paid : urgVariant,
          ),
        ],
      ),
    );

    return CasamaCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderSide: !isDone && isExpanded
          ? BorderSide(
              color: pal.forestTeal.withValues(alpha: 0.45),
              width: 1.4,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDone)
            Semantics(
              button: true,
              expanded: isExpanded,
              label: '${task.title}, $subtitle',
              child: CasamaPressable(
                onTap: onToggleExpand,
                enableHaptic: false,
                child: headerContent,
              ),
            )
          else
            Semantics(
              label: '${task.title}, $subtitle',
              child: headerContent,
            ),

          if (!isDone) ...[
            if (reduceMotion) ...[
              if (isExpanded) _buildExpandedTray(pal),
            ] else
              AnimatedSize(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedOpacity(
                  duration: animDuration,
                  opacity: isExpanded ? 1.0 : 0.0,
                  child: isExpanded
                      ? _buildExpandedTray(pal)
                      : const SizedBox.shrink(),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedTray(CasamaPalette pal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TaskTrayButton(
                  label: 'Spin',
                  icon: Icons.casino_outlined,
                  bg: pal.softBlush,
                  fg: pal.primaryCoral,
                  borderColor: pal.primaryCoral.withValues(alpha: 0.25),
                  onTap: onSpin,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _TaskTrayButton(
                  label: 'Mark as Done',
                  trailingBadge: isOwnTask ? null : '+${task.computedPoints} pts',
                  icon: Icons.check_circle_outline_rounded,
                  bg: pal.forestTeal,
                  fg: pal.onForestTeal,
                  onTap: onMarkDone ?? () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskTrayButton extends StatelessWidget {
  final String label;
  final String? trailingBadge;
  final IconData icon;
  final Color bg;
  final Color fg;
  final Color? borderColor;
  final VoidCallback onTap;

  const _TaskTrayButton({
    required this.label,
    this.trailingBadge,
    required this.icon,
    required this.bg,
    required this.fg,
    this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: CasamaSpacing.roundedPill,
            border: borderColor != null ? Border.all(color: borderColor!) : null,
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (trailingBadge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: fg.withValues(alpha: 0.16),
                      borderRadius: CasamaSpacing.roundedPill,
                    ),
                    child: Text(
                      trailingBadge!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
