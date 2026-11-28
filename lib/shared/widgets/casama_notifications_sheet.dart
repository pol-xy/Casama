import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../features/chat/chat_directory_screen.dart';
import '../../features/chat/chat_space_screen.dart';
import '../../features/chat/group_chat_screen.dart';
import '../../features/dashboard/boards_screen.dart';
import '../../features/dashboard/main_navigation_shell.dart';
import 'casama_avatar.dart';
import 'casama_sheet_scaffold.dart';
import 'casama_wave_header.dart';

/// Shared `48x48px` circular Notification Bell header button used across all
/// four top-level shell destinations (`Home`, `Boards`, `Chat`, `Profile`).
class CasamaNotificationBellButton extends ConsumerWidget {
  const CasamaNotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(repositoryProvider).unreadNotificationCount;
    final pal = context.palette;
    final theme = Theme.of(context);
    final badgeLabel = unreadCount > 9 ? '9+' : '$unreadCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CasamaCircleIconButton(
          icon: Icons.notifications_none_rounded,
          semanticLabel: unreadCount > 0
              ? 'Notifications, $unreadCount unread'
              : 'Notifications',
          showDot: false,
          onTap: () => showCasamaNotificationsSheet(context),
        ),
        if (unreadCount > 0)
          Positioned(
            top: -2,
            right: -2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: pal.coralFab,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(color: pal.surface, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeLabel,
                    style: theme.textTheme.labelSmall?.tabular.copyWith(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Visual & routing descriptor for an in-app notification row.
class _NotificationSpec {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String domainLabel;
  final int? boardTabIndex;
  final bool routeToHome;
  final bool routeToGroupChat;
  final bool routeToChatDirectory;

  const _NotificationSpec({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.domainLabel,
    this.boardTabIndex,
    this.routeToHome = false,
    this.routeToGroupChat = false,
    this.routeToChatDirectory = false,
  });
}

_NotificationSpec _resolveNotificationSpec(
  HouseholdNotificationItem item,
  CasamaPalette pal,
) {
  switch (item.type) {
    // Parcels & Deliveries -> Boards Tab 0
    case 'parcel_posted':
      return _NotificationSpec(
        icon: Icons.inventory_2_outlined,
        iconBg: pal.softBlush,
        iconColor: pal.primaryCoral,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );
    case 'parcel_reminder':
      return _NotificationSpec(
        icon: Icons.schedule_rounded,
        iconBg: pal.amberBg,
        iconColor: pal.amberFg,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );
    case 'parcel_arrived':
      return _NotificationSpec(
        icon: Icons.local_shipping_rounded,
        iconBg: pal.amberBg,
        iconColor: pal.amberFg,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );
    case 'parcel_claimed':
    case 'parcel_received':
      return _NotificationSpec(
        icon: Icons.local_shipping_outlined,
        iconBg: pal.softBlush,
        iconColor: pal.primaryCoral,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );
    case 'parcel_settled':
      return _NotificationSpec(
        icon: Icons.check_circle_outline_rounded,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );
    case 'parcel_cancelled':
      return _NotificationSpec(
        icon: Icons.cancel_outlined,
        iconBg: pal.dangerBg,
        iconColor: pal.dangerFg,
        domainLabel: 'Parcels',
        boardTabIndex: 0,
      );

    // Tasks & Roulette -> Boards Tab 1
    case 'task_created':
      return _NotificationSpec(
        icon: Icons.add_task_rounded,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Tasks',
        boardTabIndex: 1,
      );
    case 'task_due_soon':
      return _NotificationSpec(
        icon: Icons.schedule_rounded,
        iconBg: pal.warningBg,
        iconColor: pal.warningFg,
        domainLabel: 'Tasks',
        boardTabIndex: 1,
      );
    case 'task_overdue':
      return _NotificationSpec(
        icon: Icons.priority_high_rounded,
        iconBg: pal.dangerBg,
        iconColor: pal.dangerFg,
        domainLabel: 'Tasks',
        boardTabIndex: 1,
      );
    case 'task_completed':
      return _NotificationSpec(
        icon: Icons.task_alt_rounded,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Tasks',
        boardTabIndex: 1,
      );
    case 'roulette_chosen':
      return _NotificationSpec(
        icon: Icons.casino_outlined,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Roulette',
        boardTabIndex: 1,
      );

    // Lost & Found -> Boards Tab 2
    case 'lost_item_posted':
      return _NotificationSpec(
        icon: Icons.search_rounded,
        iconBg: pal.dangerBg,
        iconColor: pal.dangerFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'lost_item_find_submitted':
      return _NotificationSpec(
        icon: Icons.manage_search_rounded,
        iconBg: pal.infoBg,
        iconColor: pal.infoFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'lost_item_find_accepted':
      return _NotificationSpec(
        icon: Icons.verified_rounded,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'lost_item_find_rejected':
      return _NotificationSpec(
        icon: Icons.highlight_off_rounded,
        iconBg: pal.warningBg,
        iconColor: pal.warningFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'lost_item_self_resolved':
      return _NotificationSpec(
        icon: Icons.check_circle_outline_rounded,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'found_item_posted':
      return _NotificationSpec(
        icon: Icons.volunteer_activism_outlined,
        iconBg: pal.amberBg,
        iconColor: pal.amberFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );
    case 'found_item_claimed':
      return _NotificationSpec(
        icon: Icons.handshake_outlined,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Lost & Found',
        boardTabIndex: 2,
      );

    // Housemates Agenda -> Chat / Group Chat
    case 'housemates_agenda_created':
      return _NotificationSpec(
        icon: Icons.event_available_rounded,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Agenda',
        routeToChatDirectory: true,
      );
    case 'housemates_agenda_reminder':
    case 'meetup_reminder':
      return _NotificationSpec(
        icon: Icons.event_rounded,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Agenda',
        routeToGroupChat: true,
      );
    case 'housemates_agenda_started':
      return _NotificationSpec(
        icon: Icons.celebration_rounded,
        iconBg: pal.successBg,
        iconColor: pal.successFg,
        domainLabel: 'Agenda',
        routeToGroupChat: true,
      );
    case 'housemates_agenda_resolved':
      return _NotificationSpec(
        icon: Icons.event_note_rounded,
        iconBg: pal.infoBg,
        iconColor: pal.infoFg,
        domainLabel: 'Agenda',
        routeToChatDirectory: true,
      );

    // Household Updates -> Home
    case 'housemate_joined':
      return _NotificationSpec(
        icon: Icons.person_add_alt_1_rounded,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Household',
        routeToHome: true,
      );

    default:
      if (item.isParcelNotification) {
        return _NotificationSpec(
          icon: Icons.local_shipping_outlined,
          iconBg: pal.softBlush,
          iconColor: pal.primaryCoral,
          domainLabel: 'Parcels',
          boardTabIndex: 0,
        );
      }
      if (item.isTaskNotification) {
        return _NotificationSpec(
          icon: Icons.task_alt_rounded,
          iconBg: pal.softSage,
          iconColor: pal.forestTeal,
          domainLabel: 'Tasks',
          boardTabIndex: 1,
        );
      }
      if (item.isLostFoundNotification) {
        return _NotificationSpec(
          icon: Icons.search_rounded,
          iconBg: pal.amberBg,
          iconColor: pal.amberFg,
          domainLabel: 'Lost & Found',
          boardTabIndex: 2,
        );
      }
      if (item.isHousematesAgendaNotification) {
        return _NotificationSpec(
          icon: Icons.event_rounded,
          iconBg: pal.softSage,
          iconColor: pal.forestTeal,
          domainLabel: 'Agenda',
          routeToGroupChat: true,
        );
      }
      return _NotificationSpec(
        icon: Icons.notifications_none_rounded,
        iconBg: pal.softSage,
        iconColor: pal.forestTeal,
        domainLabel: 'Household',
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
    subtitle: 'All caught up!',
    scrollable: false,
    subtitleBuilder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final unreadCount =
            ref.watch(repositoryProvider).unreadNotificationCount;
        return Text(
          unreadCount == 0
              ? 'All caught up!'
              : '$unreadCount unread ${unreadCount == 1 ? 'update' : 'updates'}',
        );
      },
    ),
    builder: (sheetCtx) => _NotificationsSheetBody(
      hostContext: context,
      sheetContext: sheetCtx,
    ),
  );
}

class _NotificationsSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final BuildContext sheetContext;

  const _NotificationsSheetBody({
    required this.hostContext,
    required this.sheetContext,
  });

  @override
  ConsumerState<_NotificationsSheetBody> createState() =>
      _NotificationsSheetBodyState();
}

class _NotificationsSheetBodyState
    extends ConsumerState<_NotificationsSheetBody> {
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final items = repo.notifications
        .where((n) => n.isSupportedNotification)
        .toList();
    final unreadCount = items.where((n) => n.isUnread).length;
    final visibleItems = _showUnreadOnly
        ? items.where((n) => n.isUnread).toList()
        : items;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NotificationFilterBar(
          showUnreadOnly: _showUnreadOnly,
          unreadCount: unreadCount,
          hasUnread: unreadCount > 0,
          pal: pal,
          theme: theme,
          onSelectAll: () => setState(() => _showUnreadOnly = false),
          onSelectUnread: () => setState(() => _showUnreadOnly = true),
          onMarkAllRead: unreadCount > 0
              ? () {
                  ref.read(repositoryProvider).markAllNotificationsAsRead();
                  showCasamaToast(
                    widget.hostContext,
                    'All notifications marked as read',
                    icon: Icons.done_all_rounded,
                  );
                }
              : null,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              16,
              12,
              16,
              CasamaSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: CasamaSpacing.lg,
                    ),
                    child: Text(
                      repo.hasActiveHousehold
                          ? "You're all caught up! No new notifications."
                          : 'Join a household to receive household alerts',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: pal.textSecondary,
                      ),
                    ),
                  )
                else if (_showUnreadOnly && visibleItems.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: CasamaSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        Text(
                          "You're all caught up!",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'No unread notifications right now.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  for (final item in visibleItems)
                    _buildNotificationCard(
                      context: context,
                      pal: pal,
                      theme: theme,
                      repo: repo,
                      item: item,
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required BuildContext context,
    required CasamaPalette pal,
    required ThemeData theme,
    required CasamaRepository repo,
    required HouseholdNotificationItem item,
  }) {
    final spec = _resolveNotificationSpec(item, pal);
    final actorProfile = _resolveNotificationActorProfile(repo, item);
    final hasActorInfo =
        (item.actorId?.trim().isNotEmpty ?? false) ||
        (item.actorFallbackName?.trim().isNotEmpty ?? false);
    final fallbackName = hasActorInfo
        ? repo.resolveHousemateName(
            item.actorId,
            fallback: item.actorFallbackName ?? '',
          )
        : '';
    final Widget? leading = actorProfile != null
        ? CasamaAvatar(
            radius: 21,
            avatarUrl: actorProfile.avatarUrl,
            name: actorProfile.preferredName,
          )
        : (fallbackName.isNotEmpty
              ? CasamaAvatar(radius: 21, name: fallbackName)
              : null);

    final _PointsBadgeData? pointsBadge = _resolvePointsBadge(
      repo,
      item,
      pal,
    );

    return _CasamaNotificationCard(
      leading: leading,
      icon: spec.icon,
      iconBg: spec.iconBg,
      iconColor: spec.iconColor,
      domainLabel: spec.domainLabel,
      title: item.displayTitle,
      subtitle: item.displaySubtitle,
      pointsBadge: pointsBadge,
      time: DateFormat('h:mm a').format(item.createdAt),
      isUnread: item.isUnread,
      pal: pal,
      theme: theme,
      onTap: () => _handleNotificationTap(
        widget.hostContext,
        widget.sheetContext,
        ref,
        item,
        spec,
      ),
    );
  }
}

class _NotificationFilterBar extends StatelessWidget {
  final bool showUnreadOnly;
  final int unreadCount;
  final bool hasUnread;
  final CasamaPalette pal;
  final ThemeData theme;
  final VoidCallback onSelectAll;
  final VoidCallback onSelectUnread;
  final VoidCallback? onMarkAllRead;

  const _NotificationFilterBar({
    required this.showUnreadOnly,
    required this.unreadCount,
    required this.hasUnread,
    required this.pal,
    required this.theme,
    required this.onSelectAll,
    required this.onSelectUnread,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final markAllInk = hasUnread
        ? pal.headerDeep
        : pal.textSecondary.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: pal.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          _FilterPill(
            key: const ValueKey('casama_notif_filter_all'),
            label: 'All',
            selected: !showUnreadOnly,
            pal: pal,
            theme: theme,
            onTap: onSelectAll,
          ),
          const SizedBox(width: 8),
          _FilterPill(
            key: const ValueKey('casama_notif_filter_unread'),
            label: 'Unread ($unreadCount)',
            selected: showUnreadOnly,
            pal: pal,
            theme: theme,
            onTap: onSelectUnread,
          ),
          const Spacer(),
          Semantics(
            key: const ValueKey('casama_mark_all_read_button'),
            button: true,
            enabled: hasUnread,
            label: 'Mark all read',
            child: CasamaPressable(
              onTap: onMarkAllRead,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CasamaSpacing.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: markAllInk,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mark all read',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: markAllInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final CasamaPalette pal;
  final ThemeData theme;
  final VoidCallback onTap;

  const _FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.pal,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: CasamaSpacing.minTouchTarget,
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? pal.headerDeep : pal.track,
                borderRadius: CasamaSpacing.roundedPill,
                border: selected
                    ? null
                    : Border.all(color: pal.border, width: 1),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.tabular.copyWith(
                  color: selected ? Colors.white : pal.textSecondary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PointsBadgeData {
  final String label;
  final Color bg;
  final Color fg;

  const _PointsBadgeData({
    required this.label,
    required this.bg,
    required this.fg,
  });
}

_PointsBadgeData? _resolvePointsBadge(
  CasamaRepository repo,
  HouseholdNotificationItem item,
  CasamaPalette pal,
) {
  if (item.isRouletteNotification) {
    if (_isRouletteSelfRequest(repo, item)) return null;
    final bonus = item.rouletteBonusPoints ?? 4;
    if (bonus <= 0) return null;
    return _PointsBadgeData(
      label: '+$bonus bonus pts',
      bg: pal.amberBg,
      fg: pal.amberFg,
    );
  }
  if (item.type == 'task_completed' && _isTaskSelfRequest(repo, item)) {
    return null;
  }
  final pts = item.earnedPoints;
  if (pts != null && pts > 0) {
    return _PointsBadgeData(
      label: '+$pts pts',
      bg: pal.successBg,
      fg: pal.successFg,
    );
  }
  return null;
}

void _handleNotificationTap(
  BuildContext hostContext,
  BuildContext sheetCtx,
  WidgetRef ref,
  HouseholdNotificationItem item,
  _NotificationSpec spec,
) {
  final repo = ref.read(repositoryProvider);
  repo.markNotificationAsRead(item.id);
  Navigator.of(sheetCtx).pop();
  if (!hostContext.mounted) return;

  final shell = CasamaShellScope.maybeOf(hostContext);
  final router = GoRouter.maybeOf(hostContext);

  if (spec.routeToHome) {
    if (shell != null) {
      shell.selectTab(0);
      return;
    }
    if (router != null) {
      router.go('/home');
      return;
    }
    return;
  }

  if (spec.boardTabIndex != null) {
    final tabIdx = spec.boardTabIndex!;
    if (shell != null) {
      shell.openBoardTab(tabIdx);
      return;
    }
    if (router != null) {
      final slug = switch (tabIdx) {
        0 => 'parcels',
        1 => 'tasks',
        _ => 'items',
      };
      router.go('/boards?tab=$slug');
      return;
    }
    Navigator.of(hostContext).push(
      MaterialPageRoute<void>(
        builder: (_) => BoardsScreen(initialTab: tabIdx),
      ),
    );
    return;
  }

  if (spec.routeToGroupChat || spec.routeToChatDirectory) {
    final convId = (item.payload['conversation_id'] as String?)?.trim() ?? '';
    final isSpace =
        convId.isNotEmpty && repo.chatSpaces.any((s) => s.id == convId);
    if (isSpace) {
      if (router != null) {
        router.push('/space-chat?id=$convId');
      } else {
        Navigator.of(hostContext).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatSpaceScreen(spaceId: convId),
          ),
        );
      }
      return;
    }

    if (spec.routeToChatDirectory) {
      if (shell != null) {
        shell.selectTab(3);
        return;
      }
      if (router != null) {
        router.go('/chat');
        return;
      }
      Navigator.of(hostContext).push(
        MaterialPageRoute<void>(builder: (_) => const ChatDirectoryScreen()),
      );
      return;
    }

    if (router != null) {
      router.push('/group-chat');
      return;
    }
    Navigator.of(hostContext).push(
      MaterialPageRoute<void>(builder: (_) => const GroupChatScreen()),
    );
  }
}

UserProfile? _resolveProfileById(CasamaRepository repo, String userId) {
  final trimmed = userId.trim();
  if (trimmed.isEmpty) return null;
  if (repo.currentUser.id == trimmed) return repo.currentUser;
  for (final member in repo.members) {
    if (member.profile.id == trimmed) return member.profile;
  }
  return null;
}

UserProfile? _resolveNotificationActorProfile(
  CasamaRepository repo,
  HouseholdNotificationItem item,
) {
  final directActor = item.actorId;
  if (directActor != null && directActor.isNotEmpty) {
    final profile = _resolveProfileById(repo, directActor);
    if (profile != null) return profile;
  }

  if (item.isRouletteNotification) {
    final rouletteId = (item.payload['roulette_id'] as String?)?.trim() ?? '';
    final taskId = (item.payload['task_id'] as String?)?.trim() ?? '';
    for (final r in repo.rouletteRecords) {
      if ((rouletteId.isNotEmpty && r.id == rouletteId) ||
          (taskId.isNotEmpty && r.taskId == taskId)) {
        final profile = _resolveProfileById(repo, r.spunByUserId);
        if (profile != null) return profile;
        break;
      }
    }
  }

  if (item.isHousematesAgendaNotification) {
    final invitationId =
        (item.payload['invitation_id'] as String?)?.trim() ?? '';
    if (invitationId.isNotEmpty) {
      for (final inv in repo.housematesAgendaInvitations) {
        if (inv.id == invitationId && inv.creatorId.trim().isNotEmpty) {
          final profile = _resolveProfileById(repo, inv.creatorId);
          if (profile != null) return profile;
          break;
        }
      }
      if (repo.activeHousematesAgenda.id == invitationId &&
          repo.activeHousematesAgenda.creatorId.trim().isNotEmpty) {
        return _resolveProfileById(repo, repo.activeHousematesAgenda.creatorId);
      }
    }
  }

  return null;
}

bool _isRouletteSelfRequest(
  CasamaRepository repo,
  HouseholdNotificationItem item,
) {
  final taskId = (item.payload['task_id'] as String?)?.trim() ?? '';
  if (taskId.isEmpty) return false;
  final selectedId =
      (item.payload['selected_user_id'] as String?)?.trim() ??
      repo.currentUser.id;
  for (final t in repo.tasks) {
    if (t.id == taskId) {
      return t.createdBy.isNotEmpty && t.createdBy == selectedId;
    }
  }
  return false;
}

bool _isTaskSelfRequest(
  CasamaRepository repo,
  HouseholdNotificationItem item,
) {
  if (item.payload['is_self_created'] == true) return true;
  final rawPts = (item.payload['points'] as num?)?.toInt();
  if (rawPts != null && rawPts <= 0) return true;
  final taskId =
      ((item.payload['task_id'] ?? item.payload['entity_id']) as String?)
          ?.trim() ??
      '';
  if (taskId.isEmpty) return false;
  final actorId = item.actorId ?? '';
  for (final t in repo.tasks) {
    if (t.id == taskId) {
      final completerId = actorId.isNotEmpty
          ? actorId
          : (t.completedById ?? repo.currentUser.id);
      return t.createdBy.isNotEmpty && t.createdBy == completerId;
    }
  }
  return false;
}

class _CasamaNotificationCard extends StatelessWidget {
  final Widget? leading;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String domainLabel;
  final String title;
  final String subtitle;
  final _PointsBadgeData? pointsBadge;
  final String time;
  final bool isUnread;
  final CasamaPalette pal;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _CasamaNotificationCard({
    this.leading,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.domainLabel,
    required this.title,
    required this.subtitle,
    this.pointsBadge,
    required this.time,
    required this.isUnread,
    required this.pal,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? pal.surface : pal.scaffoldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? pal.headerDeep.withValues(alpha: 0.24)
              : pal.border,
          width: isUnread ? 1.2 : 1.0,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: context.isDark ? 0.20 : 0.04,
                  ),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CasamaSpacing.minTouchTarget,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isUnread) Container(width: 3, color: pal.coralFab),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isUnread ? 11 : 14,
                      14,
                      14,
                      14,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leading ??
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBg,
                                shape: BoxShape.circle,
                              ),
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
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: isUnread
                                                ? pal.textPrimary
                                                : pal.textSecondary,
                                            fontWeight: isUnread
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                    ),
                                  ),
                                  if (isUnread) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 7.5,
                                      height: 7.5,
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
                                  color: isUnread
                                      ? pal.textSecondary
                                      : pal.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      borderRadius: CasamaSpacing.roundedPill,
                                    ),
                                    child: Text(
                                      domainLabel,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: iconColor,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  if (pointsBadge != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pointsBadge!.bg,
                                        borderRadius: CasamaSpacing.roundedPill,
                                        border: Border.all(
                                          color: pointsBadge!.fg.withValues(
                                            alpha: 0.32,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        pointsBadge!.label,
                                        style: theme.textTheme.labelSmall?.tabular
                                            .copyWith(
                                              color: pointsBadge!.fg,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                ],
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) return card;

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: CasamaPressable(onTap: onTap, child: card),
    );
  }
}
