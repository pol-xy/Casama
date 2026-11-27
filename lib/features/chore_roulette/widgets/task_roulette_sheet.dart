import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    title: isChat ? 'Ask the Wheel' : 'Task Roulette',
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
  MemberPresence? _winner;
  int? _winnerIndex;
  String? _selectedTaskId;
  MaintenanceTask? _spunTask;
  ChoreRouletteRecord? _spunRecord;
  String? _spinError;
  String? _questionError;
  bool _isSubmittingChat = false;

  bool get _isChatMode => widget.mode == TaskRouletteMode.chatQuestion;

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.task?.id;
    _controller = AnimationController(
      vsync: this,
      duration: CasamaMotion.rouletteSpin,
    );
  }

  String _sliceLabel(UserProfile p) => p.preferredName;

  String _winnerDisplayName(UserProfile p) => p.preferredName;

  @override
  void dispose() {
    _questionController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _spin(
    List<MemberPresence> candidates, {
    MaintenanceTask? targetTask,
  }) {
    if (_isSpinning || candidates.isEmpty) return;

    if (!_isChatMode && (targetTask == null || _spunRecord != null)) return;

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
      _spunTask = targetTask;
      _spunRecord = null;
      _spinError = null;
    });

    Future<void> onSpinSettled() async {
      if (_isChatMode || targetTask == null) return;
      final repo = ref.read(repositoryProvider);
      try {
        final record = await repo.spinTaskRoulette(
          targetTask.id,
          pickedMember.profile.id,
        );
        if (mounted) {
          setState(() {
            _spunRecord = record;
            _spunTask = targetTask;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _spinError = e is StateError
                ? e.message
                : 'Could not assign task via Task Roulette.';
          });
        }
      }
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

    // Eligible task pool: strictly open, unspun tasks
    final eligibleTasks = repo.tasks
        .where(
          (t) =>
              t.status != TaskStatus.done &&
              repo.rouletteRecordForTask(t.id) == null,
        )
        .toList();

    final MaintenanceTask? resolvedTask = _spunTask ??
        ((widget.task != null &&
                widget.task!.status != TaskStatus.done &&
                repo.rouletteRecordForTask(widget.task!.id) == null)
            ? widget.task
            : eligibleTasks.cast<MaintenanceTask?>().firstWhere(
                (t) => t?.id == _selectedTaskId,
                orElse: () =>
                    eligibleTasks.isNotEmpty ? eligibleTasks.first : null,
              ));
    final taskTitle = resolvedTask?.title ?? 'No unspun tasks';
    final basePts = resolvedTask?.computedPoints ?? 5;
    const bonusPts = 4;

    final nonCreatorMembers =
        resolvedTask == null || resolvedTask.createdBy.isEmpty
            ? repo.members
            : repo.members
                  .where((m) => m.profile.id != resolvedTask.createdBy)
                  .toList();
    final candidates = _isChatMode ? repo.members : nonCreatorMembers;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                        '+$basePts pts + $bonusPts bonus',
                        style: theme.textTheme.labelSmall?.tabular.copyWith(
                          color: pal.successFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.task == null &&
                    eligibleTasks.length > 1 &&
                    _spunRecord == null &&
                    !_isSpinning) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final t in eligibleTasks) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              selected: resolvedTask?.id == t.id,
                              onSelected: (_) =>
                                  setState(() => _selectedTaskId = t.id),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: CasamaSpacing.sm),

          // Eligibility summary
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
                'Eligible Housemates (${candidates.length})',
                style: theme.textTheme.labelSmall?.tabular.copyWith(
                  color: pal.forestTeal,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ),
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
                                        name: candidates[i].preferredName,
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
                          candidates.isEmpty ||
                          (!_isChatMode &&
                              (resolvedTask == null || _spunRecord != null)) ||
                          (_isChatMode && value.text.trim().isEmpty);
                      final canTap =
                          !_isSpinning &&
                          candidates.isNotEmpty &&
                          (_isChatMode ||
                              (resolvedTask != null && _spunRecord == null));
                      return Semantics(
                        button: true,
                        label: _isChatMode
                            ? 'Ask the Wheel'
                            : 'Spin Task Roulette',
                        child: CasamaPressable.fab(
                          onTap: canTap
                              ? () => _spin(
                                  candidates,
                                  targetTask: resolvedTask,
                                )
                              : null,
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
                  name: _winner!.preferredName,
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
          if (_spinError != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.dangerBg,
                borderRadius: CasamaSpacing.roundedLg,
                border: Border.all(color: pal.dangerFg.withValues(alpha: 0.3)),
              ),
              child: Text(
                _spinError!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.dangerFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: CasamaSpacing.sm),
            CasamaButton(
              label: 'Done',
              isPill: true,
              height: 48,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            Container(
              key: const Key('task_roulette_result_card'),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: pal.softSage.withValues(alpha: 0.72),
                borderRadius: CasamaSpacing.roundedLg,
                border: Border.all(
                  color: pal.forestTeal.withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  CasamaAvatar(
                    radius: 24,
                    avatarUrl: _winner!.profile.avatarUrl,
                    name: _winner!.profile.id == repo.currentUser.id
                        ? repo.currentUser.preferredName
                        : _winnerDisplayName(_winner!.profile),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _winner!.profile.id == repo.currentUser.id
                              ? 'You were chosen!'
                              : '${_winnerDisplayName(_winner!.profile)} was chosen!',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          (resolvedTask != null &&
                                  resolvedTask.createdBy.isNotEmpty &&
                                  _winner!.profile.id == resolvedTask.createdBy)
                              ? 'Chosen for "$taskTitle" • Notified!'
                              : 'Chosen for "$taskTitle" • Notified with +${_spunRecord?.bonusPoints ?? bonusPts} bonus pts (+${basePts + (_spunRecord?.bonusPoints ?? bonusPts)} pts total)!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: pal.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CasamaSpacing.md),
            CasamaButton(
              label: 'Done',
              isPill: true,
              height: 48,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ] else
          Text(
            _isChatMode
                ? 'Type a question above and tap SPIN. No points apply in Chat mode.'
                : (resolvedTask == null
                      ? 'All open tasks have already been spun! Add a new task to spin the wheel.'
                      : (candidates.isEmpty
                            ? 'Add another housemate to spin Task Roulette for this task.'
                            : '1 spin per task • Creator excluded • Chosen housemate gets +4 bonus pts')),
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
    if (count <= 1) {
      final fillPaint = Paint()
        ..color = sliceColors.first
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);
      if (highlightedIndex == 0) {
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = CasamaColors.primaryCoral.withValues(alpha: 0.16)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          center,
          radius - 1.5,
          Paint()
            ..color = CasamaColors.primaryCoral
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      } else {
        canvas.drawCircle(
          center,
          radius - 1.5,
          Paint()
            ..color = ringBorderColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
      return;
    }

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
