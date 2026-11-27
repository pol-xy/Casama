import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../data/repository_provider.dart';
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
    subtitle: 'Topic room for your household',
    builder: (sheetCtx) => _CreateChatSpaceBody(hostContext: context),
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

    final repo = ref.read(repositoryProvider);
    final desc = _descController.text.trim();
    final newSpace = repo.createChatSpace(
      name: name,
      description: desc.isNotEmpty ? desc : 'Household Chat Space',
      iconEmoji: _selectedEmoji,
      initialMembers: repo.members.map((m) => m.preferredName).toList(),
    );

    Navigator.of(context).pop();
    if (widget.hostContext.mounted) {
      showCasamaToast(
        widget.hostContext,
        'Space "${newSpace.name}" created!',
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

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: pal.softSage,
            borderRadius: CasamaSpacing.roundedMd,
            border: Border.all(color: pal.forestTeal.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_rounded, size: 18, color: pal.forestTeal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All ${repo.currentHousehold.name} housemates are automatically included in this space.',
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
          label: 'Create Space',
          icon: Icons.check_circle_outline_rounded,
          onPressed: _submit,
        ),
      ],
    );
  }
}
