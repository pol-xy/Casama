import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/casama_repository.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'cas_snap_interactive_view.dart';
import 'quicksnap_camera_screen.dart';
import 'quicksnap_image_view.dart';
import 'quicksnap_lightbox.dart';

class QuickSnapFeedScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 = Highlights, 1 = All CASnaps (Filterable Gallery)

  const QuickSnapFeedScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<QuickSnapFeedScreen> createState() =>
      _QuickSnapFeedScreenState();
}

class _QuickSnapFeedScreenState extends ConsumerState<QuickSnapFeedScreen> {
  late int _selectedTab;
  late int _previousTab;
  int _currentSnapIndex = 0;
  String _galleryFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 1);
    _previousTab = _selectedTab;
  }

  void _selectTab(int next) {
    if (next == _selectedTab) return;
    setState(() {
      _previousTab = _selectedTab;
      _selectedTab = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final repo = ref.watch(repositoryProvider);
    final snaps = repo.quickSnaps;
    final streak = repo.quickSnapStreak;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: Column(
          children: [
            CasamaWaveHeader(
              title: '${repo.currentHousehold.name} Gallery',
              subtitle:
                  '${snaps.length} ${snaps.length == 1 ? 'photo' : 'photos'} • Shared household moments',
              compact: true,
              onBackTap: () => Navigator.of(context).pop(),
              rightActions: [
                if (streak > 0)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: pal.amberBg,
                      borderRadius: CasamaSpacing.roundedPill,
                      border: Border.all(
                        color: pal.amberFg.withValues(alpha: 0.35),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${streak}d 🔥',
                      style: TextStyle(
                        color: pal.amberFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                CasamaCircleIconButton(
                  icon: Icons.photo_camera_rounded,
                  semanticLabel: 'New CASnap',
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const QuickSnapCameraScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
              child: CasamaSegmentedTrack<int>(
                margin: const EdgeInsets.only(bottom: CasamaSpacing.xs),
                selectedValue: _selectedTab,
                onSelected: _selectTab,
                segments: const [
                  CasamaFilterOption(value: 0, label: 'Highlights'),
                  CasamaFilterOption(value: 1, label: 'All CASnaps'),
                ],
              ),
            ),

            Expanded(
              child: snaps.isEmpty
                  ? _buildEmptyState(context, pal)
                  : CasamaDirectionalSwitcher(
                      index: _selectedTab,
                      previousIndex: _previousTab,
                      child: _selectedTab == 0
                          ? _buildHighlightsView(context, snaps)
                          : _buildAllCasnapsView(context, repo, snaps, streak),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, CasamaPalette pal) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CasamaSpacing.xl),
        child: CasamaCard(
          padding: const EdgeInsets.all(CasamaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 56,
                color: pal.textMuted,
              ),
              const SizedBox(height: 14),
              Text(
                'No QuickSnaps yet!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Be the first to share a moment with housemates.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pal.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              CasamaButton(
                label: 'Take QuickSnap',
                icon: Icons.photo_camera_outlined,
                isFullWidth: false,
                height: 48,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const QuickSnapCameraScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsView(
    BuildContext context,
    List<QuickSnap> snaps,
  ) {
    final pal = context.palette;
    if (_currentSnapIndex >= snaps.length) _currentSnapIndex = 0;
    final snap = snaps[_currentSnapIndex];

    return SingleChildScrollView(
      key: const ValueKey('casnap_live_view'),
      padding: EdgeInsets.fromLTRB(
        CasamaSpacing.md,
        CasamaSpacing.xs,
        CasamaSpacing.md,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        children: [
          if (snaps.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(snaps.length, (index) {
                  final isCurrent = index == _currentSnapIndex;
                  return AnimatedContainer(
                    duration: CasamaMotion.resolve(
                      context,
                      CasamaMotion.press,
                    ),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isCurrent ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isCurrent ? pal.primaryCoral : pal.border,
                      borderRadius: CasamaSpacing.roundedPill,
                    ),
                  );
                }),
              ),
            ),
          CasSnapInteractiveView(
            snapId: snap.id,
            fallbackSnap: snap,
            heroTag: 'live_casnap_${snap.id}',
            onPreviousSnap: _currentSnapIndex > 0
                ? () => setState(() => _currentSnapIndex--)
                : null,
            onNextSnap: _currentSnapIndex < snaps.length - 1
                ? () => setState(() => _currentSnapIndex++)
                : null,
            onCenterTap: () => showCasamaSnapLightbox(
              context,
              snap: snap,
              heroTag: 'live_casnap_${snap.id}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllCasnapsView(
    BuildContext context,
    CasamaRepository repo,
    List<QuickSnap> snaps,
    int streak,
  ) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());
    final myName = repo.currentUser.displayName;
    final memberNames = repo.members
        .where((m) => m.profile.id != repo.currentUser.id)
        .map((m) => m.profile.displayName)
        .toList();

    final filterOptions = <CasamaFilterOption<String>>[
      CasamaFilterOption(value: 'all', label: 'All (${snaps.length})'),
      const CasamaFilterOption(value: 'you', label: 'Your Shots'),
      for (final name in memberNames)
        CasamaFilterOption(value: 'sender:$name', label: name.split(' ').first),
    ];

    final filtered = snaps.where((s) {
      if (_galleryFilter == 'all') return true;
      if (_galleryFilter == 'you') {
        return s.senderId == repo.currentUser.id ||
            s.senderName == myName ||
            s.senderName == 'You';
      }
      if (_galleryFilter.startsWith('sender:')) {
        final target = _galleryFilter.substring(7);
        return s.senderName == target ||
            s.senderName.split(' ').first == target.split(' ').first;
      }
      return true;
    }).toList();

    // Group snaps by day label
    final grouped = <String, List<QuickSnap>>{};
    final now = DateTime.now();
    for (final s in filtered) {
      final label = _groupDateLabel(s.createdAt, now);
      grouped.putIfAbsent(label, () => []).add(s);
    }

    return CustomScrollView(
      key: const ValueKey('casnap_memories_gallery'),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  CasamaSpacing.md,
                  CasamaSpacing.xs,
                  CasamaSpacing.md,
                  CasamaSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            monthName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: pal.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${snaps.length} moments saved in household album',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: pal.softBlush,
                        borderRadius: CasamaSpacing.roundedPill,
                        border: Border.all(
                          color: pal.primaryCoral.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: pal.primaryCoral,
                            size: 15,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${streak}d Streak',
                            style: theme.textTheme.labelMedium?.tabular.copyWith(
                              color: pal.primaryCoral,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              CasamaPillFilterRail<String>(
                options: filterOptions,
                selectedValue: _galleryFilter,
                onSelected: (val) => setState(() => _galleryFilter = val),
              ),
              const SizedBox(height: CasamaSpacing.xs),
            ],
          ),
        ),

        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(CasamaSpacing.xl),
                child: Text(
                  'No shots match this filter yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: pal.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          for (final entry in grouped.entries) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CasamaSpacing.md,
                  CasamaSpacing.md,
                  CasamaSpacing.md,
                  CasamaSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${entry.value.length} ${entry.value.length == 1 ? 'shot' : 'shots'}',
                      style: theme.textTheme.labelSmall?.tabular.copyWith(
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: CasamaSpacing.md),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate((context, idx) {
                  final snap = entry.value[idx];
                  final heroTag = 'gal_casnap_${entry.key}_${idx}_${snap.id}';
                  final creator = resolveSnapCreatorProfile(repo, snap);
                  return Semantics(
                    button: true,
                    label: 'Open photo by ${creator.displayName}',
                    child: CasamaPressable(
                      enableHaptic: true,
                      onTap: () => showCasamaSnapLightbox(
                        context,
                        snap: snap,
                        heroTag: heroTag,
                      ),
                      child: ExcludeSemantics(
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
                                QuickSnapImageView(
                                  imageUrl: snap.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: 42,
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
                                Positioned(
                                  left: 6,
                                  right: 6,
                                  bottom: 6,
                                  child: Row(
                                    children: [
                                      CasamaAvatar(
                                        radius: 9,
                                        avatarUrl: creator.avatarUrl,
                                        name: creator.displayName,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          creator.displayName.split(' ').first,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
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
                    ),
                  );
                }, childCount: entry.value.length),
              ),
            ),
          ],

        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
        ),
      ],
    );
  }

  String _groupDateLabel(DateTime dt, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('MMMM yyyy').format(dt);
  }
}
