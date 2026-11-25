import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/optional_profile_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/bills/add_bill_screen.dart';
import '../../features/bills/bill_detail_screen.dart';
import '../../features/bills/bills_dashboard_screen.dart';
import '../../features/chat/chat_space_screen.dart';
import '../../features/chat/create_meetup_screen.dart';
import '../../features/chat/direct_chat_screen.dart';
import '../../features/chat/group_chat_screen.dart';
import '../../features/chore_roulette/chore_roulette_screen.dart';
import '../../features/dashboard/main_navigation_shell.dart';
import '../../features/household/household_setup_screen.dart';
import '../../features/items/lost_found_screen.dart';
import '../../features/legal/terms_consent_screen.dart';
import '../../features/legal/terms_privacy_screen.dart';
import '../../features/onboarding/casama_intro_screen.dart';
import '../../features/onboarding/device_permissions_screen.dart';
import '../../features/onboarding/interactive_tutorial_screen.dart';
import '../../features/onboarding/tutorial_screen.dart';
import '../../features/parcels/parcels_screen.dart';
import '../../features/points/leaderboard_screen.dart';
import '../../features/quicksnap/quicksnap_camera_screen.dart';
import '../../features/quicksnap/quicksnap_feed_screen.dart';
import '../../features/settings/app_settings_screen.dart';
import '../../features/tasks/maintenance_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/auth',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'];
        return AuthScreen(initialTabIndex: tab == 'login' ? 1 : 0);
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/profile-setup',
      builder: (context, state) => const OptionalProfileScreen(),
    ),
    GoRoute(
      path: '/terms-consent',
      builder: (context, state) => const TermsConsentScreen(),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) {
        final readOnly = state.uri.queryParameters['readOnly'] == 'true';
        return TermsPrivacyScreen(readOnly: readOnly);
      },
    ),
    GoRoute(
      path: '/permissions',
      builder: (context, state) {
        final fromSettings = state.uri.queryParameters['fromSettings'] == 'true';
        return DevicePermissionsScreen(isOnboarding: !fromSettings);
      },
    ),
    GoRoute(
      path: '/intro',
      builder: (context, state) => const CasamaIntroScreen(),
    ),
    GoRoute(
      path: '/interactive-tutorial',
      builder: (context, state) => const InteractiveTutorialScreen(),
    ),
    GoRoute(
      path: '/tutorial',
      builder: (context, state) => const TutorialScreen(),
    ),
    GoRoute(
      path: '/household-setup',
      builder: (context, state) => const HouseholdSetupScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final tour = state.uri.queryParameters['tour'] == 'true';
        return MainNavigationShell(initialIndex: 0, isTourMode: tour);
      },
    ),
    GoRoute(
      path: '/boards',
      builder: (context, state) {
        final tabParam = state.uri.queryParameters['tab'];
        final initialBoardIndex = switch (tabParam) {
          'parcels' || '0' => 0,
          'tasks' || '1' => 1,
          'bills' || '2' => 2,
          'items' || '3' => 3,
          _ => 0,
        };
        return MainNavigationShell(
          initialIndex: 1,
          initialBoardIndex: initialBoardIndex,
        );
      },
    ),
    GoRoute(
      path: '/parcels',
      builder: (context, state) {
        final openAdd = state.uri.queryParameters['openAdd'] == 'true';
        return ParcelsScreen(initialOpenAddModal: openAdd);
      },
    ),
    GoRoute(
      path: '/lost-found',
      builder: (context, state) {
        final openPost = state.uri.queryParameters['openPost'] == 'true';
        return LostFoundScreen(initialOpenPostModal: openPost);
      },
    ),
    GoRoute(
      path: '/maintenance',
      builder: (context, state) {
        final openAdd = state.uri.queryParameters['openAdd'] == 'true';
        return MaintenanceScreen(initialOpenAddModal: openAdd);
      },
    ),
    GoRoute(
      path: '/bills',
      builder: (context, state) => const BillsDashboardScreen(),
    ),
    GoRoute(
      path: '/add-bill',
      builder: (context, state) => const AddBillScreen(),
    ),
    GoRoute(
      path: '/bill-detail',
      builder: (context, state) {
        final billId = state.uri.queryParameters['id'] ?? '';
        return BillDetailScreen(billId: billId);
      },
    ),
    GoRoute(
      path: '/quicksnap',
      builder: (context, state) => const QuickSnapCameraScreen(),
    ),
    GoRoute(
      path: '/quicksnap-feed',
      builder: (context, state) => const QuickSnapFeedScreen(),
    ),
    GoRoute(
      path: '/chat',
      builder: (context, state) => const MainNavigationShell(initialIndex: 3),
    ),
    GoRoute(
      path: '/group-chat',
      builder: (context, state) => const GroupChatScreen(),
    ),
    GoRoute(
      path: '/space-chat',
      builder: (context, state) {
        final spaceId = state.uri.queryParameters['id'] ?? 'space_grocery';
        return ChatSpaceScreen(spaceId: spaceId);
      },
    ),
    GoRoute(
      path: '/direct-chat',
      builder: (context, state) {
        final contactKey = state.uri.queryParameters['contact'] ?? 'maria';
        final contactName = state.uri.queryParameters['name'];
        final avatarUrl = state.uri.queryParameters['avatar'];
        return DirectChatScreen(
          contactKey: contactKey,
          contactName: contactName,
          avatarUrl: avatarUrl,
        );
      },
    ),
    GoRoute(
      path: '/create-meetup',
      builder: (context, state) => const CreateMeetupScreen(),
    ),
    GoRoute(
      path: '/roulette',
      builder: (context, state) => const ChoreRouletteScreen(),
    ),
    GoRoute(
      path: '/leaderboard',
      builder: (context, state) => const LeaderboardScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const MainNavigationShell(initialIndex: 4),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const AppSettingsScreen(),
    ),
  ],
);
