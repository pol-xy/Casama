import 'dart:math' as math;
import 'package:flutter/material.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: AnimTest()),
);

const kDeep = Color(0xFF38655D);
const kMid = Color(0xFF688C83);
const kLight = Color(0xFFA5B9B0);
const kPage = Color(0xFFEAE4D7);

const kSpeed = 0.45; // 1.0 = base speed, lower = slower

// Where the teal ends for each tab: shortest -> longest.
const kTabHeights = [200.0, 250.0, 300.0];
const kMaxHeader = 300.0;

// ---------------------------------------------------------------------------
// WAVES
// ---------------------------------------------------------------------------

/// One cubic wave band: [h] is where this band's header ends, y0/y1 are the
/// left/right edge offsets, c1y/c2y the control heights, c1x/c2x the control
/// positions as a fraction of the width.
class WaveParams {
  final double h, y0, c1y, c2y, y1, c1x, c2x;
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
}

/// The app's original wave shapes, at a given header height.
List<WaveParams> restWave(double h) => [
  WaveParams(h, 0, -12, 20, 0, 0.36, 0.68), // mid
  WaveParams(h, 0, -14, 18, 0, 0.40, 0.72), // light
  WaveParams(h, 0, -10, 14, 0, 0.42, 0.74), // page
];

/// Whole background in one pass. Each layer has its own height, and the
/// layers are staggered, so the bands trail the front wave as the teal
/// grows or shrinks.
class WaveBackgroundPainter extends CustomPainter {
  final Animation<double> progress;
  final List<WaveParams> from, to;

  WaveBackgroundPainter({
    required this.progress,
    required this.from,
    required this.to,
  }) : super(repaint: progress);

  static const _fromBottom = [42.0, 26.0, 12.0];
  static const curves = [
    Interval(0.20, 1.0, curve: Curves.easeInOutCubic),
    Interval(0.10, 1.0, curve: Curves.easeInOutCubic),
    Interval(0.00, 1.0, curve: Curves.easeInOutCubic),
  ];

  static final _deepFill = Paint()..color = kDeep;
  static final _fills = [
    Paint()..color = kMid,
    Paint()..color = kLight,
    Paint()..color = kPage,
  ];
  static final _ringPaints = [
    for (final a in [0.16, 0.12, 0.08])
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
  ];
  static const _ringRadii = [28.0, 44.0, 62.0];
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;

    // Teal everywhere; the page-coloured front wave covers the rest.
    canvas.drawRect(Offset.zero & size, _deepFill);

    // Concentric ring pattern, top-right.
    final center = Offset(w - 36, 48);
    for (int i = 0; i < _ringRadii.length; i++) {
      canvas.drawCircle(center, _ringRadii[i], _ringPaints[i]);
    }

    final v = progress.value;
    for (int i = 0; i < 3; i++) {
      final p = WaveParams.lerp(from[i], to[i], curves[i].transform(v));
      final base = p.h - _fromBottom[i];

      // Every band runs to the bottom of the screen; later bands cover
      // earlier ones, so a lagging band is never cut off mid-animation.
      _path
        ..reset()
        ..moveTo(0, base + p.y0)
        ..cubicTo(
          w * p.c1x, base + p.c1y,
          w * p.c2x, base + p.c2y,
          w, base + p.y1,
        )
        ..lineTo(w, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(_path, _fills[i]);
    }
  }

  @override
  bool shouldRepaint(covariant WaveBackgroundPainter old) =>
      old.from != from || old.to != to || old.progress != progress;
}

// ---------------------------------------------------------------------------
// PAGE
// ---------------------------------------------------------------------------

class AnimTest extends StatefulWidget {
  const AnimTest({super.key});

  @override
  State<AnimTest> createState() => _AnimTestState();
}

class _AnimTestState extends State<AnimTest>
    with SingleTickerProviderStateMixin {
  final _rng = math.Random();

  late final AnimationController _morph = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (1100 / kSpeed).round()),
    value: 1,
  );

  List<WaveParams> _from = restWave(kTabHeights[0]);
  List<WaveParams> _to = restWave(kTabHeights[0]);
  int _tab = 1;

  @override
  void dispose() {
    _morph.dispose();
    super.dispose();
  }

  List<WaveParams> _snapshot() {
    final v = _morph.value;
    return List.generate(3, (i) {
      final t = WaveBackgroundPainter.curves[i].transform(v);
      return WaveParams.lerp(_from[i], _to[i], t);
    });
  }

  // Random shapes in the same gentle range as the static design.
  List<WaveParams> _randomWave(double h) {
    double r(double a, double b) => a + _rng.nextDouble() * (b - a);
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

  void _selectTab(int tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _from = _snapshot(); // start from wherever the waves are right now
      _to = _randomWave(kTabHeights[tab - 1]);
    });
    _morph.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPage,
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: WaveBackgroundPainter(
                  progress: _morph,
                  from: _from,
                  to: _to,
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(
                height: 120,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      'Tab $_tab',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              // Buttons sit below the longest header so they never move.
              SizedBox(height: kMaxHeader - 120 + 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 1; i <= 3; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: ElevatedButton(
                        onPressed: () => _selectTab(i),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tab == i ? kDeep : Colors.white,
                          foregroundColor: _tab == i ? Colors.white : kDeep,
                        ),
                        child: Text('Tab $i'),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}