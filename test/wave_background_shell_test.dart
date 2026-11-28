import 'dart:math' as math;

import 'package:casama/core/constants/colors.dart';
import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/auth/widgets/auth_wave_header.dart';
import 'package:casama/features/chat/chat_directory_screen.dart';
import 'package:casama/features/chat/widgets/chat_thread_components.dart';
import 'package:casama/features/dashboard/boards_screen.dart';
import 'package:casama/features/dashboard/dashboard_screen.dart';
import 'package:casama/features/dashboard/main_navigation_shell.dart';
import 'package:casama/features/profile/profile_screen.dart';
import 'package:casama/shared/widgets/casama_wave_background.dart';
import 'package:casama/shared/widgets/casama_wave_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingCanvas implements Canvas {
  final List<Color> allColors = [];
  final List<Color> circleColors = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    allColors.add(paint.color);
    circleColors.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    for (final arg in invocation.positionalArguments) {
      if (arg is Paint) {
        allColors.add(arg.color);
      }
    }
    return null;
  }
}

bool _isGold(Color c) {
  final r = (c.r * 255).round();
  final g = (c.g * 255).round();
  final b = (c.b * 255).round();
  return r == 0xF4 && g == 0xB5 && b == 0x44;
}

void _assertNoGoldRingsOnMatchingPainters(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  for (final cp in customPaints) {
    final painter = cp.painter;
    if (painter == null) continue;
    final name = painter.runtimeType.toString();
    if (name.contains('Wave') ||
        name.contains('Header') ||
        name.contains('Thread') ||
        name.contains('Auth') ||
        name.contains('Drawer') ||
        name.contains('Splash')) {
      final canvas = _RecordingCanvas();
      painter.paint(canvas, const Size(390, 844));
      for (final c in canvas.allColors) {
        expect(_isGold(c), isFalse, reason: 'Found gold color $c in $name');
      }
      for (final c in canvas.circleColors) {
        expect(c.r, 1.0, reason: 'Circle color in $name should be white-based');
        expect(c.g, 1.0, reason: 'Circle color in $name should be white-based');
        expect(c.b, 1.0, reason: 'Circle color in $name should be white-based');
      }
    }
  }
}

CasamaWaveBackgroundPainter _findShellWavePainter(WidgetTester tester) {
  final cp = tester.widget<CustomPaint>(
    find.byKey(const Key('casama_wave_background')),
  );
  return cp.painter! as CasamaWaveBackgroundPainter;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'MainNavigationShell renders one CasamaWaveBackgroundPainter behind all 4 tabs with zero gold rings in Light & Dark',
    (tester) async {
      expect(_isGold(CasamaPalette.light.headerOrnament), isFalse);
      expect(_isGold(CasamaPalette.dark.headerOrnament), isFalse);

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = MockRepository()..login();
        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('shell_scope_${mode.name}'),
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: mode,
              home: const MainNavigationShell(initialIndex: 0),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
        final tabCases = [
          ('Home', DashboardScreen),
          ('Boards', BoardsScreen),
          ('Chat', ChatDirectoryScreen),
          ('Profile', ProfileScreen),
        ];

        for (final (label, screenType) in tabCases) {
          await tester.tap(find.descendant(of: navBar, matching: find.text(label)));
          await tester.pumpAndSettle();

          final allBgPainters = tester
              .widgetList<CustomPaint>(find.byType(CustomPaint))
              .where((w) => w.painter is CasamaWaveBackgroundPainter);
          expect(allBgPainters.length, 1);

          final screenScaffold = tester.widget<Scaffold>(
            find.descendant(
              of: find.byType(screenType),
              matching: find.byType(Scaffold),
            ).first,
          );
          expect(screenScaffold.backgroundColor, Colors.transparent);

          final header = tester.widget<CasamaWaveHeader>(
            find.descendant(
              of: find.byType(screenType),
              matching: find.byType(CasamaWaveHeader),
            ),
          );
          expect(header.paintBackground, isFalse);

          _assertNoGoldRingsOnMatchingPainters(tester);
        }

        // Also check drawer rings when opened
        await tester.tap(find.descendant(of: navBar, matching: find.text('Home')));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Open menu'));
        await tester.pumpAndSettle();
        _assertNoGoldRingsOnMatchingPainters(tester);
        await tester.tapAt(const Offset(360, 400));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Standalone headers (CasamaWaveHeader, CasamaChatThreadHeader, CasamaAuthShell) use lighter-teal rings with zero gold',
    (tester) async {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: mode,
            home: Scaffold(
              body: Column(
                children: [
                  const CasamaWaveHeader(title: 'Standalone'),
                  CasamaChatThreadHeader(
                    title: 'Thread',
                    subtitle: 'Sub',
                    leadingBadge: const Icon(Icons.chat),
                    onBack: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        _assertNoGoldRingsOnMatchingPainters(tester);

        await tester.pumpWidget(
          MaterialApp(
            theme: CasamaTheme.lightTheme,
            darkTheme: CasamaTheme.darkTheme,
            themeMode: mode,
            home: const CasamaAuthShell(child: SizedBox(height: 100)),
          ),
        );
        await tester.pumpAndSettle();
        _assertNoGoldRingsOnMatchingPainters(tester);
      }
    },
  );

  testWidgets(
    'Scrolling Home and Boards updates wave background smoothly and reveals Boards sticky pill bar',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controller = _findShellWavePainter(tester).controller;

      // Scroll Home
      final homeScrollFinder = find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(homeScrollFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      final homeScrollState = tester.state<ScrollableState>(
        find.descendant(
          of: homeScrollFinder,
          matching: find.byType(Scrollable),
        ).first,
      );
      final expectedH = math.max(
        kMinOffscreenH,
        controller.naturalHeightFor(0) - homeScrollState.position.pixels,
      );
      expect(controller.bandHeightAt(2), closeTo(expectedH, 0.5));

      // Switch to Boards and scroll past hero header
      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
      await tester.tap(find.descendant(of: navBar, matching: find.text('Boards')));
      await tester.pumpAndSettle();

      final boardsNestedFinder = find.descendant(
        of: find.byType(BoardsScreen),
        matching: find.byType(NestedScrollView),
      );
      await tester.drag(boardsNestedFinder, const Offset(0, -320));
      await tester.pumpAndSettle();

      final stickyFinder = find.byKey(const Key('boards_sticky_pill_bar'));
      final stickyOpacity = tester.widget<AnimatedOpacity>(
        find.descendant(
          of: stickyFinder,
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(stickyOpacity.opacity, 1.0);
      expect(controller.allBandsOffscreen, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reduced motion snaps immediately between tab header heights',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo = MockRepository()..login();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const MainNavigationShell(initialIndex: 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final controller = _findShellWavePainter(tester).controller;
      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));

      for (final (label, tabIdx) in [
        ('Boards', 1),
        ('Chat', 3),
        ('Profile', 4),
        ('Home', 0),
      ]) {
        await tester.tap(find.descendant(of: navBar, matching: find.text(label)));
        await tester.pump();
        expect(controller.morph.value, 1.0);
        expect(
          controller.bandHeightAt(2),
          closeTo(controller.targetHeightFor(tabIdx), 1e-6),
        );
      }
    },
  );

  testWidgets(
    'Theme switch mid-morph updates painter colors without breaking animation',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repo = MockRepository()..login();
      Widget buildApp(ThemeMode mode) => ProviderScope(
        overrides: [repositoryProvider.overrideWith((ref) => repo)],
        child: MaterialApp(
          theme: CasamaTheme.lightTheme,
          darkTheme: CasamaTheme.darkTheme,
          themeMode: mode,
          home: const MainNavigationShell(initialIndex: 0),
        ),
      );

      await tester.pumpWidget(buildApp(ThemeMode.light));
      await tester.pumpAndSettle();

      final lightPainter = _findShellWavePainter(tester);
      final lightColors = lightPainter.colors;

      final navBar = find.byKey(const ValueKey('casama_5_slot_bar'));
      await tester.tap(find.descendant(of: navBar, matching: find.text('Boards')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(lightPainter.controller.morph.isAnimating, isTrue);

      await tester.pumpWidget(buildApp(ThemeMode.dark));
      await tester.pump(const Duration(milliseconds: 200));

      final darkPainter = _findShellWavePainter(tester);
      expect(darkPainter.colors, isNot(equals(lightColors)));
      expect(darkPainter.controller.morph.isAnimating, isTrue);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
