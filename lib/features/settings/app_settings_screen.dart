import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../profile/edit_profile_dialog.dart';

class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final currentThemeMode = ref.watch(themeModeProvider);
    final repo = ref.watch(repositoryProvider);
    final households = repo.userHouseholds.isNotEmpty
        ? repo.userHouseholds
        : (repo.hasActiveHousehold
            ? [repo.currentHousehold.copyWith(memberCount: repo.members.length)]
            : const <Household>[]);
    final residencySubtitle = households.isEmpty
        ? 'Not in a household yet'
        : households.map((h) => h.name).join(', ');
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset + CasamaSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CasamaWaveHeader(
                title: 'Settings',
                subtitle: repo.hasActiveHousehold &&
                        repo.currentHousehold.name.trim().isNotEmpty
                    ? '${repo.currentHousehold.name} • Account & Preferences'
                    : 'Account & Preferences',
                titleMascotPose: CasPose.settings,
                titleMascotSize: 70,
                extendedWave: true,
                bottomPaddingOffset: 4,
                onBackTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    GoRouter.maybeOf(context)?.pop();
                  }
                },
              ),

              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Account Settings
                        const _SettingsSectionHeader(title: 'Account Settings'),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SettingsActionRow(
                                icon: Icons.person_outline_rounded,
                                iconColor: pal.primaryCoral,
                                iconBg: pal.softBlush,
                                title: 'Edit Profile',
                                subtitle: () {
                                  final u = repo.currentUser;
                                  final full = u.effectiveFullName;
                                  return full.isNotEmpty &&
                                          full != u.preferredName
                                      ? '${u.preferredName} • $full'
                                      : u.preferredName;
                                }(),
                                onTap: () => _showEditProfileModal(context),
                              ),
                              Divider(height: 1, indent: 64, color: pal.divider),
                              _SettingsActionRow(
                                icon: Icons.lock_outline_rounded,
                                iconColor: pal.forestTeal,
                                iconBg: pal.softSage,
                                title: 'Change Password',
                                subtitle: 'Update authentication credentials',
                                onTap: () => _showChangePasswordDialog(context),
                              ),
                              Divider(height: 1, indent: 64, color: pal.divider),
                              _SettingsActionRow(
                                icon: Icons.home_work_outlined,
                                iconColor: pal.infoFg,
                                iconBg: pal.infoBg,
                                title: 'Residency',
                                subtitle: residencySubtitle,
                                onTap: () => _showResidencySheet(context),
                              ),
                              Divider(height: 1, indent: 64, color: pal.divider),
                              _SettingsActionRow(
                                icon: Icons.logout_rounded,
                                iconColor: pal.dangerFg,
                                iconBg: pal.dangerBg,
                                title: 'Log Out',
                                titleColor: pal.dangerFg,
                                subtitle: 'Sign out of your active Casama session',
                                onTap: () => _confirmLogout(context, repo),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.lg),

                        // 2. Appearance (Light / Dark / System)
                        const _SettingsSectionHeader(title: 'Appearance'),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theme Mode',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose your preferred visual theme across the application:',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12.5,
                                  color: pal.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ThemeChoiceTile(
                                      icon: Icons.light_mode_outlined,
                                      label: 'Light',
                                      isSelected:
                                          currentThemeMode == ThemeMode.light,
                                      onTap: () => ref
                                          .read(themeModeProvider.notifier)
                                          .setThemeMode(ThemeMode.light),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ThemeChoiceTile(
                                      icon: Icons.dark_mode_outlined,
                                      label: 'Dark',
                                      isSelected:
                                          currentThemeMode == ThemeMode.dark,
                                      onTap: () => ref
                                          .read(themeModeProvider.notifier)
                                          .setThemeMode(ThemeMode.dark),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _ThemeChoiceTile(
                                      icon: Icons.brightness_auto_outlined,
                                      label: 'System',
                                      isSelected:
                                          currentThemeMode == ThemeMode.system,
                                      onTap: () => ref
                                          .read(themeModeProvider.notifier)
                                          .setThemeMode(ThemeMode.system),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.lg),

                        // 3. Privacy and Security
                        const _SettingsSectionHeader(
                          title: 'Privacy and Security',
                        ),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SettingsActionRow(
                                icon: Icons.perm_device_information_outlined,
                                iconColor: pal.forestTeal,
                                iconBg: pal.softSage,
                                title: 'Application Permissions',
                                subtitle:
                                    'Camera, photos & local device access status',
                                onTap: () => GoRouter.maybeOf(
                                  context,
                                )?.push('/permissions?fromSettings=true'),
                              ),
                              Divider(height: 1, indent: 64, color: pal.divider),
                              _SettingsActionRow(
                                icon: Icons.policy_outlined,
                                iconColor: pal.infoFg,
                                iconBg: pal.infoBg,
                                title: 'Terms of Service & Privacy Policy',
                                subtitle:
                                    'Zero GPS tracking • Terms & privacy policy',
                                onTap: () => GoRouter.maybeOf(
                                  context,
                                )?.push('/terms?readOnly=true'),
                              ),
                            ],
                          ),
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

  void _showResidencySheet(BuildContext context) {
    showCasamaSheet<void>(
      context,
      icon: Icons.home_work_outlined,
      title: 'Residency',
      subtitle: 'Households you belong to',
      builder: (_) => _ResidencySheetBody(hostContext: context),
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

  void _showChangePasswordDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showCasamaSheet<void>(
      context,
      icon: Icons.lock_reset_rounded,
      title: 'Change Password',
      subtitle: 'Update your account authentication credentials',
      builder: (ctx) {
        return Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CasamaTextField(
                controller: oldPasswordController,
                label: 'Current Password',
                hint: '••••••••',
                isPassword: true,
                prefixIcon: Icons.lock_outline,
                validator: (v) => v == null || v.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.sm),
              CasamaTextField(
                controller: newPasswordController,
                label: 'New Password',
                hint: '••••••••',
                isPassword: true,
                prefixIcon: Icons.lock_reset_rounded,
                validator: (v) => v == null || v.length < 6
                    ? 'New password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.sm),
              CasamaTextField(
                controller: confirmPasswordController,
                label: 'Confirm New Password',
                hint: '••••••••',
                isPassword: true,
                prefixIcon: Icons.check_circle_outline,
                validator: (v) => v != newPasswordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: CasamaSpacing.lg),
              CasamaButton(
                label: 'Update Password',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx);
                    showCasamaToast(
                      context,
                      'Password updated successfully! 🔒',
                      icon: Icons.lock_outline_rounded,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmLogout(BuildContext context, CasamaRepository repo) {
    final pal = context.palette;
    final theme = Theme.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: pal.surface,
        shape: RoundedRectangleBorder(
          borderRadius: CasamaSpacing.roundedCard,
        ),
        title: Text(
          'Log Out of Casama?',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to end your current session? You will need to log back in to access your household.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: pal.textSecondary,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: pal.dangerFg,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              repo.logout();
              GoRouter.maybeOf(context)?.go('/');
            },
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Text(
      title,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: pal.textSecondary,
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? pal.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: pal.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: titleColor ?? pal.textMuted,
            ),
        ],
      ),
    );

    if (onTap != null) {
      return CasamaPressable(onTap: onTap, child: row);
    }
    return row;
  }
}

class _ThemeChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChoiceTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final reduced = CasamaMotion.reduceMotion(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label theme',
      child: CasamaPressable(
        onTap: onTap,
        enableHaptic: true,
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : CasamaMotion.press,
          curve: CasamaMotion.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? pal.primaryCoral : pal.track,
            borderRadius: CasamaSpacing.roundedMd,
            border: Border.all(
              color: isSelected ? pal.primaryCoral : pal.border,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? pal.onPrimaryCoral : pal.textPrimary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? pal.onPrimaryCoral : pal.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResidencySheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _ResidencySheetBody({required this.hostContext});

  @override
  ConsumerState<_ResidencySheetBody> createState() =>
      _ResidencySheetBodyState();
}

class _ResidencySheetBodyState extends ConsumerState<_ResidencySheetBody> {
  String? _switchingHouseholdId;

  Future<void> _handleSelect(Household target, bool isActive) async {
    if (_switchingHouseholdId != null) return;
    if (isActive) {
      Navigator.of(context).pop();
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
    } catch (_) {
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

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final reduced = CasamaMotion.reduceMotion(context);
    final repo = ref.watch(repositoryProvider);
    final households = repo.userHouseholds.isNotEmpty
        ? repo.userHouseholds
        : (repo.hasActiveHousehold
            ? [repo.currentHousehold.copyWith(memberCount: repo.members.length)]
            : const <Household>[]);

    if (households.isEmpty) {
      return CasamaCard(
        child: Text(
          "You aren't a member of any household yet.",
          style: theme.textTheme.bodyMedium?.copyWith(color: pal.textSecondary),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < households.length; i++) ...[
          if (i > 0) const SizedBox(height: CasamaSpacing.sm),
          Builder(
            builder: (ctx) {
              final h = households[i];
              final isActive =
                  repo.hasActiveHousehold && h.id == repo.currentHousehold.id;
              final isSwitching = _switchingHouseholdId == h.id;
              final count = isActive
                  ? (h.memberCount ?? repo.members.length)
                  : h.memberCount;
              final countPart = count != null
                  ? '$count ${count == 1 ? 'member' : 'members'} • '
                  : '';
              final metaText = '${countPart}Code: ${h.inviteCode}';

              return Semantics(
                button: true,
                selected: isActive,
                label: '${h.name}, $metaText${isActive ? ', Active' : ''}',
                child: CasamaPressable(
                  onTap: () => _handleSelect(h, isActive),
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: CasamaSpacing.minTouchTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isActive ? pal.softSage : pal.card,
                      borderRadius: CasamaSpacing.roundedLg,
                      border: Border.all(
                        color: isActive ? pal.forestTeal : pal.border,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive ? pal.forestTeal : pal.track,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.cottage_rounded,
                            size: 20,
                            color: isActive
                                ? pal.onForestTeal
                                : pal.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                h.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                metaText,
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
                        const SizedBox(width: 8),
                        if (isSwitching)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: reduced
                                ? Icon(
                                    Icons.hourglass_top_rounded,
                                    size: 18,
                                    color: pal.forestTeal,
                                  )
                                : CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: pal.forestTeal,
                                  ),
                          )
                        else if (isActive)
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
                              'Active',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: pal.successFg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: pal.textMuted,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
