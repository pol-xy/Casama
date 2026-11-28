import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/items/lost_found_screen.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/features/parcels/widgets/courier_logo.dart';
import 'package:casama/features/tasks/maintenance_screen.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Boards Visual & Interaction Parity', () {
    test('resolveCourierLogoAsset maps all 8 couriers and fallback to exact PNG assets', () {
      expect(
        resolveCourierLogoAsset('J&T Express'),
        'assets/images/couriers/jnt_express.png',
      );
      expect(
        resolveCourierLogoAsset('Flash Express'),
        'assets/images/couriers/flash_express.png',
      );
      expect(
        resolveCourierLogoAsset('Ninja Van'),
        'assets/images/couriers/ninja_van.png',
      );
      expect(
        resolveCourierLogoAsset('LBC'),
        'assets/images/couriers/lbc.png',
      );
      expect(
        resolveCourierLogoAsset('2GO Express'),
        'assets/images/couriers/2go_express.png',
      );
      expect(
        resolveCourierLogoAsset('Lalamove'),
        'assets/images/couriers/lalamove.png',
      );
      expect(
        resolveCourierLogoAsset('SPX'),
        'assets/images/couriers/spx.png',
      );
      expect(
        resolveCourierLogoAsset('Other'),
        'assets/images/couriers/other.png',
      );
      expect(
        resolveCourierLogoAsset('Unknown Courier'),
        'assets/images/couriers/other.png',
      );
    });

    testWidgets(
      'Tasks summary card shows points strictly Available to you (0 own, base others, +4 only if selectedUserId == currentUserId)',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repo = MockRepository()..login();
        final jpId = repo.currentUser.id;
        const mariaId = '22222222-2222-2222-2222-222222222222';
        const alexId = '33333333-3333-3333-3333-333333333333';

        // Seeded tasks: t1 (JP, 14), t2 (Maria, 9), t3 (Maria, 7) => 16 pts for JP.
        // Spin t2 -> chosen Alex (JP gets 0 bonus); spin t3 -> chosen JP (JP gets +4 bonus).
        await repo.spinTaskRoulette('t2', alexId);
        await repo.spinTaskRoulette('t3', jpId);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const Scaffold(body: TasksBoardView()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('20 pts'), findsOneWidget);
        expect(find.text('Available to you'), findsOneWidget);
        expect(find.text('Across ongoing tasks'), findsNothing);

        // Switch to Maria: t1 (14) + t2 (0, own) + t3 (7, Alex's) = 21 pts available to Maria
        repo.setCurrentUserForTest(mariaId);
        await tester.pumpAndSettle();
        expect(find.text('21 pts'), findsOneWidget);
        expect(find.text('Available to you'), findsOneWidget);

        // Creator-only avatars on By / Spun by / Chosen pills
        expect(find.byKey(const ValueKey('task_creator_avatar_t1')), findsOneWidget);
        expect(find.byKey(const ValueKey('task_spinner_avatar_t2')), findsOneWidget);
        expect(find.byKey(const ValueKey('task_chosen_avatar_t2')), findsOneWidget);
        expect(find.byType(CasamaAvatar), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Creator-only delete works on Tasks (Ongoing & Completed) and Items (Lost, Found, Resolved) and is hidden from non-creators',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = MockRepository()..login();

        // 1. Tasks: t1 is JP's own task, t2 is Maria's task
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
                home: const Scaffold(body: TasksBoardView()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Non-creator task t2 has NO delete button
        await tester.tap(find.text('Buy Drinking Water'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('task_delete_btn_t2')), findsNothing);

        // Creator task t1 has 48x48 delete button -> cancel keeps, confirm deletes
        await tester.tap(find.text('Leaking Faucet'));
        await tester.pumpAndSettle();
        final taskDeleteBtn = find.byKey(const ValueKey('task_delete_btn_t1'));
        expect(taskDeleteBtn, findsOneWidget);
        expect(tester.getSize(taskDeleteBtn).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(taskDeleteBtn).height, greaterThanOrEqualTo(48));

        await tester.tap(taskDeleteBtn);
        await tester.pumpAndSettle();
        expect(find.text('Delete task?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('task_confirm_delete_button')));
        await tester.pumpAndSettle();
        expect(repo.tasks.any((t) => t.id == 't1'), isFalse);

        // Add & complete a self-created task -> expandable in Completed Tasks for creator delete
        repo.addTask(
          title: 'Wipe Balcony',
          category: TaskCategory.cleaning,
          urgency: TaskUrgency.low,
        );
        final ownCompletedId = repo.tasks.first.id;
        repo.completeTask(ownCompletedId);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Completed Tasks'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wipe Balcony'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('task_delete_btn_$ownCompletedId')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('task_confirm_delete_button')));
        await tester.pumpAndSettle();
        expect(repo.tasks.any((t) => t.id == ownCompletedId), isFalse);

        // 2. Items: i1 (Lost AirPods) is JP's own lost item; post a non-creator lost item by Maria
        const mariaId = '22222222-2222-2222-2222-222222222222';
        final jpId = repo.currentUser.id;
        repo.setCurrentUserForTest(mariaId);
        repo.postItem(
          type: ItemType.lost,
          title: 'Maria Notebook',
          location: 'Desk',
        );
        final mariaLostId = repo.items.first.id;
        repo.setCurrentUserForTest(jpId);

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
                home: const Scaffold(body: ItemsBoardView()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Inline reporter avatar rendered on collapsed item card
        expect(find.byKey(const ValueKey('item_reporter_avatar_i1')), findsOneWidget);

        // Non-creator item has NO delete button
        await tester.tap(find.text('Maria Notebook'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('item_delete_btn_$mariaLostId')),
          findsNothing,
        );

        // Creator item i1 has 48x48 delete button -> confirm deletes
        await tester.tap(find.text('Lost AirPods'));
        await tester.pumpAndSettle();
        final itemDeleteBtn = find.byKey(const ValueKey('item_delete_btn_i1'));
        expect(itemDeleteBtn, findsOneWidget);
        expect(tester.getSize(itemDeleteBtn).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(itemDeleteBtn).height, greaterThanOrEqualTo(48));

        await tester.tap(itemDeleteBtn);
        await tester.pumpAndSettle();
        expect(find.text('Delete item post?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('item_confirm_delete_button')));
        await tester.pumpAndSettle();
        expect(repo.items.any((i) => i.id == 'i1'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Parcel cards start collapsed, expand one at a time, render PNG courier logos in list & AddParcelSheet',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = MockRepository()..login();
        repo.addParcel(
          courier: 'SPX',
          arrival: DateTime.now(),
          paymentType: ParcelPaymentType.paid,
          notes: 'Second Today parcel notes',
        );
        final ownTodayId = repo.parcels.first.id;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => repo)],
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                disableAnimations: true,
              ),
              child: MaterialApp(
                theme: CasamaTheme.lightTheme,
                darkTheme: CasamaTheme.darkTheme,
                themeMode: ThemeMode.dark,
                home: const ParcelsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Collapsed by default: notes and action buttons hidden, PNG logos & chevrons visible
        expect(find.text('Fragile - Handle with care!'), findsNothing);
        expect(find.text('Second Today parcel notes'), findsNothing);
        expect(find.text('I Got It'), findsNothing);
        expect(find.byType(CasamaCourierLogo), findsNWidgets(2));
        expect(find.byType(Image), findsWidgets);

        // Tap p1 -> expands p1
        await tester.tap(find.byKey(const ValueKey('parcel_card_header_p1')));
        await tester.pumpAndSettle();
        expect(find.text('Fragile - Handle with care!'), findsOneWidget);
        expect(find.text('I Got It'), findsOneWidget);

        // Tap ownTodayId -> collapses p1 and expands ownTodayId (single-expanded accordion)
        await tester.tap(find.byKey(ValueKey('parcel_card_header_$ownTodayId')));
        await tester.pumpAndSettle();
        expect(find.text('Fragile - Handle with care!'), findsNothing);
        expect(find.text('Second Today parcel notes'), findsOneWidget);
        expect(find.byKey(ValueKey('parcel_delete_btn_$ownTodayId')), findsOneWidget);
        expect(find.byKey(ValueKey('parcel_edit_btn_$ownTodayId')), findsOneWidget);

        // Tap again -> collapses smoothly
        await tester.tap(find.byKey(ValueKey('parcel_card_header_$ownTodayId')));
        await tester.pumpAndSettle();
        expect(find.text('Second Today parcel notes'), findsNothing);

        // Open AddParcelSheet -> courier dropdown shows PNG logo
        await tester.tap(find.text('Add parcel'));
        await tester.pumpAndSettle();
        expect(find.text('Add Expected Parcel'), findsOneWidget);
        expect(find.byType(CasamaCourierLogo), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ParcelsBoardView shows Scheduled Today, Scheduled Yesterday + My Parcels helper without overflow at 360px',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          final repo = MockRepository()..login();
          final now = DateTime.now();
          repo.addParcel(
            courier: 'LBC',
            arrival: now.subtract(const Duration(days: 1)),
            paymentType: ParcelPaymentType.cod,
            codAmount: 450,
            notes: 'Past due parcel',
          );
          repo.addParcel(
            courier: 'SPX',
            arrival: now,
            paymentType: ParcelPaymentType.paid,
            notes: 'Today parcel',
          );

          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('parcel_copy_${mode.name}'),
              overrides: [repositoryProvider.overrideWith((ref) => repo)],
              child: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 800),
                  disableAnimations: true,
                ),
                child: MaterialApp(
                  theme: CasamaTheme.lightTheme,
                  darkTheme: CasamaTheme.darkTheme,
                  themeMode: mode,
                  home: const Scaffold(body: ParcelsBoardView(bottomPadding: 24)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Scheduled Today'), findsWidgets);
          expect(find.text('Scheduled Yesterday'), findsOneWidget);
          expect(find.text('Arriving Now'), findsNothing);

          await tester.tap(find.text('My Parcels'));
          await tester.pumpAndSettle();
          expect(find.text('Scheduled Yesterday'), findsOneWidget);
          expect(find.text('Expand to edit or delete listing'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
