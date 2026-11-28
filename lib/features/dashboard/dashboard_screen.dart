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
import '../../shared/widgets/avatar_chip.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_no_household_card.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_background.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../calendar/household_calendar_view.dart';
import '../chat/chat_directory_screen.dart';
import '../quicksnap/quicksnap_home_widget.dart';
import 'main_navigation_shell.dart';
import 'widgets/casama_household_drawer.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning.';
    if (hour < 17) return 'Good Afternoon.';
    return 'Good Evening.';
  }

  void _openDrawer(BuildContext context) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openDrawer();
      return;
    }
    showCasamaHouseholdDrawer(context);
  }

  void _openChatAgendas(BuildContext context) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openChatAgendas();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/chat?section=agendas');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ChatDirectoryScreen(initialFocusAgendas: true),
      ),
    );
  }

  void _openBoardTab(BuildContext context, int boardIndex, String routePath) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openBoardTab(boardIndex);
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push(routePath);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final members = repo.members;
    final activeCount = members.where((m) => m.isHome).length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    final attentionItems = _buildAttentionItems(context, repo, pal);

    MemberPresence? me;
    for (final m in members) {
      if (m.profile.id == repo.currentUser.id) {
        me = m;
        break;
      }
    }

    final inWaveShell = CasamaWaveTabScope.maybeOf(context) != null;

    return Scaffold(
      backgroundColor: inWaveShell ? Colors.transparent : pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        backgroundColor: inWaveShell ? Colors.transparent : null,
        child: CasamaWaveScrollSync(
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.only(bottom: bottomInset + 104),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Stepped Forest Teal Wave Header
                CasamaWaveHeaderSlot(
                  child: CasamaWaveHeader(
                    title: 'Hello, ${repo.currentUser.preferredName}!',
                    subtitle: _getTimeBasedGreeting(),
                    showNotificationBell: true,
                    paintBackground: !inWaveShell,
                    onMenuTap: () => _openDrawer(context),
                  ),
                ),

              // 2. Overlapping Split Hero (or No-Household Prompt)
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
                        title: 'No household yet',
                        subtitle:
                            'Join your housemates with an invite code or start your own Casa to unlock Presence, Boards, CASnap, and Chat.',
                        joinLabel: 'Join a Household',
                        createLabel: 'Create a Household',
                        mascotPose: CasPose.hero,
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
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: CasamaSplitHero(
                          mascotPose: CasPose.home,
                          kicker: '${repo.currentHousehold.name} Status',
                          kickerDotColor: activeCount > 0
                              ? pal.successFg
                              : pal.neutralFg,
                          headline: '$activeCount of ${members.length} Home',
                          subtitle:
                              '${members.length} members • Active now: $activeCount',
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CasamaSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3. Who's Home Card (Live Presence Toggle + Badges)
                            _buildWhosHomeCard(
                              context: context,
                              ref: ref,
                              repo: repo,
                              members: members,
                              activeCount: activeCount,
                              me: me,
                              pal: pal,
                              theme: theme,
                            ),

                            const SizedBox(height: CasamaSpacing.lg),

                            // 4. Dynamic Live Attention Needed Section
                            _buildAttentionSection(
                              context: context,
                              items: attentionItems,
                              pal: pal,
                              theme: theme,
                            ),

                            const SizedBox(height: CasamaSpacing.md),

                            // 5. Shared CASnaps Preview Slot (reskinned in Phase 5)
                            const QuickSnapHomeWidget(),

                            const SizedBox(height: CasamaSpacing.lg),

                            // 6. Compact Casa Schedule & Calendar Filter Rail
                            const HouseholdCalendarView(),
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
      ),
    );
  }

  Widget _buildWhosHomeCard({
    required BuildContext context,
    required WidgetRef ref,
    required CasamaRepository repo,
    required List<MemberPresence> members,
    required int activeCount,
    required MemberPresence? me,
    required CasamaPalette pal,
    required ThemeData theme,
  }) {
    final reduced = CasamaMotion.reduceMotion(context);
    final isMeHome = me?.isHome ?? true;

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          "Who's Home",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: pal.softSage,
                            borderRadius: CasamaSpacing.roundedPill,
                          ),
                          child: Text(
                            repo.currentHousehold.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: pal.forestTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap a profile to view or update a status note',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                toggled: isMeHome,
                label: 'Toggle your home presence',
                child: CasamaPressable(
                  enableHaptic: true,
                  onTap: () {
                    final next = !isMeHome;
                    ref
                        .read(repositoryProvider)
                        .updatePresence(isHome: next, note: me?.note);
                    showCasamaToast(
                      context,
                      next ? 'Marked as Home' : 'Marked as Out',
                      icon: next
                          ? Icons.home_rounded
                          : Icons.directions_walk_rounded,
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: CasamaSpacing.minTouchTarget,
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: reduced ? Duration.zero : CasamaMotion.press,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isMeHome ? pal.successBg : pal.neutralBg,
                          borderRadius: CasamaSpacing.roundedPill,
                          border: Border.all(
                            color: (isMeHome ? pal.successFg : pal.neutralFg)
                                .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isMeHome ? pal.successFg : pal.neutralFg,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMeHome ? 'You: Home' : 'You: Out',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isMeHome ? pal.successFg : pal.neutralFg,
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
          const SizedBox(height: CasamaSpacing.md),
          SizedBox(
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 6.0;
                final maxCols = constraints.maxWidth < 280 ? 3 : 4;
                final cols = members.isEmpty
                    ? 1
                    : (members.length < maxCols ? members.length : maxCols);
                final slotWidth =
                    ((constraints.maxWidth - spacing * (cols - 1)) / cols)
                        .clamp(64.0, 96.0);
                return Wrap(
                  alignment: members.length <= maxCols
                      ? WrapAlignment.spaceEvenly
                      : WrapAlignment.start,
                  runAlignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: spacing,
                  runSpacing: 14,
                  children: [
                    for (final m in members)
                      SizedBox(
                        width: slotWidth,
                        child: AvatarChip(
                          name: m.preferredName,
                          avatarUrl: m.profile.avatarUrl,
                          isHome: m.isHome,
                          isCurrentUser: m.profile.id == repo.currentUser.id,
                          note: m.note,
                          onTap: m.profile.id == repo.currentUser.id
                              ? () => _showPresenceToggleModal(
                                  context,
                                  ref,
                                  m.isHome,
                                  m.note,
                                )
                              : () => _showMemberInfoModal(context, m),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (members.length <= 1) ...[
            const SizedBox(height: CasamaSpacing.sm),
            Semantics(
              button: true,
              label: 'Invite housemates to join ${repo.currentHousehold.name}',
              child: CasamaPressable(
                onTap: () => _openDrawer(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: pal.softSage,
                    borderRadius: CasamaSpacing.roundedSm,
                    border: Border.all(
                      color: pal.forestTeal.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.group_add_outlined,
                        size: 18,
                        color: pal.forestTeal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Invite housemates (Code: ${repo.currentHousehold.inviteCode})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.forestTeal,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: pal.forestTeal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_AttentionRowData> _buildAttentionItems(
    BuildContext context,
    CasamaRepository repo,
    CasamaPalette pal,
  ) {
    final items = <_AttentionRowData>[];
    final now = DateTime.now();
    final nowLocal = now.toLocal();
    final startOfToday = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final startOfTomorrow = DateTime(
      nowLocal.year,
      nowLocal.month,
      nowLocal.day + 1,
    );
    final currentUserId = repo.currentUser.id;

    // 1. Ongoing household tasks with urgency == urgent
    final urgentTasks = repo.tasks.where(
      (t) => t.status != TaskStatus.done && t.urgency == TaskUrgency.urgent,
    );
    for (final task in urgentTasks) {
      final isMine = task.createdBy == currentUserId;
      final creatorName = repo.resolveHousemateName(
        task.createdBy,
        fallback: task.createdByName,
      );
      final creatorLabel = isMine ? 'You' : creatorName;
      items.add(
        _AttentionRowData(
          priority: 1,
          avatarUrl: repo.resolveHousemateAvatarUrl(task.createdBy),
          avatarName: creatorName,
          rowBg: pal.softSage.withValues(alpha: 0.65),
          title: task.title,
          subtitle:
              '${task.category.label} • ${task.urgency.label} • By $creatorLabel',
          trailingAction: 'Tasks ›',
          trailingColor: pal.forestTeal,
          onTap: () => _openBoardTab(context, 1, '/boards?tab=tasks'),
        ),
      );
    }

    // 2. Unsettled household parcels scheduled for Today
    final todayParcels = repo.parcels.where((p) {
      if (p.status == ParcelStatus.cancelled || p.isSettled) return false;
      final arrivalLocal = p.expectedArrival.toLocal();
      return !arrivalLocal.isBefore(startOfToday) &&
          arrivalLocal.isBefore(startOfTomorrow);
    });
    for (final parcel in todayParcels) {
      final isMine = parcel.buyerId == currentUserId;
      final buyerName = repo.resolveHousemateName(
        parcel.buyerId,
        fallback: parcel.buyerName,
      );
      final buyerLabel = isMine ? 'You' : buyerName;
      final isCod = parcel.paymentType == ParcelPaymentType.cod;
      items.add(
        _AttentionRowData(
          priority: 2,
          avatarUrl: repo.resolveHousemateAvatarUrl(parcel.buyerId),
          avatarName: buyerName,
          rowBg: pal.softBlush.withValues(alpha: 0.6),
          title: isCod
              ? '${parcel.courier} COD for $buyerLabel'
              : '${parcel.courier} for $buyerLabel',
          subtitle: parcel.isUnsettledClaim
              ? 'Status: Unsettled'
              : 'Status: Scheduled Today',
          trailingTop: isCod && parcel.codAmount != null
              ? '₱${parcel.codAmount!.toStringAsFixed(0)}'
              : null,
          trailingAction: 'Parcels ›',
          trailingColor: pal.primaryCoral,
          onTap: () => _openBoardTab(context, 0, '/boards?tab=parcels'),
        ),
      );
    }

    // 3. Active/upcoming Housemates Agendas starting in < 24 hours where user is undecided ('maybe' or no RSVP)
    final upcomingAgendas = repo.housematesAgendaInvitations.where((a) {
      if (!a.hasValidData || !a.isActive) return false;
      if (!a.scheduledTime.isAfter(now)) return false;
      if (a.scheduledTime.difference(now) >= const Duration(hours: 24)) {
        return false;
      }
      final rsvp = a.currentUserResponse?.trim().toLowerCase() ?? '';
      return rsvp.isEmpty || rsvp == 'maybe';
    });
    for (final agenda in upcomingAgendas) {
      final isMine = agenda.creatorId == currentUserId;
      final creatorName = repo.resolveHousemateName(
        agenda.creatorId,
        fallback: 'Housemate',
      );
      final creatorLabel = isMine ? 'You' : creatorName;
      items.add(
        _AttentionRowData(
          priority: 3,
          avatarUrl: repo.resolveHousemateAvatarUrl(agenda.creatorId),
          avatarName: creatorName,
          rowBg: pal.infoBg.withValues(alpha: 0.6),
          title: agenda.activity,
          subtitle:
              '${DateFormat('h:mm a').format(agenda.scheduledTime.toLocal())} • ${agenda.location} • By $creatorLabel',
          trailingTop: agenda.currentUserResponse == 'maybe' ? 'Maybe' : 'RSVP',
          trailingAction: 'Agenda ›',
          trailingColor: pal.infoFg,
          onTap: () => _openChatAgendas(context),
        ),
      );
    }

    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
  }

  void _showAllAttentionSheet(
    BuildContext context,
    List<_AttentionRowData> items,
  ) {
    showCasamaSheet<void>(
      context,
      icon: Icons.notifications_active_outlined,
      title: 'Live Attention Needed',
      subtitle:
          '${items.length} ${items.length == 1 ? 'item' : 'items'} needing your attention',
      builder: (sheetCtx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: CasamaSpacing.xs + 2),
            _AttentionActionTile(
              data: items[i].copyWithOnTap(() {
                Navigator.of(sheetCtx).pop();
                items[i].onTap();
              }),
            ),
          ],
          const SizedBox(height: CasamaSpacing.xs),
        ],
      ),
    );
  }

  Widget _buildAttentionSection({
    required BuildContext context,
    required List<_AttentionRowData> items,
    required CasamaPalette pal,
    required ThemeData theme,
  }) {
    final visible = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Live Attention Needed',
              style: theme.textTheme.titleMedium?.copyWith(
                color: pal.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (items.isEmpty)
              Text(
                'All clear',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: pal.successFg,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Semantics(
                button: true,
                label: 'View all live attention items',
                child: CasamaPressable(
                  key: const ValueKey('live_attention_view_all_button'),
                  onTap: () => _showAllAttentionSheet(context, items),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: CasamaSpacing.minTouchTarget,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'View all ›',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: pal.primaryCoral,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.xs),
        if (visible.isEmpty)
          CasamaCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: pal.successBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    color: pal.successFg,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All caught up — no urgent tasks, today parcels, or pending agendas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: CasamaSpacing.xs + 2),
            _AttentionActionTile(data: visible[i]),
          ],
      ],
    );
  }

  void _showPresenceToggleModal(
    BuildContext context,
    WidgetRef ref,
    bool currentIsHome,
    String? currentNote,
  ) {
    showCasamaSheet<void>(
      context,
      icon: Icons.person_pin_circle_outlined,
      title: 'Update Your Presence',
      subtitle: 'Let roommates know if you are Home or Out',
      builder: (_) => _PresenceUpdateSheetBody(
        initialIsHome: currentIsHome,
        initialNote: currentNote,
        hostContext: context,
      ),
    );
  }

  void _showMemberInfoModal(BuildContext context, MemberPresence member) {
    final savedNote = member.note?.trim() ?? '';
    final fullName = member.profile.effectiveFullName;
    final subtitle = (fullName.isNotEmpty && fullName != member.preferredName)
        ? fullName
        : 'Household Member';

    showCasamaSheet<void>(
      context,
      icon: Icons.badge_outlined,
      title: member.preferredName,
      subtitle: subtitle,
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: CasamaAvatar(
                radius: 36,
                avatarUrl: member.profile.avatarUrl,
                name: member.preferredName,
                borderWidth: 2,
                borderColor: member.isHome ? pal.successFg : pal.border,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: member.isHome ? pal.successBg : pal.neutralBg,
                  borderRadius: CasamaSpacing.roundedPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: member.isHome ? pal.successFg : pal.neutralFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      member.isHome ? 'Currently Home' : 'Currently Out',
                      style: TextStyle(
                        color: member.isHome ? pal.successFg : pal.neutralFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: pal.scaffoldBg,
                borderRadius: CasamaSpacing.roundedMd,
                border: Border.all(color: pal.border),
              ),
              child: Text(
                savedNote.isNotEmpty ? '"$savedNote"' : 'No status note yet',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: savedNote.isNotEmpty
                      ? pal.textPrimary
                      : pal.textSecondary,
                  fontStyle: savedNote.isNotEmpty
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),
          ],
        );
      },
    );
  }
}

class _AttentionRowData {
  final int priority;
  final String? avatarUrl;
  final String avatarName;
  final Color rowBg;
  final String title;
  final String subtitle;
  final String? trailingTop;
  final String trailingAction;
  final Color trailingColor;
  final VoidCallback onTap;

  const _AttentionRowData({
    required this.priority,
    required this.avatarUrl,
    required this.avatarName,
    required this.rowBg,
    required this.title,
    required this.subtitle,
    this.trailingTop,
    required this.trailingAction,
    required this.trailingColor,
    required this.onTap,
  });

  _AttentionRowData copyWithOnTap(VoidCallback nextOnTap) {
    return _AttentionRowData(
      priority: priority,
      avatarUrl: avatarUrl,
      avatarName: avatarName,
      rowBg: rowBg,
      title: title,
      subtitle: subtitle,
      trailingTop: trailingTop,
      trailingAction: trailingAction,
      trailingColor: trailingColor,
      onTap: nextOnTap,
    );
  }
}

class _AttentionActionTile extends StatelessWidget {
  final _AttentionRowData data;

  const _AttentionActionTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: '${data.title}, ${data.subtitle}',
      child: CasamaPressable.card(
        onTap: data.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: data.rowBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              CasamaAvatar(
                radius: 20,
                avatarUrl: data.avatarUrl,
                name: data.avatarName,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (data.trailingTop != null) ...[
                    Text(
                      data.trailingTop!,
                      style: theme.textTheme.labelMedium?.tabular.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                  ],
                  Text(
                    data.trailingAction,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: data.trailingColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresenceUpdateSheetBody extends ConsumerStatefulWidget {
  final bool initialIsHome;
  final String? initialNote;
  final BuildContext hostContext;

  const _PresenceUpdateSheetBody({
    required this.initialIsHome,
    required this.initialNote,
    required this.hostContext,
  });

  @override
  ConsumerState<_PresenceUpdateSheetBody> createState() =>
      _PresenceUpdateSheetBodyState();
}

class _PresenceUpdateSheetBodyState
    extends ConsumerState<_PresenceUpdateSheetBody> {
  late bool _isHome;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _isHome = widget.initialIsHome;
    _noteController = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: _isHome ? pal.successBg : Colors.transparent,
                  side: BorderSide(
                    color: _isHome ? pal.successFg : pal.border,
                    width: _isHome ? 1.8 : 1,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => setState(() => _isHome = true),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pal.successFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "I'm Home",
                      style: TextStyle(
                        color: _isHome ? pal.successFg : pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: !_isHome
                      ? pal.neutralBg
                      : Colors.transparent,
                  side: BorderSide(
                    color: !_isHome ? pal.neutralFg : pal.border,
                    width: !_isHome ? 1.8 : 1,
                  ),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => setState(() => _isHome = false),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pal.neutralFg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "I'm Out",
                      style: TextStyle(
                        color: !_isHome ? pal.neutralFg : pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.md),
        TextField(
          key: const ValueKey('presence_note_input'),
          controller: _noteController,
          maxLength: 120,
          maxLines: 2,
          minLines: 1,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Status note (optional)',
            hintText: 'e.g., Studying, At class, Cooking',
            suffixIcon: _noteController.text.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear note text',
                    icon: Icon(
                      Icons.clear_rounded,
                      size: 18,
                      color: pal.textSecondary,
                    ),
                    onPressed: () => setState(() => _noteController.clear()),
                  )
                : null,
          ),
        ),
        const SizedBox(height: CasamaSpacing.lg),
        CasamaButton(
          key: const ValueKey('presence_note_save_button'),
          label: 'Save',
          isPill: true,
          height: 50,
          onPressed: () {
            FocusScope.of(context).unfocus();
            final note = _noteController.text.trim();
            ref
                .read(repositoryProvider)
                .updatePresence(
                  isHome: _isHome,
                  note: note.isNotEmpty ? note : null,
                );
            Navigator.of(context).pop();
            if (widget.hostContext.mounted) {
              showCasamaToast(
                widget.hostContext,
                'Presence updated',
                icon: Icons.check_circle_outline_rounded,
              );
            }
          },
        ),
      ],
    );
  }
}
