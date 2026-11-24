import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/avatar_chip.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../calendar/household_calendar_view.dart';
import '../quicksnap/quicksnap_home_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning.';
    } else if (hour < 17) {
      return 'Good Afternoon.';
    } else {
      return 'Good Evening.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final members = repo.members;
    final activeCount = members.where((m) => m.isHome).length;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: CasamaSpacing.md),

              // 1. Personalized Greeting & Notification Bell
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${repo.currentUser.effectiveGreetingName}!',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getTimeBasedGreeting(),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.borderColor),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.notifications_none_rounded,
                            color: context.textColor,
                            size: 22,
                          ),
                          onPressed: () {
                            ref
                                .read(repositoryProvider)
                                .markAllNotificationsAsRead();
                            _showNotificationsSheet(context, ref);
                          },
                        ),
                      ),
                      if (repo.unreadNotificationCount > 0)
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: CasamaColors.primaryCoral,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: CasamaSpacing.lg),

              // 2. Household Information & Member Status Card (Casa 204)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(CasamaSpacing.lg),
                decoration: BoxDecoration(
                  color: CasamaColors.midnightNavy,
                  borderRadius: CasamaSpacing.roundedXl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: CasamaSpacing.roundedSm,
                          ),
                          child: const Icon(
                            Icons.home_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repo.currentHousehold.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              '${members.length} members • Active now: $activeCount',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: CasamaSpacing.lg),

                    // Avatars row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: members.map((m) {
                        final isMe = m.profile.id == repo.currentUser.id;
                        return AvatarChip(
                          name: m.profile.displayName,
                          avatarUrl: m.profile.avatarUrl,
                          isHome: m.isHome,
                          isCurrentUser: isMe,
                          onTap: isMe
                              ? () => _showPresenceToggleModal(
                                  context,
                                  ref,
                                  m.isHome,
                                  m.note,
                                )
                              : () => _showMemberInfoModal(context, m),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: CasamaSpacing.xl),

              // 3. Household Interactive Calendar Feature (Directly Below Household Card)
              const HouseholdCalendarView(),

              const SizedBox(height: CasamaSpacing.xl),

              // 4. QuickSnap Moments Widget (Locket-style)
              const QuickSnapHomeWidget(),

              const SizedBox(height: CasamaSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showPresenceToggleModal(
    BuildContext context,
    WidgetRef ref,
    bool currentIsHome,
    String? currentNote,
  ) {
    bool isHome = currentIsHome;
    final noteController = TextEditingController(text: currentNote);

    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Your Presence',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isHome
                                ? CasamaColors.homeBg
                                : Colors.transparent,
                            side: BorderSide(
                              color: isHome
                                  ? CasamaColors.homeGreen
                                  : context.borderColor,
                              width: isHome ? 2 : 1,
                            ),
                          ),
                          onPressed: () => setModalState(() => isHome = true),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: CasamaColors.homeGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("I'm Home"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !isHome
                                ? CasamaColors.outBg
                                : Colors.transparent,
                            side: BorderSide(
                              color: !isHome
                                  ? CasamaColors.outGray
                                  : context.borderColor,
                              width: !isHome ? 2 : 1,
                            ),
                          ),
                          onPressed: () => setModalState(() => isHome = false),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: CasamaColors.outGray,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("I'm Out"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Status note (optional)',
                      hintText: 'e.g. Studying, At class, Cooking',
                    ),
                  ),
                  const SizedBox(height: 20),
                  CasamaButton(
                    label: 'Save Status',
                    onPressed: () {
                      ref
                          .read(repositoryProvider)
                          .updatePresence(
                            isHome: isHome,
                            note: noteController.text.trim().isNotEmpty
                                ? noteController.text.trim()
                                : null,
                          );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Presence updated!')),
                      );
                    },
                    isPill: true,
                    height: 48,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showMemberInfoModal(BuildContext context, dynamic member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CasamaAvatar(
                radius: 36,
                avatarUrl: member.profile.avatarUrl,
                name: member.profile.displayName,
              ),
              const SizedBox(height: 12),
              Text(
                member.profile.displayName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              Text(
                member.profile.handle,
                style: TextStyle(
                  color: context.textSecondaryColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: member.isHome
                      ? CasamaColors.homeBg
                      : CasamaColors.outBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: member.isHome
                            ? CasamaColors.homeGreen
                            : CasamaColors.outGray,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      member.isHome ? "Currently Home" : "Currently Out",
                      style: TextStyle(
                        color: member.isHome
                            ? CasamaColors.homeGreen
                            : CasamaColors.outGray,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (member.note != null && member.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '"${member.note}"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: context.textSecondaryColor,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(repositoryProvider).markAllNotificationsAsRead();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read.'),
                        ),
                      );
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        color: CasamaColors.primaryCoral,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: CasamaColors.tileParcels,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: CasamaColors.primaryCoral,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Your parcel is expected today at 4 PM!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
                subtitle: Text(
                  'Shopee delivery • COD ₱350',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                trailing: Text(
                  'Just now',
                  style: TextStyle(fontSize: 11, color: context.textMutedColor),
                ),
              ),
              Divider(height: 1, color: context.borderColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF8E1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: CasamaColors.warmGold,
                    size: 20,
                  ),
                ),
                title: Text(
                  '+5 Good Kasama points received!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
                subtitle: Text(
                  'For receiving Maria\'s delivery package',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                trailing: Text(
                  '2h ago',
                  style: TextStyle(fontSize: 11, color: context.textMutedColor),
                ),
              ),
              Divider(height: 1, color: context.borderColor),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: CasamaColors.tileChat,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.school_outlined,
                    color: CasamaColors.deepTeal,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Meet-up: Study Session 🎓',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
                subtitle: Text(
                  'Dorm Common Area • 3 housemates going',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondaryColor,
                  ),
                ),
                trailing: Text(
                  '4h ago',
                  style: TextStyle(fontSize: 11, color: context.textMutedColor),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
