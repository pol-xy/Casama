import 'package:casama/core/motion/casama_motion.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/data/supabase_repository.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:casama/shared/widgets/casama_notifications_sheet.dart';
import 'package:casama/shared/widgets/casama_wave_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Home, Boards, Chat, and Profile each render one shared Notification Bell opening the same Notifications sheet',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
      final tabs = ['Home', 'Boards', 'Chat', 'Profile'];

      for (final tab in tabs) {
        await tester.tap(find.descendant(of: navBar, matching: find.text(tab)));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Open menu'), findsOneWidget);
        expect(find.byType(CasamaNotificationBellButton), findsOneWidget);

        if (tab == 'Chat') {
          expect(
            find.descendant(
              of: find.byType(CasamaWaveHeader),
              matching: find.byIcon(Icons.person_add_alt_1_outlined),
            ),
            findsNothing,
          );
          expect(
            find.descendant(
              of: find.byType(CasamaWaveHeader),
              matching: find.byIcon(Icons.calendar_month_outlined),
            ),
            findsNothing,
          );
          expect(find.text('Add Housemate'), findsOneWidget);
        }

        if (tab == 'Profile') {
          expect(
            find.descendant(
              of: find.byType(CasamaWaveHeader),
              matching: find.byIcon(Icons.settings_outlined),
            ),
            findsNothing,
          );
          expect(find.text('Application Settings'), findsOneWidget);
        }

        await tester.tap(find.byType(CasamaNotificationBellButton));
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
        final expectedSubtitle = repo.unreadNotificationCount == 0
            ? 'All caught up!'
            : '${repo.unreadNotificationCount} unread ${repo.unreadNotificationCount == 1 ? 'update' : 'updates'}';
        expect(find.text(expectedSubtitle), findsOneWidget);
        expect(find.text('All notifications caught up'), findsNothing);

        await tester.tap(find.bySemanticsLabel('Close Notifications'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Notifications sheet disables Mark all read when empty or all-read, and enables it when unread exists (Light & Dark)',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final repo = MockRepository()..login();

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('notif_scope_${mode.name}'),
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: MaterialApp(
                theme: CasamaTheme.lightTheme,
                darkTheme: CasamaTheme.darkTheme,
                themeMode: mode,
                home: const MainNavigationShell(initialIndex: 1),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Empty notifications -> Mark all read disabled
        repo.setNotificationsForTest(const []);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CasamaNotificationBellButton));
        await tester.pumpAndSettle();

        expect(
          find.text("You're all caught up! No new notifications."),
          findsOneWidget,
        );
        final emptyBtn = tester.widget<CasamaPressable>(
          find.descendant(
            of: find.byKey(const ValueKey('casama_mark_all_read_button')),
            matching: find.byType(CasamaPressable),
          ),
        );
        expect(emptyBtn.onTap, isNull);

        await tester.tap(find.byKey(const ValueKey('casama_mark_all_read_button')));
        await tester.pumpAndSettle();
        expect(find.text('Notifications'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Close Notifications'));
        await tester.pumpAndSettle();

        // 2. All notifications already read -> Mark all read disabled
        repo.setNotificationsForTest([
          HouseholdNotificationItem(
            id: 'n_read',
            type: 'parcel_received',
            title: 'Parcel arrived',
            subtitle: 'Already read update',
            createdAt: DateTime.now(),
            isRead: true,
            readAt: DateTime.now(),
          ),
        ]);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CasamaNotificationBellButton));
        await tester.pumpAndSettle();

        expect(find.text('Already read update'), findsOneWidget);
        final readBtn = tester.widget<CasamaPressable>(
          find.descendant(
            of: find.byKey(const ValueKey('casama_mark_all_read_button')),
            matching: find.byType(CasamaPressable),
          ),
        );
        expect(readBtn.onTap, isNull);

        await tester.tap(find.bySemanticsLabel('Close Notifications'));
        await tester.pumpAndSettle();

        // 3. Unread notification -> Mark all read enabled and marks read in-place
        repo.setNotificationsForTest([
          HouseholdNotificationItem(
            id: 'n_unread',
            type: 'roulette_chosen',
            title: 'Chore Roulette',
            subtitle: 'You were picked to take out trash',
            createdAt: DateTime.now(),
            isRead: false,
            readAt: null,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(repo.unreadNotificationCount, 1);

        await tester.tap(find.byType(CasamaNotificationBellButton));
        await tester.pumpAndSettle();
        expect(find.text('1 unread update'), findsOneWidget);

        final unreadBtn = tester.widget<CasamaPressable>(
          find.descendant(
            of: find.byKey(const ValueKey('casama_mark_all_read_button')),
            matching: find.byType(CasamaPressable),
          ),
        );
        expect(unreadBtn.onTap, isNotNull);

        await tester.tap(find.byKey(const ValueKey('casama_mark_all_read_button')));
        await tester.pumpAndSettle();

        expect(repo.unreadNotificationCount, 0);
        expect(repo.notifications.single.readAt, isNotNull);
        // Sheet stays open and updates in-place
        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('All caught up!'), findsOneWidget);
        final afterBtn = tester.widget<CasamaPressable>(
          find.descendant(
            of: find.byKey(const ValueKey('casama_mark_all_read_button')),
            matching: find.byType(CasamaPressable),
          ),
        );
        expect(afterBtn.onTap, isNull);
      }
    },
  );

  testWidgets(
    'housemates_agenda_reminder notification renders calendar badge fallback, title, body, and marks read + navigates to GroupChatScreen on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'notif_agenda_1',
          type: 'housemates_agenda_reminder',
          title: 'Agenda Reminder: Dinner Hangout',
          subtitle: '',
          createdAt: DateTime.now(),
          isRead: false,
          payload: const {
            'title': 'Dinner Hangout',
            'location': 'Kitchen Table',
            'message': 'Starts in 1 hour at Kitchen Table',
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
      expect(find.text('Agenda Reminder: Dinner Hangout'), findsOneWidget);
      expect(find.text('Starts in 1 hour at Kitchen Table'), findsOneWidget);

      await tester.tap(find.text('Agenda Reminder: Dinner Hangout'));
      await tester.pumpAndSettle();

      expect(repo.notifications.single.readAt, isNotNull);
      expect(repo.unreadNotificationCount, 0);
      expect(find.byType(GroupChatScreen), findsOneWidget);
    },
  );

  testWidgets(
    'housemates_agenda_reminder notification renders creator CasamaAvatar when creator_id resolves',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      final creator = repo.members.firstWhere(
        (m) => m.profile.id != repo.currentUser.id,
      );
      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'notif_agenda_creator',
          type: 'housemates_agenda_reminder',
          title: 'Agenda Reminder: Online Hangout / Call',
          subtitle: '',
          createdAt: DateTime.now(),
          isRead: false,
          payload: {
            'creator_id': creator.profile.id,
            'title': 'Online Hangout / Call',
            'location': 'Online / Discord',
            'message': 'Starts in 1 hour — Online / Discord',
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('agenda_creator_avatar_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_rounded), findsNothing);
      final avatarFinder = find.byWidgetPredicate(
        (w) =>
            w is CasamaAvatar &&
            w.name == creator.profile.displayName &&
            w.radius == 21,
      );
      expect(avatarFinder, findsOneWidget);
    },
  );

  testWidgets(
    'Notifications sheet safely ignores legacy/unsupported notification rows without crashing',
    (tester) async {
      final repo = MockRepository()..login();
      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'notif_legacy_1',
          type: 'legacy_retired_reminder',
          title: 'Legacy reminder',
          subtitle: 'Should be ignored',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ]);

      expect(repo.notifications, isEmpty);
      expect(repo.unreadNotificationCount, 0);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      expect(
        find.text("You're all caught up! No new notifications."),
        findsOneWidget,
      );
      expect(find.text('Legacy reminder'), findsNothing);
      final btn = tester.widget<CasamaPressable>(
        find.descendant(
          of: find.byKey(const ValueKey('casama_mark_all_read_button')),
          matching: find.byType(CasamaPressable),
        ),
      );
      expect(btn.onTap, isNull);
    },
  );

  testWidgets(
    'roulette_chosen notification renders spinner CasamaAvatar, fun copy, bonus pts badge, and navigates to Boards -> Tasks on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      final spinner = repo.members.firstWhere(
        (m) => m.profile.id != repo.currentUser.id,
      );
      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'notif_roulette_chosen_1',
          type: 'roulette_chosen',
          title: '',
          subtitle: '',
          createdAt: DateTime.now(),
          isRead: false,
          payload: {
            'spinner_id': spinner.profile.id,
            'spinner_name': spinner.profile.displayName,
            'task_id': 't3',
            'task_title': 'Defrost Freezer',
            'bonus_points': 4,
            'total_points': 11,
            'title': '🎡 You were chosen for "Defrost Freezer"!',
            'message':
                '${spinner.profile.displayName} spun the wheel — earn +4 bonus pts (11 pts total)!',
          },
        ),
        HouseholdNotificationItem(
          id: 'notif_roulette_self_1',
          type: 'roulette_chosen',
          title: '',
          subtitle: '',
          createdAt: DateTime.now(),
          isRead: true,
          readAt: DateTime.now(),
          payload: {
            'spinner_id': spinner.profile.id,
            'spinner_name': spinner.profile.displayName,
            'selected_user_id': repo.currentUser.id,
            'task_id': 't1',
            'task_title': 'Leaking Faucet',
            'bonus_points': 4,
            'total_points': 18,
            'title': '🎡 You were chosen for "Leaking Faucet"!',
            'message':
                '${spinner.profile.displayName} spun the wheel and picked you!',
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('roulette_notif_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      expect(
        find.text('🎡 You were chosen for "Defrost Freezer"!'),
        findsOneWidget,
      );
      expect(
        find.text(
          '${spinner.profile.displayName} spun the wheel — earn +4 bonus pts (11 pts total)!',
        ),
        findsOneWidget,
      );
      // Shown once (only for t3, hidden on self-request t1)
      expect(find.text('+4 bonus pts'), findsOneWidget);
      final avatarFinder = find.byWidgetPredicate(
        (w) =>
            w is CasamaAvatar &&
            w.name == spinner.profile.displayName &&
            w.radius == 21,
      );
      expect(avatarFinder, findsNWidgets(2));

      await tester.tap(
        find.text('🎡 You were chosen for "Defrost Freezer"!'),
      );
      await tester.pumpAndSettle();

      expect(repo.notifications.first.readAt, isNotNull);
      expect(repo.unreadNotificationCount, 0);
      expect(find.text('Household Tasks'), findsOneWidget);
    },
  );

  testWidgets(
    'Notifications sheet renders all 4 domain families, verbatim payload copy, points guards, and routes cleanly on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      final mariaId = '22222222-2222-2222-2222-222222222222';
      final now = DateTime.now();

      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'n_parcel_arrived',
          type: 'parcel_arrived',
          title: '',
          subtitle: '',
          createdAt: now,
          isRead: false,
          payload: {
            'entity_type': 'parcel',
            'entity_id': 'p1',
            'parcel_id': 'p1',
            'actor_id': mariaId,
            'title': '📦 J&T Express parcel is at the gate!',
            'message': 'Arriving now for Maria — tap to claim.',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_parcel_claimed',
          type: 'parcel_claimed',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 1)),
          isRead: false,
          payload: {
            'entity_type': 'parcel',
            'entity_id': 'p2',
            'parcel_id': 'p2',
            'actor_id': mariaId,
            'points': 5,
            'title': 'Maria got Alex\'s Flash Express parcel!',
            'message': 'Safe in the living room (+5 pts).',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_task_completed_other',
          type: 'task_completed',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 2)),
          isRead: false,
          payload: {
            'entity_type': 'task',
            'entity_id': 't2',
            'task_id': 't2',
            'actor_id': repo.currentUser.id,
            'points': 9,
            'title': 'You crushed "Buy Drinking Water"!',
            'message': 'Earned +9 pts for the Casa!',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_task_completed_self',
          type: 'task_completed',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 3)),
          isRead: true,
          readAt: now,
          payload: {
            'entity_type': 'task',
            'entity_id': 't1',
            'task_id': 't1',
            'actor_id': repo.currentUser.id,
            'is_self_created': true,
            'points': 14,
            'title': 'Marked "Leaking Faucet" done',
            'message': 'Self-requested task closed cleanly.',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_lost_accepted',
          type: 'lost_item_find_accepted',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 4)),
          isRead: false,
          payload: {
            'entity_type': 'lost_item',
            'entity_id': 'i1',
            'lost_item_id': 'i1',
            'actor_id': mariaId,
            'points': 5,
            'title': 'Match confirmed for "Lost AirPods"!',
            'message': 'You earned +5 pts for returning it.',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_found_claimed',
          type: 'found_item_claimed',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 5)),
          isRead: true,
          readAt: now,
          payload: {
            'entity_type': 'found_item',
            'entity_id': 'i2',
            'found_item_id': 'i2',
            'actor_id': mariaId,
            'points': 2,
            'title': 'Found Backpack claimed!',
            'message': 'Maria earned +2 pts.',
          },
        ),
        HouseholdNotificationItem(
          id: 'n_agenda_created',
          type: 'housemates_agenda_created',
          title: '',
          subtitle: '',
          createdAt: now.subtract(const Duration(minutes: 6)),
          isRead: false,
          payload: {
            'entity_type': 'housemates_agenda',
            'entity_id': 'm1',
            'invitation_id': 'm1',
            'creator_id': mariaId,
            'title': '📅 New Agenda: Study Session',
            'message': 'Dorm Common Area — RSVP in Connect!',
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      // Verbatim payload titles & messages render cleanly
      expect(find.text('📦 J&T Express parcel is at the gate!'), findsOneWidget);
      expect(find.text('Arriving now for Maria — tap to claim.'), findsOneWidget);
      expect(find.text('You crushed "Buy Drinking Water"!'), findsOneWidget);
      expect(find.text('Match confirmed for "Lost AirPods"!'), findsOneWidget);
      expect(find.text('📅 New Agenda: Study Session'), findsOneWidget);

      // Domain pills & points pills (+5 pts appears twice, +9 pts once, +2 pts once; +14 pts self-request hidden)
      expect(find.text('Parcels'), findsWidgets);
      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('Lost & Found'), findsWidgets);
      expect(find.text('Agenda'), findsWidgets);
      expect(find.text('+5 pts'), findsNWidgets(2));
      expect(find.text('+9 pts'), findsOneWidget);
      expect(find.text('+2 pts'), findsOneWidget);
      expect(find.text('+14 pts'), findsNothing);

      // Tap Parcel notification -> marks read and navigates to Boards -> Parcels
      await tester.tap(find.text('📦 J&T Express parcel is at the gate!'));
      await tester.pumpAndSettle();
      expect(find.text('Parcels & Deliveries'), findsOneWidget);
      expect(repo.notifications.first.readAt, isNotNull);

      // Reopen and tap Lost & Found notification -> navigates to Boards -> Items
      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Match confirmed for "Lost AirPods"!'));
      await tester.tap(find.text('Match confirmed for "Lost AirPods"!'));
      await tester.pumpAndSettle();
      expect(find.text('Lost & Found'), findsOneWidget);

      // Reopen and tap Agenda Created notification -> navigates to ChatDirectoryScreen
      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('📅 New Agenda: Study Session'));
      await tester.tap(find.text('📅 New Agenda: Study Session'));
      await tester.pumpAndSettle();
      expect(find.byType(ChatDirectoryScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Deleting entities purges their generated notifications and updates Notification Bell reactively',
    (tester) async {
      final repo = MockRepository()..login();
      repo.setNotificationsForTest(const []);

      repo.addParcel(
        courier: 'LBC Express',
        arrival: DateTime.now(),
        paymentType: ParcelPaymentType.paid,
      );
      final parcelId = repo.parcels.first.id;

      repo.addTask(
        title: 'Clean Refrigerator',
        category: TaskCategory.cleaning,
        urgency: TaskUrgency.medium,
      );
      final taskId = repo.tasks.first.id;

      repo.postItem(
        type: ItemType.lost,
        title: 'Blue Umbrella',
        location: 'Entryway',
      );
      final itemId = repo.items.first.id;

      await repo.createHousematesAgendaInvitation(
        activity: 'Game Night',
        location: 'Living Room',
        scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      );
      final agendaId = repo.housematesAgendaInvitations
          .firstWhere((a) => a.activity == 'Game Night')
          .id;

      expect(repo.notifications.length, 4);
      expect(repo.unreadNotificationCount, 4);

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
              home: const MainNavigationShell(initialIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Notifications, 4 unread'), findsOneWidget);

      // Delete each entity and assert its notification disappears immediately
      repo.deleteParcelForTest(parcelId);
      await tester.pumpAndSettle();
      expect(repo.notifications.length, 3);
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);

      repo.deleteTaskForTest(taskId);
      await tester.pumpAndSettle();
      expect(repo.notifications.length, 2);

      repo.deleteItemForTest(itemId);
      await tester.pumpAndSettle();
      expect(repo.notifications.length, 1);

      await repo.deleteHousematesAgendaInvitation(agendaId);
      await tester.pumpAndSettle();
      expect(repo.notifications, isEmpty);
      expect(repo.unreadNotificationCount, 0);
      expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
    },
  );

  testWidgets(
    'ParcelsBoardView keeps arrived parcels at top of Upcoming & My Parcels with Arriving Now badge and I Got It',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        final repo = MockRepository()..login();
        final arrivedId = 'p_arrived_${mode.name}';
        repo.addParcel(
          courier: 'Ninja Van',
          arrival: DateTime.now().add(const Duration(days: 2)),
          paymentType: ParcelPaymentType.paid,
          notes: 'Gate guard holding package',
        );
        final createdId = repo.parcels.first.id;
        await repo.updateParcel(
          parcelId: createdId,
          status: ParcelStatus.arrived,
          notes: arrivedId,
        );

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('arrived_parcel_${mode.name}'),
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(390, 844),
                disableAnimations: true,
              ),
              child: MaterialApp(
                theme: CasamaTheme.lightTheme,
                darkTheme: CasamaTheme.darkTheme,
                themeMode: mode,
                home: const Scaffold(body: ParcelsBoardView(bottomPadding: 24)),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Upcoming -> arrived future parcel appears at top with Scheduled Today badge & I Got It when expanded
        await tester.tap(find.text('Upcoming'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('parcel_scheduled_today_$createdId')), findsOneWidget);
        expect(find.text('Scheduled Today'), findsOneWidget);
        await tester.tap(find.text('Ninja Van'));
        await tester.pumpAndSettle();
        expect(find.text('I Got It'), findsWidgets);

        // Switch to My Parcels -> arrived parcel is visible there too
        await tester.tap(find.text('My Parcels'));
        await tester.pumpAndSettle();
        expect(find.byKey(ValueKey('parcel_scheduled_today_$createdId')), findsOneWidget);
        expect(find.text('Scheduled Today'), findsOneWidget);
      }
    },
  );

  test('formatGroupChatWheelSpinMessage uses natural first-person phrasing', () {
    expect(
      formatGroupChatWheelSpinMessage(
        question: '  Who gets the last slice?  ',
        winnerName: 'Maria',
        landedOnSelf: false,
      ),
      '🎡 Just spun the wheel!\n\n'
      '"Who gets the last slice?"\n'
      '👉 Landed on: Maria! 🎉',
    );
    expect(
      formatGroupChatWheelSpinMessage(
        question: 'Who is washing dishes?',
        winnerName: 'JP',
        landedOnSelf: true,
      ),
      '🎡 Just spun the wheel!\n\n'
      '"Who is washing dishes?"\n'
      '👉 Landed on: me! 😂',
    );
  });

  testWidgets(
    'housemate_joined notification parses cleanly, renders in Notifications sheet, and routes to Home',
    (tester) async {
      final parsed = SupabaseRepository.parseNotificationRow({
        'id': 'notif-join-1',
        'type': 'housemate_joined',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'read_at': null,
        'payload': {
          'entity_type': 'household',
          'actor_id': 'u-new',
          'actor_name': 'Alex',
          'household_name': 'Casa 204',
        },
      });
      expect(parsed.isSupportedNotification, isTrue);
      expect(parsed.isHouseholdUpdateNotification, isTrue);
      expect(parsed.domain, NotificationDomain.household);
      expect(parsed.displayTitle, 'Alex joined Casa 204');
      expect(parsed.displaySubtitle, 'Say hello to your new housemate!');

      final repo = MockRepository()..login();
      repo.setNotificationsForTest([parsed]);

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
              home: const MainNavigationShell(initialIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      expect(find.text('Household'), findsOneWidget);
      expect(find.text('Alex joined Casa 204'), findsOneWidget);
      expect(find.text('Say hello to your new housemate!'), findsOneWidget);

      await tester.tap(find.text('Alex joined Casa 204'));
      await tester.pumpAndSettle();

      expect(find.text('3 of 4 Home'), findsOneWidget);
    },
  );

  testWidgets(
    'Bell shows numeric unread badge matching unread count, capped at 9+, and hides at 0',
    (tester) async {
      final repo = MockRepository()..login();
      final now = DateTime.now();

      List<HouseholdNotificationItem> buildUnread(int count) => [
        for (var i = 0; i < count; i++)
          HouseholdNotificationItem(
            id: 'n_badge_$i',
            type: 'parcel_received',
            title: 'Parcel $i',
            subtitle: 'Delivered',
            createdAt: now,
            isRead: false,
          ),
      ];

      repo.setNotificationsForTest(buildUnread(3));

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
              home: const MainNavigationShell(initialIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bellFinder = find.byType(CasamaNotificationBellButton);
      expect(
        find.descendant(of: bellFinder, matching: find.text('3')),
        findsOneWidget,
      );

      repo.setNotificationsForTest(buildUnread(10));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: bellFinder, matching: find.text('9+')),
        findsOneWidget,
      );

      repo.setNotificationsForTest(const []);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: bellFinder, matching: find.text('9+')),
        findsNothing,
      );
      expect(
        find.descendant(of: bellFinder, matching: find.text('0')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Pinned filter pills switch between All and Unread and distinguish unread vs read cards',
    (tester) async {
      final repo = MockRepository()..login();
      final now = DateTime.now();

      repo.setNotificationsForTest([
        HouseholdNotificationItem(
          id: 'n_unread_card',
          type: 'parcel_arrived',
          title: 'Unread Parcel Update',
          subtitle: 'Waiting at the gate',
          createdAt: now,
          isRead: false,
          readAt: null,
        ),
        HouseholdNotificationItem(
          id: 'n_read_card',
          type: 'task_completed',
          title: 'Read Task Update',
          subtitle: 'Already completed',
          createdAt: now.subtract(const Duration(minutes: 5)),
          isRead: true,
          readAt: now,
        ),
      ]);

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
              home: const MainNavigationShell(initialIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CasamaNotificationBellButton));
      await tester.pumpAndSettle();

      // Dynamic subtitle reflects 1 unread
      expect(find.text('1 unread update'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('casama_notif_filter_all')),
          matching: find.text('All'),
        ),
        findsOneWidget,
      );
      expect(find.text('Unread (1)'), findsOneWidget);

      // Both cards visible under All
      expect(find.text('Unread Parcel Update'), findsOneWidget);
      expect(find.text('Read Task Update'), findsOneWidget);

      // Visual distinction: unread title is w700, read title is w500
      final unreadTitle = tester.widget<Text>(find.text('Unread Parcel Update'));
      final readTitle = tester.widget<Text>(find.text('Read Task Update'));
      expect(unreadTitle.style?.fontWeight, FontWeight.w700);
      expect(readTitle.style?.fontWeight, FontWeight.w500);

      // Tap Unread (1) pill -> hides read notification
      await tester.tap(find.byKey(const ValueKey('casama_notif_filter_unread')));
      await tester.pumpAndSettle();
      expect(find.text('Unread Parcel Update'), findsOneWidget);
      expect(find.text('Read Task Update'), findsNothing);

      // Tap Mark all read -> sheet stays open, shows Unread empty state
      await tester.tap(find.byKey(const ValueKey('casama_mark_all_read_button')));
      await tester.pumpAndSettle();
      expect(find.text('Unread (0)'), findsOneWidget);
      expect(find.text('No unread notifications right now.'), findsOneWidget);

      // Switch back to All -> both notifications visible as read
      await tester.tap(find.byKey(const ValueKey('casama_notif_filter_all')));
      await tester.pumpAndSettle();
      expect(find.text('Unread Parcel Update'), findsOneWidget);
      expect(find.text('Read Task Update'), findsOneWidget);
    },
  );
}
