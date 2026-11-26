import 'package:casama/core/theme/app_theme.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/data/repository_provider.dart';
import 'package:casama/data/supabase_repository.dart';
import 'package:casama/features/auth/auth_screen.dart';
import 'package:casama/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _UnverifiedAuthMockRepository extends MockRepository {
  bool throwRateLimitOnResend = false;
  final List<String> resentEmails = [];

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw const AuthException(
      'Email not confirmed',
      code: 'email_not_confirmed',
    );
  }

  @override
  Future<void> resendSignupVerificationEmail(String email) async {
    if (throwRateLimitOnResend) {
      throw const AuthException(
        'For security purposes, you can only request this after 60 seconds.',
        code: 'over_email_send_rate_limit',
        statusCode: '429',
      );
    }
    resentEmails.add(email);
  }
}

void main() {
  group('SupabaseRepository Wiring & Schema Parity Tests', () {
    test('default repositoryProvider resolves to SupabaseRepository (never MockRepository)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(repositoryProvider);
      expect(repo, isA<SupabaseRepository>());
      expect(repo.isAuthenticated, isFalse);
      expect(repo.hasActiveHousehold, isFalse);
    });

    test('resolveStartupRoute routes authenticated users cleanly by household membership', () {
      expect(
        resolveStartupRoute(isAuthenticated: false, hasActiveHousehold: false),
        '/',
      );
      expect(
        resolveStartupRoute(isAuthenticated: true, hasActiveHousehold: false),
        '/household-setup',
      );
      expect(
        resolveStartupRoute(isAuthenticated: true, hasActiveHousehold: true),
        '/dashboard',
      );
    });

    test('TaskCategory dbValue maps all 4 UI categories accurately', () {
      expect(TaskCategory.cleaning.dbValue, 'cleaning');
      expect(TaskCategory.repairMaintenance.dbValue, 'repair_maintenance');
      expect(TaskCategory.restock.dbValue, 'restock');
      expect(TaskCategory.personalRequest.dbValue, 'personal_request');

      expect(
        TaskCategoryDbX.fromDbValue('repair_maintenance'),
        TaskCategory.repairMaintenance,
      );
      expect(
        TaskCategoryDbX.fromDbValue('personal_request'),
        TaskCategory.personalRequest,
      );
    });

    test('HouseholdBill serializes live bills columns and parses responses', () {
      final bill = HouseholdBill(
        id: '11111111-1111-1111-1111-111111111111',
        householdId: '22222222-2222-2222-2222-222222222222',
        creatorId: '33333333-3333-3333-3333-333333333333',
        creatorName: 'JP',
        category: BillCategory.other,
        customCategoryLabel: 'Parking',
        billName: 'Basement Parking',
        amount: 1200,
        deadline: DateTime(2026, 12, 1),
        reminderEnabled: true,
        reminderTiming: ReminderTiming.threeDaysBefore,
        recipientType: BillRecipientType.selectedMembers,
        createdAt: DateTime(2026, 11, 20),
      );

      final json = bill.toSupabaseJson();
      expect(json['title'], 'Basement Parking');
      expect(json['custom_category_name'], 'Parking');
      expect(json['reminder_enabled'], isTrue);
      expect(json['reminder_timing'], 'three_days_before');
      expect(json['recipient_type'], 'specific_members');
      expect(json['created_by_name'], 'JP');

      final parsed = HouseholdBill.fromJson(json);
      expect(parsed.billName, 'Basement Parking');
      expect(parsed.customCategoryLabel, 'Parking');
      expect(parsed.reminderTiming, ReminderTiming.threeDaysBefore);
      expect(parsed.recipientType, BillRecipientType.selectedMembers);
      expect(parsed.creatorName, 'JP');
    });

    test('QuickSnap & ParcelItem & LostFoundItem match live schema JSON contracts', () {
      final snap = QuickSnap(
        id: 's1',
        householdId: 'h1',
        senderId: 'u1',
        senderName: 'JP',
        imageUrl: 'https://example.supabase.co/storage/v1/object/public/casnaps/a.jpg',
        recipientType: QuickSnapRecipientType.selectedHousemates,
        createdAt: DateTime(2026, 11, 26),
      );
      final snapJson = snap.toJson();
      expect(snapJson['recipient_type'], 'selected_friends');
      expect(snapJson['creator_name'], 'JP');

      final parsedSnap = QuickSnap.fromJson({
        ...snapJson,
        'quick_snap_comments': [
          {
            'id': 'c1',
            'user_id': 'u2',
            'user_name': 'Maria',
            'message': 'Nice shot!',
            'created_at': '2026-11-26T00:00:00Z',
          },
        ],
      });
      expect(parsedSnap.recipientType, QuickSnapRecipientType.selectedHousemates);
      expect(parsedSnap.comments.first.text, 'Nice shot!');

      final paidParcel = ParcelItem(
        id: 'p1',
        householdId: 'h1',
        buyerId: 'u1',
        buyerName: 'JP',
        courier: 'Shopee',
        expectedArrival: DateTime(2026, 11, 26),
        paymentType: ParcelPaymentType.paid,
        codAmount: 350,
        status: ParcelStatus.expected,
      );
      expect(paidParcel.toJson()['cod_amount'], isNull);

      final foundLostItem = LostFoundItem.fromJson({
        'id': 'l1',
        'household_id': 'h1',
        'title': 'Keys',
        'status': 'found',
        'reported_by': 'u1',
        'found_by_id': 'u2',
        'created_at': '2026-11-26T00:00:00Z',
      }, forcedType: ItemType.lost);
      expect(foundLostItem.status, ItemStatus.found);
      expect(foundLostItem.foundById, 'u2');
    });

    testWidgets(
      'AuthScreen One-Tap Demo Login without configured credentials shows error toast and stays on AuthScreen',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const AuthScreen(initialTabIndex: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('One-Tap Demo Login'), findsOneWidget);
        await tester.ensureVisible(find.text('One-Tap Demo Login'));
        await tester.tap(find.text('One-Tap Demo Login'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Demo login is not configured'), findsOneWidget);
        expect(find.text('Welcome back'), findsOneWidget);
      },
    );

    testWidgets(
      'AuthScreen reveals Resend Verification Email on email_not_confirmed, enforces 60s cooldown, handles rate limits, and hides when email cleared',
      (tester) async {
        final mockRepo = _UnverifiedAuthMockRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [repositoryProvider.overrideWith((ref) => mockRepo)],
            child: MaterialApp(
              theme: CasamaTheme.lightTheme,
              home: const AuthScreen(initialTabIndex: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hidden by default
        expect(find.text('Resend Verification Email'), findsNothing);

        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'unverified@casama.app');
        await tester.enterText(fields.at(1), 'password123');
        await tester.ensureVisible(find.text('Log In').last);
        await tester.tap(find.text('Log In').last);
        await tester.pumpAndSettle();

        expect(find.text('Resend Verification Email'), findsOneWidget);
        expect(
          find.textContaining('Your email is not verified yet'),
          findsWidgets,
        );

        // Resend succeeds -> 60s cooldown starts
        await tester.ensureVisible(find.text('Resend Verification Email'));
        await tester.tap(find.text('Resend Verification Email'));
        await tester.pump();
        expect(mockRepo.resentEmails, ['unverified@casama.app']);
        expect(find.text('Resend available in 60s'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Resend available in 59s'), findsOneWidget);

        // Clearing the email field hides the resend prompt
        await tester.enterText(fields.at(0), '');
        await tester.pumpAndSettle();
        expect(find.text('Resend available in 59s'), findsNothing);
        expect(find.text('Resend Verification Email'), findsNothing);

        // Trigger unverified prompt again and test rate-limit error handling
        mockRepo.throwRateLimitOnResend = true;
        await tester.pump(const Duration(seconds: 60));
        await tester.enterText(fields.at(0), 'unverified@casama.app');
        await tester.ensureVisible(find.text('Log In').last);
        await tester.tap(find.text('Log In').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Resend Verification Email'));
        await tester.tap(find.text('Resend Verification Email'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Too many verification emails requested'),
          findsOneWidget,
        );
      },
    );
  });
}
