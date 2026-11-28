import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/auth/optional_profile_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/onboarding/interactive_tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'OptionalProfileScreen shows Filipino name placeholders in light and dark mode',
    (tester) async {
      final repo = MockRepository();

      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: themeMode,
              home: const OptionalProfileScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(TextField, 'e.g., Juan'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'e.g., Dela Cruz'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'e.g., Jon Paul'), findsNothing);
        expect(find.widgetWithText(TextField, 'e.g., Berana'), findsNothing);
      }
    },
  );

  testWidgets(
    'App Tour walkthrough renders dimming scrim behind card and hides it on finish in light and dark mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        final repo = MockRepository()..login();

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('tour_scope_$themeMode'),
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: themeMode,
              home: const InteractiveTutorialScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrimFinder = find.byKey(const Key('app_tour_scrim'));
        expect(scrimFinder, findsOneWidget);

        final opacityBefore = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: scrimFinder,
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacityBefore.opacity, 1.0);

        // Step through all 5 tour steps to Finish Tour
        for (var step = 0; step < 4; step++) {
          await tester.tap(find.textContaining('Next:'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Finish Tour 🎉'));
        await tester.pumpAndSettle();

        final opacityAfter = tester.widget<AnimatedOpacity>(
          find.ancestor(
            of: scrimFinder,
            matching: find.byType(AnimatedOpacity),
          ),
        );
        expect(opacityAfter.opacity, 0.0);

        // Drain toast timer
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'Add parcel FAB hugs bottom-right corner 12-20px above bottom nav bar in light and dark mode',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
        final repo = MockRepository()..login();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: themeMode,
              home: const MainNavigationShell(
                initialIndex: 1,
                initialBoardIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final navBarFinder = find.byKey(const ValueKey('casama_5_slot_bar'));
        final fabFinder = find.byKey(const ValueKey('casama_morphing_fab_visible'));
        expect(navBarFinder, findsOneWidget);
        expect(fabFinder, findsOneWidget);

        final navBarTop = tester.getTopLeft(navBarFinder).dy;
        final fabRect = tester.getRect(fabFinder);

        // 16px from right viewport edge (390)
        expect(390.0 - fabRect.right, closeTo(16.0, 0.5));

        // 12-20px above the top edge of the bottom navigation bar
        final clearanceAboveNav = navBarTop - fabRect.bottom;
        expect(clearanceAboveNav, inInclusiveRange(12.0, 20.0));
      }
    },
  );
}
