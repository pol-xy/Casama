import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:casama/ai/ai_providers.dart';
import 'package:casama/ai/chore_csp_solver.dart';
import 'package:casama/ai/naive_bayes_classifier.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chore_roulette/chore_roulette_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NaiveBayesTaskClassifier loadClassifier() {
  final raw = File(taskClassifierAsset).readAsStringSync();
  return NaiveBayesTaskClassifier.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
}

/// Exhaustive search over every assignment — used to prove the CSP solver's
/// branch & bound returns the optimum.
double bruteForceBest(
  List<CspChore> chores,
  List<CspMember> members,
  int capacity,
  int repeatPenalty,
) {
  var best = double.infinity;
  final pick = List<int>.filled(chores.length, 0);
  void rec(int i) {
    if (i == chores.length) {
      final loads = [for (final m in members) m.existingLoad];
      final counts = List<int>.filled(members.length, 0);
      var repeats = 0;
      for (var c = 0; c < chores.length; c++) {
        final m = pick[c];
        if (chores[c].requiresHome && !members[m].isHome) return;
        loads[m] += chores[c].effort;
        counts[m]++;
        if (members[m].recentChores.contains(chores[c].title)) repeats++;
      }
      if (counts.any((n) => n > capacity)) return;
      final cost =
          loads.fold<double>(0, (s, l) => s + l * l) + repeats * repeatPenalty;
      if (cost < best) best = cost;
      return;
    }
    for (var m = 0; m < members.length; m++) {
      pick[i] = m;
      rec(i + 1);
    }
  }

  rec(0);
  return best;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Naive Bayes — tokenizer & parity with Python trainer', () {
    final classifier = loadClassifier();

    test(
      'tokenizer lowercases, strips punctuation, drops stopwords, adds bigrams',
      () {
        expect(classifier.tokenizer.tokenize('Leaking faucet sa CR!!'), [
          'leaking',
          'faucet',
          'cr',
          'leaking_faucet',
          'faucet_cr',
        ]);
        expect(classifier.tokenizer.tokenize('   '), isEmpty);
      },
    );

    test('Dart inference matches Python probabilities (fixture)', () {
      final cases = (jsonDecode(
        File('test/fixtures/nb_parity.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>();
      expect(cases.length, greaterThan(30));
      for (final c in cases) {
        final tokens = classifier.tokenizer.tokenize(c['title'] as String);
        expect(
          tokens,
          (c['tokens'] as List).cast<String>(),
          reason: c['title'],
        );
        for (final field in ['category', 'urgency']) {
          final model = field == 'category'
              ? classifier.categoryModel
              : classifier.urgencyModel;
          final pred = model.predict(tokens)!;
          (c[field] as Map<String, dynamic>).forEach((label, p) {
            expect(
              pred.probabilities[label]!,
              closeTo((p as num).toDouble(), 1e-4),
              reason: '${c['title']} / $field / $label',
            );
          });
        }
      }
    });
  });

  group('Naive Bayes — task suggestions', () {
    final classifier = loadClassifier();

    test('probabilities form a distribution', () {
      final p = classifier.categoryModel.predict(
        classifier.tokenizer.tokenize('Buy dishwashing liquid'),
      )!;
      final sum = p.probabilities.values.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));
      expect(p.confidence, p.probabilities.values.reduce(max));
    });

    test(
      'obvious landlord / restock / DIY titles are classified correctly',
      () {
        expect(
          classifier.suggest('Pipe burst under the sink').category,
          TaskCategory.landlord,
        );
        expect(
          classifier.suggest('Buy trash bags and detergent').category,
          TaskCategory.restock,
        );
        expect(
          classifier.suggest('Wash the dishes').category,
          TaskCategory.diy,
        );
        expect(
          classifier.suggest('Sira ang aircon').category,
          TaskCategory.landlord,
        );
        expect(
          classifier.suggest('Ubos na ang bigas').category,
          TaskCategory.restock,
        );
      },
    );

    test(
      'safety hazards are flagged urgent with enough confidence to apply',
      () {
        final s = classifier.suggest('Gas leak smell near the stove');
        expect(s.urgency, TaskUrgency.urgent);
        expect(s.shouldApplyUrgency, isTrue);
      },
    );

    test(
      'unknown words produce no suggestion instead of a prior-only guess',
      () {
        final s = classifier.suggest('qwerty zxcvb');
        expect(s.isEmpty, isTrue);
        expect(s.shouldApplyCategory, isFalse);
      },
    );
  });

  group('CSP chore solver', () {
    const solver = ChoreCspSolver();
    const chores = [
      CspChore(title: 'Trash', effort: 1, requiresHome: true),
      CspChore(title: 'Grocery', effort: 2),
      CspChore(title: 'Sweep', effort: 1),
      CspChore(title: 'Mop', effort: 2),
      CspChore(title: 'Bathroom', effort: 3),
      CspChore(title: 'Counters', effort: 1, requiresHome: true),
    ];

    test('C1: must-do-now chores only go to people who are home', () {
      final r = solver.solve(chores, const [
        CspMember(name: 'A', isHome: false),
        CspMember(name: 'B', isHome: true),
        CspMember(name: 'C', isHome: false),
      ]);
      expect(r.isSolved, isTrue);
      for (final a in r.assignments!) {
        if (a.chore.requiresHome) expect(a.member.name, 'B');
      }
    });

    test('C2: nobody gets more than ceil(chores / people)', () {
      final r = solver.solve(chores, const [
        CspMember(name: 'A', isHome: true),
        CspMember(name: 'B', isHome: true),
        CspMember(name: 'C', isHome: true),
        CspMember(name: 'D', isHome: true),
      ]);
      expect(r.capacity, 2);
      final counts = <String, int>{};
      for (final a in r.assignments!) {
        counts[a.member.name] = (counts[a.member.name] ?? 0) + 1;
      }
      expect(counts.values.every((n) => n <= 2), isTrue);
      expect(r.capacityRelaxed, isFalse);
    });

    test('S1: a housemate already carrying open tasks gets less new work', () {
      final r = solver.solve(chores, const [
        CspMember(name: 'Busy', isHome: true, existingLoad: 6),
        CspMember(name: 'Free1', isHome: true),
        CspMember(name: 'Free2', isHome: true),
      ]);
      final busyNew = r.finalLoads['Busy']! - 6;
      expect(busyNew, lessThan(r.finalLoads['Free1']!));
      expect(busyNew, lessThan(r.finalLoads['Free2']!));
    });

    test('S2: chores rotate away from whoever did them last time', () {
      final r = solver.solve(
        const [
          CspChore(title: 'Bathroom', effort: 3),
          CspChore(title: 'Trash', effort: 3),
        ],
        const [
          CspMember(name: 'A', isHome: true, recentChores: {'Bathroom'}),
          CspMember(name: 'B', isHome: true, recentChores: {'Trash'}),
        ],
      );
      final byChore = {
        for (final a in r.assignments!) a.chore.title: a.member.name,
      };
      expect(byChore['Bathroom'], 'B');
      expect(byChore['Trash'], 'A');
    });

    test('infeasible when nobody is home for a must-do-now chore', () {
      final r = solver.solve(chores, const [
        CspMember(name: 'A', isHome: false),
        CspMember(name: 'B', isHome: false),
      ]);
      expect(r.isSolved, isFalse);
      expect(r.failureReason, contains('nobody is home'));
    });

    test(
      'relaxes capacity when it is the only way to satisfy availability',
      () {
        final r = solver.solve(
          const [
            CspChore(title: 'T1', requiresHome: true),
            CspChore(title: 'T2', requiresHome: true),
            CspChore(title: 'T3', requiresHome: true),
            CspChore(title: 'T4'),
          ],
          const [
            CspMember(name: 'Home', isHome: true),
            CspMember(name: 'Out1', isHome: false),
            CspMember(name: 'Out2', isHome: false),
            CspMember(name: 'Out3', isHome: false),
          ],
        );
        expect(r.isSolved, isTrue);
        expect(r.capacityRelaxed, isTrue);
      },
    );

    test(
      'branch & bound is optimal: equals brute force on 200 random cases',
      () {
        final rng = Random(7);
        for (var trial = 0; trial < 200; trial++) {
          final nChores = 2 + rng.nextInt(5); // 2..6
          final nMembers = 2 + rng.nextInt(3); // 2..4
          final cs = [
            for (var i = 0; i < nChores; i++)
              CspChore(
                title: 'c$i',
                effort: 1 + rng.nextInt(3),
                requiresHome: rng.nextDouble() < 0.3,
              ),
          ];
          final ms = [
            for (var i = 0; i < nMembers; i++)
              CspMember(
                name: 'm$i',
                isHome: i == 0 || rng.nextBool(),
                existingLoad: rng.nextInt(5),
                recentChores: {
                  for (var c = 0; c < nChores; c++)
                    if (rng.nextDouble() < 0.2) 'c$c',
                },
              ),
          ];
          final r = solver.solve(cs, ms);
          expect(r.isSolved, isTrue, reason: 'trial $trial');
          final opt = bruteForceBest(cs, ms, r.capacity, solver.repeatPenalty);
          expect(r.cost, opt, reason: 'trial $trial');
        }
      },
    );

    test('buildCspMembers maps demo household presence and workload', () {
      final members = buildCspMembers(MockRepository());
      final byName = {for (final m in members) m.name: m};
      expect(byName['Alex']!.isHome, isFalse);
      expect(byName['Alex']!.existingLoad, 2); // Leaking Faucet (landlord)
      expect(byName['You']!.existingLoad, 1); // Buy Drinking Water (restock)
      expect(byName['Maria']!.existingLoad, 0);
      expect(byName['Ria']!.recentChores, contains('Defrost Freezer'));
    });
  });

  group('AI integration widgets', () {
    final classifier = loadClassifier();

    testWidgets('typing a task title shows the AI suggestion and auto-fills', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWith((ref) => MockRepository()),
            taskClassifierProvider.overrideWith((ref) async => classifier),
          ],
          child: const MaterialApp(
            home: MaintenanceScreen(initialOpenAddModal: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_suggestion_card')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('task_title_field')),
        'Gas leak smell near the stove',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ai_suggestion_card')), findsOneWidget);
      expect(find.text('🦉 Cas AI suggests'), findsOneWidget);
      // Dropdowns were changed from their defaults (DIY / Medium).
      expect(find.text('Landlord / Admin'), findsWidgets);
      expect(find.text('Urgent (Immediate)'), findsOneWidget);
    });

    testWidgets('Fair Assign (AI) shows an assignment and adds tasks', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = MockRepository();
      final before = repo.tasks.length;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: const MaterialApp(home: ChoreRouletteScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fair_assign_button')));
      await tester.pumpAndSettle();

      expect(find.text('Fair Assignment 🦉'), findsOneWidget);
      // Alex is out, so the two must-do-now chores never go to Alex.
      expect(find.text('Take Out Trash  →  Alex'), findsNothing);
      expect(find.text('Wipe Counters  →  Alex'), findsNothing);

      await tester.tap(find.text('Add All to Maintenance Tasks'));
      await tester.pumpAndSettle();
      expect(repo.tasks.length, before + 6);
    });
  });
}
