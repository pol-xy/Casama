import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../data/models.dart';

/// Four user-facing task categories rendered cleanly in `Create Task` and
/// `TasksBoardView` while mapping cleanly onto the backend `TaskCategory`
/// enum (`diy`, `landlord`, `restock`) without altering database constraints.
enum CasamaTaskUiCategory { cleaning, repair, restock, request }

extension CasamaTaskUiCategoryX on CasamaTaskUiCategory {
  String get label => switch (this) {
    CasamaTaskUiCategory.cleaning => 'Cleaning',
    CasamaTaskUiCategory.repair => 'Repair / Maintenance',
    CasamaTaskUiCategory.restock => 'Restock',
    CasamaTaskUiCategory.request => 'Personal Request',
  };

  String get shortLabel => switch (this) {
    CasamaTaskUiCategory.cleaning => 'Cleaning',
    CasamaTaskUiCategory.repair => 'Repair',
    CasamaTaskUiCategory.restock => 'Restock',
    CasamaTaskUiCategory.request => 'Request',
  };

  IconData get icon => switch (this) {
    CasamaTaskUiCategory.cleaning => Icons.cleaning_services_outlined,
    CasamaTaskUiCategory.repair => Icons.build_outlined,
    CasamaTaskUiCategory.restock => Icons.shopping_bag_outlined,
    CasamaTaskUiCategory.request => Icons.volunteer_activism_outlined,
  };

  TaskCategory get backendCategory => switch (this) {
    CasamaTaskUiCategory.cleaning => TaskCategory.cleaning,
    CasamaTaskUiCategory.repair => TaskCategory.repairMaintenance,
    CasamaTaskUiCategory.restock => TaskCategory.restock,
    CasamaTaskUiCategory.request => TaskCategory.personalRequest,
  };

  (Color bg, Color fg) badgeColors(CasamaPalette pal) => switch (this) {
    CasamaTaskUiCategory.cleaning => (pal.softSage, pal.forestTeal),
    CasamaTaskUiCategory.repair => (pal.warningBg, pal.warningFg),
    CasamaTaskUiCategory.restock => (pal.infoBg, pal.infoFg),
    CasamaTaskUiCategory.request => (pal.softBlush, pal.primaryCoral),
  };

  static CasamaTaskUiCategory fromTaskCategory(TaskCategory category) =>
      switch (category) {
        TaskCategory.cleaning ||
        TaskCategory.diy => CasamaTaskUiCategory.cleaning,
        TaskCategory.repairMaintenance ||
        TaskCategory.landlord => CasamaTaskUiCategory.repair,
        TaskCategory.restock => CasamaTaskUiCategory.restock,
        TaskCategory.personalRequest => CasamaTaskUiCategory.request,
      };
}

class TaskUiOverridesState {
  final Map<String, CasamaTaskUiCategory> categoryByTaskId;
  final Map<String, CasamaTaskUiCategory> categoryByTitle;

  const TaskUiOverridesState({
    this.categoryByTaskId = const {},
    this.categoryByTitle = const {},
  });

  TaskUiOverridesState copyWith({
    Map<String, CasamaTaskUiCategory>? categoryByTaskId,
    Map<String, CasamaTaskUiCategory>? categoryByTitle,
  }) {
    return TaskUiOverridesState(
      categoryByTaskId: categoryByTaskId ?? this.categoryByTaskId,
      categoryByTitle: categoryByTitle ?? this.categoryByTitle,
    );
  }

  CasamaTaskUiCategory resolveCategory(MaintenanceTask task) {
    return categoryByTaskId[task.id] ??
        categoryByTitle[task.title.trim()] ??
        CasamaTaskUiCategoryX.fromTaskCategory(task.category);
  }
}

class TaskUiOverridesNotifier extends StateNotifier<TaskUiOverridesState> {
  TaskUiOverridesNotifier() : super(const TaskUiOverridesState());

  void setCategoryForTask({
    String? taskId,
    required String title,
    required CasamaTaskUiCategory category,
  }) {
    final nextByTitle = Map<String, CasamaTaskUiCategory>.from(
      state.categoryByTitle,
    )..[title.trim()] = category;
    final nextById = Map<String, CasamaTaskUiCategory>.from(
      state.categoryByTaskId,
    );
    if (taskId != null && taskId.isNotEmpty) {
      nextById[taskId] = category;
    }
    state = state.copyWith(
      categoryByTaskId: nextById,
      categoryByTitle: nextByTitle,
    );
  }
}

final taskUiOverridesProvider =
    StateNotifierProvider<TaskUiOverridesNotifier, TaskUiOverridesState>(
      (ref) => TaskUiOverridesNotifier(),
    );
