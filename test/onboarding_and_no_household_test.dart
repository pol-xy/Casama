import 'package:casama/core/router/app_router.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/auth/optional_profile_screen.dart';
import 'package:casama/features/household/household_setup_screen.dart';
import 'package:casama/features/onboarding/interactive_tutorial_screen.dart';
import 'package:casama/features/profile/edit_profile_dialog.dart';
import 'package:casama/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('Returning Login, Onboarding Resume & No-Household Workspace', () {
    test('Returning user (hasCompletedOnboarding == true) always routes to /dashboard with or without a household', () {
      const returningNoHousehold = UserProfile(
        id: 'u-ret-1',
        displayName: 'grizzlylanz10',
        handle: '@grizzly',
        fullName: 'Trixter Lanz',
        nickname: 'Trixter',
        hasConsentedTerms: true,
        hasCompletedOnboarding: true,
      );

      expect(resolveAuthenticatedDestination(returningNoHousehold), '/dashboard');
      expect(
        resolveStartupRoute(
          isAuthenticated: true,
          hasActiveHousehold: false,
          hasCompleteRequiredProfile: false,
          hasCompletedOnboarding: true,
        ),
        '/dashboard',
      );
      expect(
        resolveProfileCompletenessRedirect(
          isAuthenticated: true,
          currentUser: returningNoHousehold,
          matchedLocation: '/dashboard',
        ),
        isNull,
      );
    });

    test('Incomplete user (hasCompletedOnboarding == false) resumes at exact missing step', () {
      const missingProfile = UserProfile(
        id: 'u-inc-1',
        displayName: 'newuser',
        handle: '@newuser',
        hasConsentedTerms: false,
        hasCompletedOnboarding: false,
      );
      expect(resolveAuthenticatedDestination(missingProfile), '/profile-setup');

      final profileDoneNeedsHousehold = UserProfile(
        id: 'u-inc-2',
        displayName: 'Clara Reyes',
        handle: '@clara',
        fullName: 'Clara Reyes',
        nickname: 'Clar',
        birthday: DateTime(2001, 4, 10),
        hasConsentedTerms: true,
        hasCompletedOnboarding: false,
      );
      expect(
        resolveAuthenticatedDestination(profileDoneNeedsHousehold),
        '/household-setup',
      );
      expect(
        resolveStartupRoute(
          isAuthenticated: true,
          hasActiveHousehold: false,
          hasCompleteRequiredProfile: true,
          hasCompletedOnboarding: false,
        ),
        '/household-setup',
      );
    });

    testWidgets('OptionalProfileScreen and EditProfileDialog use single Full Name input and pre-fill saved fields', (
      tester,
    ) async {
      final repo = MockRepository()..logout();
      repo.register(email: 'resume@casama.app', password: 'password123');
      repo.updateProfile(fullName: 'Saved Name', nickname: 'Sav');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const OptionalProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('First Name'), findsNothing);
      expect(find.text('Last Name'), findsNothing);
      expect(find.text('Saved Name'), findsOneWidget);
      expect(find.text('Sav'), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const Scaffold(body: EditProfileDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('First Name'), findsNothing);
      expect(find.text('Last Name'), findsNothing);
    });

    testWidgets('HouseholdSetupScreen "Join a household later" advances without household and keeps onboarding false until Dashboard tour', (
      tester,
    ) async {
      final repo = MockRepository()..logout();
      repo.register(email: 'later@casama.app', password: 'password123');
      repo.updateProfile(
        fullName: 'Later User',
        nickname: 'Later',
        birthday: DateTime(2000, 1, 1),
        hasConsentedTerms: true,
      );

      final router = GoRouter(
        initialLocation: '/household-setup',
        routes: [
          GoRoute(
            path: '/household-setup',
            builder: (context, state) => const HouseholdSetupScreen(),
          ),
          GoRoute(
            path: '/permissions',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Permissions Step')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp.router(
            theme: CasamaTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final joinLaterBtn = find.byKey(
        const Key('household_setup_join_later_button'),
      );
      await tester.ensureVisible(joinLaterBtn);
      await tester.tap(joinLaterBtn);
      await tester.pumpAndSettle();

      expect(find.text('Permissions Step'), findsOneWidget);
      expect(repo.hasActiveHousehold, isFalse);
      expect(repo.currentUser.hasCompletedOnboarding, isFalse);
    });

    testWidgets('No-Household Dashboard tour completes onboarding cleanly across all 5 tabs and transitions live on Join/Create', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..logout();
      repo.register(email: 'nohh@casama.app', password: 'password123');
      repo.updateProfile(
        fullName: 'Solo Explorer',
        nickname: 'Solo',
        birthday: DateTime(2001, 6, 15),
        hasConsentedTerms: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const InteractiveTutorialScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Persisted immediately on entering the Dashboard tutorial
      expect(repo.currentUser.hasCompletedOnboarding, isTrue);
      expect(find.text('Hello, Solo!'), findsOneWidget);
      expect(find.text('No household yet'), findsOneWidget);
      expect(find.text('Join a Household'), findsOneWidget);
      expect(find.text('Create a Household'), findsOneWidget);
      expect(find.text('1. Home Dashboard & Presence'), findsOneWidget);

      // Step 2: Boards (No-Household prompt, FAB hidden)
      await tester.tap(find.text('Next: Boards ›'));
      await tester.pumpAndSettle();
      expect(find.text('2. Unified Household Boards'), findsOneWidget);
      expect(find.text('Add parcel'), findsNothing);
      expect(find.text('Join a household'), findsWidgets);

      // Step 3: CASnap
      await tester.tap(find.text('Next: CASnap ›'));
      await tester.pumpAndSettle();
      expect(find.text('3. CASnap Household Camera'), findsOneWidget);

      // Step 4: Chat
      await tester.tap(find.text('Next: Chat ›'));
      await tester.pumpAndSettle();
      expect(find.text('4. Household Chat & Agendas'), findsOneWidget);

      // Step 5: Profile (0 pts / No household yet)
      await tester.tap(find.text('Next: Profile ›'));
      await tester.pumpAndSettle();
      expect(find.text('5. Profile, Roulette & Points'), findsOneWidget);
      expect(find.text('0 pts'), findsOneWidget);

      // Finish Tour -> returns to Home Dashboard
      await tester.tap(find.text('Finish Tour 🎉'));
      await tester.pumpAndSettle();
      expect(find.text('App Tour (1 of 5)'), findsNothing);

      // Open Drawer -> shows No Household Yet, hides INVITE CODE
      await tester.tap(find.bySemanticsLabel('Open menu').first);
      await tester.pumpAndSettle();
      expect(find.text('No Household Yet'), findsOneWidget);
      expect(find.byKey(const Key('drawer_copy_invite_code_pill')), findsNothing);
      expect(find.text('Join with Invite Code'), findsOneWidget);
      expect(find.text('Create New Household'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Close household menu'));
      await tester.pumpAndSettle();

      // Open Notification sheet -> shows safe No-Household message
      await tester.tap(find.bySemanticsLabel('Notifications').first);
      await tester.pumpAndSettle();
      expect(
        find.text('Join a household to receive household alerts'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Live Join/Create -> Home switches immediately into full household view
      await repo.createHousehold(name: 'Solaris Loft');
      await tester.pumpAndSettle();
      expect(repo.hasActiveHousehold, isTrue);
      expect(find.text('SOLARIS LOFT STATUS'), findsOneWidget);
      expect(find.text("Who's Home"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
