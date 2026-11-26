import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
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
  DateTime? _cooldownUntil;
  String? _expandedTaskId;

  @override
  void initState() {
    super.initState();
    _loadCooldown();
  }

  Future<void> _loadCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(rouletteLastSpinPrefKey);
      if (lastMs != null) {
        final until = DateTime.fromMillisecondsSinceEpoch(
          lastMs,
        ).add(const Duration(hours: 24));
        if (until.isAfter(DateTime.now()) && mounted) {
          setState(() => _cooldownUntil = until);
        }
      }
    } catch (_) {}
  }

  Future<void> _openRoulette([MaintenanceTask? task]) async {
    await showTaskRouletteSheet(context, task: task);
    if (mounted) _loadCooldown();
  }

  void _toggleTaskCompletion(MaintenanceTask task, bool currentlyDone) {
    final uiNotifier = ref.read(taskUiOverridesProvider.notifier);
    final repo = ref.read(repositoryProvider);

    if (currentlyDone) {
      uiNotifier.markUndone(task.id);
      repo.updateTaskStatus(task.id, TaskStatus.open);
      if (_expandedTaskId == task.id) {
        setState(() => _expandedTaskId = null);
      }
      showCasamaToast(
        context,
        'Reopened "${task.title}"',
        icon: Icons.replay_rounded,
      );
    } else {
      uiNotifier.markDone(task.id);
      if (task.status != TaskStatus.done) {
        repo.completeTask(task.id);
      }
      if (_expandedTaskId == task.id) {
        setState(() => _expandedTaskId = null);
      }
      showCasamaToast(
        context,
        'Completed "${task.title}" (+5 pts)',
        icon: Icons.check_circle_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final overrides = ref.watch(taskUiOverridesProvider);

    final tasks = repo.tasks;
    final openTasks = tasks.where((t) => !overrides.isTaskDone(t)).toList();
    final completedTasks = tasks.where((t) => overrides.isTaskDone(t)).toList();
    final urgentCount = openTasks
        .where((t) => t.urgency == TaskUrgency.urgent)
        .length;
    final orderedTasks = [...openTasks, ...completedTasks];

    final bool onCooldown =
        _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());
    final Duration remaining = onCooldown
        ? _cooldownUntil!.difference(DateTime.now())
        : Duration.zero;
    final String cooldownLabel = onCooldown
        ? '${remaining.inHours}h ${(remaining.inMinutes % 60)}m cooldown'
        : 'Ready to spin';

    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 46, bottom: widget.bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaPeekingSummaryBar(
            mascotPose: CasPose.tasks,
            leftTitle: '${openTasks.length} Open Tasks',
            leftSubtitle: '$urgentCount urgent • ${tasks.length} total',
            rightTitle: '${completedTasks.length} Done',
            rightSubtitle: 'Completed log',
            rightTitleColor: pal.forestTeal,
          ),
          const SizedBox(height: CasamaSpacing.md),

          // Task Roulette Quick-Launch Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
            child: CasamaCard(
              onTap: () => _openRoulette(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: pal.softBlush,
                      borderRadius: CasamaSpacing.roundedMd,
                      border: Border.all(
                        color: pal.primaryCoral.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      Icons.casino_outlined,
                      color: pal.primaryCoral,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chore & Task Roulette',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Need a fair pick? $cooldownLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: onCooldown ? pal.warningFg : pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: onCooldown ? pal.track : pal.primaryCoral,
                      borderRadius: CasamaSpacing.roundedPill,
                    ),
                    child: Text(
                      onCooldown ? 'Cooldown' : 'Quick Spin',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: onCooldown
                            ? pal.textSecondary
                            : pal.onPrimaryCoral,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CasamaSpacing.md),

          if (orderedTasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
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
                      'No household tasks yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Add task" below to create a chore, repair, restock, or request.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
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
                  for (final task in orderedTasks) ...[
                    _TaskCard(
                      task: task,
                      uiCategory: overrides.resolveCategory(task),
                      assigneeName: overrides.resolveAssignee(task),
                      isDone: overrides.isTaskDone(task),
                      isExpanded: _expandedTaskId == task.id,
                      onToggleExpand: () {
                        setState(() {
                          _expandedTaskId = _expandedTaskId == task.id
                              ? null
                              : task.id;
                        });
                      },
                      onToggleDone: () => _toggleTaskCompletion(
                        task,
                        overrides.isTaskDone(task),
                      ),
                      onSpin: () => _openRoulette(task),
                    ),
                    const SizedBox(height: CasamaSpacing.xs),
                  ],
                ],
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
  final String? assigneeName;
  final bool isDone;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleDone;
  final VoidCallback onSpin;

  const _TaskCard({
    required this.task,
    required this.uiCategory,
    required this.assigneeName,
    required this.isDone,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggleDone,
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
    final bool hasAssignee =
        assigneeName != null && assigneeName!.trim().isNotEmpty;
    final String subtitle = hasAssignee
        ? '${uiCategory.shortLabel} • $assigneeName'
        : '${uiCategory.shortLabel} • Unassigned';

    final (ChipVariant urgVariant, String urgLabel) = switch (task.urgency) {
      TaskUrgency.low => (ChipVariant.low, 'Low'),
      TaskUrgency.medium => (ChipVariant.medium, 'Medium'),
      TaskUrgency.urgent => (ChipVariant.urgent, 'Urgent'),
    };

    return CasamaCard(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      borderSide: isExpanded
          ? BorderSide(
              color: pal.forestTeal.withValues(alpha: 0.45),
              width: 1.4,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Independent 48x48dp completion checkbox
              Semantics(
                button: true,
                checked: isDone,
                label: isDone
                    ? 'Mark ${task.title} undone'
                    : 'Mark ${task.title} done',
                child: CasamaPressable(
                  onTap: onToggleDone,
                  enableHaptic: true,
                  child: SizedBox(
                    width: CasamaSpacing.minTouchTarget,
                    height: CasamaSpacing.minTouchTarget,
                    child: Center(
                      child: AnimatedContainer(
                        duration: animDuration,
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isDone ? pal.forestTeal : pal.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDone ? pal.forestTeal : pal.inputBorder,
                            width: 1.6,
                          ),
                        ),
                        child: isDone
                            ? Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: pal.onForestTeal,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),

              // Card body tap -> smooth expand/collapse inline tray
              Expanded(
                child: CasamaPressable(
                  onTap: onToggleExpand,
                  enableHaptic: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
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
                                  color: isDone
                                      ? pal.textMuted
                                      : pal.textPrimary,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
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
                                  color: hasAssignee
                                      ? pal.textSecondary
                                      : pal.textMuted,
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
                        if (hasAssignee) ...[
                          const SizedBox(width: 6),
                          CasamaAvatar(radius: 13, name: assigneeName!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Inline collapsible tray (`Spin` + `Mark as Done` or `Mark Undone`)
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
          if (!isDone)
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
                    trailingBadge: '+5 pts',
                    icon: Icons.check_circle_outline_rounded,
                    bg: pal.forestTeal,
                    fg: pal.onForestTeal,
                    onTap: onToggleDone,
                  ),
                ),
              ],
            )
          else
            _TaskTrayButton(
              label: 'Mark Undone',
              icon: Icons.replay_rounded,
              bg: pal.track,
              fg: pal.textPrimary,
              borderColor: pal.border,
              onTap: onToggleDone,
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
