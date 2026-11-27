/// Casama AI — Fair chore assignment as a Constraint Satisfaction Problem.
///
/// Formulation
///   Variables   X_i  = one per chore to assign
///   Domains     D_i  = housemates who could do chore i
///   Hard constraints
///     C1 availability  : a chore marked `requiresHome` can only go to a
///                        housemate whose presence is currently "Home".
///     C2 capacity      : nobody gets more than ceil(chores / eligible members)
///                        chores in one round (no one is dumped on).
///   Soft constraints (objective to minimise, solved with branch & bound)
///     S1 balance       : Σ_m (existingLoad_m + assignedEffort_m)²
///                        — sum of squares is minimal when loads are even,
///                          so housemates who already carry open tasks get less.
///     S2 rotation      : +[repeatPenalty] each time someone gets a chore they
///                        already had last time (keeps chores rotating).
///
/// Search: backtracking with
///   • MRV  (Minimum Remaining Values) to pick the next chore,
///     tie-broken by highest effort (hardest chores placed first);
///   • least-cost value ordering (try the housemate that adds the least cost);
///   • forward checking on the capacity constraint (prune domains, detect
///     dead-ends early);
///   • branch & bound: prune any branch whose admissible lower bound
///     (partial cost + cheapest possible cost of each remaining chore)
///     is already ≥ the best complete assignment found so far.
/// The result is therefore an OPTIMAL assignment under the objective above.
///
/// Pure Dart (no Flutter imports) so it can be unit-tested and benchmarked.
library;

/// A chore to be assigned.
class CspChore {
  final String title;

  /// Relative effort, e.g. 1 = quick (wipe counters), 3 = heavy (clean CR).
  final int effort;

  /// Must be done now, so only housemates who are home can take it.
  final bool requiresHome;

  const CspChore({
    required this.title,
    this.effort = 1,
    this.requiresHome = false,
  });
}

/// A housemate who can receive chores.
class CspMember {
  final String name;
  final bool isHome;

  /// Effort already on this person's plate (open tasks assigned to them).
  final int existingLoad;

  /// Chore titles this person did / was given last time (for rotation).
  final Set<String> recentChores;

  const CspMember({
    required this.name,
    required this.isHome,
    this.existingLoad = 0,
    this.recentChores = const {},
  });
}

class ChoreAssignment {
  final CspChore chore;
  final CspMember member;

  /// Human-readable reason shown in the app ("why this person?").
  final String reason;

  const ChoreAssignment({
    required this.chore,
    required this.member,
    required this.reason,
  });
}

/// Search statistics — reported in the README results.
class CspStats {
  final int nodesExpanded;
  final int backtracks;
  final int boundPrunes;
  final int forwardCheckPrunes;
  final Duration elapsed;

  const CspStats({
    required this.nodesExpanded,
    required this.backtracks,
    required this.boundPrunes,
    required this.forwardCheckPrunes,
    required this.elapsed,
  });
}

class CspResult {
  /// Null when the hard constraints cannot be satisfied (e.g. nobody is home
  /// for a chore that requires it).
  final List<ChoreAssignment>? assignments;
  final double cost;
  final Map<String, int> finalLoads;
  final int capacity;

  /// True when the capacity limit (C2) had to be raised to find a solution.
  final bool capacityRelaxed;
  final CspStats stats;
  final String? failureReason;

  const CspResult({
    required this.assignments,
    required this.cost,
    required this.finalLoads,
    required this.capacity,
    this.capacityRelaxed = false,
    required this.stats,
    this.failureReason,
  });

  bool get isSolved => assignments != null;
}

class ChoreCspSolver {
  final int repeatPenalty;

  /// Safety valve for very large inputs; the household sizes in Casama are
  /// tiny (≤ 10 chores × ≤ 8 people) and finish in a few hundred nodes.
  final int maxNodes;

  /// Heuristic switches — all on in the app; turned off one at a time in
  /// tool/evaluate_csp.dart for the ablation study in the README.
  final bool useMrv;
  final bool useValueOrdering;
  final bool useForwardChecking;
  final bool useBranchAndBound;

  const ChoreCspSolver({
    this.repeatPenalty = 4,
    this.maxNodes = 200000,
    this.useMrv = true,
    this.useValueOrdering = true,
    this.useForwardChecking = true,
    this.useBranchAndBound = true,
  });

  CspResult solve(List<CspChore> chores, List<CspMember> members) {
    final watch = Stopwatch()..start();

    // ---- Build initial domains (unary constraint C1) --------------------
    final domains = <int, List<int>>{};
    for (var i = 0; i < chores.length; i++) {
      domains[i] = [
        for (var m = 0; m < members.length; m++)
          if (!chores[i].requiresHome || members[m].isHome) m,
      ];
    }

    final eligible = <int>{for (final d in domains.values) ...d};
    final baseCapacity = eligible.isEmpty
        ? 0
        : (chores.length / eligible.length).ceil();
    var capacity = baseCapacity;

    CspResult fail(String why) => CspResult(
      assignments: null,
      cost: double.infinity,
      finalLoads: {for (final m in members) m.name: m.existingLoad},
      capacity: capacity,
      stats: CspStats(
        nodesExpanded: 0,
        backtracks: 0,
        boundPrunes: 0,
        forwardCheckPrunes: 0,
        elapsed: watch.elapsed,
      ),
      failureReason: why,
    );

    if (chores.isEmpty) return fail('No chores to assign.');
    if (members.isEmpty) return fail('No housemates in this household.');
    for (var i = 0; i < chores.length; i++) {
      if (domains[i]!.isEmpty) {
        return fail(
          '"${chores[i].title}" needs someone at home, but nobody is home.',
        );
      }
    }

    // ---- Search state -----------------------------------------------------
    final loads = [for (final m in members) m.existingLoad];
    final counts = List<int>.filled(members.length, 0);
    final assignment = <int, int>{}; // chore index -> member index
    var repeats = 0;

    double bestCost = double.infinity;
    Map<int, int>? best;
    var nodes = 0, backtracks = 0, boundPrunes = 0, fcPrunes = 0;

    double cost() {
      var s = 0.0;
      for (final l in loads) {
        s += l * l;
      }
      return s + repeats * repeatPenalty;
    }

    double deltaCost(int chore, int m) {
      final e = chores[chore].effort;
      final l = loads[m];
      final rep = members[m].recentChores.contains(chores[chore].title);
      return (l + e) * (l + e) - l * l + (rep ? repeatPenalty : 0).toDouble();
    }

    void search(Map<int, List<int>> doms) {
      if (nodes >= maxNodes) return;
      nodes++;

      // Complete assignment → record if better.
      if (assignment.length == chores.length) {
        final c = cost();
        if (c < bestCost) {
          bestCost = c;
          best = Map.of(assignment);
        }
        return;
      }

      // Branch & bound with an admissible lower bound:
      //   LB = cost(partial) + Σ_unassigned min_{m ∈ domain} Δcost(chore, m)
      // Loads only grow, so the real increase of each remaining chore can
      // never be smaller than its cheapest increase right now → LB ≤ optimum.
      if (useBranchAndBound && bestCost < double.infinity) {
        var lb = cost();
        for (final e in doms.entries) {
          if (assignment.containsKey(e.key)) continue;
          var cheapest = double.infinity;
          for (final m in e.value) {
            if (counts[m] >= capacity) continue;
            final d = deltaCost(e.key, m);
            if (d < cheapest) cheapest = d;
          }
          lb += cheapest;
          if (lb >= bestCost) break;
        }
        if (lb >= bestCost) {
          boundPrunes++;
          return;
        }
      }

      // MRV: fewest legal values; tie-break on higher effort.
      final unassigned = doms.keys.where((i) => !assignment.containsKey(i));
      final chore = !useMrv
          ? unassigned.first
          : unassigned.reduce((a, b) {
              final da = doms[a]!.length, db = doms[b]!.length;
              if (da != db) return da < db ? a : b;
              return chores[a].effort >= chores[b].effort ? a : b;
            });

      // Least-cost value ordering.
      final values = [...doms[chore]!];
      if (useValueOrdering) {
        values.sort(
          (x, y) => deltaCost(chore, x).compareTo(deltaCost(chore, y)),
        );
      }

      for (final m in values) {
        // Consistency check for C2 (needed when forward checking is off).
        if (counts[m] >= capacity) continue;

        // Assign.
        final rep = members[m].recentChores.contains(chores[chore].title);
        assignment[chore] = m;
        loads[m] += chores[chore].effort;
        counts[m]++;
        if (rep) repeats++;

        // Forward checking on capacity (C2).
        var deadEnd = false;
        Map<int, List<int>> next = doms;
        if (useForwardChecking && counts[m] >= capacity) {
          next = {};
          for (final e in doms.entries) {
            if (assignment.containsKey(e.key)) {
              next[e.key] = e.value;
              continue;
            }
            final pruned = e.value.where((x) => x != m).toList();
            if (pruned.length != e.value.length) fcPrunes++;
            if (pruned.isEmpty) deadEnd = true;
            next[e.key] = pruned;
          }
        }

        if (!deadEnd) search(next);

        // Undo.
        assignment.remove(chore);
        loads[m] -= chores[chore].effort;
        counts[m]--;
        if (rep) repeats--;
      }
      backtracks++;
    }

    // If C2 is too strict for this situation (e.g. only one person is home
    // for several must-do-now chores), relax it one step at a time.
    search(domains);
    while (best == null && capacity < chores.length && nodes < maxNodes) {
      capacity++;
      search(domains);
    }
    watch.stop();

    final stats = CspStats(
      nodesExpanded: nodes,
      backtracks: backtracks,
      boundPrunes: boundPrunes,
      forwardCheckPrunes: fcPrunes,
      elapsed: watch.elapsed,
    );

    if (best == null) {
      return CspResult(
        assignments: null,
        cost: double.infinity,
        finalLoads: {for (final m in members) m.name: m.existingLoad},
        capacity: capacity,
        stats: stats,
        failureReason: 'No assignment satisfies every constraint.',
      );
    }

    final finalLoads = {for (final m in members) m.name: m.existingLoad};
    for (final e in best!.entries) {
      finalLoads[members[e.value].name] =
          finalLoads[members[e.value].name]! + chores[e.key].effort;
    }

    final result = <ChoreAssignment>[
      for (var i = 0; i < chores.length; i++)
        ChoreAssignment(
          chore: chores[i],
          member: members[best![i]!],
          reason: _explain(chores[i], members[best![i]!], members),
        ),
    ];

    return CspResult(
      assignments: result,
      cost: bestCost,
      finalLoads: finalLoads,
      capacity: capacity,
      capacityRelaxed: capacity > baseCapacity,
      stats: stats,
    );
  }

  String _explain(CspChore chore, CspMember m, List<CspMember> all) {
    final parts = <String>[];
    if (chore.requiresHome) parts.add('is home now');
    final minLoad = all
        .map((x) => x.existingLoad)
        .reduce((a, b) => a < b ? a : b);
    if (m.existingLoad == minLoad) {
      parts.add('had the lightest load (${m.existingLoad})');
    } else {
      parts.add('balances the workload');
    }
    if (m.recentChores.contains(chore.title)) {
      parts.add('repeat was unavoidable');
    } else if (all.any((x) => x.recentChores.contains(chore.title))) {
      parts.add('rotation: not their turn last time');
    }
    return parts.join(' · ');
  }
}
