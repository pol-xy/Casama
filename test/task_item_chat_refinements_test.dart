import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/items/lost_found_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'TasksBoardView supports single-expanded Spin / Mark as Done / Mark Undone tray and independent checkbox in Dark Mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      final pendingTasks = repo.tasks
          .where((t) => t.status != TaskStatus.done)
          .toList();
      final firstTask = pendingTasks.first;
      final secondTask = pendingTasks.length > 1 ? pendingTasks[1] : null;

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
              home: const Scaffold(body: TasksBoardView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping first task opens inline action tray with Spin and Mark as Done
      await tester.tap(find.text(firstTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsOneWidget);
      expect(find.text('+5 pts'), findsOneWidget);

      // Single-expanded accordion: tapping a second task collapses the first
      if (secondTask != null) {
        await tester.tap(find.text(secondTask.title));
        await tester.pumpAndSettle();
        expect(find.text('Mark as Done'), findsOneWidget);
      }

      // Tapping Mark as Done marks it completed and collapses the tray
      final activeTask = secondTask ?? firstTask;
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsNothing);

      // Tapping the completed task shows Mark Undone
      await tester.tap(find.text(activeTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Mark Undone'), findsOneWidget);

      await tester.tap(find.text('Mark Undone'));
      await tester.pumpAndSettle();
      expect(find.text('Mark Undone'), findsNothing);

      // Independent checkbox toggles completion without expanding tray
      await tester.tap(find.bySemanticsLabel('Mark ${firstTask.title} done'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text('Mark Undone'), findsNothing);

      // Expand another pending task and tap its tray Spin button -> opens Task Roulette
      final remainingOpen = repo.tasks
          .where((t) => t.id != firstTask.id && t.status != TaskStatus.done)
          .first;
      await tester.tap(find.text(remainingOpen.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
      expect(find.text('Task Roulette'), findsOneWidget);
      expect(find.text(remainingOpen.title), findsWidgets);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ItemsBoardView renders Lost and Found only without Shared tab',
    (tester) async {
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
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const Scaffold(body: ItemsBoardView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open missing reports'), findsOneWidget);
      expect(find.text('Waiting to be claimed'), findsOneWidget);
      expect(find.textContaining('Shared'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
