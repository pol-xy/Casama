import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:casama/shared/widgets/casama_button.dart';
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
        expect(find.text('Recent household updates'), findsOneWidget);
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
        final emptyBtn = tester.widget<CasamaButton>(
          find.byKey(const ValueKey('casama_mark_all_read_button')),
        );
        expect(emptyBtn.onPressed, isNull);

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
        final readBtn = tester.widget<CasamaButton>(
          find.byKey(const ValueKey('casama_mark_all_read_button')),
        );
        expect(readBtn.onPressed, isNull);

        await tester.tap(find.bySemanticsLabel('Close Notifications'));
        await tester.pumpAndSettle();

        // 3. Unread notification -> Mark all read enabled and marks read
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

        final unreadBtn = tester.widget<CasamaButton>(
          find.byKey(const ValueKey('casama_mark_all_read_button')),
        );
        expect(unreadBtn.onPressed, isNotNull);

        await tester.tap(find.byKey(const ValueKey('casama_mark_all_read_button')));
        await tester.pumpAndSettle();

        expect(repo.unreadNotificationCount, 0);
        expect(repo.notifications.single.readAt, isNotNull);

        // Re-opening sheet now shows Mark all read disabled
        await tester.tap(find.byType(CasamaNotificationBellButton));
        await tester.pumpAndSettle();
        final afterBtn = tester.widget<CasamaButton>(
          find.byKey(const ValueKey('casama_mark_all_read_button')),
        );
        expect(afterBtn.onPressed, isNull);
      }
    },
  );

  testWidgets(
    'meetup_reminder notification renders calendar badge, title, body, and marks read + navigates to GroupChatScreen on tap',
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
          id: 'notif_meetup_1',
          type: 'meetup_reminder',
          title: 'Meet-up Reminder: Dinner Hangout',
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
      expect(find.text('Meet-up Reminder: Dinner Hangout'), findsOneWidget);
      expect(find.text('Starts in 1 hour at Kitchen Table'), findsOneWidget);

      await tester.tap(find.text('Meet-up Reminder: Dinner Hangout'));
      await tester.pumpAndSettle();

      expect(repo.notifications.single.readAt, isNotNull);
      expect(repo.unreadNotificationCount, 0);
      expect(find.byType(GroupChatScreen), findsOneWidget);
    },
  );

  testWidgets(
    'meetup_reminder notification renders creator CasamaAvatar when creator_id or invitation_id resolves',
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
          id: 'notif_meetup_creator',
          type: 'meetup_reminder',
          title: 'Meet-up Reminder: Coffee Run',
          subtitle: '',
          createdAt: DateTime.now(),
          isRead: false,
          payload: {
            'creator_id': creator.profile.id,
            'title': 'Coffee Run',
            'location': 'Kitchen',
            'message': 'Starts in 1 hour at Kitchen',
          },
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('meetup_creator_avatar_scope'),
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
            w.radius == 20,
      );
      expect(avatarFinder, findsOneWidget);
    },
  );
}
