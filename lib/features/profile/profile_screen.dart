import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../dashboard/main_navigation_shell.dart';
import '../dashboard/widgets/casama_household_drawer.dart';
import 'edit_profile_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _openDrawer(BuildContext context) {
    final shell = CasamaShellScope.maybeOf(context);
    if (shell != null) {
      shell.openDrawer();
      return;
    }
    showCasamaHouseholdDrawer(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final user = repo.currentUser;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    final primaryName = user.preferredName;
    final displayName =
        (user.fullName != null && user.fullName!.trim().isNotEmpty)
        ? user.fullName!.trim()
        : user.preferredName;
    final nicknameText =
        user.nickname != null && user.nickname!.trim().isNotEmpty
        ? user.nickname!.trim()
        : 'Not set';
    final birthdayText = user.birthday != null
        ? '${DateFormat('MMM d, y').format(user.birthday!)}${user.computedAge != null ? ' (${user.computedAge} yrs)' : ''}'
        : 'Not specified';

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
                title: 'Profile',
                subtitle: repo.hasActiveHousehold
                    ? '${repo.currentHousehold.name} • Member'
                    : 'No household yet',
                showNotificationBell: true,
                onMenuTap: () => _openDrawer(context),
              ),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Centered Coral-Ringed Avatar w/ Transparent PNG Mascot Tucked Behind Rim
                      Transform.translate(
                        offset: const Offset(0, -14),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 96,
                              height: 96,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Positioned(
                                    top: -22,
                                    right: -28,
                                    child: IgnorePointer(
                                      child: Transform.rotate(
                                        angle: 14 * math.pi / 180,
                                        child: const CasMascotView(
                                          pose: CasPose.standing,
                                          width: 68,
                                          height: 68,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Semantics(
                                    button: true,
                                    label: 'Edit profile photo',
                                    child: CasamaPressable(
                                      onTap: () =>
                                          _showEditProfileModal(context),
                                      child: Container(
                                        width: 92,
                                        height: 92,
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: pal.coralFab,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: pal.surface,
                                            shape: BoxShape.circle,
                                          ),
                                          child: CasamaAvatar(
                                            avatarUrl: user.avatarUrl,
                                            radius: 42,
                                            name: primaryName,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: IgnorePointer(
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: pal.primaryCoral,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: pal.surface,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.photo_camera_rounded,
                                          color: pal.onPrimaryCoral,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            Text(
                              primaryName,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              displayName != primaryName
                                  ? '$displayName • ${user.handle} • ${repo.hasActiveHousehold ? repo.currentHousehold.name : 'No household yet'}'
                                  : '${user.handle} • ${repo.hasActiveHousehold ? repo.currentHousehold.name : 'No household yet'}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 13.5,
                                color: pal.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),

                            CasamaButton(
                              label: 'Edit Profile',
                              icon: Icons.edit_outlined,
                              style: CasamaButtonStyle.secondary,
                              isFullWidth: false,
                              height: 44,
                              onPressed: () => _showEditProfileModal(context),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CasamaSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 3. Good Kasama Points Card (Opens Audit Trail Sheet)
                            CasamaCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              onTap: () => _showPointsAuditSheet(
                                context,
                                repo.pointHistory,
                                repo.kasamaPoints,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: pal.amberBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.military_tech_rounded,
                                      color: pal.amberFg,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Good Kasama Points',
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                                color: pal.textSecondary,
                                                letterSpacing: 0.4,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              repo.hasActiveHousehold
                                                  ? '${repo.kasamaPoints} pts'
                                                  : '0 pts',
                                              style: theme
                                                  .textTheme
                                                  .titleLarge
                                                  ?.tabular
                                                  .copyWith(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w700,
                                                    color: pal.textPrimary,
                                                  ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 9,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: repo.hasActiveHousehold
                                                    ? pal.amberBg
                                                    : pal.track,
                                                borderRadius:
                                                    CasamaSpacing.roundedPill,
                                                border: Border.all(
                                                  color: (repo.hasActiveHousehold
                                                          ? pal.amberFg
                                                          : pal.textMuted)
                                                      .withValues(alpha: 0.35),
                                                ),
                                              ),
                                              child: Text(
                                                repo.hasActiveHousehold
                                                    ? 'Gold Tier'
                                                    : 'No household yet',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: repo.hasActiveHousehold
                                                          ? pal.amberFg
                                                          : pal.textSecondary,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          repo.hasActiveHousehold
                                              ? 'View leaderboard & points history'
                                              : 'Join or create a household to earn points',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: pal.forestTeal,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (repo.hasActiveHousehold)
                                    IconButton(
                                    tooltip: 'Casama Leaderboard',
                                    icon: Icon(
                                      Icons.chevron_right_rounded,
                                      color: pal.textSecondary,
                                    ),
                                    onPressed: () {
                                      final router = GoRouter.maybeOf(context);
                                      if (router != null) {
                                        router.push('/leaderboard');
                                      } else {
                                        _showPointsAuditSheet(
                                          context,
                                          repo.pointHistory,
                                          repo.kasamaPoints,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.md),

                            // 4. Personal Information Card
                            CasamaCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Personal Information',
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: pal.textPrimary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () =>
                                            _showEditProfileModal(context),
                                        child: Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: pal.primaryCoral,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(height: 1, color: pal.divider),
                                  _InfoRow(
                                    label: 'Full Name',
                                    value: displayName,
                                  ),
                                  Divider(height: 1, color: pal.divider),
                                  _InfoRow(
                                    label: 'Nickname',
                                    value: nicknameText,
                                  ),
                                  Divider(height: 1, color: pal.divider),
                                  _InfoRow(
                                    label: 'Birthday',
                                    value: birthdayText,
                                  ),
                                  Divider(height: 1, color: pal.divider),
                                  _InfoRow(
                                    label: 'Handle',
                                    value: user.handle,
                                    isLast: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.md),

                            // 5. Account & Preferences Menu Card
                            CasamaCard(
                              padding: EdgeInsets.zero,
                              child: Column(
                                children: [
                                  _ProfileMenuRow(
                                    icon: Icons.settings_outlined,
                                    title: 'Application Settings',
                                    subtitle:
                                        'Appearance, notifications & account',
                                    onTap: () => GoRouter.maybeOf(
                                      context,
                                    )?.push('/settings'),
                                  ),
                                  Divider(
                                    height: 1,
                                    indent: 64,
                                    color: pal.divider,
                                  ),
                                  _ProfileMenuRow(
                                    icon: Icons.verified_user_outlined,
                                    title: 'Privacy & Permissions',
                                    subtitle:
                                        'Zero GPS tracking • Terms & policy',
                                    onTap: () => GoRouter.maybeOf(
                                      context,
                                    )?.push('/terms?readOnly=true'),
                                  ),
                                  Divider(
                                    height: 1,
                                    indent: 64,
                                    color: pal.divider,
                                  ),
                                  _ProfileMenuRow(
                                    icon: Icons.info_outline_rounded,
                                    title: 'About Casama',
                                    subtitle: 'v1.0.0 (Build 1)',
                                    onTap: () => _showAboutModal(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.lg),

                            // 6. Destructive Log Out Action
                            CasamaButton(
                              label: 'Log Out',
                              icon: Icons.logout_rounded,
                              style: CasamaButtonStyle.destructive,
                              onPressed: () {
                                ref.read(repositoryProvider).logout();
                                GoRouter.maybeOf(context)?.go('/');
                              },
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

  void _showPointsAuditSheet(
    BuildContext context,
    List<PointAuditEntry> history,
    int totalPoints,
  ) {
    showCasamaSheet<void>(
      context,
      icon: Icons.military_tech_rounded,
      title: 'Kasama Points Ledger',
      subtitle: 'Total Balance: $totalPoints pts',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        final listH = (MediaQuery.sizeOf(ctx).height * 0.48).clamp(240.0, 440.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recent Activity & Points Earned',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: CasamaSpacing.xs),
            SizedBox(
              height: listH,
              child: ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: pal.divider),
                itemBuilder: (context, index) {
                  final item = history[index];
                  final dateStr = DateFormat('MMM d, h:mm a')
                      .format(item.timestamp);

                  final IconData icon;
                  final Color iconColor;
                  final Color iconBg;
                  switch (item.category) {
                    case 'parcel':
                      icon = Icons.local_shipping_outlined;
                      iconColor = pal.primaryCoral;
                      iconBg = pal.softBlush;
                      break;
                    case 'task':
                      icon = Icons.check_circle_outline_rounded;
                      iconColor = pal.successFg;
                      iconBg = pal.successBg;
                      break;
                    case 'lost_found':
                      icon = Icons.search_rounded;
                      iconColor = pal.forestTeal;
                      iconBg = pal.softSage;
                      break;
                    default:
                      icon = Icons.stars_rounded;
                      iconColor = pal.amberFg;
                      iconBg = pal.amberBg;
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
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
                              Text(
                                item.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: pal.textPrimary,
                                ),
                              ),
                              Text(
                                dateStr,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: pal.successBg,
                            borderRadius: CasamaSpacing.roundedPill,
                          ),
                          child: Text(
                            '+${item.points} pts',
                            style: theme.textTheme.labelSmall?.tabular.copyWith(
                              color: pal.successFg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAboutModal(BuildContext context) {
    showCasamaSheet<void>(
      context,
      icon: Icons.info_outline_rounded,
      title: 'Casama & Cas the Owl',
      subtitle: 'Version 1.0.0 (Build 1)',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CasMascotView(pose: CasPose.hero, width: 108, height: 108),
            const SizedBox(height: CasamaSpacing.sm),
            Text(
              '"A better home starts with being a good kasama."',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(height: CasamaSpacing.sm),
            Text(
              'Casama provides one organized place for household members to coordinate presence, deliveries, shared items, maintenance, and small responsibilities.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditProfileModal(BuildContext context) {
    final reduced = CasamaMotion.reduceMotion(context);
    final pal = context.palette;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Edit Profile',
      barrierColor: pal.scrim,
      transitionDuration: reduced ? Duration.zero : CasamaMotion.sheet,
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: CasamaBreakpoints.maxSheetWidth,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.92,
            ),
            child: const Material(
              type: MaterialType.transparency,
              child: EditProfileDialog(),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        if (reduced) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: CasamaMotion.easeOut,
          reverseCurve: CasamaMotion.easeIn,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: 11, bottom: isLast ? 2 : 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: pal.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    this.subtitle,
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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: pal.softSage,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: pal.forestTeal, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
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
            Icon(
              Icons.chevron_right_rounded,
              color: pal.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
