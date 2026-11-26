import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/quicksnap/quicksnap_camera_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_feed_screen.dart';
import 'package:casama/features/quicksnap/quicksnap_home_widget.dart';
import 'package:casama/main.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:casama/shared/widgets/casama_filter_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'QuickSnapHomeWidget renders 3x2 Shared CASnaps grid without To You badges, resolves profile avatars, and opens Hero lightbox',
    (tester) async {
      final repo = MockRepository()..login();
      for (var i = 0; i < 7; i++) {
        repo.sendQuickSnap(
          imageUrl: 'offline_snap_$i.jpg',
          caption: 'Shot $i',
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
      expect(find.text('To You'), findsNothing);
      expect(find.text('Direct'), findsNothing);

      final avatar = tester.widget<CasamaAvatar>(find.byType(CasamaAvatar).first);
      expect(avatar.avatarUrl, repo.currentUser.effectiveAvatarUrl);

      // Tap a photo tile to launch 200ms Hero lightbox (no Direct badge)
      await tester.tap(find.bySemanticsLabel('Photo by ${repo.currentUser.displayName}').first);
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Close photo viewer'), findsOneWidget);
      expect(find.textContaining('Shot '), findsOneWidget);
      expect(find.text('Direct'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Close photo viewer'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close photo viewer'), findsNothing);
    },
  );

  testWidgets(
    'QuickSnapFeedScreen filters Memories gallery by Your Shots / housemate without Direct badges under Dark Mode & reduced motion',
    (tester) async {
      final repo = MockRepository()..login();
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_jp.jpg',
        caption: 'Living room chill',
      );
      repo.setCurrentUserForTest('22222222-2222-2222-2222-222222222222');
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_maria.jpg',
        caption: 'Parcel is on the counter',
      );
      repo.setCurrentUserForTest('11111111-1111-1111-1111-111111111111');

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
      expect(find.text('Direct'), findsNothing);

      // Filter strictly to Your Shots via the filter pill
      final yourShotsPill = find.descendant(
        of: find.byType(CasamaPillFilterRail<String>),
        matching: find.text('Your Shots'),
      );
      await tester.ensureVisible(yourShotsPill);
      await tester.tap(yourShotsPill);
      await tester.pumpAndSettle();
      expect(find.text('1 shot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'QuickSnapCameraScreen removes recipient picker and gallery upload, shows Shared with household, and flips camera cleanly',
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

      expect(find.text('Everyone'), findsNothing);
      expect(find.text('Send CASnap to...'), findsNothing);
      expect(find.byKey(const Key('gallery_picker_button')), findsNothing);
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
      expect(find.text('Shared with Casa 204'), findsOneWidget);

      // Trigger 180-deg flip rotation
      await tester.tap(find.byKey(const Key('flip_camera_button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Highlights renders 6 emojis & Comment... 💬, batches multi-taps across screen pop, and flushes on lifecycle pause',
    (tester) async {
      final repo = MockRepository()..login();
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_1.jpg',
        caption: 'Dinner prep',
      );
      final snap = repo.quickSnaps.first;

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
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const QuickSnapFeedScreen(),
                          ),
                        );
                      },
                      child: const Text('Open Feed'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Highlights'), findsOneWidget);
      expect(find.text('All CASnaps'), findsOneWidget);
      expect(find.text('Comment... 💬'), findsOneWidget);
      for (final emoji in kCasSnapReactionEmojis) {
        expect(find.bySemanticsLabel('React $emoji'), findsOneWidget);
      }
      expect(
        find.byKey(ValueKey('casnap_reactions_pill_${snap.id}')),
        findsNothing,
      );

      // Rapidly tap 🔥 3 times and ❤️ 2 times
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('React 🔥'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.bySemanticsLabel('React ❤️'));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Immediate optimistic UI update on pill, nothing flushed yet
      expect(
        find.byKey(ValueKey('casnap_reactions_pill_${snap.id}')),
        findsOneWidget,
      );
      expect(find.text('5'), findsOneWidget);
      expect(repo.flushedReactionBatches, isEmpty);

      // Pop back to Home BEFORE 1200ms debounce expires
      Navigator.of(tester.element(find.byType(QuickSnapFeedScreen))).pop();
      await tester.pumpAndSettle();
      expect(repo.flushedReactionBatches, isEmpty);

      // Debounce timer continues in repository and flushes once
      await tester.pump(const Duration(milliseconds: 1300));
      expect(repo.flushedReactionBatches.length, 1);
      expect(repo.flushedReactionBatches.single.snapId, snap.id);
      expect(repo.flushedReactionBatches.single.deltas, {'🔥': 3, '❤️': 2});

      // Verify root CasamaApp lifecycle pause flushes pending reactions immediately
      final lifecycleRepo = MockRepository()..login();
      lifecycleRepo.sendQuickSnap(
        imageUrl: 'offline_snap_lifecycle.jpg',
        caption: 'Late snack',
      );
      final lifecycleSnap = lifecycleRepo.quickSnaps.first;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Root Home')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('lifecycle_scope'),
          overrides: [repositoryProvider.overrideWith((ref) => lifecycleRepo)],
          child: CasamaApp(router: router),
        ),
      );
      await tester.pumpAndSettle();

      lifecycleRepo.queueQuickSnapReaction(lifecycleSnap.id, '😂');
      expect(lifecycleRepo.hasPendingSnapReactions, isTrue);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(lifecycleRepo.hasPendingSnapReactions, isFalse);
      expect(lifecycleRepo.flushedReactionBatches.length, 1);
      expect(lifecycleRepo.flushedReactionBatches.last.deltas, {'😂': 1});
    },
  );

  testWidgets(
    'Bottom-left Facebook-style reactions pill opens Reactors Breakdown sheet with user counts',
    (tester) async {
      final repo = MockRepository()..login();
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_pill.jpg',
        caption: 'Rooftop sunset',
      );
      final snap = repo.quickSnaps.first;

      // Maria reacts once with 😂
      repo.setCurrentUserForTest('22222222-2222-2222-2222-222222222222');
      repo.queueQuickSnapReaction(snap.id, '😂');
      await repo.flushPendingSnapReactions();

      // Jon Paul reacts 3x 🔥 and 2x ❤️
      repo.setCurrentUserForTest('11111111-1111-1111-1111-111111111111');
      for (var i = 0; i < 3; i++) {
        repo.queueQuickSnapReaction(snap.id, '🔥');
      }
      for (var i = 0; i < 2; i++) {
        repo.queueQuickSnapReaction(snap.id, '❤️');
      }
      await repo.flushPendingSnapReactions();

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
              home: const QuickSnapFeedScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pill = find.byKey(ValueKey('casnap_reactions_pill_${snap.id}'));
      expect(pill, findsOneWidget);
      expect(
        find.descendant(of: pill, matching: find.text('6')),
        findsOneWidget,
      );

      await tester.tap(pill);
      await tester.pumpAndSettle();

      expect(find.text('Reactions'), findsOneWidget);
      expect(find.text('6 reactions from 2 housemates'), findsOneWidget);
      expect(find.text('🔥-3'), findsOneWidget);
      expect(find.text('❤️-2'), findsOneWidget);
      expect(find.text('😂-1'), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping a thumbnail in All CASnaps opens unified viewer matching Highlights',
    (tester) async {
      final repo = MockRepository()..login();
      repo.sendQuickSnap(
        imageUrl: 'offline_snap_grid.jpg',
        caption: 'Movie night',
      );
      final snap = repo.quickSnaps.first;

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
              home: const QuickSnapFeedScreen(initialTabIndex: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All CASnaps'), findsOneWidget);

      await tester.tap(
        find.bySemanticsLabel('Open photo by ${repo.currentUser.displayName}'),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Close photo viewer'), findsOneWidget);
      expect(find.text('Movie night'), findsOneWidget);
      expect(find.text('Comment... 💬'), findsOneWidget);
      expect(find.byTooltip('Send comment'), findsOneWidget);
      expect(find.byTooltip('Open comments'), findsOneWidget);
      for (final emoji in kCasSnapReactionEmojis) {
        expect(find.bySemanticsLabel('React $emoji'), findsOneWidget);
      }

      // React inside unified All CASnaps viewer and verify bottom-left pill appears
      await tester.tap(find.bySemanticsLabel('React 👍'));
      await tester.pump();
      expect(
        find.byKey(ValueKey('casnap_reactions_pill_${snap.id}')),
        findsOneWidget,
      );

      // Post a comment inside unified viewer
      await tester.enterText(find.byType(TextField), 'Count me in!');
      await tester.tap(find.byTooltip('Send comment'));
      await tester.pumpAndSettle();
      expect(repo.quickSnaps.first.comments.single.text, 'Count me in!');

      await repo.flushPendingSnapReactions();
    },
  );
}
