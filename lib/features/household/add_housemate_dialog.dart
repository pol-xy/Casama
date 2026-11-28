import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';

/// Shows the Add Housemate slide-up sheet for sharing the household join code.
Future<void> showAddHousemateDialog(BuildContext context) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.person_add_alt_1_rounded,
    title: 'Add Housemate',
    subtitle: 'Share your join code with roommates',
    builder: (sheetCtx) => _AddHousemateSheetBody(hostContext: context),
  );
}

class _AddHousemateSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;

  const _AddHousemateSheetBody({required this.hostContext});

  @override
  ConsumerState<_AddHousemateSheetBody> createState() =>
      _AddHousemateSheetBodyState();
}

class _AddHousemateSheetBodyState
    extends ConsumerState<_AddHousemateSheetBody> {
  bool _copied = false;

  void _copyCode(String inviteCode) {
    Clipboard.setData(ClipboardData(text: inviteCode));
    setState(() => _copied = true);
    showCasamaToast(
      widget.hostContext,
      'Copied invite code "$inviteCode"!',
      icon: Icons.copy_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final inviteCode = repo.currentHousehold.inviteCode;
    final householdName = repo.currentHousehold.name;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CasamaSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CasMascotView(
            pose: CasMascotPose.inviteKey,
            width: 80,
            height: 80,
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Text(
            'Join Code for $householdName',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: pal.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Share this code with your housemates. They can enter it during setup to instantly join.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: CasamaSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: pal.track,
              borderRadius: CasamaSpacing.roundedCard,
              border: Border.all(color: pal.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    inviteCode,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Copy invite code',
                  child: CasamaPressable(
                    onTap: () => _copyCode(inviteCode),
                    child: Container(
                      width: CasamaSpacing.minTouchTarget,
                      height: CasamaSpacing.minTouchTarget,
                      decoration: BoxDecoration(
                        color: pal.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: pal.border),
                      ),
                      child: AnimatedSwitcher(
                        duration: CasamaMotion.resolve(
                          context,
                          CasamaMotion.press,
                        ),
                        child: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          key: ValueKey(_copied),
                          color: _copied ? pal.successFg : pal.primaryCoral,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),
        ],
      ),
    );
  }
}
