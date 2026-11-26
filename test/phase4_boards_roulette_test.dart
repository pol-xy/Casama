import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/bills/bills_dashboard_screen.dart';
import 'package:casama/features/chore_roulette/widgets/task_roulette_sheet.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:casama/shared/widgets/casama_lost_found_icon.dart';
import 'package:casama/shared/widgets/casama_wave_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

      // Tap Bills header tab
      await tester.tap(find.bySemanticsLabel('Bills board'));
      await tester.pumpAndSettle();
      expect(find.text('Bills & Payments'), findsOneWidget);
      expect(find.text('Edit billings'), findsOneWidget);
      expectHeaderOrder('Bills & Payments');

      // Tap Items header tab
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
    'TasksBoardView completes tasks inline and opens TaskRouletteSheet from expanded card w/ 24h cooldown',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();

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

      // Expand first open task card and tap Spin -> opens TaskRouletteSheet
      final firstTask = repo.tasks.firstWhere(
        (t) => t.status != TaskStatus.done,
      );
      await tester.tap(find.text(firstTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Spin'), findsOneWidget);
      expect(find.text('Mark as Done'), findsOneWidget);

      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();

      expect(find.text('Task Roulette'), findsOneWidget);
      expect(find.text(firstTask.title), findsWidgets);
      expect(find.text('1 spin / 24h • Ready'), findsOneWidget);
      expect(find.byKey(const Key('task_roulette_spin_button')), findsOneWidget);

      // Spin 4000ms wheel -> Accept (+2 bonus) -> saves 24h cooldown
      await tester.tap(find.byKey(const Key('task_roulette_spin_button')));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.text('Accept (+2 bonus)'), findsOneWidget);
      expect(find.text('Reject (-3 pts)'), findsOneWidget);

      await tester.ensureVisible(find.text('Accept (+2 bonus)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accept (+2 bonus)'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(rouletteLastSpinPrefKey), isNotNull);

      // Re-opening sheet from expanded card's Spin button reflects 24h cooldown
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cooldown •'), findsOneWidget);

      // Close sheet and mark the expanded task as Done inline
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();
      expect(
        repo.tasks.firstWhere((t) => t.id == firstTask.id).status,
        TaskStatus.done,
      );
    },
  );

  testWidgets(
    'EditBillingsSheet creates a bill and BoardsScreen renders cleanly in dark mode & reduced motion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();
      final initialBillCount = repo.bills.length;

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
              home: const BoardsScreen(initialTab: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bills & Payments'), findsOneWidget);
      expect(find.text('Edit billings'), findsOneWidget);

      await tester.tap(find.text('Edit billings'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., PLDT Fiber, Meralco, Rent'),
        'SkyCable Fiber',
      );
      await tester.enterText(
        find.widgetWithText(TextField, '0.00'),
        '1499',
      );
      await tester.ensureVisible(find.text('Save Billings'));
      await tester.tap(find.text('Save Billings'));
      await tester.pumpAndSettle();

      expect(repo.bills.length, initialBillCount + 1);
      expect(repo.bills.first.effectiveBillName, 'SkyCable Fiber');

      // Mark the newly added bill as paid right from BillsBoardView
      await tester.tap(find.text('Mark Paid').first);
      await tester.pumpAndSettle();
      expect(repo.bills.first.effectiveStatus, BillStatus.paid);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ParcelsBoardView auto-settles own parcel (0 points -> History) and keeps housemate claim unsettled (+5 points -> History after settle)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();
      repo.addParcel(
        courier: 'LBC',
        arrival: DateTime.now(),
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

      // 3 subtabs exist
      expect(find.text('My Parcels'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);

      // Claim own parcel from Upcoming -> 0 points awarded, no celebration dialog, auto-settled
      await tester.tap(find.text('I Got It').first);
      await tester.pumpAndSettle();
      expect(find.text('+5 Good Kasama Points!'), findsNothing);
      expect(repo.kasamaPoints, initialPoints);
      expect(find.text('Own parcel test'), findsNothing);

      // Claim housemate parcel ('p1') from Upcoming -> +5 points awarded, stays unsettled in Upcoming
      await tester.tap(find.text('I Got It').first);
      await tester.pumpAndSettle();
      expect(find.text('+5 Good Kasama Points!'), findsOneWidget);
      expect(repo.kasamaPoints, initialPoints + 5);
      await tester.tap(find.text('Awesome!'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Claimed by ${repo.currentUser.displayName} • Unsettled'),
        findsOneWidget,
      );

      // Switch to History -> own parcel is already Settled; housemate parcel not there yet
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Own parcel test'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);

      // Settle housemate parcel -> appears in History as well
      await repo.settleParcelClaim('p1');
      await tester.pumpAndSettle();
      expect(find.text('Settled'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'BillsBoardView summary card surfaces nearest unpaid bill (overdue & upcoming) and clean all-settled state in Light & Dark themes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();

      // Mark all seeded bills paid first, then add controlled upcoming + overdue bills
      for (final b in List<HouseholdBill>.from(repo.bills)) {
        repo.markBillPaid(b.id);
      }

      final soonDate = DateTime.now().add(const Duration(days: 3));
      final laterDate = DateTime.now().add(const Duration(days: 10));
      repo.addBill(
        category: BillCategory.water,
        billName: 'Later Water',
        amount: 450,
        deadline: laterDate,
      );
      repo.addBill(
        category: BillCategory.internet,
        billName: 'Soon Fiber',
        amount: 1499,
        deadline: soonDate,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: ThemeMode.light,
            home: const Scaffold(body: BillsBoardView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final soonDateStr = DateFormat('MMM d').format(soonDate);
      expect(find.text('Soon Fiber'), findsWidgets);
      expect(find.text('Due $soonDateStr • ₱1,499'), findsOneWidget);
      expect(find.text('No overdue bills'), findsNothing);

      // Add an overdue bill -> becomes nearest bill with Overdue prefix
      final overdueDate = DateTime.now().subtract(const Duration(days: 2));
      repo.addBill(
        category: BillCategory.electricity,
        billName: 'Overdue Meralco',
        amount: 2100,
        deadline: overdueDate,
      );
      await tester.pumpAndSettle();

      final overdueDateStr = DateFormat('MMM d').format(overdueDate);
      expect(find.text('Overdue Meralco'), findsWidgets);
      expect(find.text('Overdue $overdueDateStr • ₱2,100'), findsOneWidget);

      // Pay all unpaid bills -> shows "No upcoming" / "All bills settled" in Dark Mode
      for (final b in List<HouseholdBill>.from(repo.bills)) {
        if (b.effectiveStatus != BillStatus.paid) {
          repo.markBillPaid(b.id);
        }
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const Scaffold(body: BillsBoardView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No upcoming'), findsOneWidget);
      expect(find.text('All bills settled'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
