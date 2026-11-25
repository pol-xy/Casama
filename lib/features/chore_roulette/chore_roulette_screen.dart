import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/dimensions.dart';
import '../../core/motion/casama_motion.dart';
import '../../data/models.dart';
import '../../data/repository_provider.dart';
import '../../shared/widgets/cas_mascot_view.dart';
import '../../shared/widgets/casama_button.dart';
import '../../shared/widgets/casama_filter_controls.dart';
import '../../shared/widgets/casama_wave_header.dart';
import 'widgets/task_roulette_sheet.dart';

enum RouletteMode { randomHousemate, justForMe }

class ChoreRouletteScreen extends ConsumerStatefulWidget {
  const ChoreRouletteScreen({super.key});

  @override
  ConsumerState<ChoreRouletteScreen> createState() =>
      _ChoreRouletteScreenState();
}

class _ChoreRouletteScreenState extends ConsumerState<ChoreRouletteScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  Animation<double>? _animation;
  double _currentAngle = 0;
  bool _isSpinning = false;
  RouletteMode _rouletteMode = RouletteMode.randomHousemate;

  final List<_ChoreItem> _chores = const [
    _ChoreItem('Take Out Trash', Icons.delete_outline, Color(0xFF4F8A82)),
    _ChoreItem(
      'Grocery Run',
      Icons.shopping_cart_outlined,
      Color(0xFFE87461),
    ),
    _ChoreItem(
      'Sweep Living Room',
      Icons.cleaning_services_outlined,
      Color(0xFFD99829),
    ),
    _ChoreItem(
      'Mop Kitchen Floor',
      Icons.water_drop_outlined,
      Color(0xFF3E78A3),
    ),
    _ChoreItem('Clean Bathroom', Icons.bathtub_outlined, Color(0xFF8C5CA8)),
    _ChoreItem(
      'Wipe Counters',
      Icons.countertops_outlined,
      Color(0xFF37655E),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: CasamaMotion.rouletteSpin,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning) return;
    final reduced = CasamaMotion.reduceMotion(context);
    final random = math.Random();
    final extraSpins = 5 + random.nextInt(3);
    final targetSegment = random.nextInt(_chores.length);
    final segmentAngle = (2 * math.pi) / _chores.length;

    // Slice i center starts at -π/2 + i * segmentAngle; rotate so winner lands under top pointer.
    final targetMod =
        ((2 * math.pi - targetSegment * segmentAngle) % (2 * math.pi) +
            2 * math.pi) %
        (2 * math.pi);
    final currentMod =
        ((_currentAngle % (2 * math.pi)) + 2 * math.pi) % (2 * math.pi);
    final deltaToTarget =
        ((targetMod - currentMod) % (2 * math.pi) + 2 * math.pi) %
        (2 * math.pi);
    final endAngle = _currentAngle + (extraSpins * 2 * math.pi) + deltaToTarget;

    if (reduced) {
      setState(() {
        _currentAngle = endAngle % (2 * math.pi);
      });
      _showResultDialog(_chores[targetSegment]);
      return;
    }

    setState(() => _isSpinning = true);
    _animController.duration = CasamaMotion.rouletteSpin;
    _animation =
        Tween<double>(begin: _currentAngle, end: endAngle).animate(
            CurvedAnimation(
              parent: _animController,
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
              });
              _showResultDialog(_chores[targetSegment]);
            }
          });

    _animController.forward(from: 0);
  }

  void _showResultDialog(_ChoreItem chore) {
    final repo = ref.read(repositoryProvider);
    final isSolo = _rouletteMode == RouletteMode.justForMe;

    final String assignedPerson;
    if (isSolo) {
      assignedPerson = repo.currentUser.displayName.isNotEmpty
          ? repo.currentUser.displayName
          : 'You';
    } else {
      final roommates = repo.members;
      assignedPerson =
          roommates[math.Random().nextInt(roommates.length)].profile.displayName;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) {
        final pal = ctx.palette;
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: CasamaSpacing.roundedXl),
          backgroundColor: pal.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CasMascotView(
                pose: CasPose.roulette,
                width: 120,
                height: 120,
              ),
              const SizedBox(height: 10),
              Text(
                isSolo ? 'Your Personal Challenge!' : 'The Wheel Has Spoken!',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: pal.softBlush,
                  borderRadius: CasamaSpacing.roundedLg,
                ),
                child: Column(
                  children: [
                    Text(
                      chore.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pal.primaryCoral,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isSolo
                          ? 'Assigned to: You (Solo Mode)'
                          : 'Assigned to: $assignedPerson',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: pal.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isSolo
                    ? 'Tackle this chore to keep your home clean and earn Kasama points.'
                    : 'Fair, friendly, and decided by Casama.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pal.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              CasamaButton(
                label: isSolo ? 'Add to My Tasks' : 'Add to Maintenance Tasks',
                onPressed: () {
                  repo.addTask(
                    title: chore.title,
                    category: TaskCategory.diy,
                    urgency: TaskUrgency.medium,
                    assigneeName: assignedPerson,
                  );
                  Navigator.pop(ctx);
                  showCasamaToast(
                    context,
                    isSolo
                        ? 'Added "${chore.title}" to your tasks'
                        : 'Added "${chore.title}" assigned to $assignedPerson',
                    icon: Icons.check_circle_outline_rounded,
                  );
                },
                height: 46,
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Text(
                  'Dismiss',
                  style: TextStyle(color: pal.textSecondary),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pal = context.palette;
    final theme = Theme.of(context);
    final angle = _isSpinning ? (_animation?.value ?? _currentAngle) : _currentAngle;

    return Scaffold(
      backgroundColor: pal.scaffoldBg,
      body: CasamaAmbientCanvas(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom + 24,
          ),
          child: Column(
            children: [
              CasamaWaveHeader(
                title: 'Chore Roulette',
                subtitle: 'Settle household chores fairly',
                compact: true,
                onBackTap: () =>
                    context.canPop() ? context.pop() : context.go('/boards'),
                rightActions: [
                  CasamaHeaderActionPill(
                    icon: Icons.groups_outlined,
                    label: 'Quick Spin',
                    onTap: () => showTaskRouletteSheet(context),
                  ),
                ],
              ),
              CasamaSegmentedTrack<RouletteMode>(
                selectedValue: _rouletteMode,
                onSelected: (next) {
                  if (_isSpinning) return;
                  setState(() => _rouletteMode = next);
                },
                segments: const [
                  CasamaFilterOption(
                    value: RouletteMode.randomHousemate,
                    label: 'Random Dormmate',
                  ),
                  CasamaFilterOption(
                    value: RouletteMode.justForMe,
                    label: 'Just For Me',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _rouletteMode == RouletteMode.randomHousemate
                      ? "Let's settle who does what fairly! 👥"
                      : "Can't decide what to do? Spin for yourself! 👤",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: pal.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: CasamaSpacing.xl),

              // Wheel Assembly
              Center(
                child: SizedBox(
                  width: 310,
                  height: 318,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 306,
                          height: 306,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pal.card,
                            border: Border.all(color: pal.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: context.isDark ? 0.34 : 0.08,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 10,
                        child: Transform.rotate(
                          angle: angle,
                          child: CustomPaint(
                            size: const Size(286, 286),
                            painter: _RouletteWheelPainter(
                              chores: _chores,
                              dividerColor: pal.surface,
                            ),
                          ),
                        ),
                      ),
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
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 114,
                        child: Semantics(
                          button: true,
                          label: 'Spin chore wheel',
                          child: CasamaPressable.fab(
                            onTap: _isSpinning ? null : _spin,
                            child: Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                color: _isSpinning
                                    ? pal.textMuted
                                    : pal.primaryCoral,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: pal.surface,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: pal.primaryCoral.withValues(
                                      alpha: 0.32,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _isSpinning ? '...' : 'Spin',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CasamaSpacing.xl),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: pal.softBlush,
                    borderRadius: CasamaSpacing.roundedPill,
                  ),
                  child: Text(
                    _rouletteMode == RouletteMode.justForMe
                        ? 'Ready to get things done? Spin away! 🚀'
                        : "Good luck, Kasama! Let's see who's up! 🎉",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: pal.primaryCoral,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoreItem {
  final String title;
  final IconData icon;
  final Color color;

  const _ChoreItem(this.title, this.icon, this.color);
}

class _RouletteWheelPainter extends CustomPainter {
  final List<_ChoreItem> chores;
  final Color dividerColor;

  const _RouletteWheelPainter({
    required this.chores,
    required this.dividerColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final sweepAngle = (2 * math.pi) / chores.length;

    for (var i = 0; i < chores.length; i++) {
      final startAngle = (-math.pi / 2) - (sweepAngle / 2) + (i * sweepAngle);
      final paint = Paint()
        ..color = chores[i].color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      final borderPaint = Paint()
        ..color = dividerColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      final iconAngle = startAngle + (sweepAngle / 2);
      final iconDist = radius * 0.65;
      final iconX = center.dx + iconDist * math.cos(iconAngle);
      final iconY = center.dy + iconDist * math.sin(iconAngle);

      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(chores[i].icon.codePoint),
          style: TextStyle(
            fontSize: 23,
            fontFamily: chores[i].icon.fontFamily,
            package: chores[i].icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(iconX, iconY);
      canvas.rotate(iconAngle + (math.pi / 2));
      iconPainter.paint(
        canvas,
        Offset(-iconPainter.width / 2, -iconPainter.height / 2),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _RouletteWheelPainter oldDelegate) =>
      oldDelegate.dividerColor != dividerColor ||
      oldDelegate.chores.length != chores.length;
}
