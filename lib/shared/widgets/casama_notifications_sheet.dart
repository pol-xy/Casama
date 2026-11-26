import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../features/chat/group_chat_screen.dart';
import 'casama_avatar.dart';
import 'casama_button.dart';
import 'casama_sheet_scaffold.dart';
import 'casama_wave_header.dart';

/// Shared `48x48px` circular Notification Bell header button used across all
/// four top-level shell destinations (`Home`, `Boards`, `Chat`, `Profile`).
class CasamaNotificationBellButton extends ConsumerWidget {
  const CasamaNotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(repositoryProvider).unreadNotificationCount;

    return CasamaCircleIconButton(
      icon: Icons.notifications_none_rounded,
      semanticLabel: unreadCount > 0
          ? 'Notifications, $unreadCount unread'
          : 'Notifications',
      showDot: unreadCount > 0,
      onTap: () => showCasamaNotificationsSheet(context),
    );
  }
}

/// Opens the single shared Notifications bottom sheet used by `Home`, `Boards`,
/// `Chat`, and `Profile`.
Future<void> showCasamaNotificationsSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.notifications_none_rounded,
    title: 'Notifications',
    subtitle: 'Recent household updates',
    builder: (sheetCtx) => Consumer(
      builder: (ctx, ref, _) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        final repo = ref.watch(repositoryProvider);
        final items = repo.notifications;
        final hasUnread = items.any((n) => n.readAt == null && !n.isRead);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CasamaSpacing.md),
                child: Text(
                  "You're all caught up! No new notifications.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: pal.textSecondary,
                  ),
                ),
              )
            else
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 16, color: pal.border),
                Builder(
                  builder: (_) {
                    final item = items[i];
                    final isParcel = item.type == 'parcel_received';
                    final isRoulette = item.type == 'roulette_chosen';
                    final isMeetupReminder = item.type == 'meetup_reminder';
                    final isMeetupNotification =
                        isMeetupReminder || item.type.startsWith('meetup_');

                    final icon = isParcel
                        ? Icons.local_shipping_outlined
                        : isRoulette
                        ? Icons.casino_outlined
                        : isMeetupNotification
                        ? Icons.event_rounded
                        : Icons.notifications_none_rounded;
                    final iconBg = isParcel ? pal.softBlush : pal.softSage;
                    final iconColor =
                        isParcel ? pal.primaryCoral : pal.forestTeal;

                    final creatorProfile = isMeetupNotification
                        ? _resolveNotificationCreatorProfile(repo, item)
                        : null;
                    final Widget? leading = creatorProfile != null
                        ? CasamaAvatar(
                            radius: 20,
                            avatarUrl: creatorProfile.avatarUrl,
                            name: creatorProfile.displayName,
                          )
                        : null;

                    return _CasamaNotificationRow(
                      leading: leading,
                      icon: icon,
                      iconBg: iconBg,
                      iconColor: iconColor,
                      title: item.displayTitle,
                      subtitle: item.displaySubtitle,
                      time: DateFormat('h:mm a').format(item.createdAt),
                      isUnread: item.isUnread,
                      pal: pal,
                      theme: theme,
                      onTap: isMeetupReminder
                          ? () => _handleMeetupReminderTap(
                              context,
                              sheetCtx,
                              ref,
                              item,
                            )
                          : null,
                    );
                  },
                ),
              ],
            const SizedBox(height: CasamaSpacing.md),
            CasamaButton(
              key: const ValueKey('casama_mark_all_read_button'),
              label: 'Mark all read',
              style: CasamaButtonStyle.secondary,
              height: 48,
              onPressed: hasUnread
                  ? () {
                      ref.read(repositoryProvider).markAllNotificationsAsRead();
                      Navigator.of(sheetCtx).pop();
                      showCasamaToast(
                        context,
                        'All notifications marked as read',
                        icon: Icons.done_all_rounded,
                      );
                    }
                  : null,
            ),
          ],
        );
      },
    ),
  );
}

void _handleMeetupReminderTap(
  BuildContext hostContext,
  BuildContext sheetCtx,
  WidgetRef ref,
  HouseholdNotificationItem item,
) {
  final repo = ref.read(repositoryProvider);
  repo.markNotificationAsRead(item.id);
  Navigator.of(sheetCtx).pop();
  if (!hostContext.mounted) return;

  final convId = (item.payload['conversation_id'] as String?)?.trim() ?? '';
  final isSpace =
      convId.isNotEmpty && repo.chatSpaces.any((s) => s.id == convId);
  final router = GoRouter.maybeOf(hostContext);
  if (router != null) {
    if (isSpace) {
      router.push('/space-chat?id=$convId');
    } else {
      router.push('/group-chat');
    }
    return;
  }

  Navigator.of(hostContext).push(
    MaterialPageRoute<void>(builder: (_) => const GroupChatScreen()),
  );
}

UserProfile? _resolveNotificationCreatorProfile(
  CasamaRepository repo,
  HouseholdNotificationItem item,
) {
  var creatorId = (item.payload['creator_id'] as String?)?.trim() ?? '';
  if (creatorId.isEmpty) {
    final invitationId =
        (item.payload['invitation_id'] as String?)?.trim() ?? '';
    if (invitationId.isNotEmpty) {
      for (final inv in repo.meetUpInvitations) {
        if (inv.id == invitationId && inv.creatorId.trim().isNotEmpty) {
          creatorId = inv.creatorId.trim();
          break;
        }
      }
      if (creatorId.isEmpty &&
          repo.activeMeetUp.id == invitationId &&
          repo.activeMeetUp.creatorId.trim().isNotEmpty) {
        creatorId = repo.activeMeetUp.creatorId.trim();
      }
    }
  }
  if (creatorId.isEmpty) return null;
  if (repo.currentUser.id == creatorId) return repo.currentUser;
  for (final member in repo.members) {
    if (member.profile.id == creatorId) return member.profile;
  }
  return null;
}

class _CasamaNotificationRow extends StatelessWidget {
  final Widget? leading;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool isUnread;
  final CasamaPalette pal;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _CasamaNotificationRow({
    this.leading,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.isUnread,
    required this.pal,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CasamaSpacing.minTouchTarget),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading ??
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 19),
              ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: pal.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: pal.coralFab,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: pal.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return row;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: CasamaPressable(onTap: onTap, child: row),
    );
  }
}
