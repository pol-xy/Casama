import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
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

  void _openRoute(BuildContext context, String location) {
    GoRouter.maybeOf(context)?.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final meetup = repo.activeMeetUp;
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
              ? 'You: ${groupLastMsg.content}'
              : '${groupLastMsg.senderName}: ${groupLastMsg.content}')
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
      final code = s.inviteCode.toLowerCase();
      final lastMsg = s.messages.lastOrNull?.content.toLowerCase() ?? '';
      return name.contains(query) ||
          desc.contains(query) ||
          code.contains(query) ||
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
                onMenuTap: () => _openDrawer(context),
                rightActions: [
                  CasamaCircleIconButton(
                    icon: Icons.person_add_alt_1_outlined,
                    semanticLabel: 'Add Housemate',
                    onTap: () => showAddHousemateDialog(context),
                  ),
                  CasamaCircleIconButton(
                    icon: Icons.calendar_month_outlined,
                    semanticLabel: 'Plan a Meet-up',
                    onTap: () => showCreateMeetupSheet(context),
                  ),
                ],
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
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _MiniHeaderPill(
                                          icon: Icons.vpn_key_rounded,
                                          label: 'Join Code',
                                          color: pal.primaryCoral,
                                          onTap: () =>
                                              showJoinWithCodeSheet(context),
                                        ),
                                        const SizedBox(width: 6),
                                        _MiniHeaderPill(
                                          icon: Icons.add_rounded,
                                          label: '+ Space',
                                          color: pal.forestTeal,
                                          onTap: () =>
                                              showCreateChatSpaceSheet(context),
                                        ),
                                      ],
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
                                          'No chat spaces yet. Create one or join with a code!',
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
                                        code: s.inviteCode,
                                        memberCount: s.memberNames.length,
                                        preview: s.messages.lastOrNull != null
                                            ? (s.messages.last.isCurrentUser
                                                  ? 'You: ${s.messages.last.content}'
                                                  : '${s.messages.last.senderName}: ${s.messages.last.content}')
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
                                      i < filteredMembers.length;
                                      i++
                                    ) ...[
                                      if (i > 0)
                                        Divider(height: 1, color: pal.divider),
                                      Builder(
                                        builder: (context) {
                                          final m = filteredMembers[i];
                                          final contactKey = m
                                              .profile
                                              .displayName
                                              .toLowerCase();
                                          final dmMessages = repo
                                              .getDirectMessages(contactKey);
                                          final lastMsg = dmMessages.isNotEmpty
                                              ? dmMessages.last
                                              : null;
                                          final preview = lastMsg != null
                                              ? (lastMsg.isCurrentUser
                                                    ? 'You: ${lastMsg.content}'
                                                    : lastMsg.content)
                                              : (m.note != null
                                                    ? 'Status: ${m.note}'
                                                    : 'Tap to message ${m.profile.displayName}');
                                          final timeStr = DateFormat('h:mm a')
                                              .format(
                                                lastMsg?.createdAt ??
                                                    m.updatedAt,
                                              );

                                          return _HousemateConversationRow(
                                            name: m.profile.displayName,
                                            avatarUrl: m.profile.avatarUrl,
                                            isHome: m.isHome,
                                            preview: preview,
                                            time: timeStr,
                                            onTap: () => _openRoute(
                                              context,
                                              '/direct-chat?contact=$contactKey&name=${Uri.encodeComponent(m.profile.displayName)}&avatar=${Uri.encodeComponent(m.profile.avatarUrl ?? '')}',
                                            ),
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
                                    label: '+ New',
                                    color: pal.primaryCoral,
                                    onTap: () => showCreateMeetupSheet(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),
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
                                      Icons.groups_rounded,
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
                                          meetup.activity,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: pal.textPrimary,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${meetup.location} • ${meetup.goingCount} going',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: pal.textSecondary,
                                                fontSize: 12.5,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  CasamaPressable(
                                    onTap: () =>
                                        _openRoute(context, '/group-chat'),
                                    child: Container(
                                      height: 44,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      decoration: BoxDecoration(
                                        color: pal.track,
                                        borderRadius:
                                            CasamaSpacing.roundedPill,
                                        border: Border.all(color: pal.border),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'View',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: pal.textPrimary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
  final String code;
  final int memberCount;
  final String preview;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _SpaceCard({
    required this.emoji,
    required this.name,
    required this.code,
    required this.memberCount,
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
                    Flexible(
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pal.infoBg,
                        borderRadius: CasamaSpacing.roundedPill,
                      ),
                      child: Text(
                        code,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pal.infoFg,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
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
                        '$memberCount members • $preview',
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
                          '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
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
  final VoidCallback onTap;

  const _HousemateConversationRow({
    required this.name,
    required this.avatarUrl,
    required this.isHome,
    required this.preview,
    required this.time,
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
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
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      fontSize: 13,
                    ),
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
