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
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../calendar/household_calendar_view.dart';
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
                title: 'Hello, ${repo.currentUser.effectiveGreetingName}!',
                subtitle: _getTimeBasedGreeting(),
                unreadNotificationCount: repo.unreadNotificationCount,
                onMenuTap: () => _openDrawer(context),
                onNotificationTap: () {
                  ref.read(repositoryProvider).markAllNotificationsAsRead();
                  _showNotificationsSheet(context, ref);
                },
              ),

              // 2. Overlapping Split Hero (Transparent PNG Mascot + Casa Status)
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -18),
                        child: CasamaSplitHero(
                          mascotPose: CasPose.hero,
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

                            const SizedBox(height: CasamaSpacing.lg),

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
                    Row(
                      children: [
                        Text(
                          "Who's Home",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      'Tap your status to toggle or add a note',
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
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runAlignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 12,
            children: [
              for (final m in members)
                SizedBox(
                  width: 72,
                  child: AvatarChip(
                    name: m.profile.displayName,
                    avatarUrl: m.profile.avatarUrl,
                    isHome: m.isHome,
                    isCurrentUser: m.profile.id == repo.currentUser.id,
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

    final unpaidBills =
        repo.bills.where((b) => b.effectiveStatus != BillStatus.paid).toList()
          ..sort((a, b) {
            final aOverdue = a.effectiveStatus == BillStatus.overdue ? 0 : 1;
            final bOverdue = b.effectiveStatus == BillStatus.overdue ? 0 : 1;
            if (aOverdue != bOverdue) return aOverdue.compareTo(bOverdue);
            return a.deadline.compareTo(b.deadline);
          });

    for (final bill in unpaidBills) {
      final overdue = bill.effectiveStatus == BillStatus.overdue;
      final dueLabel = DateFormat('MMM d').format(bill.deadline);
      items.add(
        _AttentionRowData(
          priority: overdue ? 0 : 2,
          icon: Icons.receipt_long_rounded,
          iconBg: overdue ? pal.softBlush : pal.amberBg,
          iconColor: overdue ? pal.dangerFg : pal.amberFg,
          rowBg: overdue ? pal.softBlush.withValues(alpha: 0.72) : pal.card,
          title: overdue
              ? '${bill.effectiveBillName} • Overdue'
              : '${bill.effectiveBillName} • Unpaid',
          subtitle: 'Due $dueLabel',
          trailingTop: bill.amount != null
              ? '₱${bill.amount!.toStringAsFixed(2)}'
              : null,
          trailingAction: overdue ? 'Settle ›' : 'View ›',
          trailingColor: overdue ? pal.dangerFg : pal.forestTeal,
          onTap: () => _openBoardTab(context, 2, '/boards?tab=bills'),
        ),
      );
    }

    final pendingTasks =
        repo.tasks.where((t) => t.status != TaskStatus.done).toList()
          ..sort((a, b) {
            if (a.urgency == b.urgency) return 0;
            if (a.urgency == TaskUrgency.urgent) return -1;
            if (b.urgency == TaskUrgency.urgent) return 1;
            return a.urgency.index.compareTo(b.urgency.index);
          });

    for (final task in pendingTasks) {
      final isUrgent = task.urgency == TaskUrgency.urgent;
      items.add(
        _AttentionRowData(
          priority: isUrgent ? 1 : 3,
          icon: Icons.handyman_outlined,
          iconBg: pal.softSage,
          iconColor: pal.forestTeal,
          rowBg: pal.softSage.withValues(alpha: 0.65),
          title: task.title,
          subtitle:
              'Assigned to ${task.assigneeName ?? 'Unassigned'} • ${task.urgency.label}',
          trailingAction: 'Tasks ›',
          trailingColor: pal.forestTeal,
          onTap: () => _openBoardTab(context, 1, '/boards?tab=tasks'),
        ),
      );
    }

    final codParcels = repo.parcels.where(
      (p) =>
          p.status != ParcelStatus.received &&
          p.status != ParcelStatus.cancelled &&
          p.paymentType == ParcelPaymentType.cod,
    );
    for (final parcel in codParcels) {
      items.add(
        _AttentionRowData(
          priority: 2,
          icon: Icons.inventory_2_outlined,
          iconBg: pal.softBlush,
          iconColor: pal.primaryCoral,
          rowBg: pal.softBlush.withValues(alpha: 0.6),
          title: '${parcel.courier} COD for ${parcel.buyerName}',
          subtitle: 'Status: ${parcel.status.label}',
          trailingTop: parcel.codAmount != null
              ? '₱${parcel.codAmount!.toStringAsFixed(0)}'
              : null,
          trailingAction: 'Parcels ›',
          trailingColor: pal.primaryCoral,
          onTap: () => _openBoardTab(context, 0, '/boards?tab=parcels'),
        ),
      );
    }

    items.sort((a, b) => a.priority.compareTo(b.priority));
    return items;
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
            Text(
              items.isEmpty
                  ? 'All clear'
                  : '${items.length} ${items.length == 1 ? 'action' : 'actions'}',
              style: theme.textTheme.labelMedium?.tabular.copyWith(
                color: items.isEmpty ? pal.successFg : pal.primaryCoral,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: CasamaSpacing.xs + 2),
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
                    'All caught up — no overdue bills, urgent chores, or COD handoffs.',
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
    var isHome = currentIsHome;
    final noteController = TextEditingController(text: currentNote);

    showCasamaSheet<void>(
      context,
      icon: Icons.person_pin_circle_outlined,
      title: 'Update Your Presence',
      subtitle: 'Let roommates know if you are Home or Out',
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final pal = ctx.palette;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: isHome
                              ? pal.successBg
                              : Colors.transparent,
                          side: BorderSide(
                            color: isHome ? pal.successFg : pal.border,
                            width: isHome ? 1.8 : 1,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => setModalState(() => isHome = true),
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
                                color: isHome ? pal.successFg : pal.textPrimary,
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
                          backgroundColor: !isHome
                              ? pal.neutralBg
                              : Colors.transparent,
                          side: BorderSide(
                            color: !isHome ? pal.neutralFg : pal.border,
                            width: !isHome ? 1.8 : 1,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => setModalState(() => isHome = false),
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
                                color: !isHome
                                    ? pal.neutralFg
                                    : pal.textPrimary,
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
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Status note (optional)',
                    hintText: 'e.g., Studying, At class, Cooking',
                  ),
                ),
                const SizedBox(height: CasamaSpacing.lg),
                CasamaButton(
                  label: 'Save Status',
                  isPill: true,
                  height: 50,
                  onPressed: () {
                    final note = noteController.text.trim();
                    ref
                        .read(repositoryProvider)
                        .updatePresence(
                          isHome: isHome,
                          note: note.isNotEmpty ? note : null,
                        );
                    Navigator.of(sheetCtx).pop();
                    showCasamaToast(
                      context,
                      'Presence updated',
                      icon: Icons.check_circle_outline_rounded,
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(noteController.dispose);
  }

  void _showMemberInfoModal(BuildContext context, MemberPresence member) {
    showCasamaSheet<void>(
      context,
      icon: Icons.badge_outlined,
      title: member.profile.displayName,
      subtitle: member.profile.handle,
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        return Column(
          children: [
            CasamaAvatar(
              radius: 36,
              avatarUrl: member.profile.avatarUrl,
              name: member.profile.displayName,
              borderWidth: 2,
              borderColor: member.isHome ? pal.successFg : pal.border,
            ),
            const SizedBox(height: 12),
            Container(
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
            if (member.note != null && member.note!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '"${member.note!.trim()}"',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: pal.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: CasamaSpacing.md),
          ],
        );
      },
    );
  }

  void _showNotificationsSheet(BuildContext context, WidgetRef ref) {
    showCasamaSheet<void>(
      context,
      icon: Icons.notifications_none_rounded,
      title: 'Notifications',
      subtitle: 'Recent household updates',
      builder: (sheetCtx) {
        final pal = sheetCtx.palette;
        final theme = Theme.of(sheetCtx);
        final items = ref.watch(repositoryProvider).notifications;
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
                _NotificationRow(
                  icon: items[i].type == 'parcel_received'
                      ? Icons.local_shipping_outlined
                      : items[i].type == 'roulette_chosen'
                      ? Icons.casino_outlined
                      : Icons.notifications_none_rounded,
                  iconBg: items[i].type == 'parcel_received'
                      ? pal.softBlush
                      : pal.softSage,
                  iconColor: items[i].type == 'parcel_received'
                      ? pal.primaryCoral
                      : pal.forestTeal,
                  title: items[i].title,
                  subtitle: items[i].subtitle,
                  time: DateFormat('h:mm a').format(items[i].createdAt),
                  pal: pal,
                  theme: theme,
                ),
              ],
            const SizedBox(height: CasamaSpacing.md),
            CasamaButton(
              label: 'Mark all read',
              style: CasamaButtonStyle.secondary,
              height: 48,
              onPressed: () {
                ref.read(repositoryProvider).markAllNotificationsAsRead();
                Navigator.of(sheetCtx).pop();
                showCasamaToast(
                  context,
                  'All notifications marked as read',
                  icon: Icons.done_all_rounded,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _AttentionRowData {
  final int priority;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color rowBg;
  final String title;
  final String subtitle;
  final String? trailingTop;
  final String trailingAction;
  final Color trailingColor;
  final VoidCallback onTap;

  const _AttentionRowData({
    required this.priority,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.rowBg,
    required this.title,
    required this.subtitle,
    this.trailingTop,
    required this.trailingAction,
    required this.trailingColor,
    required this.onTap,
  });
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(data.icon, color: data.iconColor, size: 20),
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

class _NotificationRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final CasamaPalette pal;
  final ThemeData theme;

  const _NotificationRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.pal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
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
    );
  }
}
