import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/cas_mascot_view.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../household/add_housemate_dialog.dart';

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

/// Slide-over household navigation drawer (`casama-app-mockup.html`) with
/// user & household header, copyable invite code pill, primary links, and
/// unframed transparent PNG `CasMascotView`.
class CasamaHouseholdDrawer extends ConsumerWidget {
  final BuildContext hostContext;
  final ValueChanged<int>? onSelectNavTab;
  final ValueChanged<int>? onSelectBoardTab;

  const CasamaHouseholdDrawer({
    super.key,
    required this.hostContext,
    this.onSelectNavTab,
    this.onSelectBoardTab,
  });

  void _closeAndRun(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final user = repo.currentUser;
    final household = repo.currentHousehold;
    final memberCount = repo.members.length;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final drawerWidth = math.min(
      316.0,
      MediaQuery.sizeOf(context).width * 0.84,
    );

    return SizedBox(
      width: drawerWidth,
      height: double.infinity,
      child: Container(
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(28),
          ),
          border: Border(right: BorderSide(color: pal.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.42 : 0.16),
              blurRadius: 28,
              offset: const Offset(6, 0),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          right: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              topPad + 20,
              20,
              math.max(16.0, bottomPad + 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User & Household Header
                Row(
                  children: [
                    CasamaAvatar(
                      radius: 24,
                      avatarUrl: user.avatarUrl,
                      name: user.displayName,
                      borderWidth: 1.5,
                      borderColor: pal.border,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.fullName?.isNotEmpty == true
                                ? user.fullName!
                                : user.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${household.name} • $memberCount members',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textSecondary,
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
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: pal.track,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: CasamaSpacing.md),

                // Copyable Invite Code Pill
                Semantics(
                  button: true,
                  container: true,
                  excludeSemantics: true,
                  label: 'Copy household invite code ${household.inviteCode}',
                  child: CasamaPressable(
                    enableHaptic: true,
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: household.inviteCode),
                      );
                      if (hostContext.mounted) {
                        showCasamaToast(
                          hostContext,
                          'Invite code ${household.inviteCode} copied',
                          icon: Icons.copy_rounded,
                        );
                      }
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: pal.softSage,
                        borderRadius: CasamaSpacing.roundedLg,
                        border: Border.all(color: pal.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: pal.forestTeal.withValues(alpha: 0.14),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.vpn_key_outlined,
                              size: 17,
                              color: pal.forestTeal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'HOUSEHOLD INVITE CODE',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: pal.textSecondary,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  household.inviteCode,
                                  style: theme.textTheme.titleMedium?.tabular
                                      .copyWith(
                                        color: pal.forestTeal,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: pal.surface,
                              borderRadius: CasamaSpacing.roundedPill,
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: pal.forestTeal,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: pal.forestTeal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: CasamaSpacing.md),

                // Scrollable navigation list
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _DrawerNavRow(
                          icon: Icons.person_add_outlined,
                          title: 'Invite Housemate',
                          subtitle: 'Share code or search roommates',
                          onTap: () => _closeAndRun(context, () {
                            if (hostContext.mounted) {
                              showAddHousemateDialog(hostContext);
                            }
                          }),
                        ),
                        _DrawerNavRow(
                          icon: Icons.cottage_outlined,
                          title: 'My Household',
                          subtitle: 'Manage roommates & Kasama stats',
                          onTap: () => _closeAndRun(context, () {
                            if (onSelectNavTab != null) {
                              onSelectNavTab!(4);
                            } else if (GoRouter.maybeOf(hostContext) != null) {
                              hostContext.go('/profile');
                            }
                          }),
                        ),
                        _DrawerNavRow(
                          icon: Icons.dashboard_outlined,
                          title: 'Household Boards',
                          subtitle: 'Parcels, Tasks, Bills & Items',
                          onTap: () => _closeAndRun(context, () {
                            if (onSelectBoardTab != null) {
                              onSelectBoardTab!(0);
                            } else if (onSelectNavTab != null) {
                              onSelectNavTab!(1);
                            } else if (GoRouter.maybeOf(hostContext) != null) {
                              hostContext.go('/boards');
                            }
                          }),
                        ),
                        _DrawerNavRow(
                          icon: Icons.settings_outlined,
                          title: 'App Settings',
                          subtitle: 'Theme, notifications & account',
                          onTap: () => _closeAndRun(context, () {
                            if (GoRouter.maybeOf(hostContext) != null) {
                              hostContext.push('/settings');
                            }
                          }),
                        ),
                        _DrawerNavRow(
                          icon: Icons.verified_user_outlined,
                          title: 'Privacy & Permissions',
                          subtitle: 'Zero GPS tracking • Terms & policy',
                          onTap: () => _closeAndRun(context, () {
                            if (GoRouter.maybeOf(hostContext) != null) {
                              hostContext.push('/permissions?fromSettings=true');
                            }
                          }),
                        ),
                      ],
                    ),
                  ),
                ),

                // Unframed transparent PNG Mascot Footer (no box or drop shadow)
                const SizedBox(height: CasamaSpacing.sm),
                const Center(
                  child: IgnorePointer(
                    child: CasMascotView(
                      pose: CasPose.hero,
                      width: 88,
                      height: 88,
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

class _DrawerNavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerNavRow({
    required this.icon,
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
      child: CasamaPressable(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pal.softSage,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: pal.forestTeal),
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
                      const SizedBox(height: 1),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
