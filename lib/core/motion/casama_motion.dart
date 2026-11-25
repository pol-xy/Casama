import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/colors.dart';

/// Centralized animation durations, curves, and reduced-motion utilities
/// translated from casama-app-mockup.html.
class CasamaMotion {
  // Durations
  static const Duration press = Duration(milliseconds: 150);
  static const Duration fabExit = Duration(milliseconds: 180);
  static const Duration scrim = Duration(milliseconds: 200);
  static const Duration lightbox = Duration(milliseconds: 200);
  static const Duration listItem = Duration(milliseconds: 220);
  static const Duration boardSlide = Duration(milliseconds: 250);
  static const Duration drawer = Duration(milliseconds: 250);
  static const Duration sheet = Duration(milliseconds: 280);
  static const Duration fabEnter = Duration(milliseconds: 320);
  static const Duration cameraFlip = Duration(milliseconds: 350);
  static const Duration shutterFlash = Duration(milliseconds: 450);
  static const Duration rouletteSpin = Duration(milliseconds: 4000);
  static const Duration toastHold = Duration(milliseconds: 2200);

  // Scales
  static const double scaleButton = 0.95;
  static const double scaleFab = 0.90;
  static const double scaleCard = 0.99;

  // Curves
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeIn = Curves.easeIn;
  static const Curve springOvershoot = Cubic(0.34, 1.56, 0.64, 1.0);
  static const Curve rouletteDecel = Cubic(0.12, 0.7, 0.1, 1.0);

  /// True when the user or OS requests reduced motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration resolve(BuildContext context, Duration normal) =>
      reduceMotion(context) ? Duration.zero : normal;
}

/// Reusable tactile press-scale wrapper (`0.95` default, `0.90` for FABs,
/// `150ms`) honoring reduced motion and optional haptic feedback.
class CasamaPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const CasamaPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = CasamaMotion.scaleButton,
    this.enableHaptic = false,
    this.behavior = HitTestBehavior.opaque,
  });

  const CasamaPressable.fab({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHaptic = true,
  }) : pressedScale = CasamaMotion.scaleFab,
       behavior = HitTestBehavior.opaque;

  const CasamaPressable.card({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHaptic = false,
  }) : pressedScale = CasamaMotion.scaleCard,
       behavior = HitTestBehavior.opaque;

  @override
  State<CasamaPressable> createState() => _CasamaPressableState();
}

class _CasamaPressableState extends State<CasamaPressable> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_isPressed != value && mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null && widget.onLongPress == null;
    final reduced = CasamaMotion.reduceMotion(context);

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.enableHaptic) {
                HapticFeedback.selectionClick();
              }
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: (_isPressed && !reduced) ? widget.pressedScale : 1.0,
        duration: reduced ? Duration.zero : CasamaMotion.press,
        curve: CasamaMotion.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Directional horizontal slide + fade switcher (`250ms`, `Curves.easeOut`) for
/// tab changes across `Boards` views (`Parcels` -> `Tasks` -> `Bills` -> `Items`).
class CasamaDirectionalSwitcher extends StatelessWidget {
  final int index;
  final int previousIndex;
  final Widget child;

  const CasamaDirectionalSwitcher({
    super.key,
    required this.index,
    required this.previousIndex,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = CasamaMotion.reduceMotion(context);
    if (reduced) return child;

    final forward = index >= previousIndex;
    final beginX = forward ? 0.12 : -0.12;

    return AnimatedSwitcher(
      duration: CasamaMotion.boardSlide,
      switchInCurve: CasamaMotion.easeOut,
      switchOutCurve: CasamaMotion.easeIn,
      transitionBuilder: (widget, animation) {
        final offset = Tween<Offset>(
          begin: Offset(beginX, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: widget),
        );
      },
      child: child,
    );
  }
}

/// Contextual Boards pill FAB with `320ms` spring overshoot entrance, `180ms`
/// exit, `0.90` tactile press, and smooth icon/label morphing across sub-tabs.
class CasamaMorphingFab extends StatelessWidget {
  final bool visible;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? semanticLabel;

  const CasamaMorphingFab({
    super.key,
    required this.visible,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = CasamaMotion.reduceMotion(context);
    final pal = context.palette;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSwitcher(
        duration: reduced
            ? Duration.zero
            : (visible ? CasamaMotion.fabEnter : CasamaMotion.fabExit),
        switchInCurve: CasamaMotion.springOvershoot,
        switchOutCurve: CasamaMotion.easeIn,
        transitionBuilder: (child, animation) {
          if (reduced) return child;
          final scale = Tween<double>(begin: 0.6, end: 1.0).animate(animation);
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: visible
            ? Semantics(
                key: const ValueKey('casama_morphing_fab_visible'),
                button: true,
                label: semanticLabel ?? label,
                child: CasamaPressable.fab(
                  onTap: onPressed,
                  child: Material(
                    color: pal.coralFab,
                    borderRadius: BorderRadius.circular(999),
                    elevation: 6,
                    shadowColor: pal.coralFab.withValues(alpha: 0.45),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.only(left: 16, right: 20),
                      child: AnimatedSize(
                        duration: reduced
                            ? Duration.zero
                            : CasamaMotion.press,
                        curve: CasamaMotion.easeOut,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: reduced
                                  ? Duration.zero
                                  : CasamaMotion.press,
                              child: Icon(
                                icon,
                                key: ValueKey(icon.codePoint),
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedSwitcher(
                              duration: reduced
                                  ? Duration.zero
                                  : CasamaMotion.press,
                              child: Text(
                                label,
                                key: ValueKey(label),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('casama_morphing_fab_hidden')),
      ),
    );
  }
}

OverlayEntry? _activeToastEntry;

/// Shows a top pill toast above sheets, drawers, and the camera overlay
/// (`200ms` fade, `#1C2E4A` navy pill, `2200ms` auto-dismiss).
void showCasamaToast(
  BuildContext context,
  String message, {
  IconData? icon,
  Duration duration = CasamaMotion.toastHold,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeToastEntry?.remove();
  _activeToastEntry = null;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _CasamaTopToastView(
      message: message,
      icon: icon,
      duration: duration,
      onDismissed: () {
        if (_activeToastEntry == entry) {
          _activeToastEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _activeToastEntry = entry;
  overlay.insert(entry);
}

class _CasamaTopToastView extends StatefulWidget {
  final String message;
  final IconData? icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const _CasamaTopToastView({
    required this.message,
    this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_CasamaTopToastView> createState() => _CasamaTopToastViewState();
}

class _CasamaTopToastViewState extends State<_CasamaTopToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: CasamaMotion.scrim,
    );
    _controller.forward();
    _dismissTimer = Timer(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final reduced = CasamaMotion.reduceMotion(context);

    return Positioned(
      top: topInset + 16,
      left: 24,
      right: 24,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: reduced ? const AlwaysStoppedAnimation(1.0) : _controller,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CasamaColors.midnightNavy,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33071C37),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        widget.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
