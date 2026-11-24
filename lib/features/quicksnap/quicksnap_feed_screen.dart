import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/casama_avatar.dart';
import 'quicksnap_image_view.dart';

class QuickSnapFeedScreen extends ConsumerStatefulWidget {
  final int initialTabIndex; // 0 = Live Snaps, 1 = Memories
  const QuickSnapFeedScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<QuickSnapFeedScreen> createState() =>
      _QuickSnapFeedScreenState();
}

class _QuickSnapFeedScreenState extends ConsumerState<QuickSnapFeedScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedTab; // 0 = Live, 1 = Memories
  int _currentSnapIndex = 0;
  final TextEditingController _commentCtrl = TextEditingController();

  // Floating animated emoji reactions
  final List<_FloatingEmoji> _activeFloatingEmojis = [];

  final List<String> _quickReactionEmojis = ['😍', '🔥', '❤️', '😂', '👍', '✨'];

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTabIndex;
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _triggerFloatingEmoji(String emoji) {
    final random = math.Random();
    for (int i = 0; i < 4; i++) {
      final id = DateTime.now().microsecondsSinceEpoch + i;
      final startX = 0.2 + random.nextDouble() * 0.6;
      final floatingEmoji = _FloatingEmoji(
        id: id,
        emoji: emoji,
        startX: startX,
      );
      setState(() {
        _activeFloatingEmojis.add(floatingEmoji);
      });
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() {
            _activeFloatingEmojis.removeWhere((e) => e.id == id);
          });
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(repositoryProvider);
    final snaps = repo.quickSnaps;
    final streak = repo.quickSnapStreak;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D11),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),

                  // Segmented Switcher (Live Snaps / Memories)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(20),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TabPill(
                          label: 'Live Snaps',
                          selected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        _TabPill(
                          label: 'Memories',
                          selected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Streak Badge (Locket Style)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CasamaColors.warningOrange.withAlpha(30),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: CasamaColors.warningOrange.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          '${streak}d',
                          style: const TextStyle(
                            color: CasamaColors.warningOrange,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Body ───────────────────────────────────────
            Expanded(
              child: snaps.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.white30,
                            size: 64,
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No QuickSnaps yet!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Be the first to share a moment with housemates.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CasamaColors.primaryCoral,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Take QuickSnap'),
                          ),
                        ],
                      ),
                    )
                  : (_selectedTab == 0
                        ? _buildLiveSnapsView(snaps)
                        : _buildMemoriesView(snaps, streak)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Live Snaps View (Locket View Screen) ─────────────────────
  Widget _buildLiveSnapsView(List<QuickSnap> snaps) {
    if (_currentSnapIndex >= snaps.length) {
      _currentSnapIndex = 0;
    }
    final snap = snaps[_currentSnapIndex];
    final relativeTime = _formatRelativeTime(snap.createdAt);

    return Stack(
      children: [
        Column(
          children: [
            const SizedBox(height: 8),

            // Snap Counter indicator if multiple
            if (snaps.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(snaps.length, (index) {
                    final isCurrent = index == _currentSnapIndex;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isCurrent ? 16 : 6,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? CasamaColors.primaryCoral
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),

            // Rounded Square Photo Card
            Expanded(
              child: Center(
                child: Container(
                  width: math.min(MediaQuery.of(context).size.width - 32, 360),
                  height: math.min(MediaQuery.of(context).size.width - 32, 360),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(36),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(160),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Photo
                      QuickSnapImageView(
                        imageUrl: snap.imageUrl,
                        fit: BoxFit.cover,
                      ),

                      // Gradient overlay for readability
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withAlpha(150),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              CasamaAvatar(
                                avatarUrl: snap.senderAvatar,
                                radius: 18,
                                name: snap.senderName,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      snap.senderName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
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
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  snap.recipientType ==
                                          QuickSnapRecipientType.everyone
                                      ? 'Everyone'
                                      : 'Friends',
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

                      // Caption at bottom of photo (Locket style)
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
                              color: Colors.black.withAlpha(160),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              snap.caption!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),

                      // Previous/Next tap targets
                      Positioned(
                        left: 0,
                        top: 60,
                        bottom: 60,
                        width: 80,
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
                        right: 0,
                        top: 60,
                        bottom: 60,
                        width: 80,
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

            const SizedBox(height: 12),

            // ── Interactive Quick Reactions Bar ─────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _quickReactionEmojis.map((emoji) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () => _sendReaction(snap.id, emoji),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // ── Send Message / Reply Bar ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(20),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Send message... 💬',
                          hintStyle: TextStyle(
                            color: Colors.white54,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: (_) => _sendComment(snap.id),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: CasamaColors.primaryCoral,
                    ),
                    onPressed: () => _sendComment(snap.id),
                  ),
                  IconButton(
                    icon: Badge(
                      label: Text('${snap.comments.length}'),
                      isLabelVisible: snap.comments.isNotEmpty,
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white70,
                      ),
                    ),
                    onPressed: () => _showCommentsSheet(snap),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),

        // Floating Animated Emojis Layer
        ..._activeFloatingEmojis.map((fe) => _AnimatedFloatingEmoji(fe: fe)),
      ],
    );
  }

  // ── Memories View (Monthly Photo Grid) ───────────────────────
  Widget _buildMemoriesView(List<QuickSnap> snaps, int streak) {
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      monthName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${snaps.length} moments saved in household album',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: CasamaColors.primaryCoral.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: CasamaColors.primaryCoral.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: CasamaColors.primaryCoral,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${streak}d Streak',
                        style: const TextStyle(
                          color: CasamaColors.primaryCoral,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Photo Grid (Calendar style like Locket screenshot 1 & 3)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final snap = snaps[index];
              final dateStr = DateFormat('MMM d').format(snap.createdAt);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTab = 0;
                    _currentSnapIndex = index;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(100),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
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
                      // Date badge
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(160),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            dateStr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Reaction indicator
                      if (snap.reactions.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(140),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              snap.reactions.last.emoji,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }, childCount: snaps.length),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  void _showCommentsSheet(QuickSnap snap) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Comments (${snap.comments.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: snap.comments.isEmpty
                        ? const Center(
                            child: Text(
                              'No comments yet. Say something friendly!',
                              style: TextStyle(color: Colors.white54),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: snap.comments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final comment = snap.comments[i];
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CasamaAvatar(
                                    avatarUrl: comment.userAvatar,
                                    radius: 16,
                                    name: comment.userName,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment.userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          comment.text,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    _formatRelativeTime(comment.createdAt),
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
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

// ── Segmented Tab Pill ─────────────────────────────────────────
class _TabPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Floating Emoji Data & Animation ─────────────────────────────
class _FloatingEmoji {
  final int id;
  final String emoji;
  final double startX;

  _FloatingEmoji({required this.id, required this.emoji, required this.startX});
}

class _AnimatedFloatingEmoji extends StatefulWidget {
  final _FloatingEmoji fe;
  const _AnimatedFloatingEmoji({required this.fe});

  @override
  State<_AnimatedFloatingEmoji> createState() => _AnimatedFloatingEmojiState();
}

class _AnimatedFloatingEmojiState extends State<_AnimatedFloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _upAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _upAnimation = Tween<double>(
      begin: 0.0,
      end: 280.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.4).animate(
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
    final size = MediaQuery.of(context).size;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Positioned(
          left: size.width * widget.fe.startX,
          bottom: 120 + _upAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                widget.fe.emoji,
                style: const TextStyle(fontSize: 36),
              ),
            ),
          ),
        );
      },
    );
  }
}
