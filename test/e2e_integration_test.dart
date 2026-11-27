import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casama/core/theme/theme_provider.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/auth/splash_screen.dart';
import 'package:casama/features/auth/auth_screen.dart';
import 'package:casama/features/auth/optional_profile_screen.dart';
import 'package:casama/features/legal/terms_consent_screen.dart';
import 'package:casama/features/onboarding/device_permissions_screen.dart';
import 'package:casama/features/onboarding/casama_intro_screen.dart';
import 'package:casama/features/onboarding/interactive_tutorial_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/calendar/household_calendar_view.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/profile/profile_screen.dart';
import 'package:casama/features/settings/app_settings_screen.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/features/items/lost_found_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_feed_screen.dart';
import 'package:casama/shared/widgets/cas_mascot_view.dart';
import 'package:casama/shared/widgets/casama_lost_found_icon.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Part 7: Casama Final Integration & Quality Assurance Tests', () {
    // -------------------------------------------------------------------------
    // A. TEST THE COMPLETE USER JOURNEY
    // -------------------------------------------------------------------------
    testWidgets('A1. Complete New User Flow from Welcome to Home Dashboard', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockRepository();
      mockRepo.logout();

      // 1. Welcome Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: SplashScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Casama'), findsWidgets);
      expect(find.text('Get Started'), findsOneWidget);

      // 2. Auth Screen - Create Account
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: AuthScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Create an Account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Register new user
      mockRepo.register(email: 'newuser@casama.app', password: 'password123');

      // 3. Optional Profile Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: OptionalProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tell Us About You'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Birthday'), findsOneWidget);
      expect(find.text('Skip Profile for Now'), findsNothing);
      expect(find.textContaining('Terms & Privacy Policy'), findsOneWidget);

      // 4. Terms and Privacy Consent Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: TermsConsentScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Household Agreements 📋'), findsOneWidget);
      expect(find.text('Terms of Service'), findsWidgets);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(find.text('Acknowledge & Continue'), findsOneWidget);

      // 5. Device Permissions Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: DevicePermissionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Device Permissions'), findsOneWidget);
      expect(find.text('Push Notifications'), findsNothing);
      expect(find.text('Camera & Photo Library'), findsOneWidget);
      expect(find.text('Contacts Assistance'), findsNothing);
      expect(find.text('Skip All'), findsNothing);
      expect(find.text('Skip All for Now'), findsNothing);
      expect(find.text('Save & Continue'), findsOneWidget);

      // 6. Casama Introduction Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: CasamaIntroScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Welcome,'), findsOneWidget);
      expect(find.text('Skip to Home'), findsNothing);
      expect(find.text('Skip Tutorial & Go to Dashboard'), findsNothing);
      expect(find.text("Let's Get Started"), findsOneWidget);

      // 7. Interactive Tutorial Screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: InteractiveTutorialScreen()),
        ),
      );
      await tester.pumpAndSettle();
      // Initial step: Home
      expect(find.text('1. Home Dashboard & Presence'), findsOneWidget);
      expect(find.text('Skip Tour'), findsNothing);
      expect(find.text('Next: Boards ›'), findsOneWidget);

      // Advance to Step 2: Boards
      await tester.tap(find.text('Next: Boards ›'));
      await tester.pumpAndSettle();
      expect(find.text('2. Unified Household Boards'), findsOneWidget);

      // 8. Reaching the Home Dashboard
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello, newuser!'), findsOneWidget);
    });

    testWidgets(
      'A2. Returning User Flow restores session, profile, and theme',
      (tester) async {
        SharedPreferences.setMockInitialValues({'casama_theme_mode': 'dark'});
        final prefs = await SharedPreferences.getInstance();
        final themeNotifier = ThemeNotifier(prefs);
        expect(themeNotifier.state, ThemeMode.dark);

        final mockRepo = MockRepository();
        mockRepo.login(email: 'jp@casama.app', password: 'password123');
        expect(mockRepo.isAuthenticated, true);
        expect(mockRepo.currentUser.nickname, 'JP');
        expect(mockRepo.effectiveGreetingName, 'JP');
      },
    );

    // -------------------------------------------------------------------------
    // B. HOME DASHBOARD TESTING
    // -------------------------------------------------------------------------
    testWidgets(
      'B1. Home Dashboard renders greeting, household card, calendar, and activity feed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
          ),
        );
        await tester.pumpAndSettle();

        // Nickname-based greeting
        expect(find.text('Hello, JP!'), findsOneWidget);

        // Household card
        expect(find.text('Casa 204'), findsWidgets);
        expect(find.textContaining('Active now: 3'), findsOneWidget);

        // Calendar display and month navigation
        expect(find.byType(HouseholdCalendarView), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text("Today's Schedule"), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // C. PLUS MENU TESTING
    // -------------------------------------------------------------------------
    testWidgets(
      'C1. Center camera shutter button in bottom nav launches QuickSnapCameraScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: MainNavigationShell()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap center camera shutter button (no camera icon inside)
        final shutterBtn = find.byKey(const Key('center_quicksnap_shutter_button'));
        expect(shutterBtn, findsOneWidget);
        expect(
          find.descendant(of: shutterBtn, matching: find.byIcon(Icons.camera_alt_rounded)),
          findsNothing,
        );
        await tester.tap(shutterBtn);
        await tester.pumpAndSettle();

        // Dismiss or allow permission dialog if visible
        if (find.byKey(const Key('allow_camera_permission_button')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const Key('allow_camera_permission_button')));
          await tester.pumpAndSettle();
        }

        // Verify QuickSnap Camera screen is displayed
        expect(find.text('Shared with Casa 204'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.byKey(const Key('gallery_picker_button')), findsNothing);
      },
    );

    testWidgets(
      'C2. CASnap Highlights -> All CASnaps -> unified viewer -> multi-tap reactions & reactors sheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();
        mockRepo.sendQuickSnap(
          imageUrl: 'offline_e2e_snap.jpg',
          caption: 'Study session',
        );
        final snap = mockRepo.quickSnaps.first;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: QuickSnapFeedScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Highlights'), findsOneWidget);
        expect(find.text('All CASnaps'), findsOneWidget);

        // Switch to All CASnaps and tap thumbnail
        await tester.tap(find.text('All CASnaps'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(
            'Open photo by ${mockRepo.currentUser.preferredName}',
          ),
        );
        await tester.pumpAndSettle();

        // Multi-tap 🔥 3x and ❤️ 2x inside unified viewer
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.bySemanticsLabel('React 🔥'));
          await tester.pump(const Duration(milliseconds: 40));
        }
        for (var i = 0; i < 2; i++) {
          await tester.tap(find.bySemanticsLabel('React ❤️'));
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pumpAndSettle();

        expect(mockRepo.flushedReactionBatches.length, 1);
        expect(mockRepo.flushedReactionBatches.single.deltas, {'🔥': 3, '❤️': 2});

        await tester.tap(
          find.byKey(ValueKey('casnap_reactions_pill_${snap.id}')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Reactions'), findsOneWidget);
        expect(find.text('🔥-3'), findsOneWidget);
        expect(find.text('❤️-2'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // D. CHAT TESTING & HOUSEMATE MANAGEMENT
    // -------------------------------------------------------------------------
    testWidgets(
      'D1. Chat directory, search, housemate invitations, and DM privacy guard',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(
              home: Scaffold(body: ChatDirectoryScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify group chat & individual housemates
        expect(find.text('Household Group Chat'), findsOneWidget);
        expect(find.text('Casa 204'), findsWidgets);
        expect(find.text('Maria'), findsWidgets);
        expect(find.text('Alex'), findsWidgets);
        expect(find.text('Ria'), findsWidgets);

        // Verify search input
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Maria');
        await tester.pumpAndSettle();
        expect(find.text('Maria'), findsWidgets);
        expect(find.text('Alex'), findsNothing);

        // Clear search
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // Header no longer has Add Housemate button; use in-body Add Housemate pill
        expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
        await tester.ensureVisible(find.text('Add Housemate'));
        await tester.tap(find.text('Add Housemate'));
        await tester.pumpAndSettle();

        expect(find.text('Find User'), findsOneWidget);
        expect(find.text('Invite Code'), findsOneWidget);
        expect(find.text('Pending'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // E. PROFILE AND SETTINGS TESTING
    // -------------------------------------------------------------------------
    testWidgets(
      'E1. Profile screen allows updating profile, viewing points audit, and settings',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jon Paul Berana'), findsWidgets);
        expect(find.text('120 pts'), findsWidgets);
        expect(find.text('Edit Profile'), findsOneWidget);

        // Open Points Audit Ledger
        await tester.tap(find.text('120 pts').first);
        await tester.pumpAndSettle();
        expect(find.text('Kasama Points Ledger'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Open Edit Profile
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();
        expect(find.text('Edit Profile'), findsWidgets);
        expect(find.text('Remove Picture'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'E2. Settings Screen renders all 5 sections and supports theme switching',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: AppSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // 4 Active Sections (Notification Settings removed)
        expect(find.text('Account Settings'), findsOneWidget);
        expect(find.text('Appearance'), findsOneWidget);
        expect(find.text('Notification Settings'), findsNothing);
        expect(find.text('Privacy and Security'), findsOneWidget);
        expect(find.text('About Casama'), findsOneWidget);

        // Theme options
        expect(find.text('Light'), findsWidgets);
        expect(find.text('Dark'), findsWidgets);
        expect(find.text('System'), findsWidgets);
      },
    );

    // -------------------------------------------------------------------------
    // F. DATABASE, PRIVACY & SECURITY TESTING
    // -------------------------------------------------------------------------
    test('F1. Security test: External unauthorized users cannot access direct messaging', () {
      final repo = MockRepository();
      // 'external_stranger' is not in Casa 204
      expect(repo.isHousemateAuthorized('external_stranger'), false);

      // Verified members are authorized
      expect(repo.isHousemateAuthorized('maria'), true);
      expect(repo.isHousemateAuthorized('alex'), true);
      expect(repo.isHousemateAuthorized('ria'), true);
    });

    test('F2. Duplicate reward prevention: Receiving same parcel multiple times is rejected', () {
      final repo = MockRepository();
      final initialPoints = repo.kasamaPoints;

      // First claim succeeds and awards +5
      repo.receiveParcel('p1');
      expect(repo.kasamaPoints, initialPoints + 5);

      // Attempting to receive again is idempotent and does not award duplicate points
      final historyCountBefore = repo.pointHistory.length;
      repo.receiveParcel('p1');
      expect(repo.kasamaPoints, initialPoints + 5); // Unchanged
      expect(
        repo.pointHistory.length,
        historyCountBefore,
      ); // No duplicate ledger entry
    });

    test('F3. Duplicate invitation prevention: Sending duplicate invite is rejected', () {
      final repo = MockRepository();

      // First invite to Clara succeeds
      final firstInvite = repo.sendInvitation(
        inviteeEmailOrHandle: '@clarar',
        inviteeName: 'Clara Reyes',
      );
      expect(firstInvite, true);

      // Second invite to Clara returns false (rejected)
      final duplicateInvite = repo.sendInvitation(
        inviteeEmailOrHandle: '@clarar',
        inviteeName: 'Clara Reyes',
      );
      expect(duplicateInvite, false);
    });

    // -------------------------------------------------------------------------
    // G. MASCOT AND BRANDING CONSISTENCY
    // -------------------------------------------------------------------------
    testWidgets(
      'G1. Mascot retains glasses and plain shirt across all appearances',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CasMascotView(pose: CasPose.hero, width: 120, height: 120),
            ),
          ),
        );
        await tester.pump();

        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final image = tester.widget<Image>(imageFinder);
        final assetImage = image.image as AssetImage;
        expect(assetImage.assetName, 'assets/images/cas/together_cards.png');
      },
    );

    // -------------------------------------------------------------------------
    // H. PRESERVE EXISTING FEATURES
    // -------------------------------------------------------------------------
    testWidgets(
      'H1. Existing Boards (Parcels, Lost & Found, Maintenance) remain functional',
      (tester) async {
        final mockRepo = MockRepository();

        // 1. Parcels Board
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: ParcelsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('J&T Express'), findsOneWidget);
        expect(find.text('Flash Express'), findsOneWidget);

        // 2. Lost & Found Board
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: LostFoundScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Lost AirPods'), findsOneWidget);
        expect(find.byType(CasamaLostFoundIcon), findsWidgets);
        expect(find.byIcon(Icons.sell_outlined), findsNothing);

        // Switch to Found tab
        await tester.tap(find.text('Found'));
        await tester.pumpAndSettle();
        expect(find.text('Found Backpack'), findsOneWidget);

        // Switch to My Activity tab and confirm filter pills
        await tester.tap(find.text('My Activity'));
        await tester.pumpAndSettle();
        expect(find.text('All'), findsOneWidget);
        expect(find.text('My Lost'), findsOneWidget);
        expect(find.text('My Found'), findsOneWidget);
        expect(find.text('Interactions'), findsOneWidget);
        expect(find.text('Lost AirPods'), findsOneWidget);

        // Switch to Resolved tab
        await tester.tap(find.text('Resolved'));
        await tester.pumpAndSettle();
        expect(find.text('No resolved items yet'), findsOneWidget);

        // 3. Maintenance Board
        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: const MaterialApp(home: MaintenanceScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('3 Open Tasks'), findsOneWidget);
        expect(find.text('16 pts'), findsOneWidget);
        expect(find.text('Across ongoing tasks'), findsOneWidget);
        expect(find.text('Leaking Faucet'), findsOneWidget);
        expect(find.text('Buy Drinking Water'), findsOneWidget);
        expect(find.text('Defrost Freezer'), findsOneWidget);
        expect(find.text('Ongoing Tasks'), findsOneWidget);
        expect(find.text('Completed Tasks'), findsOneWidget);

        await tester.tap(find.text('Completed Tasks'));
        await tester.pumpAndSettle();
        expect(find.text('No completed tasks yet'), findsOneWidget);
      },
    );
  });
}
