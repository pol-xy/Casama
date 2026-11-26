import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import 'cas_snap_interactive_view.dart';

/// Opens the unified fade + Hero CASnap viewer (`200ms`) for viewing and
/// interacting with a [QuickSnap], matching **Highlights** identically
/// (Photo Card + bottom-left reactions pill + 6-emoji bar + `Comment... 💬`).
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
      barrierColor: Colors.black.withValues(alpha: 0.78),
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

class _CasamaSnapLightbox extends StatelessWidget {
  final QuickSnap snap;
  final String heroTag;

  const _CasamaSnapLightbox({required this.snap, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final frameMax = math.min(MediaQuery.sizeOf(context).width - 64, 340.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: pal.scaffoldBg,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: pal.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.isDark ? 0.55 : 0.24,
                          ),
                          blurRadius: 28,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CASnap',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: pal.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Close photo viewer',
                              child: CasamaPressable(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  width: CasamaSpacing.minTouchTarget,
                                  height: CasamaSpacing.minTouchTarget,
                                  decoration: BoxDecoration(
                                    color: pal.track,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: pal.textPrimary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CasSnapInteractiveView(
                          snapId: snap.id,
                          fallbackSnap: snap,
                          heroTag: heroTag,
                          maxFrameSize: frameMax,
                        ),
                      ],
                    ),
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
