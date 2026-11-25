import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_wave_header.dart';

class TermsConsentScreen extends ConsumerStatefulWidget {
  const TermsConsentScreen({super.key});

  @override
  ConsumerState<TermsConsentScreen> createState() => _TermsConsentScreenState();
}

class _TermsConsentScreenState extends ConsumerState<TermsConsentScreen> {
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;

  void _acknowledgeAndContinue() {
    if (!_agreedToTerms || !_agreedToPrivacy) {
      showCasamaToast(
        context,
        'Please acknowledge both agreements to proceed.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    ref.read(repositoryProvider).recordTermsConsent();
    GoRouter.maybeOf(context)?.push('/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
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
                title: 'Terms & Privacy',
                subtitle: 'Step 3 of 4 • Household guidelines & protections',
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
                        Text(
                          'Household Agreements 📋',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Step 3 of 4: Review and acknowledge our household guidelines and privacy commitments before entering your home.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: pal.textSecondary,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: CasamaSpacing.md),

                        _AgreementCard(
                          icon: Icons.gavel_rounded,
                          title: 'Terms of Service',
                          summary:
                              'Covers household mutual respect, prompt COD parcel reimbursements, shared resource borrowing, and fair chore obligations.',
                          onReadMore: () =>
                              GoRouter.maybeOf(context)?.push('/terms'),
                          isChecked: _agreedToTerms,
                          checkboxLabel: 'I accept the Terms of Service',
                          onChanged: (val) =>
                              setState(() => _agreedToTerms = val),
                        ),
                        const SizedBox(height: CasamaSpacing.md),

                        _AgreementCard(
                          icon: Icons.shield_outlined,
                          title: 'Privacy Policy',
                          badge: 'Zero GPS Tracking',
                          summary:
                              'Your presence is 100% manually updated by you. Casama NEVER monitors background GPS. Household records are isolated strictly to your housemates via Supabase RLS.',
                          onReadMore: () =>
                              GoRouter.maybeOf(context)?.push('/terms'),
                          isChecked: _agreedToPrivacy,
                          checkboxLabel:
                              'I acknowledge the Privacy Policy & Data Protections',
                          onChanged: (val) =>
                              setState(() => _agreedToPrivacy = val),
                        ),
                        const SizedBox(height: CasamaSpacing.xl),

                        CasamaButton(
                          label: 'Acknowledge & Continue',
                          icon: Icons.check_circle_outline_rounded,
                          height: 52,
                          onPressed: _acknowledgeAndContinue,
                        ),
                        const SizedBox(height: CasamaSpacing.md),

                        Center(
                          child: Text(
                            'Next: Relevant device permissions',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: pal.textSecondary,
                            ),
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
}

class _AgreementCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? badge;
  final String summary;
  final VoidCallback onReadMore;
  final bool isChecked;
  final String checkboxLabel;
  final ValueChanged<bool> onChanged;

  const _AgreementCard({
    required this.icon,
    required this.title,
    this.badge,
    required this.summary,
    required this.onReadMore,
    required this.isChecked,
    required this.checkboxLabel,
    required this.onChanged,
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: pal.softBlush,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: pal.primaryCoral, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
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
          const SizedBox(height: 10),
          Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          CasamaPressable(
            onTap: onReadMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Read Full Document ➔',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pal.primaryCoral,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: pal.divider),
          const SizedBox(height: 6),
          CasamaPressable(
            onTap: () => onChanged(!isChecked),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CasamaSpacing.minTouchTarget,
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isChecked,
                    activeColor: pal.primaryCoral,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    onChanged: (v) => onChanged(v ?? false),
                  ),
                  Expanded(
                    child: Text(
                      checkboxLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
