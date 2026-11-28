import 'package:flutter/foundation.dart';
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
import '../../shared/widgets/casama_no_household_card.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../dashboard/main_navigation_shell.dart';
import '../dashboard/widgets/casama_household_drawer.dart';
import '../household/add_housemate_dialog.dart';
import 'widgets/chat_thread_components.dart';
import 'widgets/create_chat_space_sheet.dart';
import 'widgets/plan_housemates_agenda_sheet.dart';

class ChatDirectoryScreen extends ConsumerStatefulWidget {
  final bool initialFocusAgendas;

  const ChatDirectoryScreen({super.key, this.initialFocusAgendas = false});

  @override
  ConsumerState<ChatDirectoryScreen> createState() =>
      _ChatDirectoryScreenState();
}

class _ChatDirectoryScreenState extends ConsumerState<ChatDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _agendasSectionKey = GlobalKey();
  ValueListenable<int>? _agendaFocusListenable;
  String _searchQuery = '';
  String _agendaFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.initialFocusAgendas) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAgendas());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextListenable =
        CasamaShellScope.maybeOf(context)?.chatAgendaFocusListenable;
    if (nextListenable != _agendaFocusListenable) {
      _agendaFocusListenable?.removeListener(_handleExternalAgendaFocus);
      _agendaFocusListenable = nextListenable;
      _agendaFocusListenable?.addListener(_handleExternalAgendaFocus);
      if ((_agendaFocusListenable?.value ?? 0) > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAgendas());
      }
    }
  }

  void _handleExternalAgendaFocus() {
    if (!mounted) return;
    if (_agendaFilter == 'history') {
      setState(() => _agendaFilter = 'all');
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToAgendas());
  }

  void _scrollToAgendas() {
    if (!mounted) return;
    final ctx = _agendasSectionKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: CasamaMotion.resolve(context, CasamaMotion.sheet),
      curve: CasamaMotion.easeOut,
      alignment: 0.08,
    );
  }

  @override
  void dispose() {
    _agendaFocusListenable?.removeListener(_handleExternalAgendaFocus);
    _scrollController.dispose();
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
    final collapsed = msg.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (msg.hasAttachment) {
      return collapsed.isEmpty ? '📷 Photo' : '📷 $collapsed';
    }
    return collapsed;
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
    final hasOngoingMine = repo.housematesAgendaInvitations.any(
      (a) => a.hasValidData && a.creatorId == repo.currentUser.id && a.isOngoing,
    );
    final agendaFilterOptions = [
      const CasamaFilterOption<String>(value: 'all', label: 'All Active'),
      CasamaFilterOption<String>(
        value: 'mine',
        label: 'My Agendas',
        dotColor: hasOngoingMine ? pal.successFg : null,
        dotKey: const Key('my_agendas_ongoing_dot'),
      ),
      const CasamaFilterOption<String>(value: 'history', label: 'History'),
    ];
    final filteredAgendas = repo.housematesAgendaInvitations
        .where((m) {
          if (!m.hasValidData) return false;
          return switch (_agendaFilter) {
            'mine' => m.isActive && m.creatorId == repo.currentUser.id,
            'history' => m.isHistory,
            _ => m.isActive,
          };
        })
        .toList()
      ..sort((a, b) {
        if (_agendaFilter == 'history') {
          return b.scheduledTime.compareTo(a.scheduledTime);
        }
        if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
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
              : '${repo.resolveHousemateName(groupLastMsg.senderId, fallback: groupLastMsg.senderName)}: ${_messagePreviewText(groupLastMsg)}')
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
      final preferred = m.preferredName.toLowerCase();
      final nickname = (m.profile.nickname ?? '').toLowerCase();
      final fullName = (m.profile.fullName ?? '').toLowerCase();
      final name = m.profile.displayName.toLowerCase();
      final note = (m.note ?? '').toLowerCase();
      final lastMsg = repo
          .getDirectMessages(m.profile.displayName.toLowerCase())
          .lastOrNull;
      final msgContent = (lastMsg?.content ?? '').toLowerCase();
      return preferred.contains(query) ||
          nickname.contains(query) ||
          fullName.contains(query) ||
          name.contains(query) ||
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
        return a.preferredName.toLowerCase().compareTo(
          b.preferredName.toLowerCase(),
        );
      });

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.only(bottom: bottomInset + 104),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Stepped Forest Teal Wave Header
              CasamaWaveHeader(
                title: 'Chat',
                subtitle: repo.hasActiveHousehold
                    ? '${repo.currentHousehold.name} • ${members.length} members'
                    : 'No household yet',
                showNotificationBell: true,
                onMenuTap: () => _openDrawer(context),
              ),

              if (!repo.hasActiveHousehold)
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: const Padding(
                      padding: EdgeInsets.fromLTRB(
                        CasamaSpacing.md,
                        CasamaSpacing.md,
                        CasamaSpacing.md,
                        0,
                      ),
                      child: CasamaNoHouseholdPrompt(
                        title: 'Join a household',
                        subtitle:
                            'Chat with housemates, create shared spaces, and plan agendas once you join or create a household.',
                        mascotPose: CasPose.chatting,
                      ),
                    ),
                  ),
                )
              else
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
                                                  : '${repo.resolveHousemateName(s.messages.last.senderId, fallback: s.messages.last.senderName)}: ${_messagePreviewText(s.messages.last)}')
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
                                                    : 'Tap to message ${m.preferredName}');
                                          final timeStr = lastMsg != null
                                              ? DateFormat('h:mm a').format(
                                                  lastMsg.createdAt,
                                                )
                                              : '';

                                          return _HousemateConversationRow(
                                            name: m.preferredName,
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
                                                '/direct-chat?contact=$contactKey&name=${Uri.encodeComponent(m.preferredName)}&avatar=${Uri.encodeComponent(m.profile.avatarUrl ?? '')}',
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

                            // 7. Housemates Agenda Card
                            SizedBox(
                              key: _agendasSectionKey,
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  Text(
                                    'Housemates Agenda',
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
                                    onTap: () =>
                                        showPlanHousematesAgendaSheet(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),
                            CasamaPillFilterRail<String>(
                              options: agendaFilterOptions,
                              selectedValue: _agendaFilter,
                              padding: EdgeInsets.zero,
                              onSelected: (val) =>
                                  setState(() => _agendaFilter = val),
                            ),
                            const SizedBox(height: CasamaSpacing.xs),
                            if (filteredAgendas.isEmpty)
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
                                            switch (_agendaFilter) {
                                              'mine' =>
                                                'You have no active agendas',
                                              'history' =>
                                                'No past agendas yet',
                                              _ => 'No active agendas',
                                            },
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  color: pal.textPrimary,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            switch (_agendaFilter) {
                                              'mine' =>
                                                'Tap + New to plan one for the household.',
                                              'history' =>
                                                'Completed and missed agendas will appear here.',
                                              _ =>
                                                'Tap + New to share an agenda with your housemates.',
                                            },
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
                                    i < filteredAgendas.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const SizedBox(height: CasamaSpacing.xs),
                                    Builder(
                                      builder: (context) {
                                        final m = filteredAgendas[i];
                                        final creator = _resolveAgendaCreator(
                                          repo,
                                          m.creatorId,
                                        );
                                        return CasamaCard(
                                          padding: const EdgeInsets.all(14),
                                          onTap: () =>
                                              _showHousematesAgendaDetailsSheet(
                                                context,
                                                invitationId: m.id,
                                              ),
                                          child: Row(
                                            children: [
                                              CasamaAvatar(
                                                avatarUrl: creator?.avatarUrl,
                                                radius: 22,
                                                name:
                                                    creator?.preferredName ??
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
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        CasamaAgendaStatusBadge(
                                                          status: m.status,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            _formatAgendaRelativeTime(
                                                              m.scheduledTime,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.tabular
                                                                .copyWith(
                                                                  color: pal
                                                                      .textPrimary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                  fontSize:
                                                                      12.5,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '${m.location} • ${m.goingCount} going',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: theme
                                                                .textTheme
                                                                .bodySmall
                                                                ?.copyWith(
                                                                  color: pal
                                                                      .textSecondary,
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'Tap to view',
                                                              style: theme
                                                                  .textTheme
                                                                  .labelSmall
                                                                  ?.copyWith(
                                                                    color: pal
                                                                        .textSecondary,
                                                                    fontSize:
                                                                        11.5,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 2,
                                                            ),
                                                            Icon(
                                                              Icons
                                                                  .chevron_right_rounded,
                                                              size: 16,
                                                              color: pal
                                                                  .textSecondary,
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ],
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

UserProfile? _resolveAgendaCreator(CasamaRepository repo, String creatorId) {
  final cleanId = creatorId.trim();
  if (cleanId.isEmpty) return null;
  if (repo.currentUser.id == cleanId) return repo.currentUser;
  for (final member in repo.members) {
    if (member.profile.id == cleanId) return member.profile;
  }
  return null;
}

String _formatAgendaRelativeTime(DateTime scheduledTime) {
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

void _showHousematesAgendaDetailsSheet(
  BuildContext hostContext, {
  String? invitationId,
}) {
  showCasamaSheet<void>(
    hostContext,
    icon: Icons.event_available_rounded,
    title: 'Housemates Agenda',
    subtitle: 'Coordinate plans & RSVP with your housemates',
    builder: (sheetCtx) => _HousematesAgendaDetailsSheetBody(
      hostContext: hostContext,
      sheetContext: sheetCtx,
      invitationId: invitationId,
    ),
  );
}

class _HousematesAgendaDetailsSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final BuildContext sheetContext;
  final String? invitationId;

  const _HousematesAgendaDetailsSheetBody({
    required this.hostContext,
    required this.sheetContext,
    this.invitationId,
  });

  @override
  ConsumerState<_HousematesAgendaDetailsSheetBody> createState() =>
      _HousematesAgendaDetailsSheetBodyState();
}

class _HousematesAgendaDetailsSheetBodyState
    extends ConsumerState<_HousematesAgendaDetailsSheetBody> {
  bool _isDeleting = false;
  bool _isUpdatingStatus = false;

  Future<void> _updateStatus(
    HousematesAgendaInvitation agenda,
    String status,
  ) async {
    if (_isUpdatingStatus || _isDeleting) return;
    setState(() => _isUpdatingStatus = true);
    try {
      await ref
          .read(repositoryProvider)
          .updateHousematesAgendaStatus(agenda.id, status);
      if (widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          status == 'done'
              ? 'Agenda marked as done'
              : 'Agenda marked as missed',
          icon: status == 'done'
              ? Icons.check_circle_outline_rounded
              : Icons.event_busy_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isUpdatingStatus = false);
      showCasamaToast(
        context,
        'Could not update agenda status. Please try again.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _confirmAndDelete(HousematesAgendaInvitation agenda) async {
    if (_isDeleting || _isUpdatingStatus) return;
    final pal = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Agenda?'),
        content: Text(
          'This will permanently remove "${agenda.activity}" and all housemate responses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('agenda_confirm_delete_button'),
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
      await ref
          .read(repositoryProvider)
          .deleteHousematesAgendaInvitation(agenda.id);
      if (widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Agenda deleted',
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      showCasamaToast(
        context,
        'Could not delete agenda. Please try again.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final pal = context.palette;
    final theme = Theme.of(context);

    HousematesAgendaInvitation agenda;
    if (widget.invitationId != null) {
      agenda = repo.housematesAgendaInvitations.firstWhere(
        (m) => m.id == widget.invitationId,
        orElse: () => repo.activeHousematesAgenda.id == widget.invitationId
            ? repo.activeHousematesAgenda
            : HousematesAgendaInvitation(
                id: '',
                activity: '',
                location: '',
                scheduledTime: DateTime.now(),
              ),
      );
    } else {
      agenda = repo.activeHousematesAgenda;
    }

    if (!agenda.hasValidData) {
      return Text(
        'No active housemates agenda.',
        style: theme.textTheme.bodyMedium?.copyWith(color: pal.textSecondary),
      );
    }

    final timeLabel = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(agenda.scheduledTime);
    final canRespond = agenda.isUpcoming && !_isDeleting && !_isUpdatingStatus;
    final isCreator =
        agenda.creatorId.isNotEmpty && agenda.creatorId == repo.currentUser.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                agenda.activity,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CasamaAgendaStatusBadge(status: agenda.status),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '$timeLabel • ${agenda.location}',
          style: theme.textTheme.bodyMedium?.copyWith(color: pal.textSecondary),
        ),
        const SizedBox(height: CasamaSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              agenda.isUpcoming
                  ? 'YOUR RESPONSE'
                  : (agenda.isOngoing ? 'RESPONSES' : 'FINAL RESPONSES'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: pal.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
            if (agenda.isOngoing)
              Text(
                '• Agenda is currently ongoing',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: pal.successFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _AgendaRsvpChip(
                label: 'Going (${agenda.goingCount})',
                selected: agenda.currentUserResponse == 'going',
                activeBg: pal.successFg,
                onTap: !canRespond
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondToHousematesAgendaInvitation(
                            'going',
                            invitationId: agenda.id,
                          ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AgendaRsvpChip(
                label: 'Maybe (${agenda.maybeCount})',
                selected: agenda.currentUserResponse == 'maybe',
                activeBg: pal.amberFg,
                onTap: !canRespond
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondToHousematesAgendaInvitation(
                            'maybe',
                            invitationId: agenda.id,
                          ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _AgendaRsvpChip(
                label: "Can't (${agenda.cantMakeCount})",
                selected: agenda.currentUserResponse == 'cant_make_it',
                activeBg: pal.neutralFg,
                onTap: !canRespond
                    ? null
                    : () => ref
                          .read(repositoryProvider)
                          .respondToHousematesAgendaInvitation(
                            'cant_make_it',
                            invitationId: agenda.id,
                          ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),
        _AgendaResponderRow(
          label: 'Going',
          accentColor: pal.successFg,
          responders: agenda.goingResponders,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _AgendaResponderRow(
          label: 'Maybe',
          accentColor: pal.amberFg,
          responders: agenda.maybeResponders,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _AgendaResponderRow(
          label: "Can't",
          accentColor: pal.neutralFg,
          responders: agenda.cantMakeResponders,
        ),
        if (agenda.isOngoing && isCreator) ...[
          const SizedBox(height: CasamaSpacing.lg),
          Text(
            'Confirm Agenda Outcome',
            style: theme.textTheme.labelMedium?.copyWith(
              color: pal.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Mark Agenda Done',
                  child: CasamaPressable(
                    key: const Key('agenda_mark_done_button'),
                    onTap: _isUpdatingStatus
                        ? null
                        : () => _updateStatus(agenda, 'done'),
                    enableHaptic: !_isUpdatingStatus,
                    child: Container(
                      height: CasamaSpacing.minTouchTarget,
                      decoration: BoxDecoration(
                        color: pal.successFg,
                        borderRadius: CasamaSpacing.roundedPill,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Done',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: CasamaSpacing.sm),
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Mark Agenda Missed',
                  child: CasamaPressable(
                    key: const Key('agenda_mark_missed_button'),
                    onTap: _isUpdatingStatus
                        ? null
                        : () => _updateStatus(agenda, 'missed'),
                    enableHaptic: !_isUpdatingStatus,
                    child: Container(
                      height: CasamaSpacing.minTouchTarget,
                      decoration: BoxDecoration(
                        color: pal.dangerBg,
                        borderRadius: CasamaSpacing.roundedPill,
                        border: Border.all(
                          color: pal.dangerFg.withValues(alpha: 0.3),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: pal.dangerFg,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Missed',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: pal.dangerFg,
                              fontSize: 14,
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
        ] else if ((agenda.isUpcoming || agenda.isHistory) && isCreator) ...[
          const SizedBox(height: CasamaSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: Semantics(
              button: true,
              label: 'Delete Agenda',
              child: CasamaPressable(
                key: const Key('agenda_delete_button'),
                onTap: _isDeleting ? null : () => _confirmAndDelete(agenda),
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

class _AgendaResponderRow extends ConsumerWidget {
  final String label;
  final Color accentColor;
  final List<HousematesAgendaResponse> responders;

  const _AgendaResponderRow({
    required this.label,
    required this.accentColor,
    required this.responders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    const maxVisible = 6;
    const avatarSize = 28.0;
    const step = 18.0;
    final visible = responders.take(maxVisible).toList();
    final overflow = responders.length - visible.length;
    final totalItems = visible.length + (overflow > 0 ? 1 : 0);
    final stackWidth =
        totalItems == 0 ? 0.0 : avatarSize + (totalItems - 1) * step;
    final namesSummary = responders
        .map((r) => repo.resolveHousemateName(r.userId, fallback: r.displayName))
        .join(', ');

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
                        key: Key('agenda_responders_$label'),
                        onTap: () => _showResponderListSheet(
                          context,
                          repo,
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
                                            name: repo.resolveHousemateName(
                                              visible[i].userId,
                                              fallback: visible[i].displayName,
                                            ),
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
  CasamaRepository repo,
  String label,
  Color accentColor,
  List<HousematesAgendaResponse> responders,
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
                  name: repo.resolveHousemateName(
                    responders[i].userId,
                    fallback: responders[i].displayName,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    repo.resolveHousemateName(
                      responders[i].userId,
                      fallback: responders[i].displayName,
                    ),
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

class _AgendaRsvpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeBg;
  final VoidCallback? onTap;

  const _AgendaRsvpChip({
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
