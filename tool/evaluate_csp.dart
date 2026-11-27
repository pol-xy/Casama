// Casama AI — CSP chore assignment evaluation.
//
// Simulates many random households and compares three strategies:
//   1. Random   — what the original Chore Roulette did (uniform random person)
//   2. Greedy   — a reasonable non-search heuristic: each chore, in order, to
//                 the currently least-loaded eligible person
//   3. CSP      — lib/ai/chore_csp_solver.dart (backtracking + MRV + FC + B&B)
// and runs an ablation study on the solver's heuristics.
//
// Run from the repo root:   dart run tool/evaluate_csp.dart
// Writes:                   ai/results/csp_results.md, ai/results/csp_results.json

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:casama/ai/chore_csp_solver.dart';

const int scenarios = 1000;
const int seed = 2026;
const int repeatPenalty = 4;

class Scenario {
  final List<CspChore> chores;
  final List<CspMember> members;
  Scenario(this.chores, this.members);
}

Scenario randomScenario(Random rng) {
  final nMembers = 3 + rng.nextInt(4); // 3..6 housemates
  final nChores = 4 + rng.nextInt(5); // 4..8 chores
  final chores = [
    for (var i = 0; i < nChores; i++)
      CspChore(
        title: 'chore$i',
        effort: 1 + rng.nextInt(3),
        requiresHome: rng.nextDouble() < 0.35,
      ),
  ];
  final members = [
    for (var i = 0; i < nMembers; i++)
      CspMember(
        name: 'm$i',
        // At least one person is home so the problem is always feasible.
        isHome: i == 0 || rng.nextDouble() < 0.6,
        existingLoad: rng.nextInt(7),
        recentChores: {
          for (var c = 0; c < nChores; c++)
            if (rng.nextDouble() < 0.15) 'chore$c',
        },
      ),
  ];
  return Scenario(chores, members);
}

/// Strategy output: chore index -> member index.
typedef Plan = List<int>;

Plan randomPlan(Scenario s, Random rng) => [
  for (var _ in s.chores) rng.nextInt(s.members.length),
];

Plan greedyPlan(Scenario s, int capacity) {
  final loads = [for (final m in s.members) m.existingLoad];
  final counts = List<int>.filled(s.members.length, 0);
  final plan = <int>[];
  for (final c in s.chores) {
    var bestM = -1;
    for (var m = 0; m < s.members.length; m++) {
      if (c.requiresHome && !s.members[m].isHome) continue;
      if (counts[m] >= capacity) continue;
      if (bestM == -1 || loads[m] < loads[bestM]) bestM = m;
    }
    // Greedy can paint itself into a corner; then it breaks capacity.
    if (bestM == -1) {
      bestM = 0;
      for (var m = 0; m < s.members.length; m++) {
        if (c.requiresHome && !s.members[m].isHome) continue;
        if (loads[m] < loads[bestM]) bestM = m;
      }
    }
    plan.add(bestM);
    loads[bestM] += c.effort;
    counts[bestM]++;
  }
  return plan;
}

class Score {
  final int availabilityViolations;
  final bool capacityViolated;
  final double loadStd;
  final int loadGap;
  final int repeats;
  final double cost;
  Score(
    this.availabilityViolations,
    this.capacityViolated,
    this.loadStd,
    this.loadGap,
    this.repeats,
    this.cost,
  );
  bool get anyHardViolation => availabilityViolations > 0 || capacityViolated;
}

Score score(Scenario s, Plan plan, int capacity) {
  final loads = [for (final m in s.members) m.existingLoad];
  final counts = List<int>.filled(s.members.length, 0);
  var avail = 0, repeats = 0;
  for (var c = 0; c < s.chores.length; c++) {
    final m = plan[c];
    if (s.chores[c].requiresHome && !s.members[m].isHome) avail++;
    if (s.members[m].recentChores.contains(s.chores[c].title)) repeats++;
    loads[m] += s.chores[c].effort;
    counts[m]++;
  }
  final mean = loads.reduce((a, b) => a + b) / loads.length;
  final std = sqrt(
    loads.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) /
        loads.length,
  );
  final cost =
      loads.fold<double>(0, (a, l) => a + l * l) + repeats * repeatPenalty;
  return Score(
    avail,
    counts.any((n) => n > capacity),
    std,
    loads.reduce(max) - loads.reduce(min),
    repeats,
    cost,
  );
}

class Agg {
  int chores = 0, availViol = 0, roundsHardViol = 0, repeats = 0;
  double std = 0, gap = 0, costRatio = 0;
  int n = 0;
  void add(Score sc, int nChores, double optimalCost) {
    n++;
    chores += nChores;
    availViol += sc.availabilityViolations;
    if (sc.anyHardViolation) roundsHardViol++;
    repeats += sc.repeats;
    std += sc.loadStd;
    gap += sc.loadGap;
    costRatio += sc.cost / optimalCost;
  }

  Map<String, num> toJson() => {
    'availability_violation_rate': availViol / chores,
    'rounds_with_hard_violation': roundsHardViol / n,
    'mean_load_std': std / n,
    'mean_load_gap': gap / n,
    'repeat_rate': repeats / chores,
    'mean_cost_vs_optimal': costRatio / n,
  };
}

String pct(num x) => '${(x * 100).toStringAsFixed(1)}%';
String f2(num x) => x.toStringAsFixed(2);

void main() {
  final rng = Random(seed);
  final data = [for (var i = 0; i < scenarios; i++) randomScenario(rng)];

  const solver = ChoreCspSolver(repeatPenalty: repeatPenalty);
  final aggs = {
    'Random (original roulette)': Agg(),
    'Greedy': Agg(),
    'CSP (ours)': Agg(),
  };
  final micros = <int>[];
  final nodes = <int>[];
  var relaxed = 0;

  final baselineRng = Random(seed + 1);
  for (final s in data) {
    final r = solver.solve(s.chores, s.members);
    if (!r.isSolved) throw StateError('Scenario unexpectedly infeasible');
    if (r.capacityRelaxed) relaxed++;
    micros.add(r.stats.elapsed.inMicroseconds);
    nodes.add(r.stats.nodesExpanded);

    final idx = {
      for (var i = 0; i < s.members.length; i++) s.members[i].name: i,
    };
    final cspPlan = [for (final a in r.assignments!) idx[a.member.name]!];
    final cap = r.capacity;
    final opt = r.cost;

    aggs['Random (original roulette)']!.add(
      score(s, randomPlan(s, baselineRng), cap),
      s.chores.length,
      opt,
    );
    aggs['Greedy']!.add(
      score(s, greedyPlan(s, cap), cap),
      s.chores.length,
      opt,
    );
    aggs['CSP (ours)']!.add(score(s, cspPlan, cap), s.chores.length, opt);
  }

  // ---- Ablation: same scenarios, one heuristic off at a time -------------
  final variants = <String, ChoreCspSolver>{
    'All heuristics (app)': solver,
    'No MRV': const ChoreCspSolver(repeatPenalty: repeatPenalty, useMrv: false),
    'No value ordering': const ChoreCspSolver(
      repeatPenalty: repeatPenalty,
      useValueOrdering: false,
    ),
    'No forward checking': const ChoreCspSolver(
      repeatPenalty: repeatPenalty,
      useForwardChecking: false,
    ),
    'No branch & bound': const ChoreCspSolver(
      repeatPenalty: repeatPenalty,
      useBranchAndBound: false,
    ),
    'Plain backtracking (all off)': const ChoreCspSolver(
      repeatPenalty: repeatPenalty,
      useMrv: false,
      useValueOrdering: false,
      useForwardChecking: false,
      useBranchAndBound: false,
    ),
  };
  final ablation = <String, Map<String, num>>{};
  for (final e in variants.entries) {
    var totalNodes = 0, maxN = 0, totalUs = 0;
    var sameCost = 0;
    for (final s in data) {
      final r = e.value.solve(s.chores, s.members);
      final ref = solver.solve(s.chores, s.members);
      totalNodes += r.stats.nodesExpanded;
      maxN = max(maxN, r.stats.nodesExpanded);
      totalUs += r.stats.elapsed.inMicroseconds;
      if ((r.cost - ref.cost).abs() < 1e-9) sameCost++;
    }
    ablation[e.key] = {
      'mean_nodes': totalNodes / data.length,
      'max_nodes': maxN,
      'mean_ms': totalUs / data.length / 1000,
      'optimal_rate': sameCost / data.length,
    };
  }

  micros.sort();
  nodes.sort();
  final perf = {
    'mean_ms': micros.reduce((a, b) => a + b) / micros.length / 1000,
    'p95_ms': micros[(micros.length * 0.95).floor()] / 1000,
    'max_ms': micros.last / 1000,
    'mean_nodes': nodes.reduce((a, b) => a + b) / nodes.length,
    'max_nodes': nodes.last,
    'capacity_relaxed_rate': relaxed / data.length,
  };

  // ---- Write report -------------------------------------------------------
  final b = StringBuffer()
    ..writeln('# CSP Chore Assignment — Evaluation Results')
    ..writeln()
    ..writeln(
      'Generated by `dart run tool/evaluate_csp.dart` '
      '($scenarios random households, seed=$seed).',
    )
    ..writeln()
    ..writeln(
      'Each household: 3–6 housemates (each home with p=0.6, at least one '
      'home), 4–8 chores (effort 1–3, 35% must be done now), existing load '
      '0–6, 15% chance a housemate had a given chore last time.',
    )
    ..writeln()
    ..writeln('## Strategy comparison')
    ..writeln()
    ..writeln(
      '| Strategy | Chores given to someone who is out | Rounds breaking a hard constraint | Load std-dev ↓ | Max–min load gap ↓ | Repeat rate ↓ | Cost vs. optimal ↓ |',
    )
    ..writeln('|---|---|---|---|---|---|---|');
  for (final e in aggs.entries) {
    final j = e.value.toJson();
    b.writeln(
      '| ${e.key} | ${pct(j['availability_violation_rate']!)} | '
      '${pct(j['rounds_with_hard_violation']!)} | ${f2(j['mean_load_std']!)} | '
      '${f2(j['mean_load_gap']!)} | ${pct(j['repeat_rate']!)} | '
      '${f2(j['mean_cost_vs_optimal']!)}× |',
    );
  }
  b
    ..writeln()
    ..writeln('## Solver performance (all heuristics on, as in the app)')
    ..writeln()
    ..writeln(
      '| Mean time | p95 time | Max time | Mean nodes | Max nodes | Capacity relaxed |',
    )
    ..writeln('|---|---|---|---|---|---|')
    ..writeln(
      '| ${f2(perf['mean_ms']!)} ms | ${f2(perf['p95_ms']!)} ms | '
      '${f2(perf['max_ms']!)} ms | ${f2(perf['mean_nodes']!)} | ${perf['max_nodes']} | '
      '${pct(perf['capacity_relaxed_rate']!)} |',
    )
    ..writeln()
    ..writeln('## Ablation study (search heuristics)')
    ..writeln()
    ..writeln(
      '| Variant | Mean nodes | Max nodes | Mean time | Finds optimum |',
    )
    ..writeln('|---|---|---|---|---|');
  for (final e in ablation.entries) {
    b.writeln(
      '| ${e.key} | ${f2(e.value['mean_nodes']!)} | ${e.value['max_nodes']} | '
      '${f2(e.value['mean_ms']!)} ms | ${pct(e.value['optimal_rate']!)} |',
    );
  }
  b
    ..writeln()
    ..writeln(
      'Timings are from a desktop Dart VM (`dart run`) and vary by machine; '
      'node counts are deterministic.',
    );

  Directory('ai/results').createSync(recursive: true);
  File('ai/results/csp_results.md').writeAsStringSync(b.toString());
  File('ai/results/csp_results.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'scenarios': scenarios,
      'seed': seed,
      'strategies': {for (final e in aggs.entries) e.key: e.value.toJson()},
      'performance': perf,
      'ablation': ablation,
    }),
  );
  stdout.write(b.toString());
}
