# Casama Wave Background Animation

This document describes the persistent, scroll-aware morphing wave background used across Casama's main navigation shell (`Home`, `Boards`, `Chat`, `Profile`).

---

## 1. Animation Speed & Timing

The wave morph speed is defined in `lib/shared/widgets/casama_wave_background.dart`:

```dart
const double kWaveSpeed = 0.45;
final Duration kWaveMorphDuration = Duration(
  milliseconds: (1100 / kWaveSpeed).round(), // ~2444ms
);
```

- **Faster transitions:** Increase `kWaveSpeed` (e.g., `1.0` → `1100ms`, `1.5` → `733ms`).
- **Slower transitions:** Decrease `kWaveSpeed` (e.g., `0.3` → `3667ms`).
- **Per-instance override:** Pass an explicit `duration:` to `CasamaWaveBackgroundController` in `lib/features/dashboard/main_navigation_shell.dart`.
- **Reduced motion:** When `MediaQuery.disableAnimationsOf(context)` is `true`, `CasamaWaveBackgroundController.reduceMotion` snaps immediately (`morph.value = 1.0`) with zero animation.

### Staggered Band Curves & Layer Offsets

The 3 wave bands (`mid`, `light`, `page`) use staggered `Interval` curves so the mid-teal and light-sage bands organically trail the front page-colored wave:

```dart
const List<double> kWaveBandFromBottom = [42.0, 26.0, 12.0];

const List<Curve> kWaveBandCurves = [
  Interval(0.20, 1.0, curve: Curves.easeInOutCubic), // Band 0: mid teal
  Interval(0.10, 1.0, curve: Curves.easeInOutCubic), // Band 1: light sage
  Interval(0.00, 1.0, curve: Curves.easeInOutCubic), // Band 2: page fill (front)
];
```

- Adjusting the `Interval` start values (`0.20`, `0.10`, `0.00`) changes how much the back bands trail behind the front wave.
- Adjusting `kWaveBandFromBottom` changes the vertical thickness/spacing of each wave band.

---

## 2. Widget Tree Structure

`MainNavigationShell` owns a single `CasamaWaveBackgroundController` (`_wave`) and paints one persistent background behind all 4 shell tabs. Each tab reports its vertical scroll offset and measured header height back to `_wave` via `CasamaWaveTabScope`, triggering repaints only on the `RepaintBoundary`-isolated `CustomPaint` (zero widget rebuilds during scroll or morph ticks).

```text
MainNavigationShell (owns `_wave: CasamaWaveBackgroundController` + SingleTickerProviderStateMixin)
└── CasamaShellScope
    └── Scaffold
        ├── body: Stack
        │   ├── [Background Layer] Positioned.fill
        │   │   └── IgnorePointer
        │   │       └── RepaintBoundary
        │   │           └── CustomPaint (key: 'casama_wave_background')
        │   │               └── painter: CasamaWaveBackgroundPainter
        │   │                   (repaint: Listenable.merge([_wave.morph, _wave]))
        │   │
        │   ├── [Foreground Tabs] IndexedStack (index: _currentIndex)
        │   │   ├── [0] CasamaWaveTabScope(controller: _wave, tabIndex: 0)
        │   │   │       └── DashboardScreen
        │   │   │           └── Scaffold(backgroundColor: Colors.transparent)
        │   │   │               └── CasamaAmbientCanvas(backgroundColor: Colors.transparent)
        │   │   │                   └── CasamaWaveScrollSync ──► reports scroll to _wave
        │   │   │                       └── SingleChildScrollView
        │   │   │                           └── Column
        │   │   │                               ├── CasamaWaveHeaderSlot ──► reports height to _wave
        │   │   │                               │   └── CasamaWaveHeader(paintBackground: false)
        │   │   │                               └── ... (Home content)
        │   │   │
        │   │   ├── [1] CasamaWaveTabScope(controller: _wave, tabIndex: 1)
        │   │   │       └── BoardsScreen
        │   │   │           └── Scaffold(backgroundColor: Colors.transparent)
        │   │   │               └── CasamaAmbientCanvas(backgroundColor: Colors.transparent)
        │   │   │                   └── Stack
        │   │   │                       ├── _BoardsWatermarkIcon
        │   │   │                       ├── NestedScrollView(controller: _outerScrollController) ──► reports scroll to _wave
        │   │   │                       │   ├── headerSliverBuilder: _MeasureSize ──► reports height to _wave
        │   │   │                       │   │   └── CasamaWaveHeader(paintBackground: false)
        │   │   │                       │   └── body: PageView (Parcels | Tasks | Items)
        │   │   │                       ├── _BoardsStickyPillBar
        │   │   │                       └── CasamaMorphingFab
        │   │   │
        │   │   ├── [2] SizedBox.shrink() (CASnap camera modal slot)
        │   │   │
        │   │   ├── [3] CasamaWaveTabScope(controller: _wave, tabIndex: 3)
        │   │   │       └── ChatDirectoryScreen
        │   │   │           └── Scaffold(backgroundColor: Colors.transparent)
        │   │   │               └── CasamaAmbientCanvas(backgroundColor: Colors.transparent)
        │   │   │                   └── CasamaWaveScrollSync(controller: _scrollController) ──► reports scroll to _wave
        │   │   │                       └── SingleChildScrollView
        │   │   │                           └── Column
        │   │   │                               ├── CasamaWaveHeaderSlot ──► reports height to _wave
        │   │   │                               │   └── CasamaWaveHeader(paintBackground: false)
        │   │   │                               └── ... (Chat content)
        │   │   │
        │   │   └── [4] CasamaWaveTabScope(controller: _wave, tabIndex: 4)
        │   │           └── ProfileScreen
        │   │               └── Scaffold(backgroundColor: Colors.transparent)
        │   │                   └── CasamaAmbientCanvas(backgroundColor: Colors.transparent)
        │   │                       └── CasamaWaveScrollSync ──► reports scroll to _wave
        │   │                           └── SingleChildScrollView
        │   │                               └── Column
        │   │                                   ├── CasamaWaveHeaderSlot(extraHeight: 34) ──► reports height to _wave
        │   │                                   │   └── CasamaWaveHeader(paintBackground: false)
        │   │                                   └── ... (Profile content)
        │   │
        │   └── [Optional] Tour Guide Card (when `_isTourActive`)
        │
        └── bottomNavigationBar: _CasamaBottomBar
```

---

## 3. Key Files

- `lib/shared/widgets/casama_wave_background.dart` — Wave math (`WaveParams`, `restWave`, `randomWave`), `CasamaHeaderRings`, `CasamaWaveBackgroundController`, `CasamaWaveBackgroundPainter`, `CasamaWaveTabScope`, `CasamaWaveScrollSync`, and `CasamaWaveHeaderSlot`.
- `lib/features/dashboard/main_navigation_shell.dart` — Hosts `_wave`, the single `RepaintBoundary` + `CustomPaint` background layer, and wraps each tab in `CasamaWaveTabScope`.
- `lib/shared/widgets/casama_wave_header.dart` — Shared header widget (`paintBackground: false` inside the shell; standalone screens still paint their own static wave + lighter-teal rings).
- `test/wave_background_controller_test.dart` & `test/wave_background_shell_test.dart` — Unit and widget tests covering wave math, scroll sync, deep-scroll clamping, mid-morph scrolling, rapid tab switching, reduced motion, and Light/Dark parity.
