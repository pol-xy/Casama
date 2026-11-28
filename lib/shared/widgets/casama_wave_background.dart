import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// Light-mode palette constants matching the wave specification.
const Color kDeep = Color(0xFF38655D);
const Color kMid = Color(0xFF688C83);
const Color kLight = Color(0xFFA5B9B0);
const Color kPage = Color(0xFFEAE4D7);

/// Morph speed & derived duration (`~2444ms`).
const double kWaveSpeed = 1.0;
final Duration kWaveMorphDuration = Duration(
  milliseconds: (1100 / kWaveSpeed).round(),
);

/// Height at which even the lowest cubic wave trough is safely above `y = 0`.
const double kMinOffscreenH = -24.0;

/// Maximum vertical shift for top-right concentric rings before they are
/// completely off-screen.
const double kRingMaxShift = 240.0;

/// Extra scroll offset reported once `BoardsScreen`'s hero header has fully
/// collapsed behind the sticky pill bar.
const double kBoardsCollapsedWaveExtra = 48.0;

/// Vertical offsets from the bottom of each band's horizon.
const List<double> kWaveBandFromBottom = [42.0, 26.0, 12.0];

/// Staggered trailing curves so mid-teal and light-sage bands trail the front
/// page-colored wave.
const List<Curve> kWaveBandCurves = [
  Interval(0.20, 1.0, curve: Curves.easeInOutCubic),
  Interval(0.10, 1.0, curve: Curves.easeInOutCubic),
  Interval(0.00, 1.0, curve: Curves.easeInOutCubic),
];

/// Immutable cubic wave band parameters.
@immutable
class WaveParams {
  final double h;
  final double y0;
  final double c1y;
  final double c2y;
  final double y1;
  final double c1x;
  final double c2x;

  const WaveParams(
    this.h,
    this.y0,
    this.c1y,
    this.c2y,
    this.y1,
    this.c1x,
    this.c2x,
  );

  static WaveParams lerp(WaveParams a, WaveParams b, double t) => WaveParams(
    a.h + (b.h - a.h) * t,
    a.y0 + (b.y0 - a.y0) * t,
    a.c1y + (b.c1y - a.c1y) * t,
    a.c2y + (b.c2y - a.c2y) * t,
    a.y1 + (b.y1 - a.y1) * t,
    a.c1x + (b.c1x - a.c1x) * t,
    a.c2x + (b.c2x - a.c2x) * t,
  );

  WaveParams copyWith({double? h}) => WaveParams(
    h ?? this.h,
    y0,
    c1y,
    c2y,
    y1,
    c1x,
    c2x,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveParams &&
          h == other.h &&
          y0 == other.y0 &&
          c1y == other.c1y &&
          c2y == other.c2y &&
          y1 == other.y1 &&
          c1x == other.c1x &&
          c2x == other.c2x;

  @override
  int get hashCode => Object.hash(h, y0, c1y, c2y, y1, c1x, c2x);
}

/// Rest wave shapes at a given header horizon height [h].
List<WaveParams> restWave(double h) => [
  WaveParams(h, 0, -12, 20, 0, 0.36, 0.68), // mid
  WaveParams(h, 0, -14, 18, 0, 0.40, 0.72), // light
  WaveParams(h, 0, -10, 14, 0, 0.42, 0.74), // page
];

/// Organic target wave shapes at height [h].
List<WaveParams> randomWave(double h, math.Random rng) {
  double r(double a, double b) => a + rng.nextDouble() * (b - a);
  return List.generate(
    3,
    (_) => WaveParams(
      h,
      r(-8, 8),
      r(-20, 4),
      r(2, 24),
      r(-8, 8),
      r(0.25, 0.50),
      r(0.55, 0.80),
    ),
  );
}

/// Shared lighter-teal (low-opacity white over deep teal) concentric ring
/// ornament used across all Casama wave headers.
class CasamaHeaderRings {
  CasamaHeaderRings._();

  static const List<double> radii = [28.0, 44.0, 62.0];
  static const double strokeWidth = 1.25;
  static const List<double> lightAlphas = [0.16, 0.12, 0.08];
  static const List<double> darkAlphas = [0.14, 0.10, 0.06];

  static final List<Paint> lightPaints = [
    for (final a in lightAlphas)
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
  ];

  static final List<Paint> darkPaints = [
    for (final a in darkAlphas)
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
  ];

  static List<Paint> paintsFor({required bool isDark}) =>
      isDark ? darkPaints : lightPaints;

  static Offset bellCenter(
    Size size,
    double safeTop, {
    double scrollOffset = 0.0,
  }) => Offset(size.width - 40, safeTop + 36 - scrollOffset);

  static void paint(Canvas canvas, Offset center, List<Paint> paints) {
    for (int i = 0; i < radii.length; i++) {
      canvas.drawCircle(center, radii[i], paints[i]);
    }
  }
}

/// Color set for [CasamaWaveBackgroundPainter].
@immutable
class CasamaWaveColors {
  final Color deep;
  final Color mid;
  final Color light;
  final Color page;
  final bool isDark;

  const CasamaWaveColors({
    required this.deep,
    required this.mid,
    required this.light,
    required this.page,
    required this.isDark,
  });

  static const CasamaWaveColors lightDefaults = CasamaWaveColors(
    deep: kDeep,
    mid: kMid,
    light: kLight,
    page: kPage,
    isDark: false,
  );

  factory CasamaWaveColors.fromPalette(
    CasamaPalette pal, {
    required bool isDark,
  }) => CasamaWaveColors(
    deep: pal.headerDeep,
    mid: pal.headerMid,
    light: pal.headerLight,
    page: pal.scaffoldBg,
    isDark: isDark,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CasamaWaveColors &&
          deep == other.deep &&
          mid == other.mid &&
          light == other.light &&
          page == other.page &&
          isDark == other.isDark;

  @override
  int get hashCode => Object.hash(deep, mid, light, page, isDark);
}

/// Scroll-aware, morphing wave background controller owned by
/// `MainNavigationShell` (zero widget rebuilds during scroll or morph ticks).
class CasamaWaveBackgroundController extends ChangeNotifier {
  final AnimationController morph;
  final math.Random _rng;

  int _activeTab;
  final Map<int, double> _tabScrollOffsets = {};
  final Map<int, double> _naturalHeights = {};
  double _lastActiveScroll = 0.0;
  double _safeTop;
  bool _reduceMotion = false;

  late List<WaveParams> _from;
  late List<WaveParams> _to;
  double _ringFrom = 0.0;
  double _ringTo = 0.0;

  CasamaWaveBackgroundController({
    required TickerProvider vsync,
    int initialTab = 0,
    double safeTop = 0.0,
    math.Random? random,
    Duration? duration,
  }) : _activeTab = initialTab,
       // ignore: prefer_initializing_formals
       _safeTop = safeTop,
       _rng = random ?? math.Random(),
       morph = AnimationController(
         vsync: vsync,
         duration: duration ?? kWaveMorphDuration,
         value: 1.0,
       ) {
    final initialH = targetHeightFor(initialTab);
    _from = restWave(initialH);
    _to = restWave(initialH);
  }

  int get activeTab => _activeTab;
  List<WaveParams> get from => UnmodifiableListView(_from);
  List<WaveParams> get to => UnmodifiableListView(_to);
  bool get isMorphing => morph.value < 1.0;

  static double defaultNaturalHeight(int tab, double safeTop) {
    return switch (tab) {
      1 => safeTop + 232.0,
      4 => safeTop + 192.0,
      _ => safeTop + 158.0,
    };
  }

  double naturalHeightFor(int tab) =>
      _naturalHeights[tab] ?? defaultNaturalHeight(tab, _safeTop);

  double scrollOffsetFor(int tab) => _tabScrollOffsets[tab] ?? 0.0;

  double targetHeightFor(int tab) =>
      math.max(kMinOffscreenH, naturalHeightFor(tab) - scrollOffsetFor(tab));

  double _t(int i) => kWaveBandCurves[i].transform(morph.value.clamp(0.0, 1.0));

  WaveParams bandAt(int i) {
    final t = _t(i);
    if (t == 1.0) return _to[i];
    return WaveParams.lerp(_from[i], _to[i], t);
  }

  double bandHeightAt(int i) {
    final t = _t(i);
    if (t == 1.0) return _to[i].h;
    return _from[i].h + (_to[i].h - _from[i].h) * t;
  }

  bool get allBandsOffscreen {
    for (int i = 0; i < 3; i++) {
      if (bandHeightAt(i) > kMinOffscreenH + 0.001) return false;
    }
    return true;
  }

  double _ringTarget(double scrollOffset) =>
      scrollOffset.clamp(0.0, kRingMaxShift);

  double get ringShift {
    final t = _t(2);
    return _ringFrom + (_ringTo - _ringFrom) * t;
  }

  List<WaveParams> _snapshot() => List<WaveParams>.generate(3, (i) {
    final p = bandAt(i);
    return p.copyWith(h: math.max(kMinOffscreenH, p.h));
  });

  set reduceMotion(bool v) {
    if (_reduceMotion == v) return;
    _reduceMotion = v;
    if (v && isMorphing) {
      _from = List<WaveParams>.of(_to);
      _ringFrom = _ringTo;
      morph.value = 1.0;
      notifyListeners();
    }
  }

  void updateSafeTop(double v) {
    if ((v - _safeTop).abs() < 0.5) return;
    _safeTop = v;
    if (!_naturalHeights.containsKey(_activeTab)) {
      final targetH = targetHeightFor(_activeTab);
      for (int i = 0; i < 3; i++) {
        _to[i] = _to[i].copyWith(h: targetH);
        if (!isMorphing) {
          _from[i] = _from[i].copyWith(h: targetH);
        }
      }
      notifyListeners();
    }
  }

  void selectTab(int tab) {
    if (tab == _activeTab) return;

    final snap = _snapshot();
    final ringNow = ringShift.clamp(0.0, kRingMaxShift);

    _activeTab = tab;
    _lastActiveScroll = scrollOffsetFor(tab);
    final targetH = targetHeightFor(tab);
    final ringTarget = _ringTarget(_lastActiveScroll);

    final bothOffscreen =
        targetH <= kMinOffscreenH &&
        snap.every((p) => p.h <= kMinOffscreenH);

    if (bothOffscreen) {
      _from = restWave(kMinOffscreenH);
      _to = restWave(kMinOffscreenH);
      _ringFrom = ringTarget;
      _ringTo = ringTarget;
      morph.value = 1.0;
      notifyListeners();
      return;
    }

    if (_reduceMotion) {
      _from = restWave(targetH);
      _to = restWave(targetH);
      _ringFrom = ringTarget;
      _ringTo = ringTarget;
      morph.value = 1.0;
      notifyListeners();
      return;
    }

    _from = snap;
    _to = randomWave(targetH, _rng);
    _ringFrom = ringNow;
    _ringTo = ringTarget;
    morph.forward(from: 0.0);
    notifyListeners();
  }

  void updateScroll(int tab, double offset) {
    if ((offset - scrollOffsetFor(tab)).abs() < 0.01) return;
    _tabScrollOffsets[tab] = offset;
    if (tab != _activeTab) return;

    final h = naturalHeightFor(tab);
    final oldDest = math.max(kMinOffscreenH, h - _lastActiveScroll);
    final newDest = math.max(kMinOffscreenH, h - offset);
    final oldRing = _ringTarget(_lastActiveScroll);
    final newRing = _ringTarget(offset);
    _lastActiveScroll = offset;

    if (isMorphing) {
      final dH = newDest - oldDest;
      for (int i = 0; i < 3; i++) {
        _to[i] = _to[i].copyWith(h: newDest);
        if (dH < 0) {
          _from[i] = _from[i].copyWith(
            h: math.max(kMinOffscreenH, _from[i].h + dH),
          );
        } else if (dH > 0) {
          _from[i] = _from[i].copyWith(
            h: math.min(math.max(_from[i].h, newDest), _from[i].h + dH),
          );
        }
      }

      final dR = newRing - oldRing;
      _ringTo = newRing;
      if (dR > 0) {
        _ringFrom = math.min(kRingMaxShift, _ringFrom + dR);
      } else if (dR < 0) {
        _ringFrom = math.max(math.min(_ringFrom, newRing), _ringFrom + dR);
      }
    } else {
      for (int i = 0; i < 3; i++) {
        _to[i] = _to[i].copyWith(h: newDest);
        _from[i] = _from[i].copyWith(h: newDest);
      }
      _ringFrom = newRing;
      _ringTo = newRing;
    }

    notifyListeners();
  }

  void updateNaturalHeight(int tab, double h) {
    if (h <= 0) return;
    final prev = _naturalHeights[tab];
    if (prev != null && (prev - h).abs() < 0.5) return;
    _naturalHeights[tab] = h;
    if (tab == _activeTab) {
      final targetH = targetHeightFor(tab);
      for (int i = 0; i < 3; i++) {
        _to[i] = _to[i].copyWith(h: targetH);
        if (!isMorphing) {
          _from[i] = _from[i].copyWith(h: targetH);
        }
      }
      notifyListeners();
    }
  }

  @override
  void dispose() {
    morph.dispose();
    super.dispose();
  }
}

/// GPU-optimized full-viewport background painter drawing deep teal,
/// scroll-synced concentric rings, and 3 staggered cubic wave bands.
class CasamaWaveBackgroundPainter extends CustomPainter {
  final CasamaWaveBackgroundController controller;
  final CasamaWaveColors colors;
  final double safeTop;

  static const List<Curve> curves = kWaveBandCurves;
  static const List<double> fromBottom = kWaveBandFromBottom;

  final Paint _deepFill;
  final Paint _pageFill;
  final List<Paint> _bandFills;
  final List<Paint> _ringPaints;
  final Path _path = Path();

  CasamaWaveBackgroundPainter({
    required this.controller,
    required this.colors,
    required this.safeTop,
  }) : _deepFill = Paint()..color = colors.deep,
       _pageFill = Paint()..color = colors.page,
       _bandFills = [
         Paint()..color = colors.mid,
         Paint()..color = colors.light,
         Paint()..color = colors.page,
       ],
       _ringPaints = CasamaHeaderRings.paintsFor(isDark: colors.isDark),
       super(repaint: Listenable.merge([controller.morph, controller]));

  @override
  void paint(Canvas canvas, Size size) {
    if (controller.allBandsOffscreen) {
      canvas.drawRect(Offset.zero & size, _pageFill);
      return;
    }

    final w = size.width;
    canvas.drawRect(Offset.zero & size, _deepFill);

    final ringCenter = CasamaHeaderRings.bellCenter(
      size,
      safeTop,
      scrollOffset: controller.ringShift,
    );
    if (ringCenter.dy + 64 > 0) {
      CasamaHeaderRings.paint(canvas, ringCenter, _ringPaints);
    }

    for (int i = 0; i < 3; i++) {
      final p = controller.bandAt(i);
      final base = p.h - fromBottom[i];
      _path
        ..reset()
        ..moveTo(0, base + p.y0)
        ..cubicTo(
          w * p.c1x,
          base + p.c1y,
          w * p.c2x,
          base + p.c2y,
          w,
          base + p.y1,
        )
        ..lineTo(w, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(_path, _bandFills[i]);
    }
  }

  @override
  bool shouldRepaint(covariant CasamaWaveBackgroundPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.colors != colors ||
      oldDelegate.safeTop != safeTop;
}

/// Provides the shell's [CasamaWaveBackgroundController] and tab index to each
/// shell tab subtree without triggering widget rebuilds on scroll.
class CasamaWaveTabScope extends InheritedWidget {
  final CasamaWaveBackgroundController controller;
  final int tabIndex;

  const CasamaWaveTabScope({
    super.key,
    required this.controller,
    required this.tabIndex,
    required super.child,
  });

  static CasamaWaveTabScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CasamaWaveTabScope>();
  }

  void reportScroll(double offset) => controller.updateScroll(tabIndex, offset);

  void reportHeaderHeight(double height) =>
      controller.updateNaturalHeight(tabIndex, height);

  @override
  bool updateShouldNotify(CasamaWaveTabScope oldWidget) =>
      oldWidget.controller != controller || oldWidget.tabIndex != tabIndex;
}

/// Attaches a [ScrollController] listener that forwards vertical scroll pixels
/// to the nearest [CasamaWaveTabScope] without calling `setState`.
class CasamaWaveScrollSync extends StatefulWidget {
  final ScrollController? controller;
  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  const CasamaWaveScrollSync({
    super.key,
    this.controller,
    required this.builder,
  });

  @override
  State<CasamaWaveScrollSync> createState() => _CasamaWaveScrollSyncState();
}

class _CasamaWaveScrollSyncState extends State<CasamaWaveScrollSync> {
  ScrollController? _internalController;
  CasamaWaveTabScope? _scope;

  ScrollController get _effectiveController =>
      widget.controller ?? (_internalController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _effectiveController.addListener(_report);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scope = CasamaWaveTabScope.maybeOf(context);
  }

  @override
  void didUpdateWidget(covariant CasamaWaveScrollSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      final oldCtrl = oldWidget.controller ?? _internalController;
      oldCtrl?.removeListener(_report);
      if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      }
      _effectiveController.addListener(_report);
    }
  }

  void _report() {
    final c = _effectiveController;
    if (c.hasClients && c.positions.length == 1) {
      _scope?.reportScroll(c.position.pixels);
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_report);
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _effectiveController);
}

/// Measures a tab's foreground header widget post-frame and reports its natural
/// height (+ optional [extraHeight]) to [CasamaWaveTabScope].
class CasamaWaveHeaderSlot extends StatefulWidget {
  final Widget child;
  final double extraHeight;

  const CasamaWaveHeaderSlot({
    super.key,
    required this.child,
    this.extraHeight = 0.0,
  });

  @override
  State<CasamaWaveHeaderSlot> createState() => _CasamaWaveHeaderSlotState();
}

class _CasamaWaveHeaderSlotState extends State<CasamaWaveHeaderSlot> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() {
    if (!mounted) return;
    final ctx = _key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      CasamaWaveTabScope.maybeOf(
        context,
      )?.reportHeaderHeight(box.size.height + widget.extraHeight);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: KeyedSubtree(key: _key, child: widget.child),
      ),
    );
  }
}
