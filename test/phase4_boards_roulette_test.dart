import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chore_roulette/widgets/task_roulette_sheet.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'BoardsScreen switches tabs via header pills and horizontal swipe, morphing contextual FAB',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
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

      // Starts on Parcels
      expect(find.text('Parcels & Deliveries'), findsOneWidget);
      expect(find.text('Add parcel'), findsOneWidget);

      // Horizontal swipe to Tasks
      await tester.drag(find.byType(PageView), const Offset(-450, 0));
      await tester.pumpAndSettle();
      expect(find.text('Household Tasks'), findsOneWidget);
      expect(find.text('Add task'), findsOneWidget);
      expect(find.text('Spin Roulette'), findsOneWidget);

      // Tap Bills header tab
      await tester.tap(find.bySemanticsLabel('Bills board'));
      await tester.pumpAndSettle();
      expect(find.text('Bills & Payments'), findsOneWidget);
      expect(find.text('Edit billings'), findsOneWidget);

      // Tap Items header tab
      await tester.tap(find.bySemanticsLabel('Items board'));
      await tester.pumpAndSettle();
      expect(find.text('Lost & Found'), findsOneWidget);
      expect(find.text('Report item'), findsOneWidget);
    },
  );

  testWidgets(
    'TasksBoardView completes tasks inline and opens embedded TaskRouletteSheet w/ 24h cooldown',
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

      // Open Spin Roulette slide-up sheet
      await tester.tap(find.text('Spin Roulette'));
      await tester.pumpAndSettle();

      expect(find.text('Task Roulette'), findsOneWidget);
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

      // Re-opening sheet reflects 24h cooldown state
      await tester.tap(find.text('Spin Roulette'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cooldown •'), findsOneWidget);
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
}
