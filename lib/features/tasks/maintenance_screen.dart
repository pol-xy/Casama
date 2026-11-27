import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ai/ai_providers.dart';
import '../../ai/naive_bayes_classifier.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/status_chip.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  final bool initialOpenAddModal;

  const MaintenanceScreen({super.key, this.initialOpenAddModal = false});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.initialOpenAddModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddTaskModal(context);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    ref.watch(taskClassifierProvider); // warm up the AI model in the background
    final allTasks = repo.tasks;
    final todoTasks = allTasks
        .where((t) => t.status == TaskStatus.open)
        .toList();
    final inProgressTasks = allTasks
        .where((t) => t.status == TaskStatus.inProgress)
        .toList();
    final doneTasks = allTasks
        .where((t) => t.status == TaskStatus.done)
        .toList();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Maintenance'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: TabBar(
              controller: _tabController,
              indicatorColor: CasamaColors.primaryCoral,
              indicatorWeight: 3,
              labelColor: CasamaColors.primaryCoral,
              unselectedLabelColor: context.textSecondaryColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'To Do'),
                Tab(text: 'In Progress'),
                Tab(text: 'Done'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _buildTaskList(allTasks),
              _buildTaskList(todoTasks),
              _buildTaskList(inProgressTasks),
              _buildTaskList(doneTasks),
            ],
          ),

          // Pinned Bottom Button: "+ Add a Task" (Dark Navy, matching Screen 5)
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: CasamaButton(
              label: 'Add a Task',
              icon: Icons.add,
              style: context.isDark
                  ? CasamaButtonStyle.primary
                  : CasamaButtonStyle.navy,
              onPressed: () => _showAddTaskModal(context),
              isPill: true,
              height: 52,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<MaintenanceTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CasMascotView(pose: CasPose.tasks, width: 140, height: 140),
            const SizedBox(height: 16),
            Text(
              'All tasks are clear!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enjoy a clean, well-coordinated home.',
              style: TextStyle(color: context.textSecondaryColor),
            ),
            const SizedBox(height: 80),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        left: CasamaSpacing.lg,
        right: CasamaSpacing.lg,
        top: CasamaSpacing.lg,
        bottom: 90,
      ),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _TaskCard(task: task);
      },
    );
  }

  void _showAddTaskModal(BuildContext context) {
    TaskCategory category = TaskCategory.diy;
    TaskUrgency urgency = TaskUrgency.medium;
    final titleController = TextEditingController();
    String? selectedAssignee = 'Jon Paul';

    // AI: Naive Bayes suggestion state. Once the user picks a dropdown
    // themselves, the AI stops overriding that field.
    TaskSuggestion? suggestion;
    bool userPickedCategory = false;
    bool userPickedUrgency = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create Maintenance Task',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      key: const Key('task_title_field'),
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText:
                            'e.g., Fix front door knob, Restock detergent',
                      ),
                      onChanged: (text) {
                        final classifier = ref
                            .read(taskClassifierProvider)
                            .valueOrNull;
                        if (classifier == null) return;
                        final s = classifier.suggest(text);
                        setModalState(() {
                          suggestion = s.isEmpty ? null : s;
                          if (s.shouldApplyCategory && !userPickedCategory) {
                            category = s.category!;
                          }
                          if (s.shouldApplyUrgency && !userPickedUrgency) {
                            urgency = s.urgency!;
                          }
                        });
                      },
                    ),
                    if (suggestion != null) ...[
                      const SizedBox(height: 10),
                      _AiSuggestionCard(suggestion: suggestion!),
                    ],
                    const SizedBox(height: 14),

                    // Category Selector
                    DropdownButtonFormField<TaskCategory>(
                      key: ValueKey('category_$category'),
                      initialValue: category,
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
                        if (val != null) {
                          setModalState(() {
                            category = val;
                            userPickedCategory = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Urgency Selector
                    DropdownButtonFormField<TaskUrgency>(
                      key: ValueKey('urgency_$urgency'),
                      initialValue: urgency,
                      decoration: const InputDecoration(
                        labelText: 'Urgency Level',
                      ),
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
                        if (val != null) {
                          setModalState(() {
                            urgency = val;
                            userPickedUrgency = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Assignee Selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedAssignee,
                      decoration: const InputDecoration(
                        labelText: 'Assign Housemate',
                      ),
                      items: ['Jon Paul', 'Maria', 'Alex', 'Ria', 'Unassigned']
                          .map(
                            (m) => DropdownMenuItem(value: m, child: Text(m)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedAssignee = val);
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    CasamaButton(
                      label: 'Add Task',
                      style: CasamaButtonStyle.navy,
                      onPressed: () {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a task title.'),
                            ),
                          );
                          return;
                        }
                        ref
                            .read(repositoryProvider)
                            .addTask(
                              title: titleController.text.trim(),
                              category: category,
                              urgency: urgency,
                              assigneeName: selectedAssignee == 'Unassigned'
                                  ? null
                                  : selectedAssignee,
                            );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Maintenance task created successfully!',
                            ),
                            backgroundColor: CasamaColors.midnightNavy,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// "Cas AI suggests…" card shown under the task title while typing.
class _AiSuggestionCard extends StatelessWidget {
  final TaskSuggestion suggestion;

  const _AiSuggestionCard({required this.suggestion});

  static String _categoryLabel(TaskCategory c) {
    switch (c) {
      case TaskCategory.diy:
        return 'DIY / Roommate';
      case TaskCategory.landlord:
        return 'Landlord / Admin';
      case TaskCategory.restock:
        return 'Household Restock';
    }
  }

  Widget _row(
    BuildContext context,
    String field,
    String value,
    double confidence,
    bool applied,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$field: ',
            style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
          ),
          Text(
            applied
                ? '${(confidence * 100).round()}% · applied'
                : '${(confidence * 100).round()}% · unsure',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: applied
                  ? CasamaColors.primaryCoral
                  : context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('ai_suggestion_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.isDark
            ? CasamaColors.darkSurface
            : const Color(0xFFFFECE8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🦉 Cas AI suggests',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: CasamaColors.primaryCoral,
            ),
          ),
          if (suggestion.category != null)
            _row(
              context,
              'Category',
              _categoryLabel(suggestion.category!),
              suggestion.categoryConfidence,
              suggestion.shouldApplyCategory,
            ),
          if (suggestion.urgency != null)
            _row(
              context,
              'Urgency',
              suggestion.urgency!.label,
              suggestion.urgencyConfidence,
              suggestion.shouldApplyUrgency,
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
    IconData categoryIcon;
    Color iconBg;
    Color iconColor;
    String subtitle;

    switch (task.category) {
      case TaskCategory.landlord:
        categoryIcon = Icons.water_drop_outlined;
        iconBg = const Color(0xFFE1F5FE);
        iconColor = const Color(0xFF0288D1);
        subtitle = 'Bathroom';
        break;
      case TaskCategory.restock:
        categoryIcon = Icons.local_mall_outlined;
        iconBg = const Color(0xFFE8EAF6);
        iconColor = const Color(0xFF3949AB);
        subtitle = 'Supplies';
        break;
      case TaskCategory.diy:
        categoryIcon = Icons.kitchen_outlined;
        iconBg = const Color(0xFFE8F5E9);
        iconColor = const Color(0xFF388E3C);
        subtitle = 'Kitchen';
        break;
    }

    ChipVariant chipVariant;
    String chipLabel;

    if (task.status == TaskStatus.done) {
      chipVariant = ChipVariant.returned;
      chipLabel = 'Done';
    } else if (task.category == TaskCategory.restock) {
      chipVariant = ChipVariant.toBuy;
      chipLabel = 'To Buy';
    } else {
      switch (task.urgency) {
        case TaskUrgency.urgent:
          chipVariant = ChipVariant.urgent;
          chipLabel = 'Urgent';
          break;
        case TaskUrgency.medium:
          chipVariant = ChipVariant.medium;
          chipLabel = 'Medium';
          break;
        case TaskUrgency.low:
          chipVariant = ChipVariant.low;
          chipLabel = 'Low';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: CasamaSpacing.roundedLg,
        border: Border.all(color: context.borderColor),
      ),
      child: Row(
        children: [
          // Category Icon in Soft Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.isDark ? iconBg.withValues(alpha: 0.25) : iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIcon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                    decoration: task.status == TaskStatus.done
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Urgency/Status Badge
          StatusChip(label: chipLabel, variant: chipVariant),
          const SizedBox(width: 10),

          // Assignee Avatar
          GestureDetector(
            onTap: () {
              if (task.status != TaskStatus.done) {
                ref.read(repositoryProvider).completeTask(task.id);
                final pts = task.category == TaskCategory.restock ? 2 : 5;
                _showTaskCompletedDialog(context, pts);
              }
            },
            child: Tooltip(
              message:
                  'Assigned to ${task.assigneeName ?? 'Unassigned'}. Tap to complete.',
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: CasamaColors.dustyBlue,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: task.assigneeAvatar != null
                      ? Image.network(
                          task.assigneeAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _fallbackAvatar(task.assigneeName),
                        )
                      : _fallbackAvatar(task.assigneeName),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(String? name) {
    return Center(
      child: Text(
        name != null && name.isNotEmpty ? name[0] : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showTaskCompletedDialog(BuildContext context, int points) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
          backgroundColor: CasamaColors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CasMascotView(pose: CasPose.tasks, width: 120, height: 120),
              const SizedBox(height: 12),
              Text(
                '+$points Kasama Points! 🎉',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: CasamaColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Task marked as completed. Thank you for looking out for the household!',
                style: TextStyle(
                  color: CasamaColors.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CasamaButton(
                label: 'Awesome!',
                onPressed: () => Navigator.pop(ctx),
                height: 44,
              ),
            ],
          ),
        );
      },
    );
  }
}
