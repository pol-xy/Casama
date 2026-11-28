import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/items/lost_found_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:casama/shared/widgets/casama_lost_found_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'TasksBoardView supports Ongoing/Completed subtabs, dynamic points, self-completion guard, and no Mark Undone in Dark & Light modes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      final ownTask = repo.tasks.firstWhere((t) => t.id == 't1');
      final housemateTask = repo.tasks.firstWhere((t) => t.id == 't2');
      final thirdTask = repo.tasks.firstWhere((t) => t.id == 't3');
      final initialPoints = repo.kasamaPoints;

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

      // Summary card: Open Tasks + color-only urgency counts (no words) + viewer-specific ongoing points (0 + 9 + 7 = 16 pts)
      expect(find.text('3 Open Tasks'), findsOneWidget);
      expect(find.text('16 pts'), findsOneWidget);
      expect(find.text('Available to you'), findsOneWidget);
      expect(
        find.bySemanticsLabel('1 low, 1 medium, 1 urgent'),
        findsOneWidget,
      );
      expect(find.text('Completed log'), findsNothing);
      expect(find.textContaining('urgent •'), findsNothing);
      expect(find.text('Unspun'), findsNWidgets(repo.tasks.length));

      // Subtabs exist and forbidden labels are absent
      expect(find.text('Ongoing Tasks'), findsOneWidget);
      expect(find.text('Completed Tasks'), findsOneWidget);
      expect(find.textContaining('Unassigned'), findsNothing);
      expect(find.textContaining('Assigned'), findsNothing);
      expect(find.text('Quick Spin'), findsNothing);
      expect(find.text('Chore & Task Roulette'), findsNothing);
      expect(find.bySemanticsLabel('Mark ${ownTask.title} done'), findsNothing);
      expect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        findsNWidgets(repo.tasks.length),
      );

      // Expanding own task (t1) shows Mark as Done WITHOUT a +pts badge
      await tester.tap(find.text(ownTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsOneWidget);
      expect(find.text('+${ownTask.computedPoints} pts'), findsNothing);

      // Single-expanded accordion: tapping housemate task (t2) collapses t1 and shows +9 pts
      await tester.tap(find.text(housemateTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsOneWidget);
      expect(find.text('+${housemateTask.computedPoints} pts'), findsOneWidget);

      // Completing housemate task awards +9 pts, moves it out of Ongoing Tasks, and updates summary (16 -> 7 pts)
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();
      expect(find.text('Mark as Done'), findsNothing);
      expect(find.text(housemateTask.title), findsNothing);
      expect(repo.kasamaPoints, initialPoints + housemateTask.computedPoints);
      expect(find.text('2 Open Tasks'), findsOneWidget);
      expect(find.text('7 pts'), findsOneWidget);

      // Completing own task awards 0 pts, moves it out of Ongoing Tasks, and keeps summary at 7 pts
      await tester.tap(find.text(ownTask.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as Done'));
      await tester.pumpAndSettle();
      expect(find.text(ownTask.title), findsNothing);
      expect(repo.kasamaPoints, initialPoints + housemateTask.computedPoints);
      expect(find.text('1 Open Tasks'), findsOneWidget);
      expect(find.text('7 pts'), findsOneWidget);

      // Switch to Completed Tasks -> shows completed tasks, Done badge, NO chevron, NO Mark Undone
      await tester.tap(find.text('Completed Tasks'));
      await tester.pumpAndSettle();
      expect(find.text(housemateTask.title), findsOneWidget);
      expect(find.text(ownTask.title), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Completed by You')),
        findsNWidgets(2),
      );
      expect(find.text('Done'), findsNWidgets(2));
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(find.text('Mark Undone'), findsNothing);

      // Tapping completed task does NOT reveal Mark Undone
      await tester.tap(find.text(housemateTask.title));
      await tester.pumpAndSettle();
      expect(find.text('Mark Undone'), findsNothing);

      // Switch back to Ongoing Tasks and open Task Roulette from remaining task (t3)
      await tester.tap(find.text('Ongoing Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(thirdTask.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
      expect(find.text('Task Roulette'), findsOneWidget);
      expect(find.text(thirdTask.title), findsWidgets);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Verify Light Mode rendering with animations enabled
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const Scaffold(body: TasksBoardView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ItemsBoardView supports Lost, Found, and My Activity subtabs, compact expandable cards, linked verification, and radio filters',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      const mariaId = '22222222-2222-2222-2222-222222222222';
      const alexId = '33333333-3333-3333-3333-333333333333';
      const jpId = '11111111-1111-1111-1111-111111111111';

      // Create an open lost item posted by Alex that remains open (must NOT appear in Resolved)
      repo.setCurrentUserForTest(alexId);
      repo.postItem(
        type: ItemType.lost,
        title: 'Blue Umbrella',
        description: 'Left by the porch.',
        location: 'Front Porch',
      );

      // Create an open lost item posted by Maria so JP can submit a find via UI
      repo.setCurrentUserForTest(mariaId);
      repo.postItem(
        type: ItemType.lost,
        title: 'Silver Keychain',
        description: 'Has a small green tag.',
        location: 'Dining Table',
      );
      repo.setCurrentUserForTest(jpId);

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
              home: const Scaffold(body: ItemsBoardView()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Summary counts & 4 subtabs ordered My Activity | Lost | Found | Resolved without Shared
      expect(find.text('3 Lost'), findsOneWidget);
      expect(find.text('Open missing reports'), findsOneWidget);
      expect(find.text('1 Found'), findsOneWidget);
      expect(find.text('Waiting to be claimed'), findsOneWidget);
      expect(find.text('My Activity'), findsOneWidget);
      expect(find.text('Lost'), findsOneWidget);
      expect(find.text('Found'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(find.textContaining('Shared'), findsNothing);
      expect(find.byIcon(Icons.sell_outlined), findsNothing);
      // No-photo Silver Keychain & Blue Umbrella use CasamaLostFoundIcon badges
      expect(find.byType(CasamaLostFoundIcon), findsNWidgets(2));

      final myActivityX = tester.getCenter(find.text('My Activity')).dx;
      final lostX = tester.getCenter(find.text('Lost')).dx;
      final foundX = tester.getCenter(find.text('Found')).dx;
      final resolvedX = tester.getCenter(find.text('Resolved')).dx;
      expect(myActivityX, lessThan(lostX));
      expect(lostX, lessThan(foundX));
      expect(foundX, lessThan(resolvedX));

      // Expand Maria's lost item -> shows "I Found It" -> open SubmitFoundMatchSheet & submit
      await tester.tap(find.text('Silver Keychain'));
      await tester.pumpAndSettle();
      expect(find.text('I Found It'), findsOneWidget);

      await tester.tap(find.text('I Found It'));
      await tester.pumpAndSettle();
      expect(find.text('Report Found Match'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., Under the study room desk'),
        'Near shoe rack',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Find'));
      await tester.pumpAndSettle();

      // Re-open card as JP -> shows Awaiting owner review
      expect(find.text('1 Pending'), findsOneWidget);
      expect(find.text('Awaiting owner review'), findsOneWidget);

      // Switch to Maria (poster) -> sees Confirm (+5 pts) & Reject -> rejects first attempt
      repo.setCurrentUserForTest(mariaId);
      await tester.pumpAndSettle();
      expect(find.text('Confirm (+5 pts)'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.text('Rejected by Poster'), findsOneWidget);

      // JP re-submits -> Maria confirms -> JP earns +5 pts and Silver Keychain leaves open Lost tab
      final jpPointsBefore = repo.pointsForUser(jpId);
      repo.setCurrentUserForTest(jpId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('I Found It'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., Under the study room desk'),
        'Sofa cushion',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit Find'));
      await tester.pumpAndSettle();

      repo.setCurrentUserForTest(mariaId);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm (+5 pts)'));
      await tester.pumpAndSettle();
      expect(find.text('Silver Keychain'), findsNothing);
      expect(repo.pointsForUser(jpId), jpPointsBefore + 5);

      // JP resolves own lost item ("Lost AirPods") via "Found It Myself" -> 0 pts
      repo.setCurrentUserForTest(jpId);
      await tester.pumpAndSettle();
      final jpPointsBeforeSelf = repo.kasamaPoints;
      await tester.tap(find.text('Lost AirPods'));
      await tester.pumpAndSettle();
      expect(find.text('Found It Myself'), findsOneWidget);
      await tester.tap(find.text('Found It Myself'));
      await tester.pumpAndSettle();
      expect(repo.kasamaPoints, jpPointsBeforeSelf);
      expect(find.text('Lost AirPods'), findsNothing);

      // Found tab -> JP taps Found Backpack -> "That's Mine" awards +2 pts to Maria
      final mariaPointsBefore = repo.pointsForUser(mariaId);
      await tester.tap(find.text('Found'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Found Backpack'));
      await tester.pumpAndSettle();
      expect(find.text("That's Mine"), findsOneWidget);
      await tester.tap(find.text("That's Mine"));
      await tester.pumpAndSettle();
      expect(find.text('Found Backpack'), findsNothing);
      expect(repo.pointsForUser(mariaId), mariaPointsBefore + 2);

      // My Activity tab -> verify radio filters (All, My Lost, My Found, Interactions)
      await tester.tap(find.text('My Activity'));
      await tester.pumpAndSettle();
      expect(find.text('Lost AirPods'), findsOneWidget);
      expect(find.text('Silver Keychain'), findsOneWidget);
      expect(find.text('Found Backpack'), findsOneWidget);

      await tester.tap(find.text('My Lost'));
      await tester.pumpAndSettle();
      expect(find.text('Lost AirPods'), findsOneWidget);
      expect(find.text('Silver Keychain'), findsNothing);
      expect(find.text('Found Backpack'), findsNothing);

      await tester.ensureVisible(find.text('Interactions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Interactions'));
      await tester.pumpAndSettle();
      expect(find.text('Silver Keychain'), findsOneWidget);
      expect(find.text('Found Backpack'), findsOneWidget);
      expect(find.text('Lost AirPods'), findsNothing);

      // Expand Silver Keychain in Interactions -> shows JP's rejected & accepted thread
      await tester.tap(find.text('Silver Keychain'));
      await tester.pumpAndSettle();
      expect(find.text('Rejected by Poster'), findsOneWidget);
      expect(find.text('Accepted • +5 pts'), findsOneWidget);

      // Switch to Resolved tab -> shows all 3 resolved items across household, excludes open Blue Umbrella,
      // and never renders linked found_items as top-level cards (1 tab + 3 card chips = 4 'Resolved' texts)
      await tester.tap(find.text('Resolved').first);
      await tester.pumpAndSettle();
      expect(find.text('Silver Keychain'), findsOneWidget);
      expect(find.text('Lost AirPods'), findsOneWidget);
      expect(find.text('Found Backpack'), findsOneWidget);
      expect(find.text('Blue Umbrella'), findsNothing);
      expect(find.text('Resolved'), findsNWidgets(4));

      // Expand Silver Keychain -> full read-only Resolution History (no mutating buttons)
      await tester.tap(find.text('Silver Keychain'));
      await tester.pumpAndSettle();
      expect(find.text('Resolution History'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Maria reported item lost')),
        findsOneWidget,
      );
      expect(find.text('Rejected by Poster'), findsOneWidget);
      expect(find.text('Accepted • +5 pts'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Confirmed by Maria')),
        findsOneWidget,
      );
      expect(find.text('I Found It'), findsNothing);
      expect(find.text('Confirm (+5 pts)'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Found It Myself'), findsNothing);
      expect(find.text("That's Mine"), findsNothing);

      // Expand Lost AirPods -> self-resolved 0 pts milestone
      await tester.tap(find.text('Lost AirPods'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('found it themselves')),
        findsOneWidget,
      );
      expect(find.text('Self-resolved • 0 pts'), findsOneWidget);

      // Expand Found Backpack -> standalone found claim w/ +2 pts to Maria
      await tester.tap(find.text('Found Backpack'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('Maria posted found item')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp("That's Mine")),
        findsOneWidget,
      );
      expect(find.text('+2 pts to Maria'), findsOneWidget);

      // Verify Light Mode rendering & My Activity filter pills
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const Scaffold(body: ItemsBoardView()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Activity'));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('My Lost'), findsOneWidget);
      expect(find.text('My Found'), findsOneWidget);
      expect(find.text('Interactions'), findsOneWidget);
      expect(find.byType(Radio<dynamic>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
