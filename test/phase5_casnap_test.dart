import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/quicksnap/quicksnap_camera_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_feed_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_home_widget.dart';
import 'package:casama/shared/widgets/casama_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'QuickSnapHomeWidget renders 3x2 Shared CASnaps grid with +N overflow slot and opens Hero lightbox',
    (tester) async {
      final repo = MockRepository()..login();
      for (var i = 0; i < 7; i++) {
        repo.sendQuickSnap(
          imageUrl: 'offline_snap_$i.jpg',
          caption: 'Shot $i',
          recipientType: i.isEven
              ? QuickSnapRecipientType.selectedHousemates
              : QuickSnapRecipientType.everyone,
          recipientNames: i.isEven ? ['Maria'] : const [],
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.lightTheme,
            home: const Scaffold(
              body: SingleChildScrollView(child: QuickSnapHomeWidget()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared CASnaps'), findsOneWidget);
      expect(find.text('7 photos'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('Browse all 7 shared shots →'), findsOneWidget);

      // Tap a photo tile to launch 200ms Hero lightbox
      await tester.tap(find.bySemanticsLabel('Photo by ${repo.currentUser.displayName}').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Close photo viewer'), findsOneWidget);
      expect(find.textContaining('Shot '), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close photo viewer'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close photo viewer'), findsNothing);
    },
  );

  testWidgets(
    'QuickSnapFeedScreen filters Memories gallery by Direct / Your Shots under Dark Mode & reduced motion',
    (tester) async {
      final repo = MockRepository()..login();
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_public.jpg',
        caption: 'Living room chill',
        recipientType: QuickSnapRecipientType.everyone,
      );
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_direct.jpg',
        caption: 'Parcel is on the counter',
        recipientType: QuickSnapRecipientType.selectedHousemates,
        recipientNames: ['Maria'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              disableAnimations: true,
            ),
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              darkTheme: CasamaTheme.darkTheme,
              themeMode: ThemeMode.dark,
              home: const QuickSnapFeedScreen(initialTabIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All (2)'), findsOneWidget);
      expect(find.text('Your Shots'), findsOneWidget);
      expect(find.text('Direct'), findsWidgets);

      // Filter strictly to Direct shots via the filter pill
      final directPill = find.descendant(
        of: find.byType(CasamaPillFilterRail<String>),
        matching: find.text('Direct'),
      );
      await tester.ensureVisible(directPill);
      await tester.tap(directPill);
      await tester.pumpAndSettle();
      expect(find.text('1 shot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QuickSnapCameraScreen cycles recipient sheet and flips camera cleanly',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'quicksnap_camera_permission_granted': true,
      });
      final repo = MockRepository()..login();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [repositoryProvider.overrideWith((ref) => repo)],
          child: MaterialApp(
            theme: CasamaTheme.darkTheme,
            home: const QuickSnapCameraScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open dark recipient selector sheet
      await tester.tap(find.text('Everyone'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      expect(find.text('Send CASnap to...'), findsOneWidget);
      expect(find.text('Everyone in Casa 204'), findsOneWidget);

      await tester.tap(find.text('Maria'));
      await tester.pump();
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));

      expect(find.text('Maria'), findsOneWidget);

      // Trigger 180-deg flip rotation
      await tester.tap(find.byKey(const Key('flip_camera_button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );
}
