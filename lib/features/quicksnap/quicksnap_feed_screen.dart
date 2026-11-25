import 'dart:async';
import 'dart:math' as math;

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
import '../../shared/widgets/casama_sheet_scaffold.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'quicksnap_camera_screen.dart';
import 'quicksnap_image_view.dart';
import 'quicksnap_lightbox.dart';

class QuickSnapFeedScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 = Live Snaps, 1 = Memories (Filterable Gallery)

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
  final TextEditingController _commentCtrl = TextEditingController();
  final List<_FloatingEmoji> _activeFloatingEmojis = [];
  final List<Timer> _emojiTimers = [];

  static const _quickReactionEmojis = ['😍', '🔥', '❤️', '😂', '👍', '✨'];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex.clamp(0, 1);
    _previousTab = _selectedTab;
  }

  @override
  void dispose() {
    for (final timer in _emojiTimers) {
      timer.cancel();
    }
    _commentCtrl.dispose();
    super.dispose();
  }

  void _triggerFloatingEmoji(String emoji) {
    if (CasamaMotion.reduceMotion(context)) return;
    final random = math.Random();
    for (var i = 0; i < 4; i++) {
      final id = DateTime.now().microsecondsSinceEpoch + i;
      final fe = _FloatingEmoji(
        id: id,
        emoji: emoji,
        startX: 0.2 + random.nextDouble() * 0.6,
      );
      setState(() => _activeFloatingEmojis.add(fe));
      final t = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _activeFloatingEmojis.removeWhere((e) => e.id == id);
          });
        }
      });
      _emojiTimers.add(t);
    }
  }

  void _sendReaction(String snapId, String emoji) {
    ref.read(repositoryProvider).reactToQuickSnap(snapId, emoji);
    _triggerFloatingEmoji(emoji);
  }

  void _sendComment(String snapId) {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(repositoryProvider).commentOnQuickSnap(snapId, text);
    _commentCtrl.clear();
    FocusScope.of(context).unfocus();
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
                  '${snaps.length} ${snaps.length == 1 ? 'photo' : 'photos'} • Shared with you & your shots',
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
                  CasamaFilterOption(value: 0, label: 'Live Snaps'),
                  CasamaFilterOption(value: 1, label: 'Memories'),
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
                          ? _buildLiveSnapsView(context, snaps)
                          : _buildMemoriesView(context, repo, snaps, streak),
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

  Widget _buildLiveSnapsView(BuildContext context, List<QuickSnap> snaps) {
    final pal = context.palette;
    final theme = Theme.of(context);
    if (_currentSnapIndex >= snaps.length) _currentSnapIndex = 0;
    final snap = snaps[_currentSnapIndex];
    final relativeTime = _formatRelativeTime(snap.createdAt);
    final frameSize = math.min(MediaQuery.sizeOf(context).width - 40, 340.0);

    return Stack(
      key: const ValueKey('casnap_live_view'),
      children: [
        SingleChildScrollView(
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

              // Hero Locket Photo Frame (tap center for Lightbox, edges to step)
              Center(
                child: SizedBox(
                  width: frameSize,
                  height: frameSize,
                  child: Hero(
                    tag: 'live_casnap_${snap.id}',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: pal.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: context.isDark ? 0.45 : 0.16,
                            ),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
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
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.65),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                children: [
                                  CasamaAvatar(
                                    avatarUrl: snap.senderAvatar,
                                    radius: 17,
                                    name: snap.senderName,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          snap.senderName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          relativeTime,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      borderRadius: CasamaSpacing.roundedPill,
                                    ),
                                    child: Text(
                                      snap.recipientType ==
                                              QuickSnapRecipientType.everyone
                                          ? 'Everyone'
                                          : 'Direct',
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
                          ),
                          if (snap.caption != null && snap.caption!.isNotEmpty)
                            Positioned(
                              bottom: 16,
                              left: 16,
                              right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: CasamaSpacing.roundedPill,
                                ),
                                child: Text(
                                  snap.caption!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            top: 56,
                            bottom: 56,
                            width: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (_currentSnapIndex > 0) {
                                  setState(() => _currentSnapIndex--);
                                }
                              },
                            ),
                          ),
                          Positioned(
                            left: 72,
                            right: 72,
                            top: 56,
                            bottom: 56,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => showCasamaSnapLightbox(
                                context,
                                snap: snap,
                                heroTag: 'live_casnap_${snap.id}',
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 56,
                            bottom: 56,
                            width: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                if (_currentSnapIndex < snaps.length - 1) {
                                  setState(() => _currentSnapIndex++);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CasamaSpacing.md),

              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: _quickReactionEmojis.map((emoji) {
                  return Semantics(
                    button: true,
                    label: 'React $emoji',
                    child: CasamaPressable(
                      enableHaptic: true,
                      onTap: () => _sendReaction(snap.id, emoji),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: pal.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.border),
                        ),
                        alignment: Alignment.center,
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: CasamaSpacing.md),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: pal.surface,
                        borderRadius: CasamaSpacing.roundedPill,
                        border: Border.all(color: pal.border),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: pal.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Send message... 💬',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(
                            color: pal.textSecondary,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendComment(snap.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Send message',
                    icon: Icon(Icons.send_rounded, color: pal.primaryCoral),
                    onPressed: () => _sendComment(snap.id),
                  ),
                  IconButton(
                    tooltip: 'View comments',
                    icon: Badge(
                      label: Text('${snap.comments.length}'),
                      isLabelVisible: snap.comments.isNotEmpty,
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: pal.textSecondary,
                      ),
                    ),
                    onPressed: () => _showCommentsSheet(context, snap),
                  ),
                ],
              ),
            ],
          ),
        ),
        ..._activeFloatingEmojis.map((fe) => _AnimatedFloatingEmoji(fe: fe)),
      ],
    );
  }

  Widget _buildMemoriesView(
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
      const CasamaFilterOption(value: 'direct', label: 'Direct'),
    ];

    final filtered = snaps.where((s) {
      if (_galleryFilter == 'all') return true;
      if (_galleryFilter == 'you') {
        return s.senderId == repo.currentUser.id ||
            s.senderName == myName ||
            s.senderName == 'You';
      }
      if (_galleryFilter == 'direct') {
        return s.recipientType == QuickSnapRecipientType.selectedHousemates;
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
                  final isDirect =
                      snap.recipientType ==
                      QuickSnapRecipientType.selectedHousemates;
                  return Semantics(
                    button: true,
                    label: 'Open photo by ${snap.senderName}',
                    child: CasamaPressable(
                      enableHaptic: true,
                      onTap: () => showCasamaSnapLightbox(
                        context,
                        snap: snap,
                        heroTag: heroTag,
                      ),
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
                                      'Direct',
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
                                      radius: 9,
                                      avatarUrl: snap.senderAvatar,
                                      name: snap.senderName,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        snap.senderName.split(' ').first,
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

  void _showCommentsSheet(BuildContext context, QuickSnap snap) {
    showCasamaSheet<void>(
      context,
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Comments (${snap.comments.length})',
      subtitle: 'Replies to ${snap.senderName}',
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        if (snap.comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No comments yet. Say something friendly!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pal.textSecondary,
                ),
              ),
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < snap.comments.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CasamaAvatar(
                    avatarUrl: snap.comments[i].userAvatar,
                    radius: 16,
                    name: snap.comments[i].userName,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snap.comments[i].userName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          snap.comments[i].text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatRelativeTime(snap.comments[i].createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: pal.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, h:mm a').format(time);
  }
}

class _FloatingEmoji {
  final int id;
  final String emoji;
  final double startX;

  const _FloatingEmoji({
    required this.id,
    required this.emoji,
    required this.startX,
  });
}

class _AnimatedFloatingEmoji extends StatefulWidget {
  final _FloatingEmoji fe;
  const _AnimatedFloatingEmoji({required this.fe});

  @override
  State<_AnimatedFloatingEmoji> createState() => _AnimatedFloatingEmojiState();
}

class _AnimatedFloatingEmojiState extends State<_AnimatedFloatingEmoji>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _upAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _upAnimation = Tween<double>(
      begin: 0.0,
      end: 260.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.35).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Positioned(
          left: width * widget.fe.startX,
          bottom: 120 + _upAnimation.value,
          child: IgnorePointer(
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  widget.fe.emoji,
                  style: const TextStyle(fontSize: 34),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
