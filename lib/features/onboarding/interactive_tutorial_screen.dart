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

class InteractiveTutorialScreen extends ConsumerStatefulWidget {
  const InteractiveTutorialScreen({super.key});

  @override
  ConsumerState<InteractiveTutorialScreen> createState() =>
      _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState
    extends ConsumerState<InteractiveTutorialScreen> {
  int _currentStep = 0;
  int _previousStep = 0;

  static const List<_TourStepData> _steps = [
    _TourStepData(
      navIndex: 0,
      title: '1. Home Dashboard & Calendar',
      description:
          'Check live housemate presence, share quick status updates, inspect the household calendar, and catch upcoming parcels.',
      pose: CasPose.hero,
      navIcon: Icons.home_rounded,
      highlightDetail:
          'Active now: see who is home or out with zero background GPS',
    ),
    _TourStepData(
      navIndex: 1,
      title: '2. Unified Household Boards',
      description:
          'Swipe smoothly across Parcels, Tasks, Bills, and Lost & Found items in one organized household hub.',
      pose: CasPose.deliveries,
      navIcon: Icons.dashboard_rounded,
      highlightDetail:
          'Keep shared deliveries, chores, and split bills crystal clear',
    ),
    _TourStepData(
      navIndex: 2,
      title: '3. CASnap Household Moments',
      description:
          'Tap the raised center CASnap button anytime to snap a photo for housemates and browse the shared home gallery.',
      pose: CasPose.jumping,
      navIcon: Icons.photo_camera_rounded,
      highlightDetail:
          'Share parcel confirmations or cozy kitchen updates in one tap',
    ),
    _TourStepData(
      navIndex: 3,
      title: '4. Household Chat & Meet-ups',
      description:
          'Chat in household spaces, message housemates 1-on-1, and plan or RSVP to shared meet-ups seamlessly.',
      pose: CasPose.chatting,
      navIcon: Icons.chat_bubble_outline_rounded,
      highlightDetail:
          'Organize study sessions, meals, and housemate check-ins',
    ),
    _TourStepData(
      navIndex: 4,
      title: '5. Profile, Roulette & Points',
      description:
          'Track Good Kasama points, spin Task Roulette inside Household Tasks, copy your invite code, and toggle Light or Dark mode.',
      pose: CasPose.roulette,
      navIcon: Icons.person_outline_rounded,
      highlightDetail: 'Fair task turns and monthly recognition for roommates',
    ),
  ];

  void _finishTutorial() {
    ref.read(repositoryProvider).completeOnboardingTutorial();
    context.go('/dashboard');
  }

  void _goToStep(int next) {
    if (next == _currentStep || next < 0 || next >= _steps.length) return;
    setState(() {
      _previousStep = _currentStep;
      _currentStep = next;
    });
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finishTutorial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final step = _steps[_currentStep];
    final maxW = CasamaBreakpoints.isTablet(context)
        ? CasamaBreakpoints.maxContentWidth
        : double.infinity;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      appBar: AppBar(
        backgroundColor: pal.scaffoldBg,
        surfaceTintColor: Colors.transparent,
        title: Text('Tour (${_currentStep + 1} of ${_steps.length})'),
        leading: _currentStep > 0
            ? IconButton(
                icon: Icon(Icons.adaptive.arrow_back, size: 20),
                tooltip: 'Previous step',
                onPressed: () => _goToStep(_currentStep - 1),
              )
            : null,
        actions: [
          TextButton(
            onPressed: _finishTutorial,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              'Skip',
              style: TextStyle(
                color: pal.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
      body: CasamaAmbientCanvas(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Column(
                children: [
                  // Progress indicator bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.lg,
                    ),
                    child: Row(
                      children: List.generate(
                        _steps.length,
                        (i) => Expanded(
                          child: AnimatedContainer(
                            duration: CasamaMotion.resolve(
                              context,
                              CasamaMotion.press,
                            ),
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: i <= _currentStep
                                  ? CasamaColors.primaryCoral
                                  : pal.border,
                              borderRadius: CasamaSpacing.roundedPill,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: CasamaSpacing.md),

                  // Scrollable slide content (safe against smaller screens)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CasamaSpacing.lg,
                        vertical: CasamaSpacing.sm,
                      ),
                      child: CasamaDirectionalSwitcher(
                        index: _currentStep,
                        previousIndex: _previousStep,
                        child: Column(
                          key: ValueKey('tour_step_$_currentStep'),
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: CasamaSpacing.sm),
                            CasMascotView(
                              pose: step.pose,
                              width: 156,
                              height: 156,
                            ),
                            const SizedBox(height: CasamaSpacing.md),
                            Text(
                              step.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              step.description,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                height: 1.45,
                                color: pal.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CasamaSpacing.md),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: pal.softBlush,
                                borderRadius: CasamaSpacing.roundedPill,
                                border: Border.all(
                                  color: pal.primaryCoral.withValues(
                                    alpha: 0.28,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tips_and_updates_outlined,
                                    size: 16,
                                    color: pal.primaryCoral,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      step.highlightDetail,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: pal.primaryCoral,
                                      ),
                                      textAlign: TextAlign.center,
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

                  // Interactive Mock 5-Slot Navigation Shell Preview
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.md,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: CasamaSpacing.roundedCard,
                      border: Border.all(color: pal.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.isDark ? 0.28 : 0.06,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMockNavItem(
                          context,
                          0,
                          Icons.home_rounded,
                          'Home',
                        ),
                        _buildMockNavItem(
                          context,
                          1,
                          Icons.dashboard_outlined,
                          'Boards',
                        ),
                        _buildMockNavCenterFab(context, 2),
                        _buildMockNavItem(
                          context,
                          3,
                          Icons.chat_bubble_outline_rounded,
                          'Chat',
                        ),
                        _buildMockNavItem(
                          context,
                          4,
                          Icons.person_outline_rounded,
                          'Profile',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CasamaSpacing.md),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CasamaSpacing.xl,
                    ),
                    child: CasamaButton(
                      label: _currentStep == _steps.length - 1
                          ? 'Enter Home Dashboard'
                          : 'Next Navigation Element',
                      isPill: true,
                      height: 50,
                      onPressed: _nextStep,
                    ),
                  ),
                  const SizedBox(height: CasamaSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMockNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
  ) {
    final pal = context.palette;
    final isHighlighted = _steps[_currentStep].navIndex == index;

    return Semantics(
      button: true,
      selected: isHighlighted,
      label: 'Jump to $label preview',
      child: CasamaPressable(
        onTap: () => _goToStep(index),
        child: AnimatedContainer(
          duration: CasamaMotion.resolve(context, CasamaMotion.boardSlide),
          constraints: const BoxConstraints(minWidth: 52, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isHighlighted ? pal.softBlush : Colors.transparent,
            borderRadius: CasamaSpacing.roundedLg,
            border: isHighlighted
                ? Border.all(color: pal.primaryCoral, width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 21,
                color: isHighlighted ? pal.primaryCoral : pal.textMuted,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                  color: isHighlighted ? pal.primaryCoral : pal.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockNavCenterFab(BuildContext context, int index) {
    final pal = context.palette;
    final isHighlighted = _steps[_currentStep].navIndex == index;

    return Semantics(
      button: true,
      selected: isHighlighted,
      label: 'Jump to CASnap preview',
      child: CasamaPressable.fab(
        onTap: () => _goToStep(index),
        child: SizedBox(
          width: 52,
          height: 48,
          child: Center(
            child: AnimatedContainer(
              duration: CasamaMotion.resolve(context, CasamaMotion.boardSlide),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: pal.coralFab,
                shape: BoxShape.circle,
                border: isHighlighted
                    ? Border.all(color: pal.forestTeal, width: 3)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: pal.coralFab.withValues(
                      alpha: isHighlighted ? 0.5 : 0.25,
                    ),
                    blurRadius: isHighlighted ? 10 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.photo_camera_rounded,
                color: Colors.white,
                size: 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TourStepData {
  final int navIndex;
  final String title;
  final String description;
  final CasPose pose;
  final IconData navIcon;
  final String highlightDetail;

  const _TourStepData({
    required this.navIndex,
    required this.title,
    required this.description,
    required this.pose,
    required this.navIcon,
    required this.highlightDetail,
  });
}
