import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'quicksnap_camera_screen.dart';
import 'quicksnap_feed_screen.dart';
import 'quicksnap_image_view.dart';
import 'quicksnap_lightbox.dart';

/// Home Dashboard `Shared CASnaps` card featuring a 3×2 thumbnail grid,
/// `Hero` lightbox viewer on tile tap, and direct link into the filterable
/// household gallery (`casama-app-mockup.html`).
class QuickSnapHomeWidget extends ConsumerWidget {
  const QuickSnapHomeWidget({super.key});

  void _openGallery(BuildContext context, {int initialTabIndex = 1}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickSnapFeedScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  void _openCamera(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuickSnapCameraScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final snaps = repo.quickSnaps;
    final streak = repo.quickSnapStreak;

    return CasamaCard(
      padding: const EdgeInsets.all(CasamaSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Shared CASnaps + count badge + View all / Snap Back
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Shared CASnaps',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: pal.textPrimary,
                          fontWeight: FontWeight.w700,
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
                        color: pal.track,
                        borderRadius: CasamaSpacing.roundedPill,
                      ),
                      child: Text(
                        '${snaps.length} ${snaps.length == 1 ? 'photo' : 'photos'}',
                        style: theme.textTheme.labelSmall?.tabular.copyWith(
                          color: pal.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (streak > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: pal.amberBg,
                          borderRadius: CasamaSpacing.roundedPill,
                        ),
                        child: Text(
                          '${streak}d',
                          style: theme.textTheme.labelSmall?.tabular.copyWith(
                            color: pal.amberFg,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openGallery(context),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  foregroundColor: pal.primaryCoral,
                ),
                child: const Text(
                  'View all ›',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: CasamaSpacing.sm),

          if (snaps.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(
                color: pal.surface,
                borderRadius: CasamaSpacing.roundedLg,
                border: Border.all(color: pal.border),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.photo_camera_back_outlined,
                    size: 38,
                    color: pal.textMuted,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No moments shared yet today',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Send a quick photo to ${repo.currentHousehold.name}.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: pal.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CasamaButton(
                    label: 'Take QuickSnap',
                    icon: Icons.add_a_photo_outlined,
                    isFullWidth: false,
                    height: 44,
                    onPressed: () => _openCamera(context),
                  ),
                ],
              ),
            )
          else ...[
            // 3×2 Grid (up to 5 recent photos + 6th View all / +N slot)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snaps.length > 5 ? 6 : snaps.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final maxPhotoSlots = snaps.length > 5 ? 5 : snaps.length;
                if (index < maxPhotoSlots) {
                  final snap = snaps[index];
                  final heroTag = 'home_casnap_${index}_${snap.id}';
                  return _SnapGridTile(
                    snap: snap,
                    heroTag: heroTag,
                    onTap: () => showCasamaSnapLightbox(
                      context,
                      snap: snap,
                      heroTag: heroTag,
                    ),
                  );
                }

                // 6th slot: "+N View all" or "+ Snap Back"
                final overflowCount = snaps.length > 5 ? snaps.length - 5 : 0;
                return Semantics(
                  button: true,
                  label: overflowCount > 0
                      ? 'View all ${snaps.length} shared photos'
                      : 'Snap back a photo',
                  child: CasamaPressable(
                    onTap: overflowCount > 0
                        ? () => _openGallery(context)
                        : () => _openCamera(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: pal.softSage,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: pal.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (overflowCount > 0) ...[
                            Text(
                              '+$overflowCount',
                              style: theme.textTheme.titleLarge?.tabular
                                  .copyWith(
                                    color: pal.forestTeal,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              'View all',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: pal.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ] else ...[
                            Icon(
                              Icons.add_a_photo_outlined,
                              size: 22,
                              color: pal.forestTeal,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Snap Back',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: pal.forestTeal,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Bottom Browse Pill Action
            Semantics(
              button: true,
              label: 'Browse all ${snaps.length} shared shots',
              child: CasamaPressable(
                onTap: () => _openGallery(context),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pal.surface,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(color: pal.border),
                  ),
                  child: Text(
                    'Browse all ${snaps.length} shared ${snaps.length == 1 ? 'shot' : 'shots'} →',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pal.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SnapGridTile extends StatelessWidget {
  final QuickSnap snap;
  final String heroTag;
  final VoidCallback onTap;

  const _SnapGridTile({
    required this.snap,
    required this.heroTag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final isDirect =
        snap.recipientType == QuickSnapRecipientType.selectedHousemates;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: 'Photo by ${snap.senderName}',
      child: CasamaPressable(
        enableHaptic: true,
        onTap: onTap,
        child: Hero(
          tag: heroTag,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: pal.headerDeep,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                QuickSnapImageView(imageUrl: snap.imageUrl, fit: BoxFit.cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 46,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.72),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isDirect)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pal.primaryCoral,
                        borderRadius: CasamaSpacing.roundedPill,
                      ),
                      child: const Text(
                        'To You',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      CasamaAvatar(
                        radius: 10,
                        avatarUrl: snap.senderAvatar,
                        name: snap.senderName,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          snap.senderName.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }
}
