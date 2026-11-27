import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../chat/chat_directory_screen.dart';
import '../profile/profile_screen.dart';
import '../quicksnap/quicksnap_camera_screen.dart';
import 'boards_screen.dart';
import 'dashboard_screen.dart';
import 'widgets/casama_household_drawer.dart';

/// Inherited shell scope letting tab screens switch top-level tabs, deep-link
/// into a remembered Board sub-tab (`0=Parcels, 1=Tasks, 2=Items`),
/// or open [CasamaHouseholdDrawer].
class CasamaShellScope extends InheritedWidget {
  final int currentIndex;
  final ValueListenable<int> boardTabListenable;
  final ValueChanged<int> selectTab;
  final ValueChanged<int> openBoardTab;
  final VoidCallback openDrawer;

  const CasamaShellScope({
    super.key,
    required this.currentIndex,
    required this.boardTabListenable,
    required this.selectTab,
    required this.openBoardTab,
    required this.openDrawer,
    required super.child,
  });

  static CasamaShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CasamaShellScope>();
  }

  @override
  bool updateShouldNotify(CasamaShellScope oldWidget) =>
      currentIndex != oldWidget.currentIndex ||
      boardTabListenable != oldWidget.boardTabListenable;
}

class MainNavigationShell extends ConsumerStatefulWidget {
  final int initialIndex;
  final int initialBoardIndex;
  final bool showBottomNav;
  final bool isTourMode;

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.initialBoardIndex = 0,
    this.showBottomNav = true,
    this.isTourMode = false,
  });

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late int _currentIndex;
  late final ValueNotifier<int> _boardTabNotifier;
  late bool _isTourActive;
  int _tourStep = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BoardsScreen(),
    SizedBox.shrink(), // Center CASnap camera slot placeholder
    ChatDirectoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _boardTabNotifier = ValueNotifier<int>(widget.initialBoardIndex.clamp(0, 2));
    _isTourActive = widget.isTourMode;
    if (_isTourActive) {
      _tourStep = _currentIndex == 1
          ? 1
          : (_currentIndex == 3 ? 3 : (_currentIndex == 4 ? 4 : 0));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final repo = ref.read(repositoryProvider);
        if (!repo.currentUser.hasCompletedOnboarding) {
          repo.completeOnboardingTutorial();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex.clamp(0, 4);
    }
    if (widget.initialBoardIndex != oldWidget.initialBoardIndex) {
      _boardTabNotifier.value = widget.initialBoardIndex.clamp(0, 2);
    }
    if (widget.isTourMode != oldWidget.isTourMode) {
      setState(() => _isTourActive = widget.isTourMode);
    }
  }

  @override
  void dispose() {
    _boardTabNotifier.dispose();
    super.dispose();
  }

  void _openQuickSnap() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QuickSnapCameraScreen()));
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      if (_isTourActive) {
        setState(() => _tourStep = 2);
      } else {
        _openQuickSnap();
      }
    } else {
      setState(() {
        _currentIndex = index.clamp(0, 4);
        if (_isTourActive) {
          _tourStep = switch (index) {
            0 => 0,
            1 => 1,
            3 => 3,
            4 => 4,
            _ => _tourStep,
          };
        }
      });
    }
  }

  void _openBoardTab(int boardIndex) {
    _boardTabNotifier.value = boardIndex.clamp(0, 2);
    setState(() {
      _currentIndex = 1;
      if (_isTourActive) _tourStep = 1;
    });
  }

  void _openDrawer() {
    showCasamaHouseholdDrawer(
      context,
      onSelectNavTab: _onTabTapped,
      onSelectBoardTab: _openBoardTab,
    );
  }

  void _finishTour() {
    ref.read(repositoryProvider).completeOnboardingTutorial();
    setState(() {
      _isTourActive = false;
      _currentIndex = 0;
    });
    GoRouter.maybeOf(context)?.go('/dashboard');
    showCasamaToast(
      context,
      'Feature tour complete! Welcome to Casama.',
      icon: Icons.check_circle_outline_rounded,
    );
  }

  void _goToTourStep(int step) {
    if (step < 0 || step > 4) return;
    setState(() {
      _tourStep = step;
      switch (step) {
        case 0:
          _currentIndex = 0;
          break;
        case 1:
          _currentIndex = 1;
          break;
        case 2:
          // Keep on current tab, highlighting CASnap center button
          break;
        case 3:
          _currentIndex = 3;
          break;
        case 4:
          _currentIndex = 4;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final unreadChat = repo.totalUnreadChatCount;
    final reduced = CasamaMotion.reduceMotion(context);
    final navVisible = widget.showBottomNav && _currentIndex != 2;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return CasamaShellScope(
      currentIndex: _currentIndex,
      boardTabListenable: _boardTabNotifier,
      selectTab: _onTabTapped,
      openBoardTab: _openBoardTab,
      openDrawer: _openDrawer,
      child: Scaffold(
        backgroundColor: pal.scaffoldBg,
        extendBody: true,
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _screens),
            if (_isTourActive)
              Positioned(
                left: CasamaSpacing.md,
                right: CasamaSpacing.md,
                bottom: 74 + (bottomInset > 0 ? bottomInset : 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: _buildTourGuideCard(context, pal),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: AnimatedSwitcher(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          child: navVisible
              ? _CasamaBottomBar(
                  key: const ValueKey('casama_5_slot_bar'),
                  currentIndex: _currentIndex,
                  unreadChatCount: unreadChat,
                  onTap: _onTabTapped,
                  highlightCasnap: _isTourActive && _tourStep == 2,
                )
              : const SizedBox.shrink(key: ValueKey('casama_hidden_bar')),
        ),
      ),
    );
  }

  Widget _buildTourGuideCard(BuildContext context, CasamaPalette pal) {
    final theme = Theme.of(context);

    final (title, desc, pose, actionLabel) = switch (_tourStep) {
      0 => (
        '1. Home Dashboard & Presence',
        'Check live housemate presence with zero background GPS, share quick status notes, and view upcoming events.',
        CasPose.home,
        'Next: Boards ›',
      ),
      1 => (
        '2. Unified Household Boards',
        'Swipe across Parcels, Household Tasks, and Lost & Found in one shared household hub.',
        CasPose.deliveries,
        'Next: CASnap ›',
      ),
      2 => (
        '3. CASnap Household Camera',
        'Tap the raised center shutter anytime to snap parcel slips, shared moments, or kitchen updates.',
        CasPose.jumping,
        'Next: Chat ›',
      ),
      3 => (
        '4. Household Chat & Agendas',
        'Message housemates 1-on-1, coordinate in topic spaces, and plan household agendas with instant RSVPs.',
        CasPose.chatting,
        'Next: Profile ›',
      ),
      _ => (
        '5. Profile, Roulette & Points',
        'Spin Task Roulette for fair chore turns, track Good Kasama points, and copy your household invite code.',
        CasPose.roulette,
        'Finish Tour 🎉',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      decoration: BoxDecoration(
        color: pal.surface,
        borderRadius: CasamaSpacing.roundedCard,
        border: Border.all(
          color: pal.primaryCoral.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pal.softBlush,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Text(
                  'App Tour (${_tourStep + 1} of 5)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: pal.primaryCoral,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CasMascotView(pose: pose, width: 44, height: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      desc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_tourStep > 0)
                OutlinedButton(
                  onPressed: () => _goToTourStep(_tourStep - 1),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    side: BorderSide(color: pal.border),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    '‹ Back',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              Flexible(
                child: CasamaButton(
                  label: actionLabel,
                  isPill: true,
                  isFullWidth: false,
                  height: 36,
                  onPressed: () {
                    if (_tourStep < 4) {
                      _goToTourStep(_tourStep + 1);
                    } else {
                      _finishTour();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CasamaBottomBar extends StatelessWidget {
  final int currentIndex;
  final int unreadChatCount;
  final ValueChanged<int> onTap;
  final bool highlightCasnap;

  const _CasamaBottomBar({
    super.key,
    required this.currentIndex,
    required this.unreadChatCount,
    required this.onTap,
    this.highlightCasnap = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: pal.surface,
        border: Border(top: BorderSide(color: pal.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.34 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset > 0 ? bottomInset : 6),
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _NavSlotItem(
              index: 0,
              currentIndex: currentIndex,
              activeIcon: Icons.home_rounded,
              inactiveIcon: Icons.home_outlined,
              label: 'Home',
              onTap: () => onTap(0),
            ),
            _NavSlotItem(
              index: 1,
              currentIndex: currentIndex,
              activeIcon: Icons.dashboard_rounded,
              inactiveIcon: Icons.dashboard_outlined,
              label: 'Boards',
              onTap: () => onTap(1),
            ),
            _RaisedCasnapButton(
              onTap: () => onTap(2),
              isHighlighted: highlightCasnap,
            ),
            _NavSlotItem(
              index: 3,
              currentIndex: currentIndex,
              activeIcon: Icons.chat_bubble_rounded,
              inactiveIcon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              badgeCount: currentIndex == 3 ? 0 : unreadChatCount,
              onTap: () => onTap(3),
            ),
            _NavSlotItem(
              index: 4,
              currentIndex: currentIndex,
              activeIcon: Icons.person_rounded,
              inactiveIcon: Icons.person_outline_rounded,
              label: 'Profile',
              onTap: () => onTap(4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSlotItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final int badgeCount;
  final VoidCallback onTap;

  const _NavSlotItem({
    required this.index,
    required this.currentIndex,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    this.badgeCount = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;
    final ink = isSelected ? pal.primaryCoral : pal.textSecondary;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: badgeCount > 0 ? '$label, $badgeCount unread' : label,
        child: CasamaPressable(
          onTap: onTap,
          enableHaptic: true,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      color: ink,
                      size: 24,
                    ),
                    if (badgeCount > 0)
                      Positioned(
                        top: -5,
                        right: -9,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: pal.coralFab,
                            borderRadius: CasamaSpacing.roundedPill,
                            border: Border.all(color: pal.surface, width: 1.5),
                          ),
                          child: Text(
                            badgeCount > 9 ? '9+' : '$badgeCount',
                            style: theme.textTheme.labelSmall?.tabular.copyWith(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RaisedCasnapButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isHighlighted;

  const _RaisedCasnapButton({
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Expanded(
      child: Semantics(
        label: 'CASnap Camera',
        button: true,
        child: CasamaPressable.fab(
          onTap: onTap,
          child: SizedBox(
            key: const Key('center_quicksnap_shutter_button'),
            height: 62,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: -18,
                  child: Container(
                    width: isHighlighted ? 62 : 56,
                    height: isHighlighted ? 62 : 56,
                    decoration: BoxDecoration(
                      color: pal.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: pal.coralFab,
                        width: isHighlighted ? 3.5 : 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: pal.coralFab.withValues(
                            alpha: isHighlighted ? 0.65 : (context.isDark ? 0.45 : 0.35),
                          ),
                          blurRadius: isHighlighted ? 18 : 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.coralFab,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.photo_camera_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  child: Text(
                    'CASnap',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.primaryCoral,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
