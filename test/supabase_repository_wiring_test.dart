import 'package:casama/core/router/app_router.dart';
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
      final agenda = HousematesAgendaInvitation(
        id: 'ha-1',
        activity: 'Movie Night',
        location: 'Living Room',
        scheduledTime: localTime,
      );
      final agendaJson = agenda.toJson(conversationId: 'conv-1', creatorId: 'u1');
      expect(agendaJson['status'], 'upcoming');
      expect(agendaJson['reminder_sent'], isFalse);
      expect(agendaJson['arrival_handled'], isFalse);
      expect((agendaJson['scheduled_time'] as String).endsWith('Z'), isTrue);

      final normalizedPastActive = HousematesAgendaInvitation.fromJson({
        ...agendaJson,
        'scheduled_time': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        'status': 'active',
      });
      expect(normalizedPastActive.status, 'ongoing');
      expect(normalizedPastActive.isOngoing, isTrue);
      expect(normalizedPastActive.isActive, isTrue);

      final parsedAgenda = HousematesAgendaInvitation.fromJson({
        ...agendaJson,
        'creator_id': 'u1',
        'status': 'done',
        'reminder_sent': true,
        'arrival_handled': true,
      });
      expect(parsedAgenda.creatorId, 'u1');
      expect(parsedAgenda.isActive, isFalse);
      expect(parsedAgenda.isHistory, isTrue);
      expect(parsedAgenda.isDone, isTrue);
      expect(parsedAgenda.isMissed, isFalse);

      final missedAgenda = parsedAgenda.copyWith(status: 'missed');
      expect(missedAgenda.isMissed, isTrue);
      expect(missedAgenda.isHistory, isTrue);
      expect(missedAgenda.isActive, isFalse);
      expect(parsedAgenda.reminderSent, isTrue);
      expect(parsedAgenda.arrivalHandled, isTrue);
      expect(parsedAgenda.scheduledTime.isUtc, isFalse);
      expect(parsedAgenda.scheduledTime.toUtc(), localTime.toUtc());

      final reminderNotif = HouseholdNotificationItem(
        id: 'n-rem-1',
        type: 'housemates_agenda_reminder',
        title: '',
        subtitle: '',
        createdAt: DateTime.now(),
        isRead: false,
        payload: const {
          'title': 'Movie Night',
          'location': 'Living Room',
        },
      );
      expect(reminderNotif.displayTitle, 'Agenda Reminder: Movie Night');
      expect(reminderNotif.displaySubtitle, 'Starting soon — Living Room');

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
      expect(task.totalRewardPoints(), 9);
      expect(task.completedById, 'u1');
      expect(task.completedByName, 'JP');
      expect(task.completedAt, isNotNull);
      expect(task.dueDate, isNotNull);
      final taskJson = task.toJson();
      expect(taskJson.containsKey('assignee_id'), isFalse);
      expect(taskJson['created_by'], 'u2');
      expect(taskJson['completed_by'], 'u1');
      expect(taskJson['completed_at'], isNotNull);

      final rouletteRecord = ChoreRouletteRecord.fromJson({
        'id': 'r1',
        'household_id': 'h1',
        'task_id': 't1',
        'chore_title': 'Clean Sink',
        'selected_user_id': 'u2',
        'selected_user_name': 'Maria',
        'spun_by_user_id': 'u1',
        'spun_by_name': 'JP',
        'status': 'assigned',
        'bonus_points': 4,
        'created_at': '2026-11-26T08:00:00Z',
        'completed_at': null,
      });
      expect(rouletteRecord.isAssigned, isTrue);
      expect(rouletteRecord.isCompleted, isFalse);
      expect(rouletteRecord.bonusPoints, 4);
      expect(task.totalRewardPoints(rouletteRecord: rouletteRecord), 13);
      final defaultBonusRecord = ChoreRouletteRecord.fromJson({
        'id': 'r2',
        'household_id': 'h1',
        'created_at': '2026-11-26T08:00:00Z',
      });
      expect(defaultBonusRecord.bonusPoints, 4);
      final rouletteJson = rouletteRecord.toJson();
      expect(rouletteJson['task_id'], 't1');
      expect(rouletteJson['selected_user_id'], 'u2');
      expect(rouletteJson['spun_by_user_id'], 'u1');
      expect(rouletteJson['bonus_points'], 4);
      expect(rouletteJson.containsKey('decision'), isFalse);
      expect(rouletteJson.containsKey('expires_at'), isFalse);
      expect(rouletteJson.containsKey('responded_at'), isFalse);

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

    test(
      'SupabaseRepository.parseNotificationRow & applyNotificationRealtimeDelete handle all domains and Realtime deletes',
      () {
        final rows = [
          {
            'id': 'n_p_arrived',
            'type': 'parcel_arrived',
            'created_at': '2026-11-26T15:30:00Z',
            'read_at': null,
            'payload': {
              'entity_type': 'parcel',
              'entity_id': 'p1',
              'parcel_id': 'p1',
              'actor_id': 'u2',
              'title': '📦 J&T Express is arriving now!',
              'message': 'Waiting at the gate for Maria.',
            },
          },
          {
            'id': 'n_t_overdue',
            'type': 'task_overdue',
            'created_at': '2026-11-26T15:31:00Z',
            'read_at': null,
            'payload': {
              'entity_type': 'task',
              'entity_id': 't1',
              'task_id': 't1',
              'title': '⏰ Overdue: Leaking Faucet',
              'message': 'Needs attention soon.',
            },
          },
          {
            'id': 'n_lf_found',
            'type': 'found_item_claimed',
            'created_at': '2026-11-26T15:32:00Z',
            'read_at': '2026-11-26T15:40:00Z',
            'payload': {
              'entity_type': 'found_item',
              'entity_id': 'i2',
              'found_item_id': 'i2',
              'points': 2,
              'title': 'Found Backpack claimed!',
              'message': 'You earned +2 pts.',
            },
          },
          {
            'id': 'n_ag_started',
            'type': 'housemates_agenda_started',
            'created_at': '2026-11-26T15:33:00Z',
            'read_at': null,
            'payload': {
              'entity_type': 'housemates_agenda',
              'entity_id': 'm1',
              'invitation_id': 'm1',
              'title': '🎉 Study Session is starting now!',
              'message': 'Meet in Dorm Common Area.',
            },
          },
        ];

        final parsed = rows.map(SupabaseRepository.parseNotificationRow).toList();
        expect(parsed.every((n) => n.isSupportedNotification), isTrue);
        expect(parsed[0].domain, NotificationDomain.parcels);
        expect(parsed[0].displayTitle, '📦 J&T Express is arriving now!');
        expect(parsed[0].isUnread, isTrue);
        expect(parsed[1].domain, NotificationDomain.tasks);
        expect(parsed[2].domain, NotificationDomain.lostFound);
        expect(parsed[2].isUnread, isFalse);
        expect(parsed[2].earnedPoints, 2);
        expect(parsed[3].domain, NotificationDomain.agenda);

        final afterDelete = SupabaseRepository.applyNotificationRealtimeDelete(
          parsed,
          {'id': 'n_t_overdue'},
        );
        expect(afterDelete.length, 3);
        expect(afterDelete.any((n) => n.id == 'n_t_overdue'), isFalse);

        // Unmatched or empty oldRecord leaves list untouched
        expect(
          SupabaseRepository.applyNotificationRealtimeDelete(afterDelete, {}),
          hasLength(3),
        );
      },
    );

    test(
      'UserProfile name join/split, handle helpers, and buildProfileUpdateMap avoid handle collisions',
      () {
        expect(UserProfile.joinFullName('  Clara ', ' Reyes '), 'Clara Reyes');
        final split = UserProfile.splitFullName('Jon Paul Berana');
        expect(split.firstName, 'Jon');
        expect(split.lastName, 'Paul Berana');

        expect(UserProfile.isPlaceholderHandle(''), isTrue);
        expect(UserProfile.isPlaceholderHandle('@member'), isTrue);
        expect(UserProfile.isPlaceholderHandle('@clara_a1b2c3'), isFalse);

        final fallback = UserProfile.buildFallbackHandle(
          preferred: 'Clara Reyes!',
          userId: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        );
        expect(fallback, '@clarareyes_a1b2c3');

        final retry = UserProfile.buildCollisionRetryHandle(
          baseHandle: fallback,
          randomSuffix: '9F2E',
        );
        expect(retry, '@clarareyes_a1b2c3_9f2e');

        final preservedMap = SupabaseRepository.buildProfileUpdateMap(
          displayName: 'Clara Reyes',
          explicitHandle: '',
          existingHandle: '@clara_existing',
          fullName: 'Clara Reyes',
          nickname: 'Clar',
          birthday: DateTime(2001, 5, 14),
          hasConsentedTerms: true,
          hasCompletedOnboarding: false,
        );
        expect(preservedMap['handle'], '@clara_existing');
        expect(preservedMap['birthday'], '2001-05-14');

        final omittedBlankMap = SupabaseRepository.buildProfileUpdateMap(
          displayName: 'Clara Reyes',
          explicitHandle: '   ',
          existingHandle: '',
          fullName: 'Clara Reyes',
          nickname: 'Clar',
          birthday: DateTime(2001, 5, 14),
          hasConsentedTerms: true,
          hasCompletedOnboarding: false,
        );
        expect(omittedBlankMap.containsKey('handle'), isFalse);
      },
    );

    test(
      'Router completeness guard blocks incomplete profiles from skipping /profile-setup',
      () {
        const incompleteUser = UserProfile(
          id: 'u-1',
          displayName: 'Housemate',
          handle: '',
          fullName: 'Clara Reyes',
          nickname: 'Clar',
          hasConsentedTerms: true,
          // birthday is missing
        );
        expect(incompleteUser.hasCompleteRequiredProfile, isFalse);

        expect(
          resolveStartupRoute(
            isAuthenticated: true,
            hasActiveHousehold: true,
            hasCompleteRequiredProfile: false,
          ),
          '/profile-setup',
        );
        expect(
          resolveProfileCompletenessRedirect(
            isAuthenticated: true,
            currentUser: incompleteUser,
            matchedLocation: '/dashboard',
          ),
          '/profile-setup',
        );
        expect(
          resolveProfileCompletenessRedirect(
            isAuthenticated: true,
            currentUser: incompleteUser,
            matchedLocation: '/household-setup',
          ),
          '/profile-setup',
        );
        expect(
          resolveProfileCompletenessRedirect(
            isAuthenticated: true,
            currentUser: incompleteUser,
            matchedLocation: '/profile-setup',
          ),
          isNull,
        );
        expect(
          resolveProfileCompletenessRedirect(
            isAuthenticated: true,
            currentUser: incompleteUser,
            matchedLocation: '/terms-consent',
          ),
          isNull,
        );

        final completeUser = UserProfile(
          id: 'u-1',
          displayName: 'Clara Reyes',
          handle: '@clara_u1',
          fullName: 'Clara Reyes',
          nickname: 'Clar',
          birthday: DateTime(2001, 5, 14),
          hasConsentedTerms: true,
        );
        expect(completeUser.hasCompleteRequiredProfile, isTrue);
        expect(
          resolveProfileCompletenessRedirect(
            isAuthenticated: true,
            currentUser: completeUser,
            matchedLocation: '/dashboard',
          ),
          isNull,
        );
      },
    );
  });
}
