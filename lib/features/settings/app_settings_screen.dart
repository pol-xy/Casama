import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/theme_provider.dart';
import '../../data/casama_repository.dart';
import '../../data/repository_provider.dart';
import '../../data/supabase_config.dart';
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
  bool _shareRoomStatus = true;

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final currentThemeMode = ref.watch(themeModeProvider);
    final repo = ref.watch(repositoryProvider);
    final notifs = repo.notificationPreferences;
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
                subtitle: '${repo.currentHousehold.name} • Account & Preferences',
                compact: true,
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
                                subtitle:
                                    '${repo.currentUser.displayName} (${repo.currentUser.handle})',
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
                                icon: Icons.badge_outlined,
                                iconColor: pal.infoFg,
                                iconBg: pal.infoBg,
                                title: 'Manage Account',
                                subtitle:
                                    'Verified Resident • ${repo.currentHousehold.name}',
                                trailing: Container(
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
                                ),
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

                        // 3. Notification Settings (4 Switch widgets)
                        const _SettingsSectionHeader(
                          title: 'Notification Settings',
                        ),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          padding: EdgeInsets.zero,
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: Text(
                                    'Household Updates',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: pal.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Member presence, housemate joins, and announcements',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  value: notifs.householdUpdates,
                                  activeTrackColor: pal.primaryCoral,
                                  onChanged: (v) => repo
                                      .updateNotificationPreferences(
                                        householdUpdates: v,
                                      ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: pal.divider,
                                ),
                                SwitchListTile(
                                  title: Text(
                                    'Parcel & Delivery Alerts',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: pal.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'When packages arrive or COD payment is needed',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  value: notifs.parcelNotifications,
                                  activeTrackColor: pal.primaryCoral,
                                  onChanged: (v) => repo
                                      .updateNotificationPreferences(
                                        parcelNotifications: v,
                                      ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: pal.divider,
                                ),
                                SwitchListTile(
                                  title: Text(
                                    'Task & Chore Reminders',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: pal.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'When maintenance chores are assigned or due',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  value: notifs.taskReminders,
                                  activeTrackColor: pal.primaryCoral,
                                  onChanged: (v) => repo
                                      .updateNotificationPreferences(
                                        taskReminders: v,
                                      ),
                                ),
                                Divider(
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                  color: pal.divider,
                                ),
                                SwitchListTile(
                                  title: Text(
                                    'Chat & Meet-up Notifications',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: pal.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Group messages, direct chats, and meet-up invites',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  value: notifs.chatNotifications,
                                  activeTrackColor: pal.primaryCoral,
                                  onChanged: (v) => repo
                                      .updateNotificationPreferences(
                                        chatNotifications: v,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.lg),

                        // 4. Privacy and Security (1 Switch widget = 5 total)
                        const _SettingsSectionHeader(
                          title: 'Privacy and Security',
                        ),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          padding: EdgeInsets.zero,
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              children: [
                                SwitchListTile(
                                  title: Text(
                                    'Presence & Status Sharing',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: pal.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Share active room notes with verified housemates',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 12,
                                      color: pal.textSecondary,
                                    ),
                                  ),
                                  value: _shareRoomStatus,
                                  activeTrackColor: pal.primaryCoral,
                                  onChanged: (v) =>
                                      setState(() => _shareRoomStatus = v),
                                ),
                              Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                                color: pal.divider,
                              ),
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
                                icon: Icons.security_outlined,
                                iconColor: pal.successFg,
                                iconBg: pal.successBg,
                                title: 'Account Security & Two-Factor',
                                subtitle:
                                    'Protected via encrypted Supabase Auth session',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.successBg,
                                    borderRadius: CasamaSpacing.roundedPill,
                                  ),
                                  child: Text(
                                    'Secured',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: pal.successFg,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              Divider(height: 1, indent: 64, color: pal.divider),
                              _SettingsActionRow(
                                icon: Icons.policy_outlined,
                                iconColor: pal.infoFg,
                                iconBg: pal.infoBg,
                                title: 'Privacy Policy',
                                subtitle:
                                    'Zero GPS background tracking guarantee',
                                onTap: () => GoRouter.maybeOf(
                                  context,
                                )?.push('/terms?readOnly=true'),
                              ),
                            ],
                          ),
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.lg),

                        // 5. About Casama
                        const _SettingsSectionHeader(title: 'About Casama'),
                        const SizedBox(height: CasamaSpacing.xs),
                        CasamaCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: pal.headerDeep,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cottage_rounded,
                                      color: Colors.white,
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
                                          'Casama',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: pal.textPrimary,
                                              ),
                                        ),
                                        Text(
                                          'Version 1.0.0 (Build 1)',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontSize: 12,
                                                color: pal.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Making shared living simpler, warmer, and more coordinated.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: pal.textSecondary,
                                ),
                              ),
                              Divider(height: 22, color: pal.divider),
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    TextButton(
                                      onPressed: () => GoRouter.maybeOf(
                                        context,
                                      )?.push('/terms?readOnly=true'),
                                      child: Text(
                                        'Terms of Service',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: pal.primaryCoral,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => GoRouter.maybeOf(
                                        context,
                                      )?.push('/terms?readOnly=true'),
                                      child: Text(
                                        'Privacy Policy',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: pal.primaryCoral,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.md),

                        // Diagnostics & Cache Reset
                        CasamaCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Backend Engine',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontSize: 13,
                                        color: pal.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SupabaseConfig.isConfigured
                                          ? pal.successBg
                                          : pal.warningBg,
                                      borderRadius: CasamaSpacing.roundedPill,
                                    ),
                                    child: Text(
                                      SupabaseConfig.isConfigured
                                          ? 'Live Supabase'
                                          : 'High-Fidelity Mock Mode',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: SupabaseConfig.isConfigured
                                                ? pal.successFg
                                                : pal.warningFg,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              CasamaButton(
                                label: 'Reset Offline Cache',
                                style: CasamaButtonStyle.secondary,
                                height: 44,
                                onPressed: () {
                                  showCasamaToast(
                                    context,
                                    'Local cache reset successfully!',
                                    icon: Icons.check_circle_outline_rounded,
                                  );
                                },
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
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
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
          if (trailing != null)
            trailing!
          else if (onTap != null)
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
