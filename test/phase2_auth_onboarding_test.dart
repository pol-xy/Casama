import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/auth/auth_screen.dart';
import 'package:casama/features/auth/optional_profile_screen.dart';
import 'package:casama/features/auth/splash_screen.dart';
import 'package:casama/features/household/household_setup_screen.dart';
import 'package:casama/features/onboarding/casama_intro_screen.dart';
import 'package:casama/features/onboarding/device_permissions_screen.dart';
import 'package:casama/features/onboarding/interactive_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Phase 2 screens render cleanly in dark mode and reduced motion without overflows',
    (tester) async {
      final repo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 760),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const AuthScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join Casama'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(375, 760),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const OptionalProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SplashScreen shows Continue button for authenticated returning user',
    (tester) async {
      final repo = MockRepository()..login();
      repo.completeOnboardingTutorial();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(theme: CasamaTheme.lightTheme, home: const SplashScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Continue as ${repo.currentUser.effectiveGreetingName}'),
        findsOneWidget,
      );
      expect(find.text('Your shared home, simplified.'), findsOneWidget);
    },
  );

  testWidgets(
    'HouseholdSetupScreen switches cleanly between Join Household and Create New',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: CasamaTheme.lightTheme, home: const HouseholdSetupScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Got an Invite Code?'), findsOneWidget);
      expect(find.text('Step 3 of 4'), findsOneWidget);

      await tester.tap(find.text('Fill Demo Code: CASA204'));
      await tester.pumpAndSettle();
      expect(find.text('CASA204'), findsWidgets);

      await tester.tap(find.text('Create New'));
      await tester.pumpAndSettle();
      expect(find.text('Start a New Household'), findsOneWidget);
    },
  );

  testWidgets(
    'DevicePermissionsScreen opened from settings persists toggle and pops cleanly without launching onboarding',
    (tester) async {
      final repo = MockRepository()..login();

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/permissions?fromSettings=true'),
                  child: const Text('Open Permissions'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/permissions',
            builder: (context, state) => DevicePermissionsScreen(
              isOnboarding: state.uri.queryParameters['fromSettings'] != 'true',
            ),
          ),
          GoRoute(
            path: '/intro',
            builder: (context, state) => const CasamaIntroScreen(),
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

      await tester.tap(find.text('Open Permissions'));
      await tester.pumpAndSettle();

      expect(find.text('Device Permissions'), findsOneWidget);
      expect(find.text('Step 4 of 4'), findsNothing);
      expect(find.text('Skip All'), findsNothing);

      await tester.tap(find.text('Push Notifications'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Open Permissions'), findsOneWidget);
      expect(repo.notificationPreferences.parcelNotifications, isFalse);
      expect(find.byType(CasamaIntroScreen), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'InteractiveTutorialScreen mock preview bar items are directly tappable across all 5 slots',
    (tester) async {
      final repo = MockRepository();

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

      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();
      expect(find.text('4. Household Chat & Meet-ups'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Jump to CASnap preview'));
      await tester.pumpAndSettle();
      expect(find.text('3. CASnap Household Moments'), findsOneWidget);
    },
  );
}
