import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chore_roulette/widgets/task_roulette_sheet.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:casama/shared/widgets/casama_lost_found_icon.dart';
import 'package:casama/shared/widgets/casama_wave_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'BoardsScreen switches tabs via header pills and horizontal swipe, morphing contextual FAB, with leveled mascot above capsule bar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const BoardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      void expectHeaderOrder(String titleText) {
        final headerFinder = find.byType(CasamaWaveHeader);
        final titleFinder = find.descendant(
          of: headerFinder,
          matching: find.text(titleText),
        );
        final mascotFinder = find.descendant(
          of: headerFinder,
          matching: find.byType(CasMascotView),
        );
        final capsuleTabFinder = find.bySemanticsLabel('Parcels board');
        expect(titleFinder, findsOneWidget);
        expect(mascotFinder, findsOneWidget);
        final titleY = tester.getCenter(titleFinder).dy;
        final mascotY = tester.getCenter(mascotFinder).dy;
        final capsuleY = tester.getCenter(capsuleTabFinder).dy;
        expect(titleY, lessThan(capsuleY));
        expect(mascotY, lessThan(capsuleY));
      }

      // Starts on Parcels
      expect(find.text('Parcels & Deliveries'), findsOneWidget);
      expect(find.text('Add parcel'), findsOneWidget);
      expectHeaderOrder('Parcels & Deliveries');

      // Horizontal swipe to Tasks
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await tester.pumpAndSettle();
      expect(find.text('Household Tasks'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Spin Roulette'), findsNothing);
      expect(find.text('Quick Spin'), findsNothing);
      expect(find.text('Chore & Task Roulette'), findsNothing);
      expectHeaderOrder('Household Tasks');

      // Tap Items header tab (Bills tab must not exist)
      expect(find.bySemanticsLabel('Bills board'), findsNothing);
      expect(find.text('Bills'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Items board'));
      await tester.pumpAndSettle();
      expect(find.text('Lost & Found'), findsOneWidget);
      expect(find.text('Report item'), findsOneWidget);
      expect(find.text('My Activity'), findsOneWidget);
      expect(find.text('Lost'), findsOneWidget);
      expect(find.text('Found'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.byType(CasamaLostFoundIcon), findsNWidgets(2));
      expect(find.byIcon(Icons.sell_outlined), findsNothing);
      expectHeaderOrder('Lost & Found');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TasksBoardView shows Unspun, directly assigns via TaskRouletteSheet with zero cooldown/Accept/Reject, allows back-to-back spins on different tasks, shows +4 bonus & awards boosted points on Done',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();
      final housemateTask = repo.tasks.firstWhere((t) => t.id == 't2');
      final secondTask = repo.tasks.firstWhere((t) => t.id == 't3');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const BoardsScreen(initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Redundant header & Quick Spin triggers must not appear
      expect(find.text('Spin Roulette'), findsNothing);
      expect(find.text('Quick Spin'), findsNothing);
      expect(find.text('Chore & Task Roulette'), findsNothing);
      expect(find.text('Unspun'), findsNWidgets(3));
      // Viewer is JP (created t1): ongoing points = t1(0) + t2(9) + t3(7) = 16 pts
      expect(find.text('16 pts'), findsOneWidget);

      // Expand t2 (Maria's task, base 9 pts) and tap Spin -> opens TaskRouletteSheet
      await tester.tap(find.text(housemateTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Spin'), findsOneWidget);
      expect(find.text('Mark as Done'), findsOneWidget);

      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();

      expect(find.text('Task Roulette'), findsOneWidget);
      expect(find.text(housemateTask.title), findsWidgets);
      expect(find.text('Eligible Housemates (3)'), findsOneWidget);
      expect(find.textContaining('Home Housemates'), findsNothing);
      expect(find.text('1 spin per task • +4 bonus pts'), findsNothing);
      expect(
        find.text('1 spin per task • Creator excluded • Chosen housemate gets +4 bonus pts'),
        findsOneWidget,
      );
      expect(find.textContaining('24h'), findsNothing);
      expect(find.byKey(const Key('task_roulette_spin_button')), findsOneWidget);

      // Spin 4000ms wheel -> directly assigns without Accept/Reject buttons
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Accept (+2 bonus)'), findsNothing);
      expect(find.text('Reject (-3 pts)'), findsNothing);
      expect(find.byKey(const Key('task_roulette_result_card')), findsOneWidget);
      expect(find.textContaining('chosen!'), findsOneWidget);
      expect(find.textContaining('+4 bonus pts'), findsWidgets);
      expect(find.text('Done'), findsOneWidget);

      // Tap Done -> closes sheet
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final record = repo.rouletteRecordForTask(housemateTask.id)!;
      expect(record.status, 'assigned');
      expect(record.bonusPoints, 4);
      // Creator (Maria) can never be chosen
      expect(record.selectedUserId, isNot(housemateTask.createdBy));

      // Two side-by-side attribution pills
      expect(
        find.byKey(ValueKey('task_spun_by_pill_${housemateTask.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('task_chosen_pill_${housemateTask.id}')),
        findsOneWidget,
      );

      final isJpChosen = record.selectedUserId == repo.currentUser.id;
      final expectedT2Reward =
          housemateTask.computedPoints + (isJpChosen ? 4 : 0);
      expect(find.text('${16 + (isJpChosen ? 4 : 0)} pts'), findsOneWidget);
      expect(
        find.text('+${housemateTask.computedPoints + 4} pts (+4 bonus)'),
        isJpChosen ? findsOneWidget : findsNothing,
      );

      // Spin button is hidden for already-spun task; Mark as Done shows viewer-specific points
      expect(find.text('Spin'), findsNothing);
      expect(find.text('Mark as Done'), findsOneWidget);
      expect(find.text('+$expectedT2Reward pts'), findsOneWidget);

      // Back-to-back spin on second unspun task (t3) works immediately with zero 24h cooldown
      await tester.ensureVisible(find.text(secondTask.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(secondTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Spin'), findsOneWidget);
      await tester.ensureVisible(find.text('Spin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cooldown'), findsNothing);
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final secondRecord = repo.rouletteRecordForTask(secondTask.id)!;
      expect(secondRecord.selectedUserId, isNot(secondTask.createdBy));
      final expectedSummaryAfterTwoSpins =
          16 +
          (isJpChosen ? 4 : 0) +
          (secondRecord.selectedUserId == repo.currentUser.id ? 4 : 0);
      expect(find.text('$expectedSummaryAfterTwoSpins pts'), findsOneWidget);

      // Complete spun t2 -> awards viewer-specific points and marks roulette record completed
      await tester.ensureVisible(find.text(housemateTask.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text(housemateTask.title));
      await tester.pumpAndSettle();
      final pointsBefore = repo.kasamaPoints;
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();
      expect(
        repo.tasks.firstWhere((t) => t.id == housemateTask.id).status,
        TaskStatus.done,
      );
      expect(repo.rouletteRecordForTask(housemateTask.id)!.status, 'completed');
      expect(repo.kasamaPoints, pointsBefore + expectedT2Reward);
    },
  );

  testWidgets(
    'TasksBoardView substitutes You accurately in two side-by-side pills and restricts +4 bonus strictly to chosen housemate across Light & Dark themes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const jpId = '11111111-1111-1111-1111-111111111111';
      const mariaId = '22222222-2222-2222-2222-222222222222';
      const alexId = '33333333-3333-3333-3333-333333333333';
      final repo = MockRepository()..login();

      // t1 (JP's own task, base 14): JP spun -> Maria chosen
      await repo.spinTaskRoulette('t1', mariaId);
      // t2 (Maria's task, base 9): JP spun -> JP chosen
      await repo.spinTaskRoulette('t2', jpId);

      // 1. Viewer is JP: sees two separate pills on t1 & t2, +4 bonus only on t2, summary = 0 + 13 + 7 = 20 pts
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const BoardsScreen(initialTab: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('20 pts'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task_spun_by_pill_t1')),
          matching: find.bySemanticsLabel(RegExp('^Spun by You')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task_chosen_pill_t1')),
          matching: find.bySemanticsLabel(RegExp('^Chosen: Maria')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task_chosen_pill_t2')),
          matching: find.bySemanticsLabel(RegExp('^Chosen: You')),
        ),
        findsOneWidget,
      );
      expect(find.text('+18 pts (+4 bonus)'), findsNothing);
      expect(find.text('+13 pts (+4 bonus)'), findsOneWidget);

      // 2. Viewer is Maria: sees Spun by JP / Chosen: You on t1 (+18 pts (+4 bonus)),
      // while t2 (created by Maria) hides bonus and summary = 18 + 0 + 7 = 25 pts
      repo.setCurrentUserForTest(mariaId);
      await tester.pumpAndSettle();

      expect(find.text('25 pts'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task_spun_by_pill_t1')),
          matching: find.bySemanticsLabel(RegExp('^Spun by JP')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('task_chosen_pill_t1')),
          matching: find.bySemanticsLabel(RegExp('^Chosen: You')),
        ),
        findsOneWidget,
      );
      expect(find.text('+18 pts (+4 bonus)'), findsOneWidget);
      expect(find.text('+13 pts (+4 bonus)'), findsNothing);

      // 3. Viewer is Alex (neither creator nor chosen on t1/t2): sees NO +4 bonus pills,
      // sees base +9 pts on Mark as Done for t2, and summary = 14 + 9 + 0 = 23 pts
      repo.setCurrentUserForTest(alexId);
      await tester.pumpAndSettle();

      expect(find.text('23 pts'), findsOneWidget);
      expect(find.text('+18 pts (+4 bonus)'), findsNothing);
      expect(find.text('+13 pts (+4 bonus)'), findsNothing);
      await tester.tap(find.text('Buy Drinking Water'));
      await tester.pumpAndSettle();
      expect(find.text('+9 pts'), findsOneWidget);
      expect(find.text('+13 pts'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TaskRouletteSheet excludes task creator and handles 1-eligible-member & 0-eligible-member households cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();
      final t2 = repo.tasks.firstWhere((t) => t.id == 't2'); // Created by Maria
      final t1 = repo.tasks.firstWhere((t) => t.id == 't1'); // Created by JP

      // 1. In a 3-member household (Home JP + Out Alex + creator Maria),
      // both JP and away-member Alex appear on the wheel while Maria is excluded
      final jpMember = repo.members.firstWhere(
        (m) => m.profile.id == repo.currentUser.id,
      );
      final mariaMember = repo.members.firstWhere(
        (m) => m.profile.id == t2.createdBy,
      );
      final alexMember = repo.members.firstWhere(
        (m) =>
            m.profile.id != repo.currentUser.id &&
            m.profile.id != t2.createdBy,
      );
      final awayAlex = MemberPresence(
        profile: alexMember.profile,
        isHome: false,
        note: 'Out',
        updatedAt: alexMember.updatedAt,
      );
      repo.setMembersForTest([jpMember, awayAlex, mariaMember]);
      MaintenanceTask activeTask = t2;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          showTaskRouletteSheet(ctx, task: activeTask),
                      child: const Text('Open Roulette'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Roulette'));
      await tester.pumpAndSettle();

      expect(find.text('Eligible Housemates (2)'), findsOneWidget);
      expect(find.textContaining('Home Housemates'), findsNothing);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Maria'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Close Task Roulette'));
      await tester.pumpAndSettle();

      // 2. In a 2-member household (JP + creator Maria), only JP is eligible on wheel
      repo.setMembersForTest([jpMember, mariaMember]);
      await tester.tap(find.text('Open Roulette'));
      await tester.pumpAndSettle();

      expect(find.text('Eligible Housemates (1)'), findsOneWidget);
      expect(find.text('Maria'), findsNothing);
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pumpAndSettle();
      expect(find.text('You were chosen!'), findsOneWidget);
      expect(
        repo.rouletteRecordForTask(t2.id)!.selectedUserId,
        jpMember.profile.id,
      );
      await tester.ensureVisible(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // 3. In a solo 1-member household (only creator JP on t1), SPIN is disabled with inline guidance
      activeTask = t1;
      repo.setMembersForTest([jpMember]);
      await tester.tap(find.text('Open Roulette'));
      await tester.pumpAndSettle();

      expect(find.text('Eligible Housemates (0)'), findsOneWidget);
      expect(
        find.text('Add another housemate to spin Task Roulette for this task.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pumpAndSettle();
      expect(repo.rouletteRecordForTask(t1.id), isNull);
      expect(find.byKey(const Key('task_roulette_result_card')), findsNothing);
    },
  );

  testWidgets(
    'BoardsScreen clamps legacy out-of-range initialTab safely to Items and renders cleanly in dark mode & reduced motion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const BoardsScreen(initialTab: 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lost & Found'), findsOneWidget);
      expect(find.text('Report item'), findsOneWidget);
      expect(find.text('Bills'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ParcelsBoardView auto-settles own parcel (0 points -> History) and keeps housemate claim unsettled (0 pts on claim, +5 pts -> History after settle)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();
      repo.addParcel(
        courier: 'LBC',
        arrival: DateTime.now().subtract(const Duration(minutes: 5)),
        paymentType: ParcelPaymentType.cod,
        codAmount: 420,
        notes: 'Own parcel test',
      );
      final initialPoints = repo.kasamaPoints;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ParcelsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4 subtabs exist
      expect(find.text('My Parcels'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Expand and claim own parcel (LBC) from Today -> 0 points awarded, no celebration dialog, auto-settled
      await tester.tap(find.text('LBC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I Got It').first);
      await tester.pumpAndSettle();
      expect(find.text('+5 Good Kasama Points!'), findsNothing);
      expect(repo.kasamaPoints, initialPoints);
      expect(find.text('Own parcel test'), findsNothing);

      // Expand and claim housemate parcel ('p1', J&T Express) from Today -> 0 points immediately, no celebration dialog, stays unsettled in Today
      await tester.tap(find.text('J&T Express'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I Got It').first);
      await tester.pumpAndSettle();
      expect(find.text('+5 Good Kasama Points!'), findsNothing);
      expect(repo.kasamaPoints, initialPoints);

      // Re-expand p1 to verify Claimed by ... • Unsettled pill
      await tester.tap(find.text('J&T Express'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('Claimed by You • Unsettled')),
        findsOneWidget,
      );

      // Switch to History -> own parcel is already Settled; housemate parcel not there yet
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('LBC'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      await tester.tap(find.text('LBC'));
      await tester.pumpAndSettle();
      expect(find.text('Own parcel test'), findsOneWidget);

      // Settle housemate parcel -> awards +5 pts and appears in History as well
      await repo.settleParcelClaim('p1');
      await tester.pumpAndSettle();
      expect(repo.kasamaPoints, initialPoints + 5);
      expect(find.text('Settled'), findsAtLeastNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
