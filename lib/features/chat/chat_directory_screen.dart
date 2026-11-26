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
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../dashboard/main_navigation_shell.dart';
import '../dashboard/widgets/casama_household_drawer.dart';
import '../household/add_housemate_dialog.dart';
import 'widgets/create_chat_space_sheet.dart';
import 'widgets/create_meetup_sheet.dart';

class ChatDirectoryScreen extends ConsumerStatefulWidget {
  const ChatDirectoryScreen({super.key});

  @override
  ConsumerState<ChatDirectoryScreen> createState() =>
      _ChatDirectoryScreenState();
}

class _ChatDirectoryScreenState extends ConsumerState<ChatDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _meetupFilter = 'all';

  static const List<CasamaFilterOption<String>> _meetupFilterOptions = [
    CasamaFilterOption(value: 'all', label: 'All Upcoming'),
    CasamaFilterOption(value: 'mine', label: 'My Invitations'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDrawer(BuildContext context) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openDrawer();
      return;
    }
    showCasamaHouseholdDrawer(context);
  }

  String _messagePreviewText(ChatMessage msg) {
    final trimmed = msg.content.trim();
    if (msg.hasAttachment) {
      return trimmed.isEmpty ? '📷 Photo' : '📷 $trimmed';
    }
    return msg.content;
  }

  ChatMessage? _latestDirectMessage(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    var latest = messages.first;
    for (var i = 1; i < messages.length; i++) {
      if (!messages[i].createdAt.isBefore(latest.createdAt)) {
        latest = messages[i];
      }
    }
    return latest;
  }

  void _openRoute(BuildContext context, String location) {
    GoRouter.maybeOf(context)?.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final upcomingMeetups = repo.meetUpInvitations
        .where((m) => m.hasValidData && m.isActive)
        .where(
          (m) => _meetupFilter == 'all' || m.creatorId == repo.currentUser.id,
        )
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final members = repo.members;
    final activeCount = members.where((m) => m.isHome).length;
    final otherMembers = members
        .where((m) => m.profile.id != repo.currentUser.id)
        .toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    // Group chat details
    final groupLastMsg = repo.groupMessages.isNotEmpty
        ? repo.groupMessages.last
        : null;
    final groupPreview = groupLastMsg != null
        ? (groupLastMsg.isCurrentUser
              ? 'You: ${_messagePreviewText(groupLastMsg)}'
              : '${groupLastMsg.senderName}: ${_messagePreviewText(groupLastMsg)}')
        : 'No messages yet in household chat';
    final groupTime = groupLastMsg != null
        ? DateFormat('h:mm a').format(groupLastMsg.createdAt)
        : '8:24 PM';

    // Search filtering
    final query = _searchQuery.trim().toLowerCase();
    final bool matchesGroup =
        query.isEmpty ||
        repo.currentHousehold.name.toLowerCase().contains(query) ||
        groupPreview.toLowerCase().contains(query);

    final filteredSpaces = repo.chatSpaces.where((s) {
      if (query.isEmpty) return true;
      final name = s.name.toLowerCase();
      final desc = s.description.toLowerCase();
      final lastMsg = s.messages.lastOrNull?.content.toLowerCase() ?? '';
      return name.contains(query) ||
          desc.contains(query) ||
          lastMsg.contains(query);
    }).toList();

    final filteredMembers = otherMembers.where((m) {
      if (query.isEmpty) return true;
      final name = m.profile.displayName.toLowerCase();
      final handle = m.profile.handle.toLowerCase();
      final note = (m.note ?? '').toLowerCase();
      final lastMsg = repo
          .getDirectMessages(m.profile.displayName.toLowerCase())
          .lastOrNull;
      final msgContent = (lastMsg?.content ?? '').toLowerCase();
      return name.contains(query) ||
          handle.contains(query) ||
          note.contains(query) ||
          msgContent.contains(query);
    }).toList();

    final sortedMembers = List<MemberPresence>.from(filteredMembers)
      ..sort((a, b) {
        final aLast = _latestDirectMessage(
          repo.getDirectMessages(a.profile.displayName.toLowerCase()),
        );
        final bLast = _latestDirectMessage(
          repo.getDirectMessages(b.profile.displayName.toLowerCase()),
        );
        if (aLast != null && bLast != null) {
          return bLast.createdAt.compareTo(aLast.createdAt);
        }
        if (aLast != null) return -1;
        if (bLast != null) return 1;
        return a.profile.displayName.toLowerCase().compareTo(
          b.profile.displayName.toLowerCase(),
        );
      });

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset + 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Stepped Forest Teal Wave Header
              CasamaWaveHeader(
                title: 'Chat',
                subtitle: '${repo.currentHousehold.name} • ${members.length} members',
                showNotificationBell: true,
                onMenuTap: () => _openDrawer(context),
              ),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Overlapping Split Hero (Transparent PNG Mascot + Connect Card)
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: CasamaSplitHero(
                          mascotPose: CasPose.chatting,
                          kicker: '${repo.currentHousehold.name} Connect',
                          kickerDotColor: activeCount > 0
                              ? pal.successFg
                              : pal.neutralFg,
                          headline:
                              '${repo.totalUnreadChatCount} Unread • ${repo.chatSpaces.length} ${repo.chatSpaces.length == 1 ? 'Space' : 'Spaces'}',
                          subtitle:
                              '$activeCount ${activeCount == 1 ? 'housemate' : 'housemates'} Home right now',
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CasamaSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3. Search Bar Pill
                            TextField(
                              controller: _searchController,
                              style: TextStyle(
                                color: pal.textPrimary,
                                fontSize: 14,
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText:
                                    'Search conversations or housemates...',
                                hintStyle: TextStyle(
                                  fontSize: 13.5,
                                  color: pal.textMuted,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: pal.textSecondary,
                                  size: 20,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                          color: pal.textSecondary,
                                        ),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: pal.card,
                                border: OutlineInputBorder(
                                  borderRadius: CasamaSpacing.roundedPill,
                                  borderSide: BorderSide(color: pal.border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: CasamaSpacing.roundedPill,
                                  borderSide: BorderSide(color: pal.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: CasamaSpacing.roundedPill,
                                  borderSide: BorderSide(
                                    color: pal.forestTeal,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.lg),

                            // 4. Pinned Household Group Chat Hero Card
                            if (matchesGroup) ...[
                              Text(
                                'Household Group Chat',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: pal.textSecondary,
                                ),
                              ),
                              const SizedBox(height: CasamaSpacing.xs),
                              _PinnedHouseholdCard(
                                title: repo.currentHousehold.name,
                                preview: groupPreview,
                                time: groupTime,
                                unreadCount: repo.groupChatUnreadCount,
                                onTap: () {
                                  ref
                                      .read(repositoryProvider)
                                      .markGroupChatAsRead();
                                  _openRoute(context, '/group-chat');
                                },
                              ),
                              const SizedBox(height: CasamaSpacing.lg),
                            ],

                            // 5. Custom Chat Spaces Section
                            if (filteredSpaces.isNotEmpty || query.isEmpty) ...[
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Custom Chat Spaces',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.6,
                                                color: pal.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: pal.track,
                                            borderRadius:
                                                CasamaSpacing.roundedPill,
                                          ),
                                          child: Text(
                                            '${repo.chatSpaces.length}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: pal.textPrimary,
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    _MiniHeaderPill(
                                      icon: Icons.add_rounded,
                                      label: 'Space',
                                      color: pal.forestTeal,
                                      onTap: () =>
                                          showCreateChatSpaceSheet(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: CasamaSpacing.xs),
                              if (filteredSpaces.isEmpty)
                                CasamaCard(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 20,
                                        color: pal.textMuted,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'No chat spaces yet. Create one for your household!',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: pal.textSecondary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: [
                                    for (final s in filteredSpaces) ...[
                                      _SpaceCard(
                                        emoji: s.iconEmoji,
                                        name: s.name,
                                        preview:
                                            s.messages.lastOrNull != null &&
                                                !(s.messages.last.inviteCode
                                                        ?.startsWith('SPC-') ??
                                                    false)
                                            ? (s.messages.last.isCurrentUser
                                                  ? 'You: ${_messagePreviewText(s.messages.last)}'
                                                  : '${s.messages.last.senderName}: ${_messagePreviewText(s.messages.last)}')
                                            : s.description,
                                        time: DateFormat('h:mm a').format(
                                          s.messages.lastOrNull?.createdAt ??
                                              s.createdAt,
                                        ),
                                        unreadCount: s.unreadCount,
                                        onTap: () {
                                          ref
                                              .read(repositoryProvider)
                                              .markSpaceChatAsRead(s.id);
                                          _openRoute(
                                            context,
                                            '/space-chat?id=${s.id}',
                                          );
                                        },
                                      ),
                                      const SizedBox(height: CasamaSpacing.xs),
                                    ],
                                  ],
                                ),
                              const SizedBox(height: CasamaSpacing.md),
                            ],

                            // 6. Individual Conversations (Housemates)
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Individual Conversations',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  _MiniHeaderPill(
                                    icon: Icons.person_add_alt_1_rounded,
                                    label: 'Add Housemate',
                                    color: pal.primaryCoral,
                                    onTap: () =>
                                        showAddHousemateDialog(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),

                            if (otherMembers.isEmpty)
                              _buildEmptyHousematesState(context, pal, theme)
                            else if (filteredMembers.isEmpty &&
                                _searchQuery.isNotEmpty)
                              _buildNoSearchResultsState(pal, theme)
                            else
                              CasamaCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < sortedMembers.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        Divider(height: 1, color: pal.divider),
                                      Builder(
                                        builder: (context) {
                                          final m = sortedMembers[i];
                                          final contactKey = m
                                              .profile
                                              .displayName
                                              .toLowerCase();
                                          final dmMessages = repo
                                              .getDirectMessages(contactKey);
                                          final lastMsg = _latestDirectMessage(
                                            dmMessages,
                                          );
                                          final unreadCount = repo
                                              .getDirectUnreadCount(contactKey);
                                          final preview = lastMsg != null
                                              ? (lastMsg.isCurrentUser
                                                    ? 'You: ${_messagePreviewText(lastMsg)}'
                                                    : _messagePreviewText(lastMsg))
                                              : (m.note != null
                                                    ? 'Status: ${m.note}'
                                                    : 'Tap to message ${m.profile.displayName}');
                                          final timeStr = lastMsg != null
                                              ? DateFormat('h:mm a').format(
                                                  lastMsg.createdAt,
                                                )
                                              : '';

                                          return _HousemateConversationRow(
                                            name: m.profile.displayName,
                                            avatarUrl: m.profile.avatarUrl,
                                            isHome: m.isHome,
                                            preview: preview,
                                            time: timeStr,
                                            unreadCount: unreadCount,
                                            onTap: () {
                                              ref
                                                  .read(repositoryProvider)
                                                  .markDirectChatAsRead(
                                                    contactKey,
                                                  );
                                              _openRoute(
                                                context,
                                                '/direct-chat?contact=$contactKey&name=${Uri.encodeComponent(m.profile.displayName)}&avatar=${Uri.encodeComponent(m.profile.avatarUrl ?? '')}',
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                            const SizedBox(height: CasamaSpacing.lg),

                            // 7. Meet-up Invitations Card
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Meet-up Invitations',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  _MiniHeaderPill(
                                    icon: Icons.add_rounded,
                                    label: 'New',
                                    color: pal.primaryCoral,
                                    onTap: () => showCreateMeetupSheet(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),
                            CasamaPillFilterRail<String>(
                              options: _meetupFilterOptions,
                              selectedValue: _meetupFilter,
                              onSelected: (val) =>
                                  setState(() => _meetupFilter = val),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),
                            if (upcomingMeetups.isEmpty)
                              CasamaCard(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: pal.softSage,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.event_note_rounded,
                                        color: pal.forestTeal,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _meetupFilter == 'mine'
                                                ? "You haven't created any upcoming meet-ups yet."
                                                : 'No upcoming meet-ups',
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: pal.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _meetupFilter == 'mine'
                                                ? 'Tap + New to plan one for the household.'
                                                : 'Tap + New to invite your housemates.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: pal.textSecondary,
                                                  fontSize: 12.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < upcomingMeetups.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const SizedBox(height: CasamaSpacing.xs),
                                    Builder(
                                      builder: (context) {
                                        final m = upcomingMeetups[i];
                                        final creator = _resolveMeetupCreator(
                                          repo,
                                          m.creatorId,
                                        );
                                        return CasamaCard(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            children: [
                                              CasamaAvatar(
                                                avatarUrl: creator?.avatarUrl,
                                                radius: 22,
                                                name:
                                                    creator?.displayName ??
                                                    'Housemate',
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      m.activity,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color:
                                                                pal.textPrimary,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      _formatMeetupRelativeTime(
                                                        m.scheduledTime,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.tabular
                                                          .copyWith(
                                                            color:
                                                                pal.textPrimary,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            fontSize: 12.5,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${m.location} • ${m.goingCount} going',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: pal
                                                                .textSecondary,
                                                            fontSize: 12,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              CasamaPressable(
                                                onTap: () =>
                                                    _showMeetupDetailsSheet(
                                                      context,
                                                      invitationId: m.id,
                                                    ),
                                                child: Container(
                                                  height: 48,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: pal.track,
                                                    borderRadius: CasamaSpacing
                                                        .roundedPill,
                                                    border: Border.all(
                                                      color: pal.border,
                                                    ),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'View',
                                                    style: theme
                                                        .textTheme
                                                        .labelMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              pal.textPrimary,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                          ],
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
    );
  }

  Widget _buildEmptyHousematesState(
    BuildContext context,
    CasamaPalette pal,
    ThemeData theme,
  ) {
    return CasamaCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          const CasMascotView(
            pose: CasPose.together,
            width: 84,
            height: 84,
          ),
          const SizedBox(height: 10),
          Text(
            'Your household is better together! 🏡',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Invite your housemates to start communicating and coordinating.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          CasamaButton(
            label: 'Invite Housemate',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () => showAddHousemateDialog(context),
            height: 48,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResultsState(CasamaPalette pal, ThemeData theme) {
    return CasamaCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: pal.textMuted),
          const SizedBox(height: 8),
          Text(
            'No conversations found matching "$_searchQuery"',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedHouseholdCard extends StatelessWidget {
  final String title;
  final String preview;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _PinnedHouseholdCard({
    required this.title,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaPressable.card(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: pal.headerDeep,
          borderRadius: CasamaSpacing.roundedCard,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: CasamaSpacing.roundedMd,
              ),
              child: const Icon(
                Icons.cottage_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 22,
                            minHeight: 22,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: pal.coralFab,
                            borderRadius: CasamaSpacing.roundedPill,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String preview;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _SpaceCard({
    required this.emoji,
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: pal.softSage,
              borderRadius: CasamaSpacing.roundedMd,
              border: Border.all(color: pal.border),
            ),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
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
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
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
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: unreadCount > 0
                              ? pal.textPrimary
                              : pal.textSecondary,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: pal.coralFab,
                          borderRadius: CasamaSpacing.roundedPill,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: theme.textTheme.labelSmall?.tabular.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HousemateConversationRow extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isHome;
  final String preview;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _HousemateConversationRow({
    required this.name,
    required this.avatarUrl,
    required this.isHome,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CasamaAvatar(avatarUrl: avatarUrl, radius: 22, name: name),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isHome ? pal.successFg : pal.neutralFg,
                      shape: BoxShape.circle,
                      border: Border.all(color: pal.card, width: 2),
                    ),
                  ),
                ),
              ],
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
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                      if (time.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: theme.textTheme.labelSmall?.tabular.copyWith(
                            color: unreadCount > 0
                                ? pal.textPrimary
                                : pal.textMuted,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: unreadCount > 0
                                ? pal.textPrimary
                                : pal.textSecondary,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          key: Key('dm_unread_badge_${name.toLowerCase()}'),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: pal.coralFab,
                            borderRadius: CasamaSpacing.roundedPill,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: theme.textTheme.labelSmall?.tabular.copyWith(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MiniHeaderPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: pal.surface,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(color: pal.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

UserProfile? _resolveMeetupCreator(CasamaRepository repo, String creatorId) {
  final cleanId = creatorId.trim();
  if (cleanId.isEmpty) return null;
  if (repo.currentUser.id == cleanId) return repo.currentUser;
  for (final member in repo.members) {
    if (member.profile.id == cleanId) return member.profile;
  }
  return null;
}

String _formatMeetupRelativeTime(DateTime scheduledTime) {
  final local = scheduledTime.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final targetDay = DateTime(local.year, local.month, local.day);
  final timePart = DateFormat('h:mm a').format(local);
  if (targetDay == today) return 'Today, $timePart';
  if (targetDay == tomorrow) return 'Tomorrow, $timePart';
  return DateFormat('EEE, MMM d • h:mm a').format(local);
}

void _showMeetupDetailsSheet(
  BuildContext hostContext, {
  String? invitationId,
}) {
  showCasamaSheet<void>(
    hostContext,
    icon: Icons.event_available_rounded,
    title: 'Meet-up Invitation',
    subtitle: 'Coordinate plans & RSVP with your housemates',
    builder: (sheetCtx) => _MeetupDetailsSheetBody(
      hostContext: hostContext,
      sheetContext: sheetCtx,
      invitationId: invitationId,
    ),
  );
}

class _MeetupDetailsSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final BuildContext sheetContext;
  final String? invitationId;

  const _MeetupDetailsSheetBody({
    required this.hostContext,
    required this.sheetContext,
    this.invitationId,
  });

  @override
  ConsumerState<_MeetupDetailsSheetBody> createState() =>
      _MeetupDetailsSheetBodyState();
}

class _MeetupDetailsSheetBodyState
    extends ConsumerState<_MeetupDetailsSheetBody> {
  bool _isDeleting = false;

  Future<void> _confirmAndDelete(MeetUpInvitation meetup) async {
    if (_isDeleting) return;
    final pal = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Meet-up?'),
        content: Text(
          'This will permanently remove "${meetup.activity}" and all housemate responses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('meetup_confirm_delete_button'),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: TextButton.styleFrom(foregroundColor: pal.dangerFg),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(repositoryProvider).deleteMeetUpInvitation(meetup.id);
      if (widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Meet-up deleted',
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showCasamaToast(
        context,
        'Could not delete meet-up. Please try again.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final pal = context.palette;
    final theme = Theme.of(context);

    MeetUpInvitation meetup;
    if (widget.invitationId != null) {
      meetup = repo.meetUpInvitations.firstWhere(
        (m) => m.id == widget.invitationId,
        orElse: () => repo.activeMeetUp.id == widget.invitationId
            ? repo.activeMeetUp
            : MeetUpInvitation(
                id: '',
                activity: '',
                location: '',
                scheduledTime: DateTime.now(),
              ),
      );
    } else {
      meetup = repo.activeMeetUp;
    }

    if (!meetup.hasValidData) {
      return Text(
        'No active meet-up invitation.',
        style: theme.textTheme.bodyMedium?.copyWith(color: pal.textSecondary),
      );
    }

    final timeLabel = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(meetup.scheduledTime);
    final isCompleted = !meetup.isActive;
    final isCreator =
        meetup.creatorId.isNotEmpty && meetup.creatorId == repo.currentUser.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                meetup.activity,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ),
            if (isCompleted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: pal.neutralBg,
                  borderRadius: CasamaSpacing.roundedPill,
                  border: Border.all(color: pal.border),
                ),
                child: Text(
                  'Completed',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pal.neutralFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$timeLabel • ${meetup.location}',
          style: theme.textTheme.bodyMedium?.copyWith(color: pal.textSecondary),
        ),
        const SizedBox(height: CasamaSpacing.md),
        Text(
          isCompleted ? 'FINAL RESPONSES' : 'YOUR RESPONSE',
          style: theme.textTheme.labelSmall?.copyWith(
            color: pal.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _MeetupRsvpChip(
                label: 'Going (${meetup.goingCount})',
                selected: meetup.currentUserResponse == 'going',
                activeBg: pal.successFg,
                onTap: isCompleted || _isDeleting
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondMeetUp('going', invitationId: meetup.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MeetupRsvpChip(
                label: 'Maybe (${meetup.maybeCount})',
                selected: meetup.currentUserResponse == 'maybe',
                activeBg: pal.amberFg,
                onTap: isCompleted || _isDeleting
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondMeetUp('maybe', invitationId: meetup.id),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MeetupRsvpChip(
                label: "Can't (${meetup.cantMakeCount})",
                selected: meetup.currentUserResponse == 'cant_make_it',
                activeBg: pal.neutralFg,
                onTap: isCompleted || _isDeleting
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondMeetUp(
                            'cant_make_it',
                            invitationId: meetup.id,
                          ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),
        _MeetupResponderRow(
          label: 'Going',
          accentColor: pal.successFg,
          responders: meetup.goingResponders,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _MeetupResponderRow(
          label: 'Maybe',
          accentColor: pal.amberFg,
          responders: meetup.maybeResponders,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _MeetupResponderRow(
          label: "Can't",
          accentColor: pal.neutralFg,
          responders: meetup.cantMakeResponders,
        ),
        if (isCreator) ...[
          const SizedBox(height: CasamaSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Delete Meet-up',
              child: CasamaPressable(
                key: const Key('meetup_delete_button'),
                onTap: _isDeleting ? null : () => _confirmAndDelete(meetup),
                enableHaptic: !_isDeleting,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: CasamaSpacing.minTouchTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: pal.dangerBg,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(
                      color: pal.dangerFg.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isDeleting)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: pal.dangerFg,
                          ),
                        )
                      else
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: pal.dangerFg,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        'Delete',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: pal.dangerFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MeetupResponderRow extends StatelessWidget {
  final String label;
  final Color accentColor;
  final List<MeetUpResponder> responders;

  const _MeetupResponderRow({
    required this.label,
    required this.accentColor,
    required this.responders,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    const maxVisible = 6;
    const avatarSize = 28.0;
    const step = 18.0;
    final visible = responders.take(maxVisible).toList();
    final overflow = responders.length - visible.length;
    final totalItems = visible.length + (overflow > 0 ? 1 : 0);
    final stackWidth =
        totalItems == 0 ? 0.0 : avatarSize + (totalItems - 1) * step;
    final namesSummary = responders.map((r) => r.displayName).join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 88,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: pal.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: responders.isEmpty
                ? Text(
                    'None yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textMuted,
                      fontSize: 12,
                    ),
                  )
                : Tooltip(
                    message: namesSummary,
                    child: Semantics(
                      button: true,
                      label: '$label responders: $namesSummary',
                      child: CasamaPressable(
                        key: Key('meetup_responders_$label'),
                        onTap: () => _showResponderListSheet(
                          context,
                          label,
                          accentColor,
                          responders,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 36),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: stackWidth,
                                height: avatarSize,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (var i = 0; i < visible.length; i++)
                                      Positioned(
                                        left: i * step,
                                        top: 0,
                                        child: Container(
                                          width: avatarSize,
                                          height: avatarSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: pal.surface,
                                              width: 2,
                                            ),
                                          ),
                                          child: CasamaAvatar(
                                            avatarUrl: visible[i].avatarUrl,
                                            radius: 12,
                                            name: visible[i].displayName,
                                          ),
                                        ),
                                      ),
                                    if (overflow > 0)
                                      Positioned(
                                        left: visible.length * step,
                                        top: 0,
                                        child: Container(
                                          width: avatarSize,
                                          height: avatarSize,
                                          decoration: BoxDecoration(
                                            color: pal.track,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: pal.surface,
                                              width: 2,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '+$overflow',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: pal.textPrimary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${responders.length}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: pal.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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

void _showResponderListSheet(
  BuildContext context,
  String label,
  Color accentColor,
  List<MeetUpResponder> responders,
) {
  showCasamaSheet<void>(
    context,
    icon: Icons.groups_rounded,
    title: '$label (${responders.length})',
    subtitle: 'Housemates who responded $label',
    builder: (ctx) {
      final pal = ctx.palette;
      final theme = Theme.of(ctx);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < responders.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                CasamaAvatar(
                  avatarUrl: responders[i].avatarUrl,
                  radius: 16,
                  name: responders[i].displayName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    responders[i].displayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}

class _MeetupRsvpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeBg;
  final VoidCallback? onTap;

  const _MeetupRsvpChip({
    required this.label,
    required this.selected,
    required this.activeBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);
    final disabled = onTap == null;
    final effectiveBg = selected
        ? (disabled ? activeBg.withValues(alpha: 0.45) : activeBg)
        : (disabled ? pal.surface.withValues(alpha: 0.6) : pal.surface);
    final effectiveFg = selected
        ? Colors.white.withValues(alpha: disabled ? 0.75 : 1.0)
        : pal.textPrimary.withValues(alpha: disabled ? 0.45 : 1.0);

    return Semantics(
      button: true,
      enabled: !disabled,
      selected: selected,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: !disabled,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          curve: CasamaMotion.easeOut,
          height: CasamaSpacing.minTouchTarget,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: CasamaSpacing.roundedPill,
            border: Border.all(
              color: selected
                  ? effectiveBg
                  : pal.border.withValues(alpha: disabled ? 0.5 : 1.0),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effectiveFg,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
