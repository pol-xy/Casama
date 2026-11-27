import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import '../../shared/widgets/casama_sheet_scaffold.dart';
import 'quicksnap_image_view.dart';

String formatSnapRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return DateFormat('MMM d, h:mm a').format(time);
}

QuickSnap? _resolveLiveSnap(
  List<QuickSnap> snaps,
  String snapId,
  QuickSnap? fallback,
) {
  for (final s in snaps) {
    if (s.id == snapId) return s;
  }
  return fallback;
}

/// Opens the live-updating slide-up sheet listing every housemate's reaction
/// breakdown (`🔥-3`, `❤️-2`) sorted by highest total reaction count descending.
Future<void> showCasSnapReactorsSheet(
  BuildContext context, {
  required String snapId,
  QuickSnap? fallbackSnap,
}) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.favorite_rounded,
    title: 'Reactions',
    subtitle: '',
    subtitleBuilder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final repo = ref.watch(repositoryProvider);
        final snap = _resolveLiveSnap(repo.quickSnaps, snapId, fallbackSnap);
        final total = snap?.totalReactionCount ?? 0;
        final reactorCount = snap?.reactorBreakdowns.length ?? 0;
        return Text(
          '$total ${total == 1 ? 'reaction' : 'reactions'} from '
          '$reactorCount ${reactorCount == 1 ? 'housemate' : 'housemates'}',
        );
      },
    ),
    builder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        final repo = ref.watch(repositoryProvider);
        final snap = _resolveLiveSnap(repo.quickSnaps, snapId, fallbackSnap);
        final breakdowns = snap?.reactorBreakdowns ?? const [];

        if (breakdowns.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'No reactions yet. Tap an emoji to react!',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: pal.textSecondary,
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < breakdowns.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _ReactorBreakdownRow(breakdown: breakdowns[i]),
            ],
          ],
        );
      },
    ),
  );
}

class _ReactorBreakdownRow extends ConsumerWidget {
  final QuickSnapReactorBreakdown breakdown;

  const _ReactorBreakdownRow({required this.breakdown});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final profile = resolveProfileByUserId(
      repo,
      breakdown.userId,
      breakdown.fallbackUserName,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CasamaAvatar(
          avatarUrl: profile.avatarUrl,
          radius: 18,
          name: profile.preferredName,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.preferredName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: pal.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 6,
            runSpacing: 6,
            children: breakdown.emojiCounts.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: CasamaSpacing.roundedPill,
                  border: Border.all(color: pal.border),
                ),
                child: Text(
                  '${entry.key}-${entry.value}',
                  style: theme.textTheme.labelMedium?.tabular.copyWith(
                    color: pal.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Opens the live-updating slide-up sheet listing comments on [snapId].
Future<void> showCasSnapCommentsSheet(
  BuildContext context, {
  required String snapId,
  QuickSnap? fallbackSnap,
}) {
  return showCasamaSheet<void>(
    context,
    icon: Icons.chat_bubble_outline_rounded,
    title: 'Comments',
    subtitle: '',
    subtitleBuilder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final repo = ref.watch(repositoryProvider);
        final snap = _resolveLiveSnap(repo.quickSnaps, snapId, fallbackSnap);
        final count = snap?.comments.length ?? 0;
        final creator = snap != null
            ? resolveSnapCreatorProfile(repo, snap).preferredName
            : 'Housemate';
        return Text(
          '$count ${count == 1 ? 'reply' : 'replies'} to $creator',
        );
      },
    ),
    builder: (_) => Consumer(
      builder: (ctx, ref, _) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        final repo = ref.watch(repositoryProvider);
        final snap = _resolveLiveSnap(repo.quickSnaps, snapId, fallbackSnap);
        final comments = snap?.comments ?? const <QuickSnapComment>[];

        if (comments.isEmpty) {
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
            for (var i = 0; i < comments.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final comment = comments[i];
                  final profile = resolveProfileByUserId(
                    repo,
                    comment.userId,
                    comment.userName,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CasamaAvatar(
                        avatarUrl: profile.avatarUrl ?? comment.userAvatar,
                        radius: 16,
                        name: profile.preferredName,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.preferredName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: pal.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              comment.text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: pal.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatSnapRelativeTime(comment.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pal.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// Shared interactive CASnap stage used identically in both **Highlights** and
/// the **All CASnaps** photo viewer: Photo Card (with top creator bar, caption,
/// and bottom-left Facebook-style reactions pill), 6-emoji multi-tap bar, and
/// `Comment... 💬 [Send] [Open comments]` row.
class CasSnapInteractiveView extends ConsumerStatefulWidget {
  final String snapId;
  final QuickSnap? fallbackSnap;
  final String heroTag;
  final double? maxFrameSize;
  final VoidCallback? onPreviousSnap;
  final VoidCallback? onNextSnap;
  final VoidCallback? onCenterTap;

  const CasSnapInteractiveView({
    super.key,
    required this.snapId,
    this.fallbackSnap,
    required this.heroTag,
    this.maxFrameSize,
    this.onPreviousSnap,
    this.onNextSnap,
    this.onCenterTap,
  });

  @override
  ConsumerState<CasSnapInteractiveView> createState() =>
      _CasSnapInteractiveViewState();
}

class _CasSnapInteractiveViewState
    extends ConsumerState<CasSnapInteractiveView> {
  final TextEditingController _commentCtrl = TextEditingController();
  final List<_FloatingEmoji> _activeFloatingEmojis = [];
  int _floatingSeq = 0;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _triggerFloatingEmoji(String emoji) {
    if (CasamaMotion.reduceMotion(context)) return;
    final random = math.Random();
    final batch = List.generate(3, (i) {
      return _FloatingEmoji(
        id: ++_floatingSeq,
        emoji: emoji,
        startX: 0.18 + random.nextDouble() * 0.64,
      );
    });
    setState(() => _activeFloatingEmojis.addAll(batch));
  }

  void _removeFloatingEmoji(int id) {
    if (!mounted) return;
    setState(() {
      _activeFloatingEmojis.removeWhere((e) => e.id == id);
    });
  }

  void _handleReactionTap(String snapId, String emoji) {
    ref.read(repositoryProvider).queueQuickSnapReaction(snapId, emoji);
    _triggerFloatingEmoji(emoji);
  }

  void _sendComment(String snapId) {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(repositoryProvider).commentOnQuickSnap(snapId, text);
    _commentCtrl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);
    final snap = _resolveLiveSnap(
      repo.quickSnaps,
      widget.snapId,
      widget.fallbackSnap,
    );
    if (snap == null) return const SizedBox.shrink();

    final creator = resolveSnapCreatorProfile(repo, snap);
    final relativeTime = formatSnapRelativeTime(snap.createdAt);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final frameSize = math.min(
      screenWidth - 40,
      widget.maxFrameSize ?? 340.0,
    );
    final totalReactions = snap.totalReactionCount;
    final topEmojis = snap.topReactionEmojis(maxCount: 3);
    final hasCaption =
        snap.caption != null && snap.caption!.trim().isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: SizedBox(
                width: frameSize,
                height: frameSize,
                child: Hero(
                  tag: widget.heroTag,
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
                        // Top creator gradient scrim
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
                                  avatarUrl: creator.avatarUrl,
                                  radius: 17,
                                  name: creator.preferredName,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        creator.preferredName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                              ],
                            ),
                          ),
                        ),

                        // Optional deck navigation zones (kept clear of bottom pill)
                        if (widget.onPreviousSnap != null)
                          Positioned(
                            left: 0,
                            top: 64,
                            bottom: 72,
                            width: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onPreviousSnap,
                            ),
                          ),
                        if (widget.onCenterTap != null)
                          Positioned(
                            left: 72,
                            right: 72,
                            top: 64,
                            bottom: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onCenterTap,
                            ),
                          ),
                        if (widget.onNextSnap != null)
                          Positioned(
                            right: 0,
                            top: 64,
                            bottom: 72,
                            width: 72,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: widget.onNextSnap,
                            ),
                          ),

                        // Bottom caption + Facebook-style reactions pill
                        if (hasCaption || totalReactions > 0)
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasCaption)
                                  Align(
                                    alignment: totalReactions > 0
                                        ? Alignment.centerLeft
                                        : Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.65,
                                        ),
                                        borderRadius: CasamaSpacing.roundedPill,
                                      ),
                                      child: Text(
                                        snap.caption!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: totalReactions > 0
                                            ? TextAlign.start
                                            : TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (hasCaption && totalReactions > 0)
                                  const SizedBox(height: 8),
                                if (totalReactions > 0)
                                  _FacebookReactionsPill(
                                    key: ValueKey(
                                      'casnap_reactions_pill_${snap.id}',
                                    ),
                                    topEmojis: topEmojis,
                                    totalCount: totalReactions,
                                    onTap: () => showCasSnapReactorsSheet(
                                      context,
                                      snapId: snap.id,
                                      fallbackSnap: snap,
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
            const SizedBox(height: CasamaSpacing.md),

            // 6-Emoji Multi-Tap Reaction Bar
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: kCasSnapReactionEmojis.map((emoji) {
                  final isActive = snap.hasUserReacted(
                    repo.currentUser.id,
                    emoji,
                  );
                  return Semantics(
                    button: true,
                    label: 'React $emoji',
                    child: CasamaPressable(
                      enableHaptic: true,
                      onTap: () => _handleReactionTap(snap.id, emoji),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: AnimatedContainer(
                            duration: CasamaMotion.resolve(
                              context,
                              CasamaMotion.press,
                            ),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isActive ? pal.softBlush : pal.card,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive ? pal.primaryCoral : pal.border,
                                width: isActive ? 1.5 : 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: ExcludeSemantics(
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),

            // Comment Input Row
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
                        hintText: 'Comment... 💬',
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
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Send comment',
                  constraints: const BoxConstraints(
                    minWidth: CasamaSpacing.minTouchTarget,
                    minHeight: CasamaSpacing.minTouchTarget,
                  ),
                  icon: Icon(Icons.send_rounded, color: pal.primaryCoral),
                  onPressed: () => _sendComment(snap.id),
                ),
                IconButton(
                  tooltip: 'Open comments',
                  constraints: const BoxConstraints(
                    minWidth: CasamaSpacing.minTouchTarget,
                    minHeight: CasamaSpacing.minTouchTarget,
                  ),
                  icon: Badge(
                    label: Text('${snap.comments.length}'),
                    isLabelVisible: snap.comments.isNotEmpty,
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: pal.textSecondary,
                    ),
                  ),
                  onPressed: () => showCasSnapCommentsSheet(
                    context,
                    snapId: snap.id,
                    fallbackSnap: snap,
                  ),
                ),
              ],
            ),
          ],
        ),
        ..._activeFloatingEmojis.map(
          (fe) => _AnimatedFloatingEmoji(
            key: ValueKey('float_${fe.id}'),
            fe: fe,
            onComplete: () => _removeFloatingEmoji(fe.id),
          ),
        ),
      ],
    );
  }
}

class _FacebookReactionsPill extends StatelessWidget {
  final List<String> topEmojis;
  final int totalCount;
  final VoidCallback onTap;

  const _FacebookReactionsPill({
    super.key,
    required this.topEmojis,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = context.isDark;
    const badgeSize = 24.0;
    const step = 18.0; // 6px overlap
    final stackWidth = topEmojis.isEmpty
        ? 0.0
        : badgeSize + (topEmojis.length - 1) * step;

    return Semantics(
      button: true,
      label:
          '$totalCount ${totalCount == 1 ? 'reaction' : 'reactions'}. View reactions',
      child: CasamaPressable(
        enableHaptic: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: CasamaSpacing.minTouchTarget,
            minHeight: CasamaSpacing.minTouchTarget,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: CasamaSpacing.roundedPill,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (topEmojis.isNotEmpty) ...[
                    SizedBox(
                      width: stackWidth,
                      height: badgeSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = topEmojis.length - 1; i >= 0; i--)
                            Positioned(
                              left: i * step,
                              top: 0,
                              child: Container(
                                width: badgeSize,
                                height: badgeSize,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1F2B28)
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.85),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  topEmojis[i],
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    '$totalCount',
                    style: theme.textTheme.labelMedium?.tabular.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
  final VoidCallback onComplete;

  const _AnimatedFloatingEmoji({
    super.key,
    required this.fe,
    required this.onComplete,
  });

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
      duration: const Duration(milliseconds: 900),
    );
    _upAnimation = Tween<double>(
      begin: 0.0,
      end: 220.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.55, end: 1.3).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
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
          left: (width * widget.fe.startX).clamp(24.0, width - 64.0),
          bottom: 120 + _upAnimation.value,
          child: IgnorePointer(
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Text(
                  widget.fe.emoji,
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
