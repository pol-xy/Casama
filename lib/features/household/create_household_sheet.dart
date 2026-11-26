import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_text_field.dart';

/// Opens a slide-up sheet to create a new household, generate its invite code,
/// and immediately switch the app into it.
Future<Household?> showCreateHouseholdSheet(BuildContext context) {
  return showCasamaSheet<Household?>(
    context,
    icon: Icons.add_home_work_outlined,
    title: 'Create New Household',
    subtitle: 'Start a shared space and generate its invite code.',
    builder: (sheetCtx) => _CreateHouseholdForm(hostContext: context),
  );
}

/// Opens a slide-up sheet to join an existing household by 6-character code.
Future<Household?> showJoinHouseholdSheet(BuildContext context) {
  return showCasamaSheet<Household?>(
    context,
    icon: Icons.vpn_key_outlined,
    title: 'Join with Invite Code',
    subtitle: 'Enter the 6-character code from your housemate.',
    builder: (sheetCtx) => _JoinHouseholdForm(hostContext: context),
  );
}

class _CreateHouseholdForm extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _CreateHouseholdForm({required this.hostContext});

  @override
  ConsumerState<_CreateHouseholdForm> createState() =>
      _CreateHouseholdFormState();
}

class _CreateHouseholdFormState extends ConsumerState<_CreateHouseholdForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final created = await ref
          .read(repositoryProvider)
          .createHousehold(name: name);
      if (!mounted) return;
      Navigator.of(context).pop(created);
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Created "${created.name}" • Code: ${created.inviteCode}',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e is StateError
            ? e.message
            : 'Could not create household "$name". Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaTextField(
            controller: _nameController,
            label: 'Household Name',
            hint: 'e.g., TeenTitans, Casa 204, The Loft',
            prefixIcon: Icons.cottage_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter a household name';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pal.softSage,
              borderRadius: CasamaSpacing.roundedMd,
              border: Border.all(color: pal.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 18,
                  color: pal.forestTeal,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'An invite code will be generated automatically and you will switch into this household right away.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: CasamaSpacing.sm),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: CasamaSpacing.lg),
          CasamaButton(
            label: 'Create Household',
            style: CasamaButtonStyle.navy,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _JoinHouseholdForm extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _JoinHouseholdForm({required this.hostContext});

  @override
  ConsumerState<_JoinHouseholdForm> createState() => _JoinHouseholdFormState();
}

class _JoinHouseholdFormState extends ConsumerState<_JoinHouseholdForm> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = _codeController.text.trim().toUpperCase();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final joined = await ref
          .read(repositoryProvider)
          .joinHouseholdByCode(code);
      if (!mounted) return;
      Navigator.of(context).pop(joined);
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Joined "${joined.name}"',
          icon: Icons.check_circle_outline_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = e is StateError
            ? e.message
            : 'Could not join household "$code".';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CasamaTextField(
            controller: _codeController,
            label: 'Household Invite Code',
            hint: 'e.g., SYZKB2',
            prefixIcon: Icons.vpn_key_outlined,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            enabled: !_isSubmitting,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter an invite code';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: CasamaSpacing.sm),
            _ErrorBanner(message: _errorMessage!),
          ],
          const SizedBox(height: CasamaSpacing.lg),
          CasamaButton(
            label: 'Join Household',
            style: CasamaButtonStyle.navy,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.dangerBg,
        borderRadius: CasamaSpacing.roundedMd,
        border: Border.all(color: pal.dangerFg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: pal.dangerFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: pal.dangerFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
