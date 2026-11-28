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
import 'package:casama/features/profile/profile_screen.dart';
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
          GoRoute(
            path: '/interactive-tutorial',
            builder: (context, state) => const InteractiveTutorialScreen(),
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
      expect(find.text('Push Notifications'), findsNothing);
      expect(find.text('Skip All'), findsNothing);
      expect(find.text('Skip All for Now'), findsNothing);

      await tester.tap(find.text('Camera & Photo Library'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Open Permissions'), findsOneWidget);
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
      expect(find.text('4. Household Chat & Agendas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('center_quicksnap_shutter_button')));
      await tester.pumpAndSettle();
      expect(find.text('3. CASnap Household Camera'), findsOneWidget);
    },
  );

  testWidgets(
    'Onboarding enforces profile & Terms validation, persists birthday/consent/onboarding flags, and reflects on ProfileScreen',
    (tester) async {
      final repo = MockRepository()..logout();
      repo.register(email: 'clara@casama.app', password: 'password123');

      final router = GoRouter(
        initialLocation: '/profile-setup',
        routes: [
          GoRoute(
            path: '/profile-setup',
            builder: (context, state) => const OptionalProfileScreen(),
          ),
          GoRoute(
            path: '/household-setup',
            builder: (context, state) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => context.push('/permissions'),
                  child: const Text('Go Permissions'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/permissions',
            builder: (context, state) =>
                const DevicePermissionsScreen(isOnboarding: true),
          ),
          GoRoute(
            path: '/intro',
            builder: (context, state) => const CasamaIntroScreen(),
          ),
          GoRoute(
            path: '/interactive-tutorial',
            builder: (context, state) => const InteractiveTutorialScreen(),
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

      // Empty submit should block progression and show inline errors
      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your first name'), findsOneWidget);
      expect(find.text('Please enter your last name'), findsOneWidget);
      expect(find.text('Please enter your nickname'), findsOneWidget);
      expect(find.text('Please select your complete birthday'), findsOneWidget);
      expect(
        find.text('Please agree to the Terms & Privacy Policy'),
        findsOneWidget,
      );
      expect(find.text('Go Permissions'), findsNothing);

      // Seed a taken nickname to verify inline duplicate-nickname validation
      repo.seedTakenNicknamesForTest(['clar']);

      // Fill First Name, Last Name, taken Nickname, Birthday via calendar picker, and accept Terms
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., Juan'),
        'Clara',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., Dela Cruz'),
        'Reyes',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your nickname'),
        'Clar',
      );
      await tester.ensureVisible(find.byTooltip('Pick date from calendar'));
      await tester.tap(find.byTooltip('Pick date from calendar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final termsFinder = find.bySemanticsLabel(
        'I agree to the Terms & Privacy Policy',
      );
      await tester.ensureVisible(termsFinder);
      await tester.tapAt(
        tester.getTopLeft(termsFinder) + const Offset(12, 20),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      // Duplicate nickname blocks navigation and preserves entered fields
      expect(
        find.text('That nickname is already taken. Please choose another.'),
        findsOneWidget,
      );
      expect(find.text('Clara'), findsOneWidget);
      expect(find.text('Reyes'), findsOneWidget);
      expect(find.text('Go Permissions'), findsNothing);

      // Update to a unique nickname and save
      await tester.enterText(
        find.widgetWithText(TextField, 'Enter your nickname'),
        'ClarR',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Go Permissions'), findsOneWidget);
      expect(repo.currentUser.firstName, 'Clara');
      expect(repo.currentUser.lastName, 'Reyes');
      expect(repo.currentUser.fullName, 'Clara Reyes');
      expect(repo.currentUser.nickname, 'ClarR');
      expect(repo.currentUser.birthday, isNotNull);
      expect(repo.currentUser.hasConsentedTerms, isTrue);

      // Step 4: DevicePermissionsScreen (no Push Notifications, Contacts Assistance, or Skip buttons)
      await tester.tap(find.text('Go Permissions'));
      await tester.pumpAndSettle();
      expect(find.text('Push Notifications'), findsNothing);
      expect(find.text('Contacts Assistance'), findsNothing);
      expect(find.text('Skip All'), findsNothing);
      expect(find.text('Skip All for Now'), findsNothing);

      await tester.ensureVisible(find.text('Save & Continue'));
      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(repo.currentUser.hasCompletedOnboarding, isFalse);
      expect(find.byType(CasamaIntroScreen), findsOneWidget);
      expect(find.text('Skip to Home'), findsNothing);
      expect(find.text('Skip Tutorial & Go to Dashboard'), findsNothing);

      await tester.ensureVisible(find.text("Let's Get Started"));
      await tester.tap(find.text("Let's Get Started"));
      await tester.pumpAndSettle();

      expect(repo.currentUser.hasCompletedOnboarding, isTrue);
      expect(find.byType(InteractiveTutorialScreen), findsOneWidget);
      expect(find.text('Skip Tour'), findsNothing);

      // Verify ProfileScreen immediately reflects saved data
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Clara Reyes'), findsWidgets);
      expect(find.text('ClarR'), findsWidgets);
      expect(find.text('Birthday'), findsOneWidget);
      expect(find.text('Not specified'), findsNothing);
    },
  );
}
