import 'dart:math' as math;

import 'package:casama/shared/widgets/casama_wave_background.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaveParams & CasamaWaveBackgroundController', () {
    testWidgets('WaveParams.lerp interpolates at 0, 0.5, and 1, and bands stagger', (
      tester,
    ) async {
      const a = WaveParams(100, -4, -12, 20, 4, 0.30, 0.70);
      const b = WaveParams(200, 4, -20, 12, -4, 0.50, 0.80);

      expect(WaveParams.lerp(a, b, 0.0), a);
      expect(WaveParams.lerp(a, b, 1.0), b);

      final mid = WaveParams.lerp(a, b, 0.5);
      expect(mid.h, closeTo(150, 1e-6));
      expect(mid.y0, closeTo(0, 1e-6));
      expect(mid.c1y, closeTo(-16, 1e-6));
      expect(mid.c2y, closeTo(16, 1e-6));
      expect(mid.y1, closeTo(0, 1e-6));
      expect(mid.c1x, closeTo(0.40, 1e-6));
      expect(mid.c2x, closeTo(0.75, 1e-6));

      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);

      final initial0 = controller.bandAt(0);
      final initial1 = controller.bandAt(1);
      final initial2 = controller.bandAt(2);

      controller.selectTab(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // v = 0.1

      // Bands 0 (Interval 0.20..1.0) and 1 (Interval 0.10..1.0) have not moved yet.
      expect(controller.bandAt(0), initial0);
      expect(controller.bandAt(1), initial1);
      // Band 2 (Interval 0.00..1.0) has already started moving toward 280.
      expect(controller.bandAt(2).h, greaterThan(initial2.h));

      controller.dispose();
    });

    testWidgets('Home -> Boards rises with band 2 leading and settles at 280, then back to 200', (
      tester,
    ) async {
      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);

      controller.selectTab(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.isMorphing, isTrue);
      expect(controller.bandHeightAt(2), greaterThan(controller.bandHeightAt(1)));
      expect(controller.bandHeightAt(1), greaterThan(controller.bandHeightAt(0)));

      await tester.pump(const Duration(milliseconds: 700));
      expect(controller.isMorphing, isFalse);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(280, 1e-6));
      }

      controller.selectTab(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.isMorphing, isFalse);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(200, 1e-6));
      }

      controller.dispose();
    });

    testWidgets('Deep-scroll edge cases: 1500->0, 0->1500, 1500->1500, and inactive scroll', (
      tester,
    ) async {
      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // Scroll inactive tab 1 -> should not notify listeners
      controller.updateScroll(1, 1500);
      expect(notifyCount, 0);

      // Scroll active tab 0 deep -> 1500
      controller.updateScroll(0, 1500);
      expect(notifyCount, 1);
      expect(controller.allBandsOffscreen, isTrue);

      // 1500 -> 1500 (both offscreen): no animation runs
      controller.selectTab(1);
      expect(controller.morph.isAnimating, isFalse);
      expect(controller.morph.value, 1.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.allBandsOffscreen, isTrue);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(kMinOffscreenH, 1e-6));
      }

      // Reset tab 0 scroll to 0 while on tab 1 (inactive -> no notify)
      final countBefore = notifyCount;
      controller.updateScroll(0, 0);
      expect(notifyCount, countBefore);

      // 1500 -> 0: starts clamped at kMinOffscreenH and front band moves immediately at 10%
      controller.selectTab(0);
      expect(controller.morph.isAnimating, isTrue);
      for (int i = 0; i < 3; i++) {
        expect(controller.from[i].h, closeTo(kMinOffscreenH, 1e-6));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.bandHeightAt(2), greaterThan(kMinOffscreenH));

      await tester.pump(const Duration(milliseconds: 1000));
      expect(controller.bandHeightAt(2), closeTo(200, 1e-6));

      // 0 -> 1500: tab 1 is still at 1500, so morph ends at kMinOffscreenH
      controller.selectTab(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      expect(controller.allBandsOffscreen, isTrue);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(kMinOffscreenH, 1e-6));
      }

      controller.dispose();
    });

    testWidgets('Mid-morph scrolling tracks finger 1:1 without detaching or overshooting', (
      tester,
    ) async {
      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);

      controller.selectTab(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final before = [
        controller.bandHeightAt(0),
        controller.bandHeightAt(1),
        controller.bandHeightAt(2),
      ];

      // Scroll down 40 -> every band drops by 40, and to.h == 240
      controller.updateScroll(1, 40);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(before[i] - 40, 1e-6));
        expect(controller.to[i].h, closeTo(240, 1e-6));
      }

      // Scroll back to 0 -> restores earlier heights
      controller.updateScroll(1, 0);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(before[i], 1e-6));
        expect(controller.to[i].h, closeTo(280, 1e-6));
      }

      // Pump to end: no band ever exceeds 280
      for (int step = 0; step < 8; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        for (int i = 0; i < 3; i++) {
          expect(controller.bandHeightAt(i), lessThanOrEqualTo(280.0 + 1e-6));
        }
      }

      // Boards -> Home with mid-flight scroll down then back up ends at 200 without overshoot
      controller.selectTab(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      controller.updateScroll(0, 50);
      await tester.pump(const Duration(milliseconds: 100));
      controller.updateScroll(0, 0);
      for (int step = 0; step < 8; step++) {
        await tester.pump(const Duration(milliseconds: 100));
        for (int i = 0; i < 3; i++) {
          expect(controller.bandHeightAt(i), greaterThanOrEqualTo(200.0 - 1e-6));
        }
      }
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(200, 1e-6));
      }

      controller.dispose();
    });

    testWidgets('Rapid mid-flight tab switching preserves exact continuity & re-selecting is a no-op', (
      tester,
    ) async {
      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);
      controller.updateNaturalHeight(3, 190);
      controller.updateNaturalHeight(4, 230);

      // Re-selecting active tab is a no-op
      int notifyCount = 0;
      controller.addListener(() => notifyCount++);
      controller.selectTab(0);
      expect(notifyCount, 0);
      expect(controller.isMorphing, isFalse);

      // Switch 0 -> 1, advance 30%
      controller.selectTab(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final at30 = [
        controller.bandAt(0),
        controller.bandAt(1),
        controller.bandAt(2),
      ];

      // Rapid switch to tab 3: bandAt(i) immediately equals pre-switch snapshot
      controller.selectTab(3);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandAt(i).h, closeTo(at30[i].h, 1e-6));
        expect(controller.bandAt(i).y0, closeTo(at30[i].y0, 1e-6));
        expect(controller.bandAt(i).c1y, closeTo(at30[i].c1y, 1e-6));
        expect(controller.bandAt(i).c2y, closeTo(at30[i].c2y, 1e-6));
        expect(controller.bandAt(i).y1, closeTo(at30[i].y1, 1e-6));
        expect(controller.bandAt(i).c1x, closeTo(at30[i].c1x, 1e-6));
        expect(controller.bandAt(i).c2x, closeTo(at30[i].c2x, 1e-6));
      }

      // Advance 50%, rapid switch to tab 4
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final at50 = [
        controller.bandAt(0),
        controller.bandAt(1),
        controller.bandAt(2),
      ];
      controller.selectTab(4);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandAt(i).h, closeTo(at50[i].h, 1e-6));
        expect(controller.bandAt(i).c1x, closeTo(at50[i].c1x, 1e-6));
        expect(controller.bandAt(i).c2x, closeTo(at50[i].c2x, 1e-6));
      }

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(230, 1e-6));
      }

      controller.dispose();
    });

    testWidgets('reduceMotion = true snaps immediately on tab switch', (
      tester,
    ) async {
      final controller = CasamaWaveBackgroundController(
        vsync: tester,
        initialTab: 0,
        random: math.Random(7),
        duration: const Duration(milliseconds: 1000),
      );
      controller.updateNaturalHeight(0, 200);
      controller.updateNaturalHeight(1, 280);
      controller.reduceMotion = true;

      controller.selectTab(1);
      expect(controller.morph.value, 1.0);
      expect(controller.isMorphing, isFalse);
      for (int i = 0; i < 3; i++) {
        expect(controller.bandHeightAt(i), closeTo(280, 1e-6));
      }

      controller.dispose();
    });
  });
}
