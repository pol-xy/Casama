import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/cas_mascot_view.dart';
import '../../household/create_household_sheet.dart';
import '../../points/leaderboard_screen.dart';

/// Opens the slide-over [CasamaHouseholdDrawer] from the left (`250ms`
/// `Curves.easeOut` slide + `200ms` `#1C2E4A` 45% scrim fade), honoring
/// reduced-motion settings.
Future<void> showCasamaHouseholdDrawer(
  BuildContext rootContext, {
  ValueChanged<int>? onSelectNavTab,
  ValueChanged<int>? onSelectBoardTab,
}) {
  final reduced = CasamaMotion.reduceMotion(rootContext);
  final pal = rootContext.palette;

  return showGeneralDialog<void>(
    context: rootContext,
    barrierDismissible: true,
    barrierLabel: 'Dismiss household drawer',
    barrierColor: Colors.transparent,
    transitionDuration: reduced ? Duration.zero : CasamaMotion.drawer,
    pageBuilder: (dialogCtx, animation, secondaryAnimation) {
      return _DrawerOverlayLayout(
        scrimAnimation: animation,
        scrimColor: pal.scrim,
        reducedMotion: reduced,
        child: CasamaHouseholdDrawer(
          hostContext: rootContext,
          onSelectNavTab: onSelectNavTab,
          onSelectBoardTab: onSelectBoardTab,
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => child,
  );
}

class _DrawerOverlayLayout extends StatelessWidget {
  final Animation<double> scrimAnimation;
  final Color scrimColor;
  final bool reducedMotion;
  final Widget child;

  const _DrawerOverlayLayout({
    required this.scrimAnimation,
    required this.scrimColor,
    required this.reducedMotion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scrimCurve = CurvedAnimation(
      parent: scrimAnimation,
      // 200ms scrim fade inside 250ms total drawer transition.
      curve: const Interval(0.0, 0.80, curve: Curves.easeOut),
      reverseCurve: const Interval(0.0, 0.80, curve: Curves.easeIn),
    );
    final slideCurve = CurvedAnimation(
      parent: scrimAnimation,
      curve: CasamaMotion.easeOut,
      reverseCurve: CasamaMotion.easeIn,
    );

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: FadeTransition(
                opacity: reducedMotion
                    ? const AlwaysStoppedAnimation(1.0)
                    : scrimCurve,
                child: ColoredBox(color: scrimColor),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: reducedMotion
                ? child
                : SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1, 0),
                      end: Offset.zero,
                    ).animate(slideCurve),
                    child: child,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Slide-over household navigation drawer with a full-bleed Forest Teal organic
/// wave header, interactive household switcher dropdown, copyable invite code
/// pill, circular [CasMascotView] badge, and `Casama Leaderboard` navigation.
class CasamaHouseholdDrawer extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final ValueChanged<int>? onSelectNavTab;
  final ValueChanged<int>? onSelectBoardTab;

  const CasamaHouseholdDrawer({
    super.key,
    required this.hostContext,
    this.onSelectNavTab,
    this.onSelectBoardTab,
  });

  @override
  ConsumerState<CasamaHouseholdDrawer> createState() =>
      _CasamaHouseholdDrawerState();
}

class _CasamaHouseholdDrawerState extends ConsumerState<CasamaHouseholdDrawer> {
  bool _isSwitcherExpanded = false;
  bool _copiedInviteCode = false;
  String? _switchingHouseholdId;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  void _closeAndRun(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  Future<void> _copyInviteCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    _copiedResetTimer?.cancel();
    setState(() => _copiedInviteCode = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() => _copiedInviteCode = false);
      }
    });
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Invite code $code copied',
        icon: Icons.copy_rounded,
      );
    }
  }

  Future<void> _handleSelectHousehold(Household target, String activeId) async {
    if (_switchingHouseholdId != null) return;
    if (target.id == activeId) {
      setState(() => _isSwitcherExpanded = false);
      return;
    }

    setState(() => _switchingHouseholdId = target.id);
    try {
      await ref.read(repositoryProvider).switchHousehold(target.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Switched to ${target.name}',
          icon: Icons.cottage_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _switchingHouseholdId = null);
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Could not switch to ${target.name}.',
          icon: Icons.error_outline_rounded,
        );
      }
    }
  }

  void _openCreateHouseholdSheet() {
    _closeAndRun(context, () {
      if (widget.hostContext.mounted) {
        showCreateHouseholdSheet(widget.hostContext);
      }
    });
  }

  void _openJoinHouseholdSheet() {
    _closeAndRun(context, () {
      if (widget.hostContext.mounted) {
        showJoinHouseholdSheet(widget.hostContext);
      }
    });
  }

  void _openLeaderboard() {
    _closeAndRun(context, () {
      if (!widget.hostContext.mounted) return;
      final router = GoRouter.maybeOf(widget.hostContext);
      if (router != null) {
        router.push('/leaderboard');
      } else {
        Navigator.of(widget.hostContext).push(
          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final household = repo.currentHousehold;
    final memberCount = repo.members.length;
    final households = repo.userHouseholds.isNotEmpty
        ? repo.userHouseholds
        : [household];
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final drawerWidth = math.min(
      316.0,
      MediaQuery.sizeOf(context).width * 0.84,
    );
    final drawerBg = pal.surface;
    final statusDotColor = context.isDark
        ? CasamaColors.darkTeal
        : const Color(0xFF8CE0BC);

    return SizedBox(
      width: drawerWidth,
      height: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: drawerBg,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(28),
          ),
          border: Border(right: BorderSide(color: pal.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.44 : 0.18),
              blurRadius: 28,
              offset: const Offset(6, 0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Full-Bleed Forest Teal Organic Wave Header
              Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DrawerWaveHeaderPainter(
                        deep: pal.headerDeep,
                        mid: pal.headerMid,
                        bottomBg: drawerBg,
                        ornament: pal.headerOrnament,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPad + 16, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top Row: Space subtitle + member count | Translucent Close button
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: statusDotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      '${household.displaySubtitle} • $memberCount ${memberCount == 1 ? 'member' : 'members'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: pal.headerSubtitle,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              button: true,
                              label: 'Close household menu',
                              child: CasamaPressable(
                                onTap: () => Navigator.of(context).pop(),
                                child: SizedBox(
                                  width: CasamaSpacing.minTouchTarget,
                                  height: CasamaSpacing.minTouchTarget,
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Middle Row: Interactive Household Switcher Dropdown Trigger
                        Semantics(
                          button: true,
                          toggled: _isSwitcherExpanded,
                          label: 'Switch household, ${household.name}',
                          child: CasamaPressable(
                            key: const Key('drawer_household_switcher_trigger'),
                            enableHaptic: true,
                            onTap: () {
                              setState(
                                () => _isSwitcherExpanded = !_isSwitcherExpanded,
                              );
                            },
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      household.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.headlineLarge
                                          ?.copyWith(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.15,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: _isSwitcherExpanded ? 0.5 : 0.0,
                                    duration: CasamaMotion.resolve(
                                      context,
                                      CasamaMotion.listItem,
                                    ),
                                    curve: CasamaMotion.easeOut,
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 24,
                                      color: Colors.white.withValues(alpha: 0.92),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Bottom Row Inside Teal Header: Invite Code Pill | Circular Mascot Badge
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Semantics(
                                  button: true,
                                  container: true,
                                  excludeSemantics: true,
                                  label:
                                      'Copy household invite code ${household.inviteCode}',
                                  child: CasamaPressable(
                                    key: const Key(
                                      'drawer_copy_invite_code_pill',
                                    ),
                                    enableHaptic: true,
                                    onTap: () =>
                                        _copyInviteCode(household.inviteCode),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 40,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius:
                                            CasamaSpacing.roundedPill,
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'INVITE CODE: ',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.82),
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    letterSpacing: 0.4,
                                                  ),
                                            ),
                                            Text(
                                              household.inviteCode,
                                              style: theme
                                                  .textTheme
                                                  .labelMedium
                                                  ?.tabular
                                                  .copyWith(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.9,
                                                  ),
                                            ),
                                            const SizedBox(width: 8),
                                            AnimatedSwitcher(
                                              duration: CasamaMotion.resolve(
                                                context,
                                                CasamaMotion.press,
                                              ),
                                              child: _copiedInviteCode
                                                  ? Row(
                                                      key: const ValueKey(
                                                        'copied_state',
                                                      ),
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          size: 14,
                                                          color: statusDotColor,
                                                        ),
                                                        const SizedBox(
                                                          width: 3,
                                                        ),
                                                        Text(
                                                          'Copied',
                                                          style: theme
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                color:
                                                                    statusDotColor,
                                                                fontSize: 10.5,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                        ),
                                                      ],
                                                    )
                                                  : Icon(
                                                      Icons.copy_rounded,
                                                      key: const ValueKey(
                                                        'copy_state',
                                                      ),
                                                      size: 14,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.88,
                                                          ),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 44,
                              height: 44,
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  width: 1.2,
                                ),
                              ),
                              child: const ClipOval(
                                child: CasMascotView(
                                  pose: CasPose.hero,
                                  width: 36,
                                  height: 36,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2. Drawer Body (Household Switcher Dropdown + Casa Highlights)
              Expanded(
                child: SafeArea(
                  top: false,
                  right: false,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      6,
                      18,
                      math.max(20.0, bottomPad + 14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Expandable Household Switcher Panel
                        if (CasamaMotion.reduceMotion(context))
                          if (_isSwitcherExpanded)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: CasamaSpacing.md,
                              ),
                              child: _HouseholdSwitcherPanel(
                                households: households,
                                activeHouseholdId: household.id,
                                switchingHouseholdId: _switchingHouseholdId,
                                onSelectHousehold: (hh) =>
                                    _handleSelectHousehold(hh, household.id),
                                onCreateNew: _openCreateHouseholdSheet,
                                onJoinByCode: _openJoinHouseholdSheet,
                              ),
                            )
                          else
                            const SizedBox.shrink()
                        else
                          AnimatedSize(
                            duration: CasamaMotion.listItem,
                            curve: CasamaMotion.easeOut,
                            alignment: Alignment.topCenter,
                            child: _isSwitcherExpanded
                                ? Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: CasamaSpacing.md,
                                    ),
                                    child: _HouseholdSwitcherPanel(
                                      households: households,
                                      activeHouseholdId: household.id,
                                      switchingHouseholdId:
                                          _switchingHouseholdId,
                                      onSelectHousehold: (hh) =>
                                          _handleSelectHousehold(
                                            hh,
                                            household.id,
                                          ),
                                      onCreateNew: _openCreateHouseholdSheet,
                                      onJoinByCode: _openJoinHouseholdSheet,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                        // Micro-header
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Text(
                            'CASA HIGHLIGHTS',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: pal.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),

                        // Casama Leaderboard Navigation Item
                        _DrawerHighlightNavCard(
                          icon: Icons.emoji_events_rounded,
                          iconBg: pal.amberBg,
                          iconColor: pal.amberFg,
                          title: 'Casama Leaderboard',
                          subtitle: 'Household standings & point rules',
                          onTap: _openLeaderboard,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HouseholdSwitcherPanel extends StatelessWidget {
  final List<Household> households;
  final String activeHouseholdId;
  final String? switchingHouseholdId;
  final ValueChanged<Household> onSelectHousehold;
  final VoidCallback onCreateNew;
  final VoidCallback onJoinByCode;

  const _HouseholdSwitcherPanel({
    required this.households,
    required this.activeHouseholdId,
    required this.switchingHouseholdId,
    required this.onSelectHousehold,
    required this.onCreateNew,
    required this.onJoinByCode,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Container(
      key: const Key('drawer_household_switcher_panel'),
      decoration: BoxDecoration(
        color: context.isDark ? pal.card : CasamaColors.authCream,
        borderRadius: CasamaSpacing.roundedCard,
        border: Border.all(color: pal.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'YOUR HOUSEHOLDS',
              style: theme.textTheme.labelSmall?.copyWith(
                color: pal.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
          for (var i = 0; i < households.length; i++) ...[
            _HouseholdOptionRow(
              household: households[i],
              isActive: households[i].id == activeHouseholdId,
              isSwitching: switchingHouseholdId == households[i].id,
              onTap: () => onSelectHousehold(households[i]),
            ),
            if (i < households.length - 1)
              Divider(height: 1, indent: 56, color: pal.divider),
          ],
          Divider(height: 1, color: pal.divider),
          _SwitcherActionRow(
            key: const Key('drawer_create_household_action'),
            icon: Icons.add_rounded,
            iconBg: pal.softBlush,
            iconColor: pal.primaryCoral,
            label: 'Create New Household',
            labelColor: pal.primaryCoral,
            onTap: onCreateNew,
          ),
          Divider(height: 1, indent: 56, color: pal.divider),
          _SwitcherActionRow(
            key: const Key('drawer_join_household_action'),
            icon: Icons.vpn_key_outlined,
            iconBg: pal.softSage,
            iconColor: pal.forestTeal,
            label: 'Join with Invite Code',
            labelColor: pal.textPrimary,
            onTap: onJoinByCode,
          ),
        ],
      ),
    );
  }
}

class _HouseholdOptionRow extends StatelessWidget {
  final Household household;
  final bool isActive;
  final bool isSwitching;
  final VoidCallback onTap;

  const _HouseholdOptionRow({
    required this.household,
    required this.isActive,
    required this.isSwitching,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final count = household.memberCount ?? 1;

    return Semantics(
      button: true,
      selected: isActive,
      label: '${household.name}, $count ${count == 1 ? 'member' : 'members'}',
      child: CasamaPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isActive ? pal.forestTeal : pal.softSage,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.cottage_outlined,
                  size: 18,
                  color: isActive ? pal.onForestTeal : pal.forestTeal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      household.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'member' : 'members'} • ${household.inviteCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSwitching)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(pal.forestTeal),
                  ),
                )
              else if (isActive)
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: pal.forestTeal,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitcherActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback onTap;

  const _SwitcherActionRow({
    super.key,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: CasamaPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: labelColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
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

class _DrawerHighlightNavCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerHighlightNavCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: title,
      child: CasamaPressable.card(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: CasamaSpacing.roundedLg,
            border: Border.all(color: pal.border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: pal.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: pal.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: pal.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerWaveHeaderPainter extends CustomPainter {
  final Color deep;
  final Color mid;
  final Color bottomBg;
  final Color ornament;

  const _DrawerWaveHeaderPainter({
    required this.deep,
    required this.mid,
    required this.bottomBg,
    required this.ornament,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base Forest Teal fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = deep,
    );

    // 2. Subtle celestial gold orbital ornament
    final center = Offset(w - 28, 36);
    final ringPaint = Paint()
      ..color = ornament
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(center, 46, ringPaint);
    canvas.drawCircle(
      center,
      28,
      ringPaint..color = ornament.withValues(alpha: ornament.a * 0.65),
    );

    // 3. Soft sage wave accent
    final sageWave = Path()
      ..moveTo(0, h - 24)
      ..cubicTo(w * 0.34, h - 38, w * 0.68, h - 8, w, h - 24)
      ..lineTo(w, h + 1)
      ..lineTo(0, h + 1)
      ..close();
    canvas.drawPath(sageWave, Paint()..color = mid.withValues(alpha: 0.45));

    // 4. Organic wave transition into drawer body surface
    final bottomWave = Path()
      ..moveTo(0, h - 14)
      ..cubicTo(w * 0.36, h - 26, w * 0.70, h - 2, w, h - 14)
      ..lineTo(w, h + 1)
      ..lineTo(0, h + 1)
      ..close();
    canvas.drawPath(bottomWave, Paint()..color = bottomBg);
  }

  @override
  bool shouldRepaint(covariant _DrawerWaveHeaderPainter oldDelegate) {
    return oldDelegate.deep != deep ||
        oldDelegate.mid != mid ||
        oldDelegate.bottomBg != bottomBg ||
        oldDelegate.ornament != ornament;
  }
}
