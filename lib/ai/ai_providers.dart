/// Glue between the pure-Dart AI algorithms and the Casama app
/// (asset loading, Riverpod providers, and mapping repository data → CSP).
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_repository.dart';
import '../data/models.dart';
import 'chore_csp_solver.dart';
import 'naive_bayes_classifier.dart';

const String taskClassifierAsset = 'assets/ai/task_classifier_model.json';

/// Loads the trained Naive Bayes model once and caches it for the session.
final taskClassifierProvider = FutureProvider<NaiveBayesTaskClassifier>((
  ref,
) async {
  final raw = await rootBundle.loadString(taskClassifierAsset);
  return NaiveBayesTaskClassifier.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
});

/// Effort weight of an open task already on someone's plate.
/// Mirrors the app's points system (restock = 2 pts, other chores = 5 pts).
int taskEffort(MaintenanceTask t) => t.category == TaskCategory.restock ? 1 : 2;

/// The household member list shows the current user as "You", while tasks
/// store their real name; treat all of those as the same person.
Set<String> memberAliases(MemberPresence m, MockRepository repo) {
  final aliases = <String>{m.profile.displayName.toLowerCase()};
  if (m.profile.id == repo.currentUser.id) {
    final u = repo.currentUser;
    aliases.addAll(
      [
        u.displayName,
        u.displayName.split(' ').take(2).join(' '),
        u.fullName ?? '',
        u.nickname ?? '',
        'you',
      ].where((s) => s.trim().isNotEmpty).map((s) => s.toLowerCase()),
    );
  }
  return aliases;
}

/// Builds CSP members from live presence + task data in the repository.
List<CspMember> buildCspMembers(MockRepository repo) {
  return [
    for (final m in repo.members)
      () {
        final aliases = memberAliases(m, repo);
        final theirs = repo.tasks.where(
          (t) =>
              t.assigneeName != null &&
              aliases.contains(t.assigneeName!.toLowerCase()),
        );
        return CspMember(
          name: m.profile.displayName,
          isHome: m.isHome,
          existingLoad: theirs
              .where((t) => t.status != TaskStatus.done)
              .fold(0, (sum, t) => sum + taskEffort(t)),
          recentChores: theirs.map((t) => t.title).toSet(),
        );
      }(),
  ];
}
