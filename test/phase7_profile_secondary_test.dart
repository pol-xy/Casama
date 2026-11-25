import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/core/theme/theme_provider.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/legal/terms_consent_screen.dart';
import 'package:casama/features/legal/terms_privacy_screen.dart';
import 'package:casama/features/points/leaderboard_screen.dart';
import 'package:casama/features/profile/profile_screen.dart';
import 'package:casama/features/settings/app_settings_screen.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'ProfileScreen renders tucked mascot, points ledger sheet, and invite sheet cleanly at 390x844',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
              home: const ProfileScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.byType(CasMascotView), findsOneWidget);
      expect(find.text('Good Kasama Points'), findsOneWidget);
      expect(find.text('Gold Tier'), findsOneWidget);

      // Open My Household invite sheet
      await tester.scrollUntilVisible(
        find.text('My Household'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('My Household'));
      await tester.pumpAndSettle();
      expect(find.text('Invite Your Housemates 🏡'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Open About Casama modal
      await tester.scrollUntilVisible(
        find.text('About Casama'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('About Casama'));
      await tester.pumpAndSettle();
      expect(find.text('Casama & Cas the Owl'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'LeaderboardScreen and AppSettingsScreen render cleanly in Dark Mode with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
              home: const LeaderboardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kasama Leaderboard'), findsOneWidget);
      expect(find.text('Good Kasama Rank'), findsOneWidget);
      expect(find.text('Household Standings'), findsOneWidget);
      expect(find.text('How to Earn Points'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // AppSettingsScreen in Dark Mode
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(themeModeProvider);
              return MediaQuery(
                data: const MediaQueryData(
                  size: Size(390, 844),
                  disableAnimations: true,
                ),
                child: MaterialApp(
                  theme: CasamaTheme.lightTheme,
                  darkTheme: CasamaTheme.darkTheme,
                  themeMode: mode,
                  home: const AppSettingsScreen(),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(find.byType(Switch), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TermsPrivacyScreen supports segmented tabs + readOnly mode and TermsConsentScreen toggles checkboxes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const TermsPrivacyScreen(readOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Household Harmony'), findsOneWidget);
      expect(find.text('I Understand & Agree'), findsNothing);

      await tester.tap(find.text('Privacy'));
      await tester.pumpAndSettle();
      expect(find.text('Zero Background GPS Tracking'), findsOneWidget);

      await tester.tap(find.text('Permissions'));
      await tester.pumpAndSettle();
      expect(find.text('Camera & Photo Library'), findsOneWidget);

      // TermsConsentScreen at 390x844
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
              home: const TermsConsentScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('I accept the Terms of Service'));
      await tester.pumpAndSettle();
      final privacyCheck = find.text(
        'I acknowledge the Privacy Policy & Data Protections',
      );
      await tester.ensureVisible(privacyCheck);
      await tester.tap(privacyCheck);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
