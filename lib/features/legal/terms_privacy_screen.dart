import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';

class TermsPrivacyScreen extends StatefulWidget {
  final bool readOnly;

  const TermsPrivacyScreen({super.key, this.readOnly = false});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen> {
  int _selectedTab = 0;
  int _previousTab = 0;

  void _selectTab(int idx) {
    if (idx == _selectedTab) return;
    setState(() {
      _previousTab = _selectedTab;
      _selectedTab = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: 'Terms & Privacy',
              subtitle: 'Zero background GPS • Household-isolated rules',
              titleMascotPose: CasPose.terms,
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
                child: CasamaSegmentedTrack<int>(
                  selectedValue: _selectedTab,
                  onSelected: _selectTab,
                  segments: const [
                    CasamaFilterOption(value: 0, label: 'Terms'),
                    CasamaFilterOption(value: 1, label: 'Privacy'),
                    CasamaFilterOption(value: 2, label: 'Permissions'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxW),
                  child: CasamaDirectionalSwitcher(
                    index: _selectedTab,
                    previousIndex: _previousTab,
                    child: switch (_selectedTab) {
                      0 => _buildTermsTab(context),
                      1 => _buildPrivacyTab(context),
                      _ => _buildPermissionsTab(context),
                    },
                  ),
                ),
              ),
            ),
            if (!widget.readOnly)
              Container(
                padding: EdgeInsets.fromLTRB(
                  CasamaSpacing.md,
                  CasamaSpacing.sm,
                  CasamaSpacing.md,
                  bottomInset + CasamaSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: pal.surface,
                  border: Border(top: BorderSide(color: pal.divider)),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxW),
                    child: CasamaButton(
                      label: 'I Understand & Agree',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context, true);
                        } else {
                          GoRouter.maybeOf(context)?.pop(true);
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsTab(BuildContext context) {
    return ListView(
      key: const ValueKey('legal_terms_tab'),
      padding: const EdgeInsets.all(CasamaSpacing.md),
      children: [
        _LegalSectionCard(
          icon: Icons.handshake_outlined,
          title: 'Household Harmony',
          content:
              'Casama is designed to foster transparency, cooperation, and goodwill between housemates. By using Casama, you agree to treat your housemates with respect and keep household logs accurate.',
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalSectionCard(
          icon: Icons.payments_outlined,
          title: 'Parcel Deliveries & COD Reimbursement',
          content:
              'Housemates can mark deliveries received ("I Got It") and track Cash on Delivery (COD) amounts covered on your behalf. Once reimbursed, the parcel owner marks the COD balance as settled to keep household records clear.',
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalSectionCard(
          icon: Icons.checklist_rounded,
          title: 'Household Tasks & Task Roulette',
          content:
              'Household tasks (Cleaning, Repair / Maintenance, Restock, and Personal Request) and Task Roulette spins help distribute responsibilities fairly. Completing tasks and accepting Roulette spins awards Good Kasama points to recognize helpful housemates.',
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalSectionCard(
          icon: Icons.inventory_2_outlined,
          title: 'Lost & Found Board',
          content:
              'The Lost & Found board helps housemates report missing items, post found belongings, confirm returns, and earn Good Kasama points for helping recover a housemate\'s item.',
        ),
      ],
    );
  }

  Widget _buildPrivacyTab(BuildContext context) {
    return ListView(
      key: const ValueKey('legal_privacy_tab'),
      padding: const EdgeInsets.all(CasamaSpacing.md),
      children: [
        _LegalSectionCard(
          icon: Icons.location_off_rounded,
          title: 'Zero Background GPS Tracking',
          badge: 'Privacy First',
          content:
              'Casama strictly respects your personal privacy and NEVER monitors, requests, or records background GPS location. Your Home / Out presence status, optional status notes, and Housemates Agenda location or link labels are 100% manual.',
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalSectionCard(
          icon: Icons.shield_outlined,
          title: 'Household Data Isolation (RLS)',
          content:
              'Your household chats, parcels, household tasks, Lost & Found posts, CASnaps, and Housemates Agendas are isolated using Supabase Row Level Security (RLS). Only members who join your household via its invite code can view your home\'s data.',
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalSectionCard(
          icon: Icons.lock_outline_rounded,
          title: 'Data Security & Storage',
          content:
              'Your profile details, photos, and household data are encrypted in transit and protected by Supabase authentication and security policies. Casama does not sell personal data to third parties or advertisers.',
        ),
      ],
    );
  }

  Widget _buildPermissionsTab(BuildContext context) {
    return ListView(
      key: const ValueKey('legal_permissions_tab'),
      padding: const EdgeInsets.all(CasamaSpacing.md),
      children: [
        _LegalPermissionCard(
          icon: Icons.camera_alt_outlined,
          title: 'Camera & Photo Library',
          reason:
              'Used only when you choose to capture CASnap moments, update your profile avatar, share photos in chat, or attach photos to Lost & Found reports.',
          badgeKind: _PermissionBadgeKind.optional,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalPermissionCard(
          icon: Icons.notifications_none_rounded,
          title: 'In-App Notifications',
          reason:
              'Alerts for parcels, Task Roulette picks, and Housemates Agenda reminders are delivered inside the app\'s Notifications drawer without requiring device push permissions.',
          badgeKind: _PermissionBadgeKind.builtIn,
        ),
        const SizedBox(height: CasamaSpacing.sm),
        _LegalPermissionCard(
          icon: Icons.storage_rounded,
          title: 'Local Session & Preferences',
          reason:
              'Local device storage is used to keep your active login session, theme preference (Light, Dark, or System), and basic app preferences.',
          badgeKind: _PermissionBadgeKind.required,
        ),
      ],
    );
  }
}

class _LegalSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final String? badge;

  const _LegalSectionCard({
    required this.icon,
    required this.title,
    required this.content,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return CasamaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: pal.softBlush,
                  borderRadius: CasamaSpacing.roundedSm,
                ),
                child: Icon(icon, size: 19, color: pal.primaryCoral),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              if (badge != null)
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
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.successFg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Text(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

enum _PermissionBadgeKind { optional, builtIn, required }

class _LegalPermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String reason;
  final _PermissionBadgeKind badgeKind;

  const _LegalPermissionCard({
    required this.icon,
    required this.title,
    required this.reason,
    required this.badgeKind,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final (badgeLabel, badgeBg, badgeFg) = switch (badgeKind) {
      _PermissionBadgeKind.optional => (
        'Optional',
        pal.track,
        pal.textSecondary,
      ),
      _PermissionBadgeKind.builtIn => (
        'Built-in',
        pal.softSage,
        pal.forestTeal,
      ),
      _PermissionBadgeKind.required => (
        'Required',
        pal.softBlush,
        pal.primaryCoral,
      ),
    };

    return CasamaCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: pal.softSage,
              borderRadius: CasamaSpacing.roundedMd,
            ),
            child: Icon(icon, size: 21, color: pal.forestTeal),
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
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: CasamaSpacing.roundedPill,
                      ),
                      child: Text(
                        badgeLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: badgeFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: pal.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
