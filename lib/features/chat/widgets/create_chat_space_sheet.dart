import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

/// Opens the unified slide-up Create Chat Space sheet matching
/// `casama-app-mockup.html` (`280ms` ease-out rise, Light/Dark parity).
Future<void> showCreateChatSpaceSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.forum_outlined,
    title: 'Create Chat Space',
    subtitle: 'Topic room & invite code for your household',
    builder: (sheetCtx) => _CreateChatSpaceBody(hostContext: context),
  );
}

/// Opens the unified slide-up Join Space with Code sheet.
Future<void> showJoinWithCodeSheet(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.vpn_key_rounded,
    title: 'Join Space with Code',
    subtitle: 'Enter a space or household code shared by a housemate',
    builder: (sheetCtx) => _JoinSpaceWithCodeBody(hostContext: context),
  );
}

class _CreateChatSpaceBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _CreateChatSpaceBody({required this.hostContext});

  @override
  ConsumerState<_CreateChatSpaceBody> createState() =>
      _CreateChatSpaceBodyState();
}

class _CreateChatSpaceBodyState extends ConsumerState<_CreateChatSpaceBody> {
  static const List<String> _emojis = [
    '🛒',
    '🧹',
    '🍿',
    '📚',
    '🍕',
    '💬',
    '🎮',
    '🌿',
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _selectedEmoji = '🛒';
  final Set<String> _selectedMembers = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showCasamaToast(
        widget.hostContext,
        'Please enter a space name.',
        icon: Icons.info_outline_rounded,
      );
      return;
    }

    final desc = _descController.text.trim();
    final newSpace = ref.read(repositoryProvider).createChatSpace(
      name: name,
      description: desc.isNotEmpty ? desc : 'Household Chat Space',
      iconEmoji: _selectedEmoji,
      initialMembers: _selectedMembers.toList(),
    );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Space "${newSpace.name}" created • ${newSpace.inviteCode}',
        icon: Icons.check_circle_outline_rounded,
      );
      GoRouter.maybeOf(widget.hostContext)?.push('/space-chat?id=${newSpace.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final otherMembers = repo.members
        .where((m) => m.profile.id != repo.currentUser.id)
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'CHOOSE SPACE ICON',
          style: theme.textTheme.labelSmall?.copyWith(
            color: pal.textSecondary,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: CasamaSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _emojis.map((emoji) {
              final selected = _selectedEmoji == emoji;
              return Padding(
                padding: const EdgeInsets.only(right: CasamaSpacing.xs),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: 'Space icon $emoji',
                  child: CasamaPressable(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    enableHaptic: true,
                    child: Container(
                      width: CasamaSpacing.minTouchTarget,
                      height: CasamaSpacing.minTouchTarget,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? pal.softSage : pal.track,
                        borderRadius: CasamaSpacing.roundedMd,
                        border: Border.all(
                          color: selected ? pal.forestTeal : pal.border,
                          width: selected ? 1.8 : 1,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        CasamaTextField(
          controller: _nameController,
          label: 'Space Name',
          hint: 'e.g., Grocery & Supplies',
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: CasamaSpacing.md),

        CasamaTextField(
          controller: _descController,
          label: 'Purpose or Description (optional)',
          hint: 'e.g., Shared pantry list and errands',
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: CasamaSpacing.md),

        if (otherMembers.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'ADD HOUSEMATES DIRECTLY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: pal.textSecondary,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '${_selectedMembers.length} selected',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: pal.primaryCoral,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.xs),
          Wrap(
            spacing: CasamaSpacing.xs,
            runSpacing: CasamaSpacing.xs,
            children: otherMembers.map((m) {
              final name = m.profile.displayName;
              final selected = _selectedMembers.contains(name);
              return Semantics(
                button: true,
                selected: selected,
                label: 'Include $name',
                child: CasamaPressable(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedMembers.remove(name);
                      } else {
                        _selectedMembers.add(name);
                      }
                    });
                  },
                  enableHaptic: true,
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: CasamaSpacing.minTouchTarget,
                    ),
                    padding: const EdgeInsets.only(
                      left: 6,
                      right: 14,
                      top: 6,
                      bottom: 6,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? pal.forestTeal : pal.track,
                      borderRadius: CasamaSpacing.roundedPill,
                      border: Border.all(
                        color: selected ? pal.forestTeal : pal.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CasamaAvatar(
                          avatarUrl: m.profile.avatarUrl,
                          radius: 14,
                          name: name,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          name,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: selected ? pal.onForestTeal : pal.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: CasamaSpacing.md),
        ],

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.softSage,
            borderRadius: CasamaSpacing.roundedMd,
            border: Border.all(color: pal.forestTeal.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 18, color: pal.forestTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Creates a private topic space for ${repo.currentHousehold.name} with a shareable invite code.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: pal.textPrimary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: CasamaSpacing.lg),

        CasamaButton(
          label: 'Create Space & Generate Code',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _JoinSpaceWithCodeBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _JoinSpaceWithCodeBody({required this.hostContext});

  @override
  ConsumerState<_JoinSpaceWithCodeBody> createState() =>
      _JoinSpaceWithCodeBodyState();
}

class _JoinSpaceWithCodeBodyState
    extends ConsumerState<_JoinSpaceWithCodeBody> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    if (data?.text != null) {
      _codeController.text = data!.text!.trim().toUpperCase();
      setState(() => _errorText = null);
    }
  }

  void _submit() {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter an invite code.');
      return;
    }

    final repo = ref.read(repositoryProvider);
    if (code == repo.currentHousehold.inviteCode.toUpperCase()) {
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Already a verified member of ${repo.currentHousehold.name}',
          icon: Icons.verified_user_outlined,
        );
        GoRouter.maybeOf(widget.hostContext)?.push('/group-chat');
      }
      return;
    }

    final joinedSpace = repo.joinChatSpaceByCode(code);
    if (joinedSpace != null) {
      Navigator.of(context).pop();
      if (widget.hostContext.mounted) {
        showCasamaToast(
          widget.hostContext,
          'Joined "${joinedSpace.name}"!',
          icon: Icons.check_circle_outline_rounded,
        );
        GoRouter.maybeOf(widget.hostContext)
            ?.push('/space-chat?id=${joinedSpace.id}');
      }
    } else {
      setState(() {
        _errorText = 'No space found with code "$code". Check and retry.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CasamaTextField(
          controller: _codeController,
          label: 'Space Invite Code',
          hint: 'e.g., SPC-101 or CASA204',
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
          suffix: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: TextButton(
              onPressed: _pasteCode,
              child: Text(
                'PASTE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: pal.primaryCoral,
                ),
              ),
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: CasamaSpacing.xs),
          Text(
            _errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: pal.dangerFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: CasamaSpacing.lg),
        CasamaButton(
          label: 'Join Space',
          icon: Icons.login_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}
