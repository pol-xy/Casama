import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_wave_header.dart';
import '../auth/widgets/auth_wave_header.dart';

class DevicePermissionsScreen extends ConsumerStatefulWidget {
  final bool isOnboarding;

  const DevicePermissionsScreen({super.key, this.isOnboarding = true});

  @override
  ConsumerState<DevicePermissionsScreen> createState() =>
      _DevicePermissionsScreenState();
}

class _DevicePermissionsScreenState
    extends ConsumerState<DevicePermissionsScreen> {
  late bool _notificationsAllowed;
  bool _cameraPhotosAllowed = true;
  bool _contactsAllowed = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOnboarding) {
      _notificationsAllowed = true;
    } else {
      final prefs = ref.read(repositoryProvider).notificationPreferences;
      _notificationsAllowed =
          prefs.householdUpdates ||
          prefs.parcelNotifications ||
          prefs.taskReminders ||
          prefs.chatNotifications;
    }
  }

  void _savePreferences(bool notifications) {
    ref
        .read(repositoryProvider)
        .updateNotificationPreferences(
          householdUpdates: notifications,
          parcelNotifications: notifications,
          taskReminders: notifications,
          chatNotifications: notifications,
        );
  }

  void _continue() {
    _savePreferences(_notificationsAllowed);
    if (!widget.isOnboarding) {
      showCasamaToast(
        context,
        'Permission preferences updated',
        icon: Icons.check_circle_outline_rounded,
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/settings');
      }
      return;
    }
    context.push('/intro');
  }

  void _skipAll() {
    setState(() {
      _notificationsAllowed = false;
      _cameraPhotosAllowed = false;
      _contactsAllowed = false;
    });
    _savePreferences(false);
    context.push('/intro');
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaAuthShell(
      stepLabel: widget.isOnboarding ? 'Step 4 of 4' : null,
      skipLabel: widget.isOnboarding ? 'Skip All' : null,
      onSkip: widget.isOnboarding ? _skipAll : null,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(widget.isOnboarding ? '/household-setup' : '/settings');
        }
      },
      mascotPose: CasPose.standing,
      mascotAlignment: Alignment.bottomRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Device Permissions',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Casama requests only what supports household coordination. You can toggle or adjust these anytime.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          _buildPermissionTile(
            context: context,
            icon: Icons.notifications_active_outlined,
            iconBg: pal.softBlush,
            iconColor: pal.primaryCoral,
            title: 'Push Notifications',
            badge: 'Recommended',
            isRecommended: true,
            reason:
                'Receive timely alerts when deliveries arrive, bills need attention, or housemates post updates.',
            value: _notificationsAllowed,
            onChanged: (val) => setState(() => _notificationsAllowed = val),
          ),
          const SizedBox(height: CasamaSpacing.md),

          _buildPermissionTile(
            context: context,
            icon: Icons.photo_camera_outlined,
            iconBg: pal.softSage,
            iconColor: pal.forestTeal,
            title: 'Camera & Photo Library',
            badge: 'Recommended',
            isRecommended: true,
            reason:
                'Capture CASnap moments, photograph parcel delivery slips, or attach photos for household items.',
            value: _cameraPhotosAllowed,
            onChanged: (val) => setState(() => _cameraPhotosAllowed = val),
          ),
          const SizedBox(height: CasamaSpacing.md),

          _buildPermissionTile(
            context: context,
            icon: Icons.contacts_outlined,
            iconBg: pal.infoBg,
            iconColor: pal.infoFg,
            title: 'Contacts Assistance',
            badge: 'Optional',
            isRecommended: false,
            reason:
                'Quickly invite housemates from your contact list using your household invite code.',
            value: _contactsAllowed,
            onChanged: (val) => setState(() => _contactsAllowed = val),
          ),
          const SizedBox(height: CasamaSpacing.xl),

          CasamaButton(
            label: 'Save & Continue',
            isPill: true,
            height: 50,
            onPressed: _continue,
          ),
          if (widget.isOnboarding) ...[
            const SizedBox(height: CasamaSpacing.xs),
            CasamaButton(
              label: 'Skip All for Now',
              style: CasamaButtonStyle.ghost,
              onPressed: _skipAll,
              height: 48,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String badge,
    required bool isRecommended,
    required String reason,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Semantics(
      toggled: value,
      label: '$title, $badge',
      child: CasamaCard(
        padding: const EdgeInsets.all(CasamaSpacing.md),
        onTap: () => onChanged(!value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: pal.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isRecommended ? pal.successBg : pal.neutralBg,
                          borderRadius: CasamaSpacing.roundedPill,
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isRecommended
                                ? pal.successFg
                                : pal.neutralFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: value,
                  activeTrackColor: CasamaColors.primaryCoral,
                  onChanged: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.textSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
