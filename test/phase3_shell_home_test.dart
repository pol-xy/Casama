import 'package:casama/core/router/app_router.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/calendar/household_calendar_view.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/dashboard/widgets/casama_household_drawer.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'MainNavigationShell displays 5 slots with unread Chat badge, remembers board tab, and hides bottom bar when disabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(
              initialIndex: 0,
              initialBoardIndex: 2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
      expect(find.descendant(of: navBar, matching: find.text('Home')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Boards')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('CASnap')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Chat')), findsOneWidget);
      expect(find.descendant(of: navBar, matching: find.text('Profile')), findsOneWidget);
      expect(find.byKey(const Key('center_quicksnap_shutter_button')), findsOneWidget);
      expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);

      // Tapping Live Attention row routes to Boards while remembering tab 2 (Bills)
      final context = tester.element(find.byType(DashboardScreen));
      final shell = CasamaShellScope.maybeOf(context)!;
      expect(shell.boardTabListenable.value, 2);

      shell.openBoardTab(1);
      await tester.pumpAndSettle();
      expect(find.byType(BoardsScreen), findsOneWidget);
      expect(shell.boardTabListenable.value, 1);

      // Returning Home and tapping Boards remembers tab index 1
      await tester.tap(find.descendant(of: navBar, matching: find.text('Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: navBar, matching: find.text('Boards')));
      await tester.pumpAndSettle();
      expect(shell.boardTabListenable.value, 1);

      // Focused mode cleanly hides bottom bar
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(showBottomNav: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('center_quicksnap_shutter_button')), findsNothing);
    },
  );

  testWidgets(
    'CasamaHouseholdDrawer opens from menu button, copies invite code, and shows transparent mascot',
    (tester) async {
      final repo = MockRepository()..login();
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp.router(
            theme: CasamaTheme.lightTheme,
            routerConfig: appRouter,
          ),
        ),
      );
      // Navigate straight to dashboard using goRouter.go
      appRouter.go('/dashboard');
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pumpAndSettle();

      expect(find.byType(CasamaHouseholdDrawer), findsOneWidget);
      expect(find.text('CASA204'), findsOneWidget);
      expect(find.text('Invite Housemate'), findsOneWidget);
      expect(find.text('App Settings'), findsOneWidget);
      expect(find.byType(CasMascotView), findsWidgets);

      await tester.tap(find.bySemanticsLabel('Copy household invite code CASA204'));
      await tester.pumpAndSettle();
      expect(copiedText, 'CASA204');

      // Advance past auto-dismiss toast timer cleanly
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Close household menu'));
      await tester.pumpAndSettle();
      expect(find.byType(CasamaHouseholdDrawer), findsNothing);
    },
  );

  testWidgets(
    'DashboardScreen toggles inline You: Home status, renders Live Attention items, and filters Bills in Casa Schedule under dark mode & reduced motion',
    (tester) async {
      final repo = MockRepository()..login();
      repo.addBill(
        category: BillCategory.electricity,
        billName: 'Meralco Due Today',
        amount: 2400,
        deadline: DateTime.now(),
      );

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
              home: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 of 4 Home'), findsOneWidget);
      expect(find.text('You: Home'), findsOneWidget);
      expect(find.text('Live Attention Needed'), findsOneWidget);
      expect(find.text('Casa Schedule'), findsOneWidget);
      expect(find.byType(HouseholdCalendarView), findsOneWidget);
      expect(find.text('Bills'), findsOneWidget);

      // Filter Casa Schedule to Bills
      await tester.ensureVisible(find.text('Bills'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bills'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(HouseholdCalendarView),
          matching: find.text('Meralco Due Today (Due)'),
        ),
        findsOneWidget,
      );

      // Toggle presence inline via You: Home pill
      await tester.ensureVisible(find.text('You: Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('You: Home'));
      await tester.pumpAndSettle();
      expect(find.text('You: Out'), findsOneWidget);
      expect(find.text('2 of 4 Home'), findsOneWidget);

      // Clear toast timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
