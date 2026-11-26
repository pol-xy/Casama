import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/dimensions.dart';
import '../../../core/motion/casama_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models.dart';
import '../../../data/repository_provider.dart';
import '../../../shared/widgets/casama_avatar.dart';
import '../../../shared/widgets/casama_button.dart';
import '../../../shared/widgets/casama_sheet_scaffold.dart';
import '../../../shared/widgets/casama_text_field.dart';

const String rouletteLastSpinPrefKey = 'casama_roulette_last_spin_ms';

enum TaskRouletteMode { task, chatQuestion }

/// Opens the embedded slide-up Roulette sheet for either `Household Tasks`
/// ([TaskRouletteMode.task]) or `Group Chat` ([TaskRouletteMode.chatQuestion]).
Future<void> showTaskRouletteSheet(
  BuildContext context, {
  MaintenanceTask? task,
  TaskRouletteMode mode = TaskRouletteMode.task,
  Future<void> Function(String question, MemberPresence winner)?
      onChatSpinSubmitted,
}) {
  final isChat = mode == TaskRouletteMode.chatQuestion;
  return showCasamaSheet<void>(
    context,
    icon: Icons.casino_outlined,
    title: isChat ? 'Spin Chore Roulette' : 'Task Roulette',
    subtitle: isChat
        ? 'Ask a question & let the wheel pick a housemate'
        : 'Spin to pick a housemate fairly',
    builder: (sheetCtx) => _TaskRouletteSheetBody(
      hostContext: context,
      task: task,
      mode: mode,
      onChatSpinSubmitted: onChatSpinSubmitted,
    ),
  );
}

class _TaskRouletteSheetBody extends ConsumerStatefulWidget {
  final BuildContext hostContext;
  final MaintenanceTask? task;
  final TaskRouletteMode mode;
  final Future<void> Function(String question, MemberPresence winner)?
      onChatSpinSubmitted;

  const _TaskRouletteSheetBody({
    required this.hostContext,
    this.task,
    this.mode = TaskRouletteMode.task,
    this.onChatSpinSubmitted,
  });

  @override
  ConsumerState<_TaskRouletteSheetBody> createState() =>
      _TaskRouletteSheetBodyState();
}

class _TaskRouletteSheetBodyState extends ConsumerState<_TaskRouletteSheetBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Animation<double>? _angleAnim;
  final TextEditingController _questionController = TextEditingController();

  double _currentAngle = 0;
  bool _isSpinning = false;
  DateTime? _lastSpinAt;
  MemberPresence? _winner;
  int? _winnerIndex;
  bool _cooldownLoaded = false;
  String? _activeSpinId;
  String? _questionError;
  bool _isSubmittingChat = false;

  bool get _isChatMode => widget.mode == TaskRouletteMode.chatQuestion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CasamaMotion.rouletteSpin,
    );
    if (!_isChatMode) {
      _loadCooldown();
    }
  }

  Future<void> _loadCooldown() async {
    try {
      final repoSpinAt = ref.read(repositoryProvider).lastRouletteSpinAt;
      if (repoSpinAt != null && mounted) {
        setState(() {
          _lastSpinAt = repoSpinAt;
          _cooldownLoaded = true;
        });
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(rouletteLastSpinPrefKey);
      if (mounted) {
        setState(() {
          if (ms != null) {
            _lastSpinAt = DateTime.fromMillisecondsSinceEpoch(ms);
          }
          _cooldownLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cooldownLoaded = true);
    }
  }

  Future<void> _persistCooldown() async {
    final now = DateTime.now();
    if (mounted) {
      setState(() => _lastSpinAt = now);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(rouletteLastSpinPrefKey, now.millisecondsSinceEpoch);
    } catch (_) {
      // Ignore storage failure in ephemeral test environments.
    }
  }

  Duration get _cooldownRemaining {
    if (_lastSpinAt == null) return Duration.zero;
    final expiresAt = _lastSpinAt!.add(const Duration(hours: 24));
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get _isOnCooldown =>
      !_isChatMode && _cooldownLoaded && _cooldownRemaining > Duration.zero;

  String _sliceLabel(UserProfile p) {
    final nick = p.nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final full = p.fullName?.trim();
    if (full != null && full.isNotEmpty) return full.split(' ').first;
    return p.displayName.trim().split(' ').first;
  }

  String _winnerDisplayName(UserProfile p) {
    final nick = p.nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    final full = p.fullName?.trim();
    if (full != null && full.isNotEmpty) return full;
    return p.displayName.trim();
  }

  String _cooldownLabel() {
    final rem = _cooldownRemaining;
    if (rem <= Duration.zero) return '1 spin / 24h • Ready';
    final hours = rem.inHours;
    final mins = rem.inMinutes.remainder(60);
    return 'Cooldown • ${hours}h ${mins}m left';
  }

  @override
  void dispose() {
    _questionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _spin(List<MemberPresence> candidates) {
    if (_isSpinning || _isOnCooldown || candidates.isEmpty) return;

    if (_isChatMode) {
      if (_questionController.text.trim().isEmpty) {
        setState(() {
          _questionError = 'Enter a question before spinning.';
        });
        return;
      }
      if (_questionError != null) {
        setState(() => _questionError = null);
      }
    }

    final reduced = CasamaMotion.reduceMotion(context);
    final sliceCount = candidates.length;
    final sliceAngle = (2 * math.pi) / sliceCount;
    final pickedIdx = math.Random().nextInt(sliceCount);
    final pickedMember = candidates[pickedIdx];

    // Canvas slice `i` center is at `-π/2 + i * sliceAngle`.
    // Rotate wheel clockwise so winner slice center lands cleanly under `-π/2`.
    final targetMod =
        ((2 * math.pi - pickedIdx * sliceAngle) % (2 * math.pi) +
            2 * math.pi) %
        (2 * math.pi);
    final currentMod =
        ((_currentAngle % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);
    final deltaToTarget =
        ((targetMod - currentMod) % (2 * math.pi) + 2 * math.pi) %
        (2 * math.pi);
    final endAngle = _currentAngle + (5 * 2 * math.pi) + deltaToTarget;

    setState(() {
      _isSpinning = true;
      _winner = null;
      _winnerIndex = pickedIdx;
      _activeSpinId = null;
    });

    Future<void> onSpinSettled() async {
      if (_isChatMode) return;
      final repo = ref.read(repositoryProvider);
      final targetTask =
          widget.task ??
          repo.tasks.cast<MaintenanceTask?>().firstWhere(
            (t) => t != null && t.status != TaskStatus.done,
            orElse: () => null,
          );
      try {
        final spinId = await repo.recordRouletteSpin(
          taskId: targetTask?.id,
          taskTitle: targetTask?.title ?? 'Clean Bathroom',
          selectedUserId: pickedMember.profile.id,
        );
        if (mounted) setState(() => _activeSpinId = spinId);
      } catch (_) {}
    }

    if (reduced) {
      setState(() {
        _currentAngle = endAngle % (2 * math.pi);
        _isSpinning = false;
        _winner = pickedMember;
      });
      onSpinSettled();
      return;
    }

    _controller.duration = CasamaMotion.rouletteSpin;
    _angleAnim =
        Tween<double>(begin: _currentAngle, end: endAngle).animate(
            CurvedAnimation(
              parent: _controller,
              curve: CasamaMotion.rouletteDecel,
            ),
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _currentAngle = endAngle % (2 * math.pi);
                _isSpinning = false;
                _winner = pickedMember;
              });
              onSpinSettled();
            }
          });

    _controller.forward(from: 0);
  }

  Future<void> _handleDecision({
    required bool accepted,
    required String taskTitle,
    String? taskId,
  }) async {
    final chosenName = _winner?.profile.displayName ?? 'Housemate';
    final hostContext = widget.hostContext;
    final spinId = _activeSpinId;
    if (spinId != null) {
      try {
        await ref
            .read(repositoryProvider)
            .respondToRouletteSpin(
              spinId: spinId,
              taskId: taskId,
              accepted: accepted,
            );
      } catch (e) {
        if (hostContext.mounted) {
          showCasamaToast(
            hostContext,
            e is StateError ? e.message : 'Could not submit roulette decision.',
            icon: Icons.error_outline_rounded,
          );
        }
        return;
      }
    }
    await _persistCooldown();
    if (!mounted) return;
    Navigator.of(context).pop();
    if (hostContext.mounted) {
      showCasamaToast(
        hostContext,
        accepted
            ? '$chosenName accepted "$taskTitle" (+2 bonus pts)'
            : '$chosenName rejected "$taskTitle" (-3 pts)',
        icon: accepted
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _handleSendToChat() async {
    final winner = _winner;
    final question = _questionController.text.trim();
    if (winner == null || question.isEmpty || _isSubmittingChat) return;
    setState(() => _isSubmittingChat = true);
    try {
      await widget.onChatSpinSubmitted?.call(question, winner);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingChat = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final repo = ref.watch(repositoryProvider);

    // Resolve target task
    final MaintenanceTask? resolvedTask =
        widget.task ??
        repo.tasks.cast<MaintenanceTask?>().firstWhere(
          (t) => t != null && t.status != TaskStatus.done,
          orElse: () => null,
        );
    final taskTitle = resolvedTask?.title ?? 'Clean Bathroom';

    final homeMembers = repo.members.where((m) => m.isHome).toList();
    final candidates = _isChatMode
        ? repo.members
        : (homeMembers.isNotEmpty ? homeMembers : repo.members);

    final displayAngle = _isSpinning
        ? (_angleAnim?.value ?? _currentAngle)
        : _currentAngle;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isChatMode) ...[
          CasamaTextField(
            controller: _questionController,
            label: 'Your Question',
            hint: "e.g., Who's buying dinner tonight?",
            prefixIcon: Icons.help_outline_rounded,
            maxLines: 2,
            enabled: !_isSpinning,
            readOnly: _isSpinning,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_questionError != null) {
                setState(() => _questionError = null);
              }
            },
          ),
          if (_questionError != null) ...[
            const SizedBox(height: 6),
            Text(
              _questionError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: pal.primaryCoral,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: CasamaSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: pal.softSage,
                borderRadius: CasamaSpacing.roundedPill,
                border: Border.all(
                  color: pal.forestTeal.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                'All Housemates (${candidates.length})',
                style: theme.textTheme.labelSmall?.tabular.copyWith(
                  color: pal.forestTeal,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ] else ...[
          // Spinning for task banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: pal.track,
              borderRadius: CasamaSpacing.roundedLg,
              border: Border.all(color: pal.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SPINNING FOR TASK',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: pal.textSecondary,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        taskTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: pal.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pal.successBg,
                    borderRadius: CasamaSpacing.roundedPill,
                    border: Border.all(
                      color: pal.successFg.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    '+5 pts + 2 bonus',
                    style: theme.textTheme.labelSmall?.tabular.copyWith(
                      color: pal.successFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),

          // Eligibility & 24h Cooldown badges
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pal.successBg,
                  borderRadius: CasamaSpacing.roundedPill,
                  border: Border.all(
                    color: pal.successFg.withValues(alpha: 0.32),
                  ),
                ),
                child: Text(
                  homeMembers.isNotEmpty
                      ? '✓ Home Housemates (${candidates.length})'
                      : 'All Housemates (${candidates.length})',
                  style: theme.textTheme.labelSmall?.tabular.copyWith(
                    color: pal.successFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOnCooldown ? pal.neutralBg : pal.amberBg,
                  borderRadius: CasamaSpacing.roundedPill,
                  border: Border.all(
                    color: (_isOnCooldown ? pal.neutralFg : pal.amberFg)
                        .withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  _cooldownLabel(),
                  style: theme.textTheme.labelSmall?.tabular.copyWith(
                    color: _isOnCooldown ? pal.neutralFg : pal.amberFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: CasamaSpacing.md),

        // Roulette Wheel w/ top `-π/2` diamond pointer
        Center(
          child: SizedBox(
            width: 244,
            height: 256,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Rotating slice disc
                Positioned(
                  bottom: 0,
                  child: Transform.rotate(
                    angle: displayAngle,
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _RouletteSlicesPainter(
                                count: math.max(1, candidates.length),
                                sliceColors: [
                                  pal.softBlush,
                                  pal.softSage,
                                  pal.infoBg,
                                  pal.amberBg,
                                ],
                                ringBorderColor: pal.border,
                                highlightedIndex: _isSpinning
                                    ? null
                                    : _winnerIndex,
                              ),
                            ),
                          ),
                          for (var i = 0; i < candidates.length; i++)
                            Transform.rotate(
                              angle: i * (2 * math.pi / candidates.length),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CasamaAvatar(
                                        radius: 15,
                                        avatarUrl:
                                            candidates[i].profile.avatarUrl,
                                        name: candidates[i].profile.displayName,
                                      ),
                                      const SizedBox(height: 3),
                                      SizedBox(
                                        width: 72,
                                        child: Text(
                                          _sliceLabel(candidates[i].profile),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: pal.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Diamond Pointer aligned strictly at -π/2 (12 o'clock)
                Positioned(
                  top: 2,
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: CasamaColors.midnightNavy,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: pal.surface, width: 2),
                      ),
                      child: Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: pal.primaryCoral,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Center Coral SPIN Trigger
                Positioned(
                  bottom: 84,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _questionController,
                    builder: (context, value, _) {
                      final isDisabled =
                          _isSpinning ||
                          _isOnCooldown ||
                          (_isChatMode && value.text.trim().isEmpty);
                      return Semantics(
                        button: true,
                        label: _isChatMode
                            ? 'Spin Chore Roulette'
                            : 'Spin Task Roulette',
                        child: CasamaPressable.fab(
                          onTap: (_isSpinning || _isOnCooldown)
                              ? null
                              : () => _spin(candidates),
                          child: AnimatedContainer(
                            key: const Key('task_roulette_spin_button'),
                            duration: CasamaMotion.resolve(
                              context,
                              CasamaMotion.press,
                            ),
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? pal.textMuted
                                  : pal.primaryCoral,
                              shape: BoxShape.circle,
                              border: Border.all(color: pal.surface, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDisabled
                                          ? pal.textMuted
                                          : pal.primaryCoral)
                                      .withValues(alpha: 0.38),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _isSpinning ? '...' : 'SPIN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CasamaSpacing.md),

        // Result panel or rules caption
        if (_winner != null && _isChatMode) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: pal.track,
              borderRadius: CasamaSpacing.roundedLg,
              border: Border.all(color: pal.border),
            ),
            child: Row(
              children: [
                CasamaAvatar(
                  radius: 18,
                  avatarUrl: _winner!.profile.avatarUrl,
                  name: _winner!.profile.displayName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_winnerDisplayName(_winner!.profile)} was chosen!',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: CasamaButton(
                  label: 'Spin Again',
                  style: CasamaButtonStyle.secondary,
                  height: 48,
                  onPressed: _isSubmittingChat
                      ? null
                      : () => _spin(candidates),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CasamaButton(
                  label: 'Send to Chat',
                  icon: Icons.send_rounded,
                  style: CasamaButtonStyle.primary,
                  height: 48,
                  onPressed: _isSubmittingChat ? null : _handleSendToChat,
                ),
              ),
            ],
          ),
        ] else if (_winner != null) ...[
          Text(
            '${_winner!.profile.displayName} is up for $taskTitle!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: pal.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),
          Row(
            children: [
              Expanded(
                child: CasamaButton(
                  label: 'Reject (-3 pts)',
                  style: CasamaButtonStyle.secondary,
                  height: 48,
                  onPressed: () => _handleDecision(
                    accepted: false,
                    taskTitle: taskTitle,
                    taskId: resolvedTask?.id,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CasamaButton(
                  label: 'Accept (+2 bonus)',
                  style: CasamaButtonStyle.primary,
                  height: 48,
                  onPressed: () => _handleDecision(
                    accepted: true,
                    taskTitle: taskTitle,
                    taskId: resolvedTask?.id,
                  ),
                ),
              ),
            ],
          ),
        ] else
          Text(
            _isChatMode
                ? 'Type a question above and tap SPIN. No cooldown or points apply in Chat mode.'
                : (_isOnCooldown
                      ? 'Daily spin already used for this household. Come back after cooldown.'
                      : 'Chosen housemate gets Accept (+2 bonus pts) or Reject (-3 pts). 24h cooldown applies after spinning.'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: pal.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
      ],
    );
  }
}

class _RouletteSlicesPainter extends CustomPainter {
  final int count;
  final List<Color> sliceColors;
  final Color ringBorderColor;
  final int? highlightedIndex;

  const _RouletteSlicesPainter({
    required this.count,
    required this.sliceColors,
    required this.ringBorderColor,
    this.highlightedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = (2 * math.pi) / count;
    final dividerPaint = Paint()
      ..color = ringBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < count; i++) {
      // Slice `i` is centered at `-π/2 + i * sweep`.
      final startAngle = (-math.pi / 2) - (sweep / 2) + (i * sweep);
      final paint = Paint()
        ..color = sliceColors[i % sliceColors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(rect, startAngle, sweep, true, paint);
      if (highlightedIndex == i) {
        final highlightPaint = Paint()
          ..color = CasamaColors.primaryCoral.withValues(alpha: 0.16)
          ..style = PaintingStyle.fill;
        canvas.drawArc(rect, startAngle, sweep, true, highlightPaint);
        final highlightStroke = Paint()
          ..color = CasamaColors.primaryCoral
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawArc(rect, startAngle, sweep, true, highlightStroke);
      }
      canvas.drawArc(rect, startAngle, sweep, true, dividerPaint);
    }

    canvas.drawCircle(
      center,
      radius - 1.5,
      Paint()
        ..color = ringBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _RouletteSlicesPainter oldDelegate) =>
      oldDelegate.count != count ||
      oldDelegate.ringBorderColor != ringBorderColor ||
      oldDelegate.highlightedIndex != highlightedIndex;
}
