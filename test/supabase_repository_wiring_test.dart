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
      expect(repo.userHouseholds, isEmpty);
    });

    test('Household model supports displaySubtitle, copyWith, and optional JSON fields', () {
      final hh = Household.fromJson({
        'id': 'hh-1',
        'name': 'TeenTitans',
        'invite_code': 'SYZKB2',
        'created_by': 'u-1',
        'member_count': 3,
      });
      expect(hh.displaySubtitle, 'Community Space');
      expect(hh.memberCount, 3);

      final updated = hh.copyWith(spaceType: 'Dorm Suite', memberCount: 5);
      expect(updated.displaySubtitle, 'Dorm Suite');
      expect(updated.memberCount, 5);
      expect(updated.toJson().containsKey('member_count'), isFalse);
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
        caption: 'Balcony view',
        createdAt: DateTime.utc(2026, 11, 26),
      );
      final snapJson = snap.toJson();
      expect(
        snapJson.keys.toSet(),
        {'id', 'household_id', 'creator_id', 'creator_name', 'image_url', 'caption', 'created_at'},
      );
      expect(snapJson.containsKey('recipient_type'), isFalse);
      expect(snapJson.containsKey('creator_avatar'), isFalse);
      expect(snapJson.containsKey('expires_at'), isFalse);
      expect(snapJson['creator_name'], 'JP');

      final parsedSnap = QuickSnap.fromJson({
        ...snapJson,
        'quick_snap_reactions': [
          {
            'emoji': '🔥',
            'user_id': 'u2',
            'user_name': 'Maria',
            'count': 3,
            'created_at': '2026-11-26T00:00:00Z',
            'updated_at': '2026-11-26T00:02:00Z',
          },
          {
            'emoji': '❤️',
            'user_id': 'u3',
            'user_name': 'Leo',
            'created_at': '2026-11-26T00:01:00Z',
          },
        ],
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
      expect(parsedSnap.creatorId, 'u1');
      expect(parsedSnap.creatorName, 'JP');
      expect(parsedSnap.totalReactionCount, 4);
      expect(parsedSnap.reactions.first.count, 3);
      expect(parsedSnap.reactions.first.updatedAt, isNotNull);
      expect(parsedSnap.reactions.last.count, 1);
      expect(parsedSnap.comments.first.text, 'Nice shot!');
      expect(kCasSnapReactionEmojis, ['❤️', '😂', '😍', '🔥', '👍', '👎']);

      expect(CasamaCouriers.defaultCourier, 'J&T Express');
      expect(CasamaCouriers.options, [
        'J&T Express',
        'Flash Express',
        'Ninja Van',
        'LBC',
        '2GO Express',
        'Lalamove',
        'SPX',
        'Other',
      ]);

      final paidParcel = ParcelItem(
        id: 'p1',
        householdId: 'h1',
        buyerId: 'u1',
        buyerName: 'JP',
        courier: 'J&T Express',
        expectedArrival: DateTime(2026, 11, 26),
        paymentType: ParcelPaymentType.paid,
        codAmount: 350,
        status: ParcelStatus.expected,
      );
      expect(paidParcel.toJson()['cod_amount'], isNull);

      final openLostItem = LostFoundItem.fromJson({
        'id': 'l1',
        'household_id': 'h1',
        'title': 'Keys',
        'last_seen_location': 'Kitchen',
        'status': 'open',
        'owner_id': 'u1',
        'resolved_found_item_id': 'f_win',
        'created_at': '2026-11-26T00:00:00Z',
      }, forcedType: ItemType.lost);
      expect(openLostItem.status, ItemStatus.open);
      expect(openLostItem.ownerId, 'u1');
      expect(openLostItem.location, 'Kitchen');
      expect(openLostItem.resolvedFoundItemId, 'f_win');
      final lostJson = openLostItem.toJson();
      expect(lostJson.containsKey('reported_by'), isFalse);
      expect(lostJson['owner_id'], 'u1');
      expect(lostJson['last_seen_location'], 'Kitchen');
      expect(lostJson['resolved_found_item_id'], 'f_win');
      expect(lostJson['status'], 'open');

      final resolvedLostItem = LostFoundItem.fromJson({
        'id': 'l2',
        'household_id': 'h1',
        'title': 'Wallet',
        'last_seen_location': 'Sofa',
        'status': 'resolved',
        'owner_id': 'u1',
        'found_by_id': 'u2',
        'resolved_found_item_id': 'f2',
        'created_at': '2026-11-26T00:00:00Z',
      }, forcedType: ItemType.lost);
      expect(resolvedLostItem.status, ItemStatus.resolved);
      expect(resolvedLostItem.isResolved, isTrue);
      expect(resolvedLostItem.foundById, 'u2');

      final standaloneFound = LostFoundItem.fromJson({
        'id': 'f1',
        'household_id': 'h1',
        'title': 'Umbrella',
        'found_location': 'Lobby',
        'status': 'unclaimed',
        'finder_id': 'u2',
        'created_at': '2026-11-26T00:00:00Z',
      }, forcedType: ItemType.found);
      expect(standaloneFound.finderId, 'u2');
      expect(standaloneFound.isStandalone, isTrue);
      expect(standaloneFound.isLinkedToLost, isFalse);
      expect(standaloneFound.location, 'Lobby');
      final foundJson = standaloneFound.toJson();
      expect(foundJson.containsKey('reported_by'), isFalse);
      expect(foundJson['finder_id'], 'u2');
      expect(foundJson['found_location'], 'Lobby');
      expect(foundJson['lost_item_id'], isNull);

      final localTime = DateTime(2026, 11, 27, 19, 0);
      final meetup = MeetUpInvitation(
        id: 'mu-1',
        activity: 'Movie Night',
        location: 'Living Room',
        scheduledTime: localTime,
      );
      final meetupJson = meetup.toJson(conversationId: 'conv-1', creatorId: 'u1');
      expect(meetupJson['status'], 'active');
      expect(meetupJson['reminder_sent'], isFalse);
      expect(meetupJson['arrival_handled'], isFalse);
      expect((meetupJson['scheduled_time'] as String).endsWith('Z'), isTrue);

      final parsedMeetup = MeetUpInvitation.fromJson({
        ...meetupJson,
        'creator_id': 'u1',
        'status': 'done',
        'reminder_sent': true,
        'arrival_handled': true,
      });
      expect(parsedMeetup.creatorId, 'u1');
      expect(parsedMeetup.isActive, isFalse);
      expect(parsedMeetup.isDone, isTrue);
      expect(parsedMeetup.reminderSent, isTrue);
      expect(parsedMeetup.arrivalHandled, isTrue);
      expect(parsedMeetup.scheduledTime.isUtc, isFalse);
      expect(parsedMeetup.scheduledTime.toUtc(), localTime.toUtc());

      final reminderNotif = HouseholdNotificationItem(
        id: 'n-rem-1',
        type: 'meetup_reminder',
        title: '',
        subtitle: '',
        createdAt: DateTime.now(),
        isRead: false,
        payload: const {
          'title': 'Movie Night',
          'location': 'Living Room',
        },
      );
      expect(reminderNotif.displayTitle, 'Meet-up Reminder: Movie Night');
      expect(reminderNotif.displaySubtitle, 'Starting soon at Living Room');

      final rejectedLinkedFind = LostFoundItem.fromJson({
        'id': 'f2',
        'household_id': 'h1',
        'title': 'Keys',
        'found_location': 'Balcony',
        'lost_item_id': 'l1',
        'status': 'rejected',
        'finder_id': 'u2',
        'rejected_at': '2026-11-26T02:00:00Z',
        'created_at': '2026-11-26T01:00:00Z',
      }, forcedType: ItemType.found);
      expect(rejectedLinkedFind.isLinkedToLost, isTrue);
      expect(rejectedLinkedFind.isStandalone, isFalse);
      expect(rejectedLinkedFind.status, ItemStatus.rejected);
      expect(rejectedLinkedFind.rejectedAt, isNotNull);
      final linkedJson = rejectedLinkedFind.toJson();
      expect(linkedJson['lost_item_id'], 'l1');
      expect(linkedJson['rejected_at'], isNotNull);
      expect(linkedJson['status'], 'rejected');

      final task = MaintenanceTask.fromJson({
        'id': 't1',
        'household_id': 'h1',
        'title': 'Clean Sink',
        'category': 'cleaning',
        'urgency': 'medium',
        'status': 'done',
        'created_by': 'u2',
        'created_by_name': 'Maria',
        'completed_by': 'u1',
        'completed_by_name': 'JP',
        'completed_at': '2026-11-26T10:00:00Z',
        'created_at': '2026-11-26T08:00:00Z',
        'due_date': '2026-11-27T08:00:00Z',
      });
      expect(task.createdBy, 'u2');
      expect(task.createdByName, 'Maria');
      expect(task.computedPoints, 9);
      expect(task.completedById, 'u1');
      expect(task.completedByName, 'JP');
      expect(task.completedAt, isNotNull);
      expect(task.dueDate, isNotNull);
      final taskJson = task.toJson();
      expect(taskJson.containsKey('assignee_id'), isFalse);
      expect(taskJson['created_by'], 'u2');
      expect(taskJson['completed_by'], 'u1');
      expect(taskJson['completed_at'], isNotNull);

      final chatMsg = ChatMessage(
        id: 'm1',
        senderId: 'u1',
        senderName: 'JP',
        content: 'Hello!',
        inviteCode: 'SYZKB2',
        inviteSpaceName: 'TeenTitans',
        createdAt: DateTime(2026, 11, 26),
        isCurrentUser: true,
      );
      final chatJson = chatMsg.toJson();
      expect(chatJson.containsKey('invite_code'), isFalse);
      expect(chatJson.containsKey('invite_space_name'), isFalse);
      expect(chatJson.containsKey('media_url'), isFalse);
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
