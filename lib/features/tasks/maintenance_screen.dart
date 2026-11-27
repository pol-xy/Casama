import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_no_household_card.dart';
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
        if (mounted && ref.read(repositoryProvider).hasActiveHousehold) {
          showNewTaskSheet(context);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      floatingActionButton: repo.hasActiveHousehold
          ? FloatingActionButton.extended(
              onPressed: () => showNewTaskSheet(context),
              backgroundColor: pal.coralFab,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_task_rounded),
              label: const Text(
                'New task',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Household Tasks',
              subtitle: repo.hasActiveHousehold
                  ? '${repo.currentHousehold.name} • Chores & requests'
                  : 'No household yet • Chores & requests',
              titleMascotPose: CasPose.tasks,
              extendedWave: true,
              compact: true,
              onBackTap: () =>
                  context.canPop() ? context.pop() : context.go('/boards'),
              rightActions: [
                if (repo.hasActiveHousehold)
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
    final rouletteRecord = repo.rouletteRecordForTask(task.id);
    final isOwnTask =
        task.createdBy.isNotEmpty && task.createdBy == repo.currentUser.id;
    final rewardPoints = task.rewardPointsForUser(
      repo.currentUser.id,
      rouletteRecord: rouletteRecord,
    );
    repo.completeTask(task.id);
    if (_expandedTaskId == task.id) {
      setState(() => _expandedTaskId = null);
    }
    showCasamaToast(
      context,
      isOwnTask || rewardPoints <= 0
          ? 'Task marked as done'
          : 'Completed "${task.title}" (+$rewardPoints pts)',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  String _resolveViewerName(
    CasamaRepository repo,
    String userId,
    String fallbackName,
  ) {
    return repo.resolveHousemateName(
      userId,
      fallback: fallbackName,
      useYouForCurrentUser: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    if (!repo.hasActiveHousehold) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          CasamaSpacing.md,
          CasamaSpacing.md,
          CasamaSpacing.md,
          widget.bottomPadding,
        ),
        child: const CasamaNoHouseholdPrompt(
          title: 'Join a household',
          subtitle:
              'Track shared chores, earn Good Kasama points, and spin Task Roulette once you join or create a household.',
          mascotPose: CasPose.tasks,
        ),
      );
    }
    final overrides = ref.watch(taskUiOverridesProvider);
    final currentUserId = repo.currentUser.id;

    final tasks = repo.tasks;
    final rouletteByTaskId = <String, ChoreRouletteRecord>{
      for (final r in repo.rouletteRecords)
        if (r.taskId != null && r.taskId!.isNotEmpty) r.taskId!: r,
    };
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
      (sum, t) =>
          sum +
          t.rewardPointsForUser(
            currentUserId,
            rouletteRecord: rouletteByTaskId[t.id],
          ),
    );
    final visibleTasks = _selectedSegment == 0 ? ongoingTasks : completedTasks;
    final emptyTitle = _selectedSegment == 0
        ? 'No ongoing tasks'
        : 'No completed tasks yet';
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
            rightSubtitle: 'Across ongoing tasks',
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
              CasamaFilterOption(value: 0, label: 'Ongoing Tasks'),
              CasamaFilterOption(value: 1, label: 'Completed Tasks'),
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
                          Builder(
                            builder: (_) {
                              final rouletteRecord = rouletteByTaskId[task.id];
                              final spinnerLabel = rouletteRecord != null
                                  ? _resolveViewerName(
                                      repo,
                                      rouletteRecord.spunByUserId,
                                      rouletteRecord.spunByName,
                                    )
                                  : null;
                              final chosenLabel = rouletteRecord != null
                                  ? _resolveViewerName(
                                      repo,
                                      rouletteRecord.selectedUserId,
                                      rouletteRecord.selectedUserName,
                                    )
                                  : null;
                              return _TaskCard(
                                task: task,
                                uiCategory: overrides.resolveCategory(task),
                                rouletteRecord: rouletteRecord,
                                spinnerLabel: spinnerLabel,
                                chosenLabel: chosenLabel,
                                creatorLabel: repo.resolveHousemateName(
                                  task.createdBy,
                                  fallback: task.createdByName,
                                ),
                                completerLabel: repo.resolveHousemateName(
                                  task.completedById,
                                  fallback: task.completedByName ?? 'Housemate',
                                ),
                                isDone: task.status == TaskStatus.done,
                                isOwnTask:
                                    task.createdBy.isNotEmpty &&
                                    task.createdBy == currentUserId,
                                viewerRewardPoints: task.rewardPointsForUser(
                                  currentUserId,
                                  rouletteRecord: rouletteRecord,
                                ),
                                isViewerChosen: task.isBonusEligibleForUser(
                                  currentUserId,
                                  rouletteRecord: rouletteRecord,
                                ),
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
                              );
                            },
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
  final ChoreRouletteRecord? rouletteRecord;
  final String? spinnerLabel;
  final String? chosenLabel;
  final String creatorLabel;
  final String completerLabel;
  final bool isDone;
  final bool isOwnTask;
  final int viewerRewardPoints;
  final bool isViewerChosen;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback? onMarkDone;
  final VoidCallback onSpin;

  const _TaskCard({
    required this.task,
    required this.uiCategory,
    this.rouletteRecord,
    this.spinnerLabel,
    this.chosenLabel,
    required this.creatorLabel,
    required this.completerLabel,
    required this.isDone,
    required this.isOwnTask,
    required this.viewerRewardPoints,
    required this.isViewerChosen,
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
      subtitle = '${uiCategory.shortLabel} • Completed by $completerLabel';
    } else {
      final dueSuffix = task.dueDate != null
          ? ' • Due ${DateFormat('MMM d').format(task.dueDate!)}'
          : '';
      subtitle = '${uiCategory.shortLabel} • By $creatorLabel$dueSuffix';
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

          const SizedBox(height: 8),
          _buildRouletteStatusStrip(context, pal, theme),

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

  Widget _buildRouletteStatusStrip(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
  ) {
    final record = rouletteRecord;
    if (record == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: pal.track,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.casino_outlined, size: 13, color: pal.textSecondary),
              const SizedBox(width: 5),
              Text(
                'Unspun',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pal.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spinner = spinnerLabel ?? record.spunByName;
    final chosen = chosenLabel ?? record.selectedUserName;
    final isViewerChosenHighlight = chosen == 'You';
    final isViewerSpinner = spinner == 'You';

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          key: ValueKey('task_spun_by_pill_${task.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: pal.softSage.withValues(alpha: 0.72),
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: pal.forestTeal.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.casino_outlined,
                size: 13.5,
                color: pal.forestTeal,
              ),
              const SizedBox(width: 5),
              Text.rich(
                TextSpan(
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11.5,
                    color: pal.textSecondary,
                  ),
                  children: [
                    const TextSpan(text: 'Spun by '),
                    TextSpan(
                      text: spinner,
                      style: TextStyle(
                        fontWeight: isViewerSpinner
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isViewerSpinner
                            ? pal.forestTeal
                            : pal.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          key: ValueKey('task_chosen_pill_${task.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isViewerChosenHighlight
                ? pal.softBlush.withValues(alpha: 0.85)
                : pal.track,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: isViewerChosenHighlight
                  ? pal.primaryCoral.withValues(alpha: 0.38)
                  : pal.border,
            ),
          ),
          child: Text.rich(
            TextSpan(
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11.5,
                color: pal.textSecondary,
              ),
              children: [
                const TextSpan(text: 'Chosen: '),
                TextSpan(
                  text: chosen,
                  style: TextStyle(
                    fontWeight: isViewerChosenHighlight
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: isViewerChosenHighlight
                        ? pal.primaryCoral
                        : pal.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isViewerChosen && !isOwnTask)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: pal.amberBg,
              borderRadius: CasamaSpacing.roundedPill,
              border: Border.all(color: pal.amberFg.withValues(alpha: 0.32)),
            ),
            child: Text(
              '+$viewerRewardPoints pts (+${record.bonusPoints} bonus)',
              style: theme.textTheme.labelSmall?.tabular.copyWith(
                color: pal.amberFg,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildExpandedTray(CasamaPalette pal) {
    final record = rouletteRecord;
    final showPointsBadge = !isOwnTask && viewerRewardPoints > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              if (record == null) ...[
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
              ],
              Expanded(
                flex: 2,
                child: _TaskTrayButton(
                  label: 'Mark as Done',
                  trailingBadge: showPointsBadge
                      ? '+$viewerRewardPoints pts'
                      : null,
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
          height: 48,
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
