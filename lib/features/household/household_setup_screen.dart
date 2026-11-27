import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/casama_repository.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_text_field.dart';
import '../auth/widgets/auth_wave_header.dart';

class HouseholdSetupScreen extends StatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  State<HouseholdSetupScreen> createState() => _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends State<HouseholdSetupScreen> {
  final _joinFormKey = GlobalKey<FormState>();
  final _createFormKey = GlobalKey<FormState>();
  final _createNameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  int _selectedTab = 0;
  int _previousTab = 0;
  bool _isSubmitting = false;

  CasamaRepository? _tryReadRepository() {
    try {
      return ProviderScope.containerOf(
        context,
        listen: false,
      ).read(repositoryProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _createNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _selectTab(int next) {
    if (next == _selectedTab) return;
    setState(() {
      _previousTab = _selectedTab;
      _selectedTab = next;
    });
  }

  Future<void> _submitJoin() async {
    if (_isSubmitting) return;
    if (!(_joinFormKey.currentState?.validate() ?? false)) return;
    final code = _joinCodeController.text.trim().toUpperCase();
    final repo = _tryReadRepository();
    if (repo != null) {
      setState(() => _isSubmitting = true);
      try {
        await repo.joinHouseholdByCode(code);
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          showCasamaToast(
            context,
            e is StateError ? e.message : 'Could not join household "$code".',
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    showCasamaToast(
      context,
      'Joined household with code $code',
      icon: Icons.check_circle_outline_rounded,
    );
    if (repo?.currentUser.hasCompletedOnboarding == true) {
      context.go('/dashboard');
    } else {
      context.push('/permissions');
    }
  }

  Future<void> _submitCreate() async {
    if (_isSubmitting) return;
    if (!(_createFormKey.currentState?.validate() ?? false)) return;
    final name = _createNameController.text.trim();
    final repo = _tryReadRepository();
    if (repo != null) {
      setState(() => _isSubmitting = true);
      try {
        await repo.createHousehold(name: name);
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          showCasamaToast(
            context,
            'Could not create household "$name".',
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }
    }
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    showCasamaToast(
      context,
      'Created household "$name"',
      icon: Icons.check_circle_outline_rounded,
    );
    if (repo?.currentUser.hasCompletedOnboarding == true) {
      context.go('/dashboard');
    } else {
      context.push('/permissions');
    }
  }

  void _joinLater() {
    if (_isSubmitting) return;
    final repo = _tryReadRepository();
    if (repo?.currentUser.hasCompletedOnboarding == true) {
      context.go('/dashboard');
    } else {
      context.push('/permissions');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return CasamaAuthShell(
      stepLabel: 'Step 3 of 4',
      onBack: () =>
          context.canPop() ? context.pop() : context.go('/profile-setup'),
      mascotPose: _selectedTab == 0 ? CasPose.waving : CasPose.hero,
      mascotAlignment: _selectedTab == 0
          ? Alignment.bottomRight
          : Alignment.bottomLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaSegmentedTrack<int>(
            selectedValue: _selectedTab,
            onSelected: _selectTab,
            segments: const [
              CasamaFilterOption(value: 0, label: 'Join Household'),
              CasamaFilterOption(value: 1, label: 'Create New'),
            ],
          ),
          const SizedBox(height: CasamaSpacing.lg),
          CasamaDirectionalSwitcher(
            index: _selectedTab,
            previousIndex: _previousTab,
            child: _selectedTab == 0
                ? _buildJoinForm(context, pal)
                : _buildCreateForm(context, pal),
          ),
          const SizedBox(height: CasamaSpacing.md),
          Center(
            child: TextButton(
              key: const Key('household_setup_join_later_button'),
              onPressed: _isSubmitting ? null : _joinLater,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                'Join a household later',
                style: TextStyle(
                  color: pal.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinForm(BuildContext context, CasamaPalette pal) {
    final theme = Theme.of(context);
    return Form(
      key: _joinFormKey,
      child: Column(
        key: const ValueKey('join-household-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Got an Invite Code?',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ask your roommate or household owner for the 6-character code (e.g., CASA204).',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaTextField(
            controller: _joinCodeController,
            label: 'Household Invite Code',
            hint: 'CASA204',
            prefixIcon: Icons.vpn_key_outlined,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter an invite code';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitJoin(),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaButton(
            label: 'Join Household',
            isPill: true,
            height: 50,
            onPressed: _submitJoin,
          ),
          const SizedBox(height: CasamaSpacing.xs),

          Center(
            child: TextButton(
              onPressed: () {
                _joinCodeController.text = 'CASA204';
              },
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(
                'Fill Demo Code: CASA204',
                style: TextStyle(
                  color: pal.forestTeal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm(BuildContext context, CasamaPalette pal) {
    final theme = Theme.of(context);
    return Form(
      key: _createFormKey,
      child: Column(
        key: const ValueKey('create-household-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start a New Household',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Give your shared living space a name to generate an invite code for your housemates.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: pal.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaTextField(
            controller: _createNameController,
            label: 'Household Name',
            hint: 'e.g., Casa 204, Apartment 4B, The Loft',
            prefixIcon: Icons.home_work_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a household name';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitCreate(),
          ),
          const SizedBox(height: CasamaSpacing.lg),

          CasamaButton(
            label: 'Create Household',
            style: CasamaButtonStyle.navy,
            isPill: true,
            height: 50,
            onPressed: _submitCreate,
          ),
        ],
      ),
    );
  }
}
