import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/features/parcels/parcels_screen.dart';
import 'package:casama/features/parcels/widgets/add_parcel_sheet.dart';
import 'package:casama/shared/widgets/casama_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Parcels & Deliveries Refactor', () {
    test('isParcelArrivalInPast blocks strictly past minutes and allows current/future minutes', () {
      final now = DateTime(2026, 11, 27, 15, 30, 45);
      expect(
        isParcelArrivalInPast(DateTime(2026, 11, 27, 15, 29), now: now),
        isTrue,
      );
      expect(
        isParcelArrivalInPast(DateTime(2026, 11, 26, 23, 59), now: now),
        isTrue,
      );
      expect(
        isParcelArrivalInPast(DateTime(2026, 11, 27, 15, 30), now: now),
        isFalse,
      );
      expect(
        isParcelArrivalInPast(DateTime(2026, 11, 27, 15, 31), now: now),
        isFalse,
      );
    });

    test('ParcelItem.toJson omits legacy parcel_availability fields', () {
      final parcel = ParcelItem(
        id: 'p-json',
        householdId: 'h1',
        buyerId: 'u1',
        buyerName: 'JP',
        courier: 'J&T Express',
        expectedArrival: DateTime(2026, 11, 28, 12, 0),
        paymentType: ParcelPaymentType.paid,
        status: ParcelStatus.expected,
      );
      final json = parcel.toJson();
      expect(json.containsKey('available_members'), isFalse);
      expect(json.containsKey('is_all_unavailable'), isFalse);
    });

    testWidgets(
      'Claiming awards 0 pts with delayed-points toast; settling awards +5 pts to receiver; self-claim awards 0 pts',
      (tester) async {
        final repo = MockRepository()..login();
        const mariaId = '22222222-2222-2222-2222-222222222222';
        final jpId = repo.currentUser.id;
        final initialJpPoints = repo.kasamaPoints;
        final initialMariaPoints = repo.pointsForUser(mariaId);

        // 1. JP expands and claims Maria's parcel ('p1') -> 0 pts immediately, delayed toast, no celebration modal
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
                home: const ParcelsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('parcel_card_header_p1')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('I Got It').first);
        await tester.pumpAndSettle();

        expect(find.text('+5 Good Kasama Points!'), findsNothing);
        expect(
          find.text(
            "Parcel claimed! You'll earn +5 pts once the owner marks it settled.",
          ),
          findsOneWidget,
        );
        expect(repo.kasamaPoints, initialJpPoints);

        // 2. Switch to Maria (creator), expand p1, and tap Mark Settled -> JP (receiver) gets +5 pts
        repo.setCurrentUserForTest(mariaId);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('parcel_card_header_p1')));
        await tester.pumpAndSettle();

        expect(find.text('Mark Settled'), findsOneWidget);
        await tester.tap(find.text('Mark Settled'));
        await tester.pumpAndSettle();

        expect(repo.pointsForUser(jpId), initialJpPoints + 5);
        expect(repo.pointsForUser(mariaId), initialMariaPoints);

        // 3. Maria posts her own parcel, expands it, and claims it -> 0 pts, self-claim toast
        repo.addParcel(
          courier: 'SPX',
          arrival: DateTime.now(),
          paymentType: ParcelPaymentType.paid,
          notes: 'Maria own parcel',
        );
        final mariaParcelId = repo.parcels.first.id;
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(ValueKey('parcel_card_header_$mariaParcelId')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('I Got It').first);
        await tester.pumpAndSettle();
        expect(find.text('Parcel marked as received.'), findsOneWidget);
        expect(repo.pointsForUser(mariaId), initialMariaPoints);
      },
    );

    testWidgets(
      '4-subtab layout, local-date filtering, Mark Settled visibility across My Parcels/Today/Upcoming, and zero Mark Unavailable on 360px Dark & Light',
      (tester) async {
        for (final mode in [ThemeMode.light, ThemeMode.dark]) {
          tester.view.physicalSize = const Size(360, 800);
          tester.view.devicePixelRatio = 1.0;

          final repo = MockRepository()..login();
          final jpId = repo.currentUser.id;
          const mariaId = '22222222-2222-2222-2222-222222222222';
          final now = DateTime.now();

          // Overdue creator parcel -> Today & My Parcels
          repo.addParcel(
            courier: 'LBC',
            arrival: now.subtract(const Duration(days: 1)),
            paymentType: ParcelPaymentType.paid,
            notes: 'Overdue parcel',
          );
          final overdueId = repo.parcels.first.id;

          // Future creator parcel -> Upcoming & My Parcels, claimed by Maria (unsettled)
          repo.addParcel(
            courier: 'Lalamove',
            arrival: now.add(const Duration(days: 2)),
            paymentType: ParcelPaymentType.cod,
            codAmount: 180,
            notes: 'Future claimed parcel',
          );
          final futureClaimedId = repo.parcels.first.id;
          repo.setCurrentUserForTest(mariaId);
          repo.receiveParcel(futureClaimedId);
          repo.setCurrentUserForTest(jpId);

          await tester.pumpWidget(
            ProviderScope(
              key: ValueKey('parcels_tabs_${mode.name}'),
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
                  home: const ParcelsScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 4 segments exist with no overflow
          expect(find.text('My Parcels'), findsOneWidget);
          expect(find.text('Today'), findsOneWidget);
          expect(find.text('Upcoming'), findsOneWidget);
          expect(find.text('History'), findsOneWidget);
          expect(find.text('Mark Unavailable'), findsNothing);

          // Today tab shows LBC (overdue) and does not show Lalamove (future)
          expect(find.text('LBC'), findsOneWidget);
          expect(find.text('Lalamove'), findsNothing);
          await tester.tap(find.byKey(ValueKey('parcel_card_header_$overdueId')));
          await tester.pumpAndSettle();
          expect(find.text('Overdue parcel'), findsOneWidget);

          // Upcoming tab shows future claimed parcel with Mark Settled for creator when expanded
          await tester.tap(find.text('Upcoming'));
          await tester.pumpAndSettle();
          expect(find.text('Mark Unavailable'), findsNothing);
          expect(find.text('Lalamove'), findsOneWidget);
          await tester.tap(
            find.byKey(ValueKey('parcel_card_header_$futureClaimedId')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Future claimed parcel'), findsOneWidget);
          expect(find.text('Unsettled'), findsWidgets);
          expect(find.text('Mark Settled'), findsOneWidget);
          expect(
            find.bySemanticsLabel(RegExp('Claimed by Maria')),
            findsOneWidget,
          );

          // Non-creator viewer sees 'Claimed by ... • Unsettled' and NOT Mark Settled
          repo.setCurrentUserForTest(mariaId);
          await tester.pumpAndSettle();
          expect(find.text('Mark Settled'), findsNothing);
          expect(
            find.bySemanticsLabel(RegExp('Claimed by You • Unsettled')),
            findsOneWidget,
          );

          // Creator sees Mark Settled in My Parcels too
          repo.setCurrentUserForTest(jpId);
          await tester.pumpAndSettle();
          await tester.tap(find.text('My Parcels'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(ValueKey('parcel_card_header_$futureClaimedId')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Future claimed parcel'), findsOneWidget);
          expect(find.text('Mark Settled'), findsOneWidget);

          expect(tester.takeException(), isNull);
        }
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );

    testWidgets(
      'Creator can edit unclaimed Today/Upcoming parcel and past date/time is blocked on Add & Edit',
      (tester) async {
        final repo = MockRepository()..login();
        final now = DateTime.now();
        repo.addParcel(
          courier: 'SPX',
          arrival: now.add(const Duration(days: 1)),
          paymentType: ParcelPaymentType.paid,
          notes: 'Original notes',
        );
        final createdId = repo.parcels.first.id;

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
                home: const ParcelsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Go to Upcoming, expand card, and tap Edit
        await tester.tap(find.text('Upcoming'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('parcel_card_header_$createdId')));
        await tester.pumpAndSettle();

        final editBtn = find.byKey(ValueKey('parcel_edit_btn_$createdId'));
        expect(editBtn, findsOneWidget);

        await tester.tap(editBtn);
        await tester.pumpAndSettle();
        expect(find.text('Edit Parcel'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Original notes'), findsOneWidget);

        // Update notes and save
        await tester.enterText(
          find.widgetWithText(TextField, 'Original notes'),
          'Updated guard instructions',
        );
        await tester.tap(find.byKey(const Key('parcel_save_button')));
        await tester.pumpAndSettle();

        expect(
          repo.parcels.firstWhere((p) => p.id == createdId).notes,
          'Updated guard instructions',
        );
        expect(find.text('Updated guard instructions'), findsOneWidget);

        // Verify Edit Mode blocks an already-past expectedArrival
        final pastParcel = ParcelItem(
          id: 'p-past',
          householdId: repo.currentHousehold.id,
          buyerId: repo.currentUser.id,
          buyerName: repo.currentUser.preferredName,
          courier: 'LBC',
          expectedArrival: DateTime(2026, 11, 27, 10, 0),
          paymentType: ParcelPaymentType.paid,
          status: ParcelStatus.expected,
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
                home: Builder(
                  builder: (ctx) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => showAddParcelSheet(
                        ctx,
                        existingParcel: pastParcel,
                        nowProvider: () => DateTime(2026, 11, 27, 15, 0),
                      ),
                      child: const Text('Open Past Edit'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Past Edit'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('parcel_datetime_error')), findsOneWidget);
        expect(
          find.text('Please choose a date and time from now onward.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Creator-only bottom-left Delete icon works across Today, Upcoming, Unsettled, and History cards',
      (tester) async {
        final repo = MockRepository()..login();
        final now = DateTime.now();

        // 1. Unclaimed Today parcel by JP
        repo.addParcel(
          courier: 'LBC',
          arrival: now,
          paymentType: ParcelPaymentType.paid,
          notes: 'Delete today',
        );
        final todayId = repo.parcels.first.id;

        // 2. Settled History parcel by JP
        repo.addParcel(
          courier: 'SPX',
          arrival: now,
          paymentType: ParcelPaymentType.paid,
          notes: 'Delete history',
        );
        final historyId = repo.parcels.first.id;
        repo.receiveParcel(historyId);

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
                home: const ParcelsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expanding non-creator ('p1' by Maria) must NOT show delete icon
        await tester.tap(find.byKey(const ValueKey('parcel_card_header_p1')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('parcel_delete_btn_p1')), findsNothing);

        // Expanding JP's parcel shows 48x48 delete icon
        await tester.tap(find.byKey(ValueKey('parcel_card_header_$todayId')));
        await tester.pumpAndSettle();
        final deleteTodayBtn = find.byKey(ValueKey('parcel_delete_btn_$todayId'));
        expect(deleteTodayBtn, findsOneWidget);
        expect(tester.getSize(deleteTodayBtn).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(deleteTodayBtn).height, greaterThanOrEqualTo(48));

        // Delete Today parcel via confirmation dialog
        await tester.ensureVisible(deleteTodayBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteTodayBtn);
        await tester.pumpAndSettle();
        expect(find.text('Delete parcel?'), findsOneWidget);
        await tester.tap(find.byKey(const Key('parcel_confirm_delete_button')));
        await tester.pumpAndSettle();
        expect(repo.parcels.any((p) => p.id == todayId), isFalse);

        // Switch to History, expand, and delete settled parcel
        await tester.ensureVisible(find.text('History'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('parcel_card_header_$historyId')));
        await tester.pumpAndSettle();
        final deleteHistoryBtn = find.byKey(ValueKey('parcel_delete_btn_$historyId'));
        expect(deleteHistoryBtn, findsOneWidget);
        await tester.ensureVisible(deleteHistoryBtn);
        await tester.pumpAndSettle();
        await tester.tap(deleteHistoryBtn);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('parcel_confirm_delete_button')));
        await tester.pumpAndSettle();
        expect(repo.parcels.any((p) => p.id == historyId), isFalse);
      },
    );

    testWidgets(
      'Poster attribution renders inline CasamaAvatar with For [avatar] You / <username> without overflow at 360px',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = MockRepository()..login();
        repo.addParcel(
          courier: '2GO Express',
          arrival: DateTime.now(),
          paymentType: ParcelPaymentType.cod,
          codAmount: 550,
          notes: 'Avatar test own parcel',
        );
        final ownId = repo.parcels.first.id;

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
                home: const ParcelsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(ValueKey('parcel_poster_avatar_$ownId')), findsOneWidget);
        expect(find.byKey(const ValueKey('parcel_poster_avatar_p1')), findsOneWidget);
        expect(find.byType(CasamaAvatar), findsWidgets);
        expect(
          find.bySemanticsLabel(RegExp('For You')),
          findsWidgets,
        );
        expect(
          find.bySemanticsLabel(RegExp('For Maria')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
