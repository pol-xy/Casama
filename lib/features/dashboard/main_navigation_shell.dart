import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import 'boards_screen.dart';
import 'dashboard_screen.dart';
import '../chat/chat_directory_screen.dart';
import '../profile/profile_screen.dart';
import '../quicksnap/quicksnap_camera_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  ConsumerState<MainNavigationShell> createState() =>
      _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    DashboardScreen(),
    BoardsScreen(),
    SizedBox.shrink(), // Center + Action dummy placeholder
    ChatDirectoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (index == 2) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const QuickSnapCameraScreen()));
    } else {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final unreadChat = repo.totalUnreadChatCount;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          border: Border(top: BorderSide(color: context.borderColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDark ? 0.3 : 0.05,
              ),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.grid_view_rounded, 'Boards'),
                _buildCenterPlusButton(),
                _buildNavItem(
                  3,
                  Icons.chat_bubble_rounded,
                  'Chat',
                  badge: unreadChat > 0 ? '$unreadChat' : null,
                ),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    String? badge,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? CasamaColors.primaryCoral
        : (context.isDark
              ? CasamaColors.darkTextSecondary
              : CasamaColors.textMuted);

    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: CasamaSpacing.roundedMd,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: CasamaColors.primaryCoral,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterPlusButton() {
    return Semantics(
      label: 'QuickSnap Camera',
      button: true,
      child: GestureDetector(
        key: const Key('center_quicksnap_shutter_button'),
        onTap: () => _onTabTapped(2),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: CasamaColors.primaryCoral,
              width: 3.2,
            ),
            boxShadow: [
              BoxShadow(
                color: CasamaColors.primaryCoral.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4.0),
          child: Container(
            decoration: const BoxDecoration(
              color: CasamaColors.primaryCoral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
