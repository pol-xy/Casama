import 'package:casama/core/router/app_router.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/calendar/household_calendar_view.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/dashboard/widgets/casama_household_drawer.dart';
import 'package:casama/features/household/create_household_sheet.dart';
import 'package:casama/features/points/leaderboard_screen.dart';
import 'package:casama/shared/widgets/avatar_chip.dart';
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

      // Tapping Live Attention row routes to Boards while remembering tab 2 (Items)
      final context = tester.element(find.byType(DashboardScreen));
      final shell = CasamaShellScope.maybeOf(context)!;
      expect(shell.boardTabListenable.value, 2);

      // Legacy out-of-range board tab index (3) safely clamps to 2
      shell.openBoardTab(3);
      await tester.pumpAndSettle();
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
    'DashboardScreen toggles inline You: Home status, enforces Live Attention 3-rule filter + View all sheet, and Casa Schedule shows Parcels & Agendas only',
    (tester) async {
      final repo = MockRepository()..login();
      repo.addTask(
        title: 'Clean Balcony Today',
        category: TaskCategory.cleaning,
        urgency: TaskUrgency.urgent,
      );
      repo.addTask(
        title: 'Non Urgent Task',
        category: TaskCategory.cleaning,
        urgency: TaskUrgency.low,
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
              home: const MainNavigationShell(),
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
      expect(find.text('Non Urgent Task'), findsNothing);
      expect(find.text('Clean Balcony Today'), findsOneWidget);
      expect(find.textContaining('By You'), findsWidgets);
      expect(find.text('Status: Scheduled Today'), findsWidgets);
      expect(find.text('Casa Schedule'), findsOneWidget);
      expect(find.byType(HouseholdCalendarView), findsOneWidget);
      expect(find.text('Bills'), findsNothing);

      // Casa Schedule shows All, Parcels, Agenda (no Tasks filter or tasks in schedule)
      final cal = find.byType(HouseholdCalendarView);
      expect(find.descendant(of: cal, matching: find.text('All')), findsOneWidget);
      expect(find.descendant(of: cal, matching: find.text('Parcels')), findsOneWidget);
      expect(find.descendant(of: cal, matching: find.text('Agenda')), findsWidgets);
      expect(find.descendant(of: cal, matching: find.text('Tasks')), findsNothing);
      expect(
        find.descendant(of: cal, matching: find.text('Clean Balcony Today')),
        findsNothing,
      );
      expect(
        find.descendant(of: cal, matching: find.text("Maria's J&T Express Package")),
        findsOneWidget,
      );

      // Live Attention "View all ›" opens bottom sheet listing all qualifying items (including <24h undecided Agenda)
      final viewAllBtn = find.byKey(const ValueKey('live_attention_view_all_button'));
      await tester.ensureVisible(viewAllBtn);
      await tester.pumpAndSettle();
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();
      expect(find.text('Study Session 🎓'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Close Live Attention Needed'));
      await tester.pumpAndSettle();

      // Tapping an Agenda row in Casa Schedule routes to ChatDirectoryScreen (Housemates Agenda section)
      final agendaRow = find.descendant(
        of: cal,
        matching: find.text('Study Session 🎓'),
      );
      await tester.ensureVisible(agendaRow);
      await tester.pumpAndSettle();
      await tester.tap(agendaRow);
      await tester.pumpAndSettle();
      expect(find.byType(ChatDirectoryScreen), findsOneWidget);

      // Return Home and toggle presence inline via You: Home pill
      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
      await tester.tap(find.descendant(of: navBar, matching: find.text('Home')));
      await tester.pumpAndSettle();
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

  testWidgets(
    'DashboardScreen shows clean Live Attention Needed empty copy when no urgent tasks, today parcels, or undecided agendas remain',
    (tester) async {
      final repo = MockRepository()..login();
      for (final t in List<MaintenanceTask>.from(repo.tasks)) {
        repo.completeTask(t.id);
      }
      for (final p in List<ParcelItem>.from(repo.parcels)) {
        if (p.status != ParcelStatus.received &&
            p.status != ParcelStatus.cancelled) {
          repo.receiveParcel(p.id);
        }
        if (!p.isSettled) {
          await repo.settleParcelClaim(p.id);
        }
      }
      repo.respondToHousematesAgendaInvitation('going');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('All caught up — no urgent tasks, today parcels, or pending agendas.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "DashboardScreen Who's Home card aligns avatars, renders note bubbles, and opens bottom drawer without controller disposal errors",
    (tester) async {
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            // Keep animations enabled to exercise the real 280ms sheet exit transition.
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: false,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const DashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 avatars sit on a single aligned baseline row
      final avatarChips = find.byType(AvatarChip);
      expect(avatarChips, findsNWidgets(4));
      final baselineY = tester.getBottomLeft(avatarChips.at(0)).dy;
      for (var i = 1; i < 4; i++) {
        expect(
          tester.getBottomLeft(avatarChips.at(i)).dy,
          closeTo(baselineY, 0.5),
        );
      }

      // Existing housemate note bubble is rendered above Maria's avatar
      expect(find.text('In living room'), findsOneWidget);

      // Tap current user ("You") -> opens bottom sheet drawer with input & Save
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();

      expect(find.text('Update Your Presence'), findsOneWidget);
      expect(find.byKey(const ValueKey('presence_note_input')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('presence_note_save_button')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('presence_note_input')),
        'Studying in living room',
      );
      await tester.tap(find.byKey(const ValueKey('presence_note_save_button')));
      // Pump through the 280ms reverse sheet transition to catch _dependents.isEmpty
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final selfMember = repo.members.firstWhere(
        (m) => m.profile.id == repo.currentUser.id,
      );
      expect(selfMember.note, 'Studying in living room');
      expect(find.text('Studying in living room'), findsOneWidget);

      // Advance past toast timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Reopen self sheet, clear note, and save -> clears note cleanly
      await tester.tap(find.text('You'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('presence_note_input')),
        '',
      );
      await tester.tap(find.byKey(const ValueKey('presence_note_save_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final clearedSelf = repo.members.firstWhere(
        (m) => m.profile.id == repo.currentUser.id,
      );
      expect(clearedSelf.note, isNull);
      expect(find.text('Studying in living room'), findsNothing);

      // Advance past toast timer
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Tap another housemate ("Maria") -> opens bottom drawer with saved note
      await tester.tap(find.text('Maria'));
      await tester.pumpAndSettle();

      expect(find.text('Currently Home'), findsOneWidget);
      expect(find.text('"In living room"'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close Maria'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
