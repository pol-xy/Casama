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
import 'package:casama/features/household/create_household_sheet.dart';
import 'package:casama/features/points/leaderboard_screen.dart';
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
    'CasamaHouseholdDrawer renders Forest Teal header, copies invite code, removes legacy items, and opens Casama Leaderboard',
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
      appRouter.go('/dashboard');
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pumpAndSettle();

      expect(find.byType(CasamaHouseholdDrawer), findsOneWidget);
      expect(find.text('Community Space • 4 members'), findsOneWidget);
      expect(find.text('Casa 204'), findsWidgets);
      expect(find.text('INVITE CODE: '), findsOneWidget);
      expect(find.text('CASA204'), findsOneWidget);
      expect(find.byType(CasMascotView), findsWidgets);

      // Legacy 5 drawer items must be removed
      expect(find.text('Invite Housemate'), findsNothing);
      expect(find.text('My Household'), findsNothing);
      expect(find.text('Household Boards'), findsNothing);
      expect(find.text('App Settings'), findsNothing);
      expect(find.text('Privacy & Permissions'), findsNothing);

      // New Casama Leaderboard highlight item
      expect(find.text('CASA HIGHLIGHTS'), findsOneWidget);
      expect(find.text('Casama Leaderboard'), findsOneWidget);
      expect(find.text('Household standings & point rules'), findsOneWidget);

      // Copy invite code shows Copied visual feedback + copies to clipboard
      await tester.tap(find.byKey(const Key('drawer_copy_invite_code_pill')));
      await tester.pump();
      expect(copiedText, 'CASA204');
      expect(find.text('Copied'), findsOneWidget);

      // Advance past copied reset + auto-dismiss toast timer cleanly
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Close drawer via circular close button
      await tester.tap(find.bySemanticsLabel('Close household menu'));
      await tester.pumpAndSettle();
      expect(find.byType(CasamaHouseholdDrawer), findsNothing);

      // Re-open drawer and navigate to Casama Leaderboard
      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casama Leaderboard'));
      await tester.pumpAndSettle();

      expect(find.byType(CasamaHouseholdDrawer), findsNothing);
      expect(find.byType(LeaderboardScreen), findsOneWidget);
      expect(find.text('Casama Leaderboard'), findsOneWidget);
    },
  );

  testWidgets(
    'CasamaHouseholdDrawer supports expanding switcher, creating a new household, and switching back',
    (tester) async {
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp.router(
            theme: CasamaTheme.lightTheme,
            routerConfig: appRouter,
          ),
        ),
      );
      appRouter.go('/dashboard');
      await tester.pumpAndSettle();

      // Open drawer & expand household switcher dropdown
      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('drawer_household_switcher_panel')), findsNothing);

      await tester.tap(find.byKey(const Key('drawer_household_switcher_trigger')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('drawer_household_switcher_panel')),
        findsOneWidget,
      );
      expect(find.text('YOUR HOUSEHOLDS'), findsOneWidget);
      expect(find.text('Create New Household'), findsOneWidget);
      expect(find.text('Join with Invite Code'), findsOneWidget);

      // Tap Create New Household -> opens slide-up sheet
      await tester.tap(find.byKey(const Key('drawer_create_household_action')));
      await tester.pumpAndSettle();
      expect(find.text('Create New Household'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'TeenTitans');
      await tester.tap(find.text('Create Household'));
      await tester.pumpAndSettle();

      expect(repo.currentHousehold.name, 'TeenTitans');
      expect(repo.currentHousehold.inviteCode, isNot('CASA204'));
      expect(repo.currentHousehold.inviteCode.length, 6);
      expect(repo.userHouseholds.length, 2);
      expect(find.text('TEENTITANS STATUS'), findsOneWidget);

      // Advance past toast timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Reopen drawer, expand switcher, and switch back to Casa 204
      await tester.tap(find.bySemanticsLabel('Open menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('drawer_household_switcher_trigger')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Casa 204'));
      await tester.pumpAndSettle();

      expect(find.byType(CasamaHouseholdDrawer), findsNothing);
      expect(repo.currentHousehold.name, 'Casa 204');
      expect(repo.members.length, 4);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'CasamaHouseholdDrawer and CreateHouseholdSheet render cleanly in Dark Mode with reduced motion',
    (tester) async {
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
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => showCasamaHouseholdDrawer(ctx),
                          child: const Text('Open Drawer'),
                        ),
                        ElevatedButton(
                          onPressed: () => showCreateHouseholdSheet(ctx),
                          child: const Text('Open Create Sheet'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Drawer'));
      await tester.pumpAndSettle();
      expect(find.byType(CasamaHouseholdDrawer), findsOneWidget);

      await tester.tap(find.byKey(const Key('drawer_household_switcher_trigger')));
      await tester.pumpAndSettle();
      expect(find.text('Create New Household'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close household menu'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Create Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Household'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      expect(find.textContaining('Assigned to'), findsNothing);
      expect(find.textContaining('Unassigned'), findsNothing);
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
