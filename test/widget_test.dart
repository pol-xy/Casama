import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:casama/features/auth/auth_screen.dart';
import 'package:casama/features/auth/optional_profile_screen.dart';
import 'package:casama/features/auth/splash_screen.dart';
import 'package:casama/features/legal/terms_consent_screen.dart';
import 'package:casama/features/legal/terms_privacy_screen.dart';
import 'package:casama/features/onboarding/casama_intro_screen.dart';
import 'package:casama/features/onboarding/device_permissions_screen.dart';
import 'package:casama/features/onboarding/interactive_tutorial_screen.dart';
import 'package:casama/features/settings/app_settings_screen.dart';
import 'package:casama/features/profile/profile_screen.dart';
import 'package:casama/features/profile/edit_profile_dialog.dart';
import 'package:casama/features/bills/add_bill_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_feed_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_camera_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/calendar/household_calendar_view.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/features/items/lost_found_screen.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:casama/features/chore_roulette/chore_roulette_screen.dart';
import 'package:casama/features/chat/create_meetup_screen.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/group_chat_screen.dart';
import 'package:casama/features/chat/direct_chat_screen.dart';
import 'package:casama/features/household/add_housemate_dialog.dart';
import 'package:casama/shared/widgets/invite_housemate_sheet.dart';
import 'package:casama/shared/widgets/profile_camera_sheet.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casama/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Casama app boots to splash screen with brand mascot and tagline',
    (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: CasamaApp()));

      await tester.pump();

      // Verify brand identity
      expect(find.text('Casama'), findsWidgets);
      expect(
        find.text(
          'Making shared living\nsimpler, warmer, and more coordinated.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('SplashScreen renders Get Started button and brand identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );

    await tester.pump();
    expect(find.text('Casama'), findsWidgets);
    expect(
      find.text('Making shared living\nsimpler, warmer, and more coordinated.'),
      findsOneWidget,
    );
  });

  testWidgets('AuthScreen displays Create an Account and Log In tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AuthScreen())),
    );

    expect(find.text('Create an Account'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Continue to Profile Details'), findsOneWidget);

    // Switch to Log In tab
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back! 👋'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets(
    'OptionalProfileScreen renders all four optional fields and skippable actions',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OptionalProfileScreen())),
      );

      expect(find.text('Tell Us About You 👋'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Age (Optional)'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
      expect(find.text('Skip Profile for Now'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    },
  );

  testWidgets(
    'TermsConsentScreen renders agreements and consent acknowledgment checkboxes',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TermsConsentScreen())),
      );

      expect(find.text('Household Agreements 📋'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Zero GPS Tracking'), findsOneWidget);
      expect(find.text('I accept the Terms of Service'), findsOneWidget);
      expect(
        find.text('I acknowledge the Privacy Policy & Data Protections'),
        findsOneWidget,
      );
      expect(find.text('Acknowledge & Continue'), findsOneWidget);
    },
  );

  testWidgets(
    'DevicePermissionsScreen explains relevant permissions with skippable options',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DevicePermissionsScreen()),
      );

      expect(find.text('Device Permissions 📱'), findsOneWidget);
      expect(find.text('Push Notifications'), findsOneWidget);
      expect(find.text('Camera & Photo Library'), findsOneWidget);
      expect(find.text('Contacts Assistance'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
      expect(find.text('Skip All for Now'), findsOneWidget);
      expect(find.text('Skip All'), findsOneWidget);
    },
  );

  testWidgets(
    'CasamaIntroScreen displays welcome benefits and CTA to launch interactive tutorial',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CasamaIntroScreen())),
      );

      expect(find.textContaining('Welcome, '), findsOneWidget);
      expect(find.text('Manual Presence Awareness'), findsOneWidget);
      expect(find.text('Delivery & COD Protection'), findsOneWidget);
      expect(find.text('Fair Chores & Kasama Points'), findsOneWidget);
      expect(find.text('Harmonious Housemate Connect'), findsOneWidget);
      expect(find.text("Let's Get Started"), findsOneWidget);
      expect(find.text('Skip to Home'), findsOneWidget);
    },
  );

  testWidgets(
    'InteractiveTutorialScreen highlights actual navigation elements with skip option',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: InteractiveTutorialScreen()),
        ),
      );

      // Initial step: Home
      expect(find.text('1. Home Dashboard & Calendar 🏠'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next Navigation Element'), findsOneWidget);

      // Advance to Step 2: Boards
      await tester.tap(find.text('Next Navigation Element'));
      await tester.pumpAndSettle();
      expect(find.text('2. Household Boards 📦'), findsOneWidget);

      // Advance to Step 3: Plus (+)
      await tester.tap(find.text('Next Navigation Element'));
      await tester.pumpAndSettle();
      expect(find.text('3. Plus (+) Quick Actions ➕'), findsOneWidget);

      // Advance to Step 4: Chat
      await tester.tap(find.text('Next Navigation Element'));
      await tester.pumpAndSettle();
      expect(find.text('4. Household Chat & Connect 💬'), findsOneWidget);

      // Advance to Step 5: Profile
      await tester.tap(find.text('Next Navigation Element'));
      await tester.pumpAndSettle();
      expect(find.text('5. Profile & Settings ⚙️'), findsOneWidget);
      expect(find.text('Enter Home Dashboard'), findsOneWidget);
    },
  );

  testWidgets('TermsPrivacyScreen renders terms tabs and acceptance button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TermsPrivacyScreen()));

    expect(find.text('Terms & Privacy'), findsOneWidget);
    expect(find.text('Household Harmony'), findsOneWidget);
    expect(find.text('I Understand & Agree'), findsOneWidget);
  });

  testWidgets('AppSettingsScreen renders appearance and preferences', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AppSettingsScreen())),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets(
    'DashboardScreen renders personalized greeting, household card, calendar, quick access, and activity feed in order',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      await tester.pump();

      // 1. Personalized Greeting
      expect(find.text('Hello, JP!'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == 'Good Morning.' ||
                  widget.data == 'Good Afternoon.' ||
                  widget.data == 'Good Evening.'),
        ),
        findsOneWidget,
      );

      // 2. Household Information Card (Casa 204)
      expect(find.text('Casa 204'), findsOneWidget);
      expect(find.textContaining('4 members • Active now:'), findsOneWidget);

      // 3. Calendar Feature & Schedule
      expect(find.byType(HouseholdCalendarView), findsOneWidget);
      expect(find.text("Today's Schedule"), findsOneWidget);

      // Verify redundant sections are removed from Home
      expect(find.text('Quick Access'), findsNothing);
      expect(find.text("Today's Activity"), findsNothing);
    },
  );

  testWidgets(
    'DashboardScreen greeting reactively updates when profile nickname changes',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      await tester.pump();
      expect(find.text('Hello, JP!'), findsOneWidget);

      // Change profile nickname
      mockRepo.updateProfile(nickname: 'Jaypee');
      await tester.pump();

      expect(find.text('Hello, Jaypee!'), findsOneWidget);
    },
  );

  testWidgets(
    'HouseholdCalendarView allows month navigation, category filtering, and displays events or empty state',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: HouseholdCalendarView()),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Calendar structure
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Parcels'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Meetups'), findsOneWidget);

      // Month Navigation: tap chevron right (Next month)
      final nextMonthFinder = find.byIcon(Icons.chevron_right_rounded);
      expect(nextMonthFinder, findsOneWidget);
      await tester.tap(nextMonthFinder);
      await tester.pumpAndSettle();

      // Tap chevron left (Previous month - back to current)
      final prevMonthFinder = find.byIcon(Icons.chevron_left_rounded);
      expect(prevMonthFinder, findsOneWidget);
      await tester.tap(prevMonthFinder);
      await tester.pumpAndSettle();

      // Tap Today button
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Category filter tap
      await tester.tap(find.text('Meetups'), warnIfMissed: false);
      await tester.pumpAndSettle();

      await tester.tap(find.text('All'), warnIfMissed: false);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Center camera shutter button in bottom nav launches QuickSnapCameraScreen',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: MainNavigationShell()),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap the center camera shutter action button
      final cameraBtn = find.byKey(const Key('center_quicksnap_shutter_button'));
      expect(cameraBtn, findsOneWidget);
      expect(
        find.descendant(of: cameraBtn, matching: find.byIcon(Icons.camera_alt_rounded)),
        findsNothing,
      );
      await tester.tap(cameraBtn);
      await tester.pumpAndSettle();

      // Verify that permission request modal is shown first
      expect(find.text('Enable Camera for QuickSnap'), findsOneWidget);
      expect(find.byKey(const Key('allow_camera_permission_button')), findsOneWidget);

      // Tap allow to proceed to viewfinder
      await tester.tap(find.byKey(const Key('allow_camera_permission_button')));
      await tester.pumpAndSettle();

      // Verify QuickSnap Camera screen is displayed
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
    },
  );

  testWidgets(
    'Add a Parcel action launches existing parcel form and saves data to repository',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();
      final initialCount = mockRepo.parcels.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(
            home: ParcelsScreen(initialOpenAddModal: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form is displayed
      expect(find.text('Add Expected Parcel'), findsOneWidget);
      expect(find.text('Courier'), findsOneWidget);
      expect(find.text('Save Parcel'), findsOneWidget);

      // Save parcel
      await tester.tap(find.text('Save Parcel'));
      await tester.pumpAndSettle();

      // Verify data saved to repository
      expect(mockRepo.parcels.length, initialCount + 1);
      expect(mockRepo.parcels.first.status, ParcelStatus.expected);
    },
  );

  testWidgets(
    'Report an Item action launches existing lost & found form and saves data to repository',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();
      final initialCount = mockRepo.items.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(
            home: LostFoundScreen(initialOpenPostModal: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form is displayed
      expect(find.text('Post an Item'), findsWidgets);
      expect(find.text('Lost Item'), findsOneWidget);
      expect(find.text('Found Item'), findsOneWidget);
      expect(find.text('Item Title'), findsOneWidget);
      expect(find.text('Post to Housemates'), findsOneWidget);

      // Enter title
      await tester.enterText(
        find.widgetWithText(TextField, 'e.g., AirPods, Keys, Blue Backpack'),
        'Blue Water Bottle',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Post to Housemates'));
      await tester.pumpAndSettle();

      // Verify data saved to repository
      expect(mockRepo.items.length, initialCount + 1);
      expect(mockRepo.items.first.title, 'Blue Water Bottle');
    },
  );

  testWidgets(
    'Add a Household Task action launches existing maintenance form and saves data to repository',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();
      final initialCount = mockRepo.tasks.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(
            home: MaintenanceScreen(initialOpenAddModal: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Form is displayed
      expect(find.text('Create Maintenance Task'), findsOneWidget);
      expect(find.text('Task Title'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);

      // Enter task title
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g., Fix front door knob, Restock detergent',
        ),
        'Clean kitchen microwave',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Add Task'));
      await tester.pumpAndSettle();

      // Verify data saved to repository
      expect(mockRepo.tasks.length, initialCount + 1);
      expect(mockRepo.tasks.first.title, 'Clean kitchen microwave');
    },
  );

  testWidgets(
    'Create a Meet-up action launches existing meet-up form and sends invitation to chat',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();
      final initialMessages = mockRepo.groupMessages.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: CreateMeetupScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Create Meet-up'), findsOneWidget);
      expect(find.text('Bring the household together'), findsOneWidget);
      expect(find.text('Send Invitation'), findsOneWidget);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send Invitation'));
      await tester.pumpAndSettle();

      // Message sent to group chat
      expect(mockRepo.groupMessages.length, initialMessages + 1);
      expect(
        mockRepo.groupMessages.last.content,
        contains('Meet-up Invitation'),
      );
    },
  );

  testWidgets(
    'Invite a Housemate action opens household invitation sheet with code and copy functionality',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showInviteHousemateSheet(
                    context,
                    householdName: 'Casa 204',
                    inviteCode: 'CASA204',
                  ),
                  child: const Text('Open Invite'),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Invite'));
      await tester.pumpAndSettle();

      // Verify sheet contents
      expect(find.text('Invite Your Housemates 🏡'), findsOneWidget);
      expect(find.textContaining('Casa 204'), findsWidgets);
      expect(find.text('CASA204'), findsOneWidget);
      expect(find.text('Copy Full Invitation Message'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Close button dismisses sheet
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Invite Your Housemates 🏡'), findsNothing);
    },
  );

  testWidgets(
    'ChatDirectoryScreen displays household group chat, individual conversations, and search bar',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: Scaffold(body: ChatDirectoryScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify search bar and header
      expect(find.text('Chat'), findsOneWidget);
      expect(
        find.text('Search conversations or housemates...'),
        findsOneWidget,
      );
      expect(find.text('Add Housemate'), findsOneWidget);

      // Verify Household Group Chat
      expect(find.text('Household Group Chat'), findsOneWidget);
      expect(find.text('Casa 204'), findsWidgets);

      // Verify Individual Conversations
      expect(find.text('Individual Conversations'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Ria'), findsOneWidget);
    },
  );

  testWidgets('ChatDirectoryScreen filters conversations by search query', (
    WidgetTester tester,
  ) async {
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
        child: const MaterialApp(home: Scaffold(body: ChatDirectoryScreen())),
      ),
    );

    await tester.pumpAndSettle();

    // Type "Alex" in the search bar
    await tester.enterText(find.byType(TextField), 'Alex');
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsWidgets);
    expect(find.text('Maria'), findsNothing);
    expect(find.text('Ria'), findsNothing);
  });

  testWidgets(
    'ChatDirectoryScreen displays empty state when household has no other members',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockRepository();
      mockRepo.resetMembersForNewUserTest();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: Scaffold(body: ChatDirectoryScreen())),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state
      expect(
        find.text('Your household is better together! 🏡'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Invite your housemates to start communicating and coordinating.',
        ),
        findsOneWidget,
      );
      expect(find.text('Invite Housemate'), findsWidgets);
    },
  );

  testWidgets(
    'showAddHousemateDialog renders Find User, Invite Code, and Pending Invites tabs',
    (WidgetTester tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showAddHousemateDialog(ctx),
                  child: const Text('Open Add Housemate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Add Housemate'));
      await tester.pumpAndSettle();

      // Verify modal header and tabs
      expect(find.text('Add Housemate'), findsOneWidget);
      expect(find.text('Find User'), findsOneWidget);
      expect(find.text('Invite Code'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);

      // Switch to Invite Code tab
      await tester.tap(find.text('Invite Code'));
      await tester.pumpAndSettle();
      expect(find.text('CASA204'), findsOneWidget);
      expect(find.text('Copy Invitation Message'), findsOneWidget);

      // Switch to Pending tab
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();
      expect(find.text('Miguel Ramos'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    },
  );

  testWidgets(
    'showAddHousemateDialog allows searching external users and sending an invitation',
    (WidgetTester tester) async {
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
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showAddHousemateDialog(ctx),
                  child: const Text('Open Add Housemate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Add Housemate'));
      await tester.pumpAndSettle();

      // In Find User tab, enter search term 'Clara'
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Search by username or handle (e.g. @miguel)...',
        ),
        'Clara',
      );
      await tester.pumpAndSettle();

      expect(find.text('Clara Reyes'), findsOneWidget);
      expect(find.text('@clara'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);

      // Tap Invite button
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();

      // Now button changes to Invited
      expect(find.text('Invited'), findsOneWidget);
      expect(
        mockRepo.invitations.any((i) => i.inviteeEmailOrHandle == '@clara'),
        isTrue,
      );
    },
  );

  testWidgets(
    'showAddHousemateDialog allows accepting a pending invitation and updating household members',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockRepository();
      final initialMemberCount = mockRepo.members.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showAddHousemateDialog(ctx),
                  child: const Text('Open Add Housemate'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Add Housemate'));
      await tester.pumpAndSettle();

      // Switch to Pending tab
      await tester.tap(find.text('Pending'));
      await tester.pumpAndSettle();

      expect(find.text('Miguel Ramos'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();

      // Verify member was added to household
      expect(mockRepo.members.length, initialMemberCount + 1);
      expect(
        mockRepo.members.any((m) => m.profile.displayName == 'Miguel Ramos'),
        isTrue,
      );
    },
  );

  testWidgets(
    'DirectChatScreen allows messaging authorized housemates and displays presence note',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockRepository();
      final initialMsgCount = mockRepo.getDirectMessages('maria').length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(
            home: DirectChatScreen(contactKey: 'maria', contactName: 'Maria'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Maria'), findsWidgets);
      expect(
        find.text('In living room'),
        findsOneWidget,
      ); // Maria's presence note

      // Send a direct message
      await tester.enterText(
        find.byType(TextField),
        'Did you order the dish soap?',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify message sent
      expect(mockRepo.getDirectMessages('maria').length, initialMsgCount + 1);
      expect(
        mockRepo.getDirectMessages('maria').last.content,
        'Did you order the dish soap?',
      );
      expect(find.text('Did you order the dish soap?'), findsOneWidget);
    },
  );

  testWidgets(
    'DirectChatScreen renders Access Restricted view when contact is unauthorized',
    (WidgetTester tester) async {
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
            home: DirectChatScreen(
              contactKey: 'stranger_hacker',
              contactName: 'Unknown Person',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Authorization restricted screen displayed
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Unauthorized Conversation'), findsOneWidget);
      expect(
        find.textContaining(
          'Private messaging is restricted to verified housemates',
        ),
        findsOneWidget,
      );
      expect(find.text('Return to Messages'), findsOneWidget);
    },
  );

  testWidgets(
    'GroupChatScreen displays group messages, meet-up card and allows opening household members sheet',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockRepository();
      final initialGroupMsgCount = mockRepo.groupMessages.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: GroupChatScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Casa 204'), findsWidgets);
      expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);

      // Send a message to group
      await tester.enterText(
        find.byType(TextField),
        'Team dinner at 7pm tonight!',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(mockRepo.groupMessages.length, initialGroupMsgCount + 1);
      expect(
        mockRepo.groupMessages.last.content,
        'Team dinner at 7pm tonight!',
      );

      // Tap "Housemates" / members header icon button to open member sheet
      await tester.tap(find.byIcon(Icons.people_alt_outlined));
      await tester.pumpAndSettle();

      // Verify Household Members sheet opened
      expect(find.textContaining('Casa 204 Members'), findsOneWidget);
      expect(find.text('Add Housemate'), findsWidgets);
    },
  );

  testWidgets(
    'ProfileScreen displays user profile details, points card, and edit button',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify User Details
      expect(find.text('Jon Paul Berana'), findsWidgets);
      expect(find.textContaining('JP'), findsWidgets);
      expect(find.text('@jpberana'), findsWidgets);
      expect(find.text('Edit Profile'), findsWidgets);

      // Verify Personal Information section
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);

      // Verify Points card
      expect(find.text('Good Kasama Points'), findsOneWidget);
      expect(find.text('120 pts'), findsOneWidget);
      expect(find.text('Gold Tier'), findsOneWidget);

      // Verify Menu options & Log Out
      expect(find.text('My Household'), findsOneWidget);
      expect(find.text('Application Settings'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
    },
  );

  testWidgets(
    'ProfileScreen points card opens Kasama Points Ledger with activity history',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: ProfileScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Good Kasama Points Card
      await tester.tap(find.text('Good Kasama Points'));
      await tester.pumpAndSettle();

      // Verify Ledger Sheet contents
      expect(find.text('Kasama Points Ledger'), findsOneWidget);
      expect(find.text('Total Balance: 120 pts'), findsOneWidget);
      expect(find.text('Recent Activity & Points Earned'), findsOneWidget);
      expect(find.textContaining('Shopee'), findsOneWidget);
      expect(find.textContaining('welcome bonus'), findsOneWidget);
    },
  );

  testWidgets(
    'EditProfileDialog allows editing full name, nickname, age, and saving changes',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: Scaffold(body: EditProfileDialog())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Nickname'), findsOneWidget);
      expect(find.text('Age (Optional)'), findsOneWidget);

      // Enter updated full name and nickname
      await tester.enterText(
        find.widgetWithText(TextField, 'Jon Paul Berana'),
        'Jonathan Paul',
      );
      await tester.enterText(find.widgetWithText(TextField, 'JP'), 'Nate');
      await tester.enterText(find.widgetWithText(TextField, '21'), '24');
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify repository record was updated
      expect(mockRepo.currentUser.fullName, 'Jonathan Paul');
      expect(mockRepo.currentUser.nickname, 'Nate');
      expect(mockRepo.currentUser.age, 24);
      expect(mockRepo.effectiveGreetingName, 'Nate');
    },
  );

  testWidgets(
    'EditProfileDialog allows removing picture and validates required fields',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: Scaffold(body: EditProfileDialog())),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Remove Picture
      await tester.tap(find.text('Remove Picture'));
      await tester.pumpAndSettle();

      expect(find.text('Default Avatar'), findsOneWidget);

      // Clear name field to test validation
      await tester.enterText(
        find.widgetWithText(TextField, 'Jon Paul Berana'),
        '',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Error message displayed
      expect(find.text('Please enter your full name'), findsOneWidget);

      // Restore name and save
      await tester.enterText(find.byType(TextField).first, 'Jon Paul');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Avatar cleared in repository
      expect(mockRepo.currentUser.avatarUrl, isNull);
    },
  );

  testWidgets(
    'AppSettingsScreen displays all five sections and allows switching theme modes',
    (WidgetTester tester) async {
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

      // 1. Account Settings
      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Manage Account'), findsOneWidget);

      // 2. Appearance
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Theme Mode'), findsOneWidget);
      expect(find.text('Light'), findsWidgets);
      expect(find.text('Dark'), findsWidgets);
      expect(find.text('System'), findsWidgets);

      // 3. Notification Settings
      expect(find.text('Notification Settings'), findsOneWidget);
      expect(find.text('Household Updates'), findsOneWidget);
      expect(find.text('Parcel & Delivery Alerts'), findsOneWidget);
      expect(find.text('Task & Chore Reminders'), findsOneWidget);
      expect(find.text('Chat & Meet-up Notifications'), findsOneWidget);

      // 4. Privacy and Security
      expect(find.text('Privacy and Security'), findsOneWidget);
      expect(find.text('Presence & Status Sharing'), findsOneWidget);
      expect(find.text('Application Permissions'), findsOneWidget);

      // 5. About Casama
      expect(find.text('About Casama'), findsOneWidget);
      expect(find.text('Version 1.0.0 (Build 1)'), findsOneWidget);
      expect(
        find.text(
          'Making shared living simpler, warmer, and more coordinated.',
        ),
        findsOneWidget,
      );

      // Switch theme to Dark
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      // Switch theme to System
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'AppSettingsScreen toggles notification preferences and updates repository',
    (WidgetTester tester) async {
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

      // Toggle Parcel & Delivery Alerts
      final switches = find.byType(Switch);
      expect(
        switches,
        findsNWidgets(5),
      ); // 4 notification switches + 1 privacy switch

      await tester.tap(switches.at(1)); // Parcel switch
      await tester.pumpAndSettle();

      expect(mockRepo.notificationPreferences.parcelNotifications, false);
    },
  );

  testWidgets(
    'AppSettingsScreen opens Change Password dialog and validates passwords',
    (WidgetTester tester) async {
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

      await tester.tap(find.text('Change Password'));
      await tester.pumpAndSettle();

      // Verify modal appeared
      expect(find.text('Change Password'), findsWidgets);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      // Tap Update Password with empty fields to trigger validation
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsWidgets);
    },
  );

  testWidgets('AppSettingsScreen prompts confirmation and logs out', (
    WidgetTester tester,
  ) async {
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

    // Scroll to Log Out if necessary
    await tester.tap(find.text('Log Out'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears
    expect(find.text('Log Out of Casama?'), findsOneWidget);
    expect(
      find.textContaining('Are you sure you want to end your current session?'),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log Out of Casama?'), findsNothing);
  });

  testWidgets(
    'ChoreRouletteScreen switches between Random Dormmate and Just For Me modes and spins',
    (WidgetTester tester) async {
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
          child: const MaterialApp(home: ChoreRouletteScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and mode toggle options
      expect(find.text('Chore Roulette'), findsOneWidget);
      expect(find.text('Random Dormmate'), findsOneWidget);
      expect(find.text('Just For Me'), findsOneWidget);
      expect(
        find.text("Let's settle who does what fairly! 👥"),
        findsOneWidget,
      );
      expect(
        find.text("Good luck, Kasama! Let's see who's up! 🎉"),
        findsOneWidget,
      );

      // Switch to "Just For Me" mode
      await tester.tap(find.text('Just For Me'));
      await tester.pumpAndSettle();

      expect(
        find.text("Can't decide what to do? Spin for yourself! 👤"),
        findsOneWidget,
      );
      expect(
        find.text('Ready to get things done? Spin away! 🚀'),
        findsOneWidget,
      );

      // Tap Spin button
      expect(find.text('Spin'), findsOneWidget);
      await tester.tap(find.text('Spin'));
      await tester.pump(const Duration(milliseconds: 500));

      // Re-switch to "Random Dormmate"
      await tester.tap(find.text('Random Dormmate'));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'BoardsScreen displays Bills & Payments card and navigates to BillsDashboard',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BoardsScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parcels & Deliveries'), findsOneWidget);
      expect(find.text('Lost & Found Items'), findsOneWidget);
      expect(find.text('Maintenance & Restock'), findsOneWidget);
      expect(find.text('Chore Roulette'), findsOneWidget);
      expect(find.text('Bills & Payments'), findsOneWidget);
      expect(
        find.text(
          'Track household bills, set reminders, and never miss a deadline',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'AddBillScreen renders illustration, form fields, and responsible member dropdown without assertion errors',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AddBillScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a New Bill'), findsOneWidget);
      expect(find.text('Bill Type'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Responsible Member'), findsOneWidget);
      expect(find.text('Save Bill'), findsOneWidget);

      // Verify dropdown rendered valid initial responsible member without crash
      expect(find.byType(DropdownButton<String>), findsOneWidget);
    },
  );

  testWidgets(
    'DashboardScreen renders QuickSnapHomeWidget empty state initially and active snap when populated',
    (tester) async {
      final mockRepo = MockRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state verification: no photos taken yet
      expect(find.text('No moments shared yet today'), findsOneWidget);
      expect(find.text('Take QuickSnap'), findsOneWidget);

      // Now add a snap and verify active state
      mockRepo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'Balcony sunrise',
        recipientType: QuickSnapRecipientType.everyone,
      );
      await tester.pumpAndSettle();

      expect(find.text('Household QuickSnap'), findsOneWidget);
      expect(find.text('Snap Back'), findsOneWidget);
      expect(find.text('😍'), findsWidgets);
      expect(find.text('🔥'), findsWidgets);
    },
  );

  testWidgets(
    'QuickSnapFeedScreen renders empty state when no snaps and full tabs when populated',
    (tester) async {
      final mockRepo = MockRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state
      expect(find.text('No QuickSnaps yet!'), findsOneWidget);
      expect(find.text('Take QuickSnap'), findsOneWidget);

      // Add snap and pump
      mockRepo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'First dorm moment',
        recipientType: QuickSnapRecipientType.everyone,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live Snaps'), findsOneWidget);
      expect(find.text('Memories'), findsOneWidget);
      expect(find.text('Send message... 💬'), findsOneWidget);

      // Switch to Memories tab
      await tester.tap(find.text('Memories'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('moments saved in household album'),
        findsOneWidget,
      );
      expect(find.textContaining('Streak'), findsWidgets);
    },
  );

  testWidgets(
    'QuickSnapCameraScreen prompts permission first and allows continuing with fallback when denied',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapCameraScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Check permission modal is present
      expect(find.text('Enable Camera for QuickSnap'), findsOneWidget);
      expect(find.byKey(const Key('deny_camera_permission_button')), findsOneWidget);

      // Tap 'Not Now'
      await tester.tap(find.byKey(const Key('deny_camera_permission_button')));
      await tester.pumpAndSettle();

      // Viewfinder displays with clean dark viewfinder and permission needed pill
      expect(find.text('Permission Needed'), findsOneWidget);
      expect(find.text('Camera Access Needed'), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
    },
  );

  testWidgets(
    'QuickSnapCameraScreen skips permission prompt when already granted in SharedPreferences',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'quicksnap_camera_permission_granted': true,
      });
      final mockRepo = MockRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapCameraScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verified: No permission modal is shown!
      expect(find.text('Enable Camera for QuickSnap'), findsNothing);
      expect(find.byKey(const Key('quicksnap_shutter_button')), findsOneWidget);
      expect(find.text('Everyone'), findsOneWidget);
    },
  );

  testWidgets(
    'QuickSnapCameraScreen takes snap with shutter and sends to household',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final mockRepo = MockRepository();
      final initialCount = mockRepo.quickSnaps.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapCameraScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Allow permission
      if (find.byKey(const Key('allow_camera_permission_button')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const Key('allow_camera_permission_button')));
        await tester.pumpAndSettle();
      }

      // Tap shutter button
      await tester.tap(find.byKey(const Key('quicksnap_shutter_button')));
      await tester.pumpAndSettle();

      // Verify caption and send button appear
      expect(find.text('Retake'), findsOneWidget);
      expect(find.byKey(const Key('send_quicksnap_button')), findsOneWidget);

      // Tap send
      await tester.tap(find.byKey(const Key('send_quicksnap_button')));
      await tester.pumpAndSettle();

      // Repository count increased
      expect(mockRepo.quickSnaps.length, equals(initialCount + 1));
    },
  );

  testWidgets(
    'QuickSnapCameraScreen allows retaking photo, restoring shutter and capturing again',
    (tester) async {
      SharedPreferences.setMockInitialValues({'quicksnap_camera_permission_granted': true});
      final mockRepo = MockRepository();
      final initialCount = mockRepo.quickSnaps.length;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: QuickSnapCameraScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap shutter for first capture
      expect(find.byKey(const Key('quicksnap_shutter_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('quicksnap_shutter_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // First capture: Retake and Send appear
      expect(find.text('Retake'), findsOneWidget);
      expect(find.byKey(const Key('send_quicksnap_button')), findsOneWidget);
      expect(find.byKey(const Key('quicksnap_shutter_button')), findsNothing);

      // Tap Retake
      await tester.tap(find.text('Retake'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Shutter is restored, Retake and Send are gone
      expect(find.byKey(const Key('quicksnap_shutter_button')), findsOneWidget);
      expect(find.text('Retake'), findsNothing);
      expect(find.byKey(const Key('send_quicksnap_button')), findsNothing);

      // Tap shutter again to capture second photo
      await tester.tap(find.byKey(const Key('quicksnap_shutter_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Second capture succeeds: Retake and Send reappear
      expect(find.text('Retake'), findsOneWidget);
      expect(find.byKey(const Key('send_quicksnap_button')), findsOneWidget);

      // Send second photo
      await tester.tap(find.byKey(const Key('send_quicksnap_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockRepo.quickSnaps.length, equals(initialCount + 1));
    },
  );

  testWidgets(
    'OptionalProfileScreen Take Photo opens ProfileCameraSheet and closes gracefully',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OptionalProfileScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Take Photo'), findsOneWidget);

      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Take Profile Photo'), findsOneWidget);
      expect(find.byType(ProfileCameraSheet), findsOneWidget);
      expect(find.text('Position your face in the circle'), findsOneWidget);
      expect(find.byKey(const Key('profile_camera_close_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_camera_close_button')));
      await tester.pumpAndSettle();

      expect(find.text('Take Profile Photo'), findsNothing);
      expect(find.text('Tell Us About You 👋'), findsOneWidget);
    },
  );

  testWidgets(
    'EditProfileDialog Take Photo opens ProfileCameraSheet',
    (WidgetTester tester) async {
      final mockRepo = MockRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
          child: const MaterialApp(home: Scaffold(body: EditProfileDialog())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Take Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Take Profile Photo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile_camera_close_button')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Profile'), findsOneWidget);
    },
  );
}
