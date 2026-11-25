import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repository_provider.dart';
import '../chat/chat_directory_screen.dart';
import '../profile/profile_screen.dart';
import '../quicksnap/quicksnap_camera_screen.dart';
import 'boards_screen.dart';
import 'dashboard_screen.dart';
import 'widgets/casama_household_drawer.dart';

/// Inherited shell scope letting tab screens switch top-level tabs, deep-link
/// into a remembered Board sub-tab (`0=Parcels, 1=Tasks, 2=Bills, 3=Items`),
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

  const MainNavigationShell({
    super.key,
    this.initialIndex = 0,
    this.initialBoardIndex = 0,
    this.showBottomNav = true,
  });

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late int _currentIndex;
  late final ValueNotifier<int> _boardTabNotifier;

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
    _boardTabNotifier = ValueNotifier<int>(widget.initialBoardIndex.clamp(0, 3));
  }

  @override
  void didUpdateWidget(covariant MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      _currentIndex = widget.initialIndex.clamp(0, 4);
    }
    if (widget.initialBoardIndex != oldWidget.initialBoardIndex) {
      _boardTabNotifier.value = widget.initialBoardIndex.clamp(0, 3);
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
      _openQuickSnap();
    } else {
      setState(() => _currentIndex = index.clamp(0, 4));
    }
  }

  void _openBoardTab(int boardIndex) {
    _boardTabNotifier.value = boardIndex.clamp(0, 3);
    setState(() => _currentIndex = 1);
  }

  void _openDrawer() {
    showCasamaHouseholdDrawer(
      context,
      onSelectNavTab: _onTabTapped,
      onSelectBoardTab: _openBoardTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final unreadChat = repo.totalUnreadChatCount;
    final reduced = CasamaMotion.reduceMotion(context);
    final navVisible = widget.showBottomNav && _currentIndex != 2;

    return CasamaShellScope(
      currentIndex: _currentIndex,
      boardTabListenable: _boardTabNotifier,
      selectTab: _onTabTapped,
      openBoardTab: _openBoardTab,
      openDrawer: _openDrawer,
      child: Scaffold(
        backgroundColor: pal.scaffoldBg,
        extendBody: true,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: AnimatedSwitcher(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          child: navVisible
              ? _CasamaBottomBar(
                  key: const ValueKey('casama_5_slot_bar'),
                  currentIndex: _currentIndex,
                  unreadChatCount: unreadChat,
                  onTap: _onTabTapped,
                )
              : const SizedBox.shrink(key: ValueKey('casama_hidden_bar')),
        ),
      ),
    );
  }
}

class _CasamaBottomBar extends StatelessWidget {
  final int currentIndex;
  final int unreadChatCount;
  final ValueChanged<int> onTap;

  const _CasamaBottomBar({
    super.key,
    required this.currentIndex,
    required this.unreadChatCount,
    required this.onTap,
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
            _RaisedCasnapButton(onTap: () => onTap(2)),
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

  const _RaisedCasnapButton({required this.onTap});

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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: pal.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.coralFab, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: pal.coralFab.withValues(
                            alpha: context.isDark ? 0.45 : 0.35,
                          ),
                          blurRadius: 12,
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
