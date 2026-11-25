import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import 'quicksnap_image_view.dart';

/// Opens the fullscreen fade + Hero lightbox (`200ms`) for viewing a [QuickSnap],
/// supporting reduced-motion, quick emoji reactions, and tap-outside dismiss.
Future<void> showCasamaSnapLightbox(
  BuildContext context, {
  required QuickSnap snap,
  String? heroTag,
}) {
  final reduced = CasamaMotion.reduceMotion(context);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.86),
      transitionDuration: reduced ? Duration.zero : CasamaMotion.lightbox,
      reverseTransitionDuration: reduced ? Duration.zero : CasamaMotion.lightbox,
      pageBuilder: (_, animation, _) => _CasamaSnapLightbox(
        snap: snap,
        heroTag: heroTag ?? 'casnap_${snap.id}',
      ),
      transitionsBuilder: (_, animation, _, child) {
        if (reduced) return child;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: CasamaMotion.easeOut,
          ),
          child: child,
        );
      },
    ),
  );
}

class _CasamaSnapLightbox extends ConsumerWidget {
  final QuickSnap snap;
  final String heroTag;

  const _CasamaSnapLightbox({required this.snap, required this.heroTag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(repositoryProvider);
    final currentSnap = repo.quickSnaps.cast<QuickSnap?>().firstWhere(
      (s) => s?.id == snap.id,
      orElse: () => snap,
    )!;
    final dateLabel = DateFormat('MMM d • h:mm a').format(currentSnap.createdAt);
    final isDirect =
        currentSnap.recipientType == QuickSnapRecipientType.selectedHousemates;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Semantics(
                          button: true,
                          label: 'Close photo viewer',
                          child: CasamaPressable(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Hero(
                        tag: heroTag,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 24,
                                  offset: Offset(0, 12),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                QuickSnapImageView(
                                  imageUrl: currentSnap.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                                if (isDirect)
                                  Positioned(
                                    top: 12,
                                    right: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CasamaColors.primaryCoral,
                                        borderRadius: CasamaSpacing.roundedPill,
                                      ),
                                      child: const Text(
                                        'Direct',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CasamaAvatar(
                            radius: 14,
                            avatarUrl: currentSnap.senderAvatar,
                            name: currentSnap.senderName,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              currentSnap.caption?.isNotEmpty == true
                                  ? '${currentSnap.senderName} • ${currentSnap.caption}'
                                  : '${currentSnap.senderName} • $dateLabel',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: ['😍', '🔥', '❤️', '😂'].map((emoji) {
                          return Semantics(
                            button: true,
                            label: 'React $emoji',
                            child: CasamaPressable(
                              enableHaptic: true,
                              onTap: () {
                                ref
                                    .read(repositoryProvider)
                                    .reactToQuickSnap(currentSnap.id, emoji);
                                showCasamaToast(
                                  context,
                                  'Reacted $emoji to ${currentSnap.senderName}',
                                );
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
