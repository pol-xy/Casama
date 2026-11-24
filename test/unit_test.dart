import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casama/core/theme/theme_provider.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';

void main() {
  group('Casama MockRepository Unit Tests', () {
    late MockRepository repo;

    setUp(() {
      repo = MockRepository();
    });

    test('Initial state matches Casa 204 mockup data', () {
      expect(repo.currentHousehold.name, 'Casa 204');
      expect(repo.currentHousehold.inviteCode, 'CASA204');
      expect(repo.currentUser.displayName, 'Jon Paul Berana');
      expect(repo.currentUser.nickname, 'JP');
      expect(repo.currentUser.age, 21);
      expect(repo.currentUser.effectiveGreetingName, 'JP');
      expect(repo.kasamaPoints, 120);
      expect(repo.members.length, 4);
      expect(repo.parcels.length, 2);
      expect(repo.items.length, 2);
      expect(repo.tasks.length, 3);
      expect(repo.groupMessages.length, 3);
      expect(repo.isAuthenticated, true);
    });

    test('New user registration and session initialization', () {
      repo.register(email: 'newuser@casama.app', password: 'password123');

      expect(repo.isAuthenticated, true);
      expect(repo.currentUser.displayName, 'newuser');
      expect(repo.currentUser.handle, '@newuser');
      expect(repo.currentUser.hasConsentedTerms, false);
      expect(repo.currentUser.hasCompletedOnboarding, false);
      expect(repo.currentUser.effectiveGreetingName, 'newuser');
    });

    test('Existing user login restores session and preserves data', () {
      repo.logout();
      expect(repo.isAuthenticated, false);

      repo.login(email: 'jp@casama.app', password: 'password123');
      expect(repo.isAuthenticated, true);
      expect(repo.currentUser.nickname, 'JP');
      expect(repo.currentUser.hasCompletedOnboarding, true);
    });

    test(
      'Optional profile fields: saving and sensible fallbacks when skipped',
      () {
        repo.register(email: 'maria@casama.app', password: 'password123');

        // 1. Incomplete profile with skipped nickname and age
        repo.updateProfile(
          displayName: 'Maria Santos',
          fullName: 'Maria Santos',
          nickname: null,
          age: null,
          avatarUrl: null,
        );

        expect(repo.currentUser.displayName, 'Maria Santos');
        expect(repo.currentUser.fullName, 'Maria Santos');
        expect(repo.currentUser.nickname, null);
        expect(repo.currentUser.age, null);
        // Fallback greeting uses first word of full name
        expect(repo.currentUser.effectiveGreetingName, 'Maria');
        // Fallback avatar returns default asset
        expect(repo.currentUser.effectiveAvatarUrl.isNotEmpty, true);

        // 2. Complete optional profile details
        repo.updateProfile(
          displayName: 'Maria Santos',
          fullName: 'Maria Santos',
          nickname: 'Mars',
          age: 22,
          avatarUrl: 'https://images.unsplash.com/custom_avatar.png',
        );

        expect(repo.currentUser.nickname, 'Mars');
        expect(repo.currentUser.age, 22);
        expect(repo.currentUser.effectiveGreetingName, 'Mars');
        expect(
          repo.currentUser.avatarUrl,
          'https://images.unsplash.com/custom_avatar.png',
        );
      },
    );

    test('Consent acknowledgment records terms acceptance', () {
      repo.register(email: 'test@casama.app', password: 'password123');
      expect(repo.currentUser.hasConsentedTerms, false);

      repo.recordTermsConsent();
      expect(repo.currentUser.hasConsentedTerms, true);
    });

    test('Completing onboarding tutorial marks completed so returning users are not re-prompted', () {
      repo.register(email: 'test@casama.app', password: 'password123');
      expect(repo.currentUser.hasCompletedOnboarding, false);

      repo.completeOnboardingTutorial();
      expect(repo.currentUser.hasCompletedOnboarding, true);
    });

    test('updatePresence toggles home status and note for current user', () {
      expect(repo.members.first.isHome, true);
      expect(repo.members.first.note, 'Studying');

      repo.updatePresence(isHome: false, note: 'Out for lunch');

      expect(repo.members.first.isHome, false);
      expect(repo.members.first.note, 'Out for lunch');
    });

    test('receiveParcel marks parcel received and awards +5 Kasama Points', () {
      final initialPoints = repo.kasamaPoints;
      final targetParcel = repo.parcels.first;
      expect(targetParcel.status, ParcelStatus.expected);

      repo.receiveParcel(targetParcel.id);

      final updatedParcel = repo.parcels.firstWhere(
        (p) => p.id == targetParcel.id,
      );
      expect(updatedParcel.status, ParcelStatus.received);
      expect(repo.kasamaPoints, initialPoints + 5);
    });

    test('addParcel prepends new expected delivery', () {
      final initialCount = repo.parcels.length;

      repo.addParcel(
        courier: 'FedEx',
        arrival: DateTime.now().add(const Duration(days: 1)),
        paymentType: ParcelPaymentType.paid,
        notes: 'Important documents',
      );

      expect(repo.parcels.length, initialCount + 1);
      expect(repo.parcels.first.courier, 'FedEx');
      expect(repo.parcels.first.notes, 'Important documents');
      expect(repo.parcels.first.status, ParcelStatus.expected);
    });

    test('completeTask awards points based on category', () {
      final repairTask = repo.tasks.firstWhere(
        (t) => t.category == TaskCategory.landlord,
      );
      final pointsBeforeRepair = repo.kasamaPoints;
      repo.completeTask(repairTask.id);

      expect(
        repo.tasks.firstWhere((t) => t.id == repairTask.id).status,
        TaskStatus.done,
      );
      expect(repo.kasamaPoints, pointsBeforeRepair + 5);

      final restockTask = repo.tasks.firstWhere(
        (t) => t.category == TaskCategory.restock,
      );
      final pointsBeforeRestock = repo.kasamaPoints;
      repo.completeTask(restockTask.id);

      expect(
        repo.tasks.firstWhere((t) => t.id == restockTask.id).status,
        TaskStatus.done,
      );
      expect(repo.kasamaPoints, pointsBeforeRestock + 2);
    });

    test('postItem, claimItem, and returnItem operations', () {
      final initialCount = repo.items.length;

      repo.postItem(
        type: ItemType.found,
        title: 'Blue Umbrellla',
        description: 'Left near doorstep',
      );

      expect(repo.items.length, initialCount + 1);
      final newItem = repo.items.first;
      expect(newItem.title, 'Blue Umbrellla');
      expect(newItem.status, ItemStatus.unclaimed);

      repo.claimItem(newItem.id);
      expect(repo.items.first.status, ItemStatus.claimed);

      final pointsBeforeReturn = repo.kasamaPoints;
      repo.returnItem(newItem.id);
      expect(repo.items.first.status, ItemStatus.returned);
      expect(repo.kasamaPoints, pointsBeforeReturn + 3);
    });

    test('sendChatMessage adds message to group stream', () {
      final initialCount = repo.groupMessages.length;

      repo.sendChatMessage('See everyone tonight at 7 PM!');

      expect(repo.groupMessages.length, initialCount + 1);
      expect(repo.groupMessages.last.content, 'See everyone tonight at 7 PM!');
      expect(repo.groupMessages.last.isCurrentUser, true);
    });

    test('sendDirectMessage records 1-on-1 housemate conversation', () {
      final initialMariaMessages = repo.getDirectMessages('maria').length;

      repo.sendDirectMessage('maria', 'I left the keys on the counter.');

      final updated = repo.getDirectMessages('maria');
      expect(updated.length, initialMariaMessages + 1);
      expect(updated.last.content, 'I left the keys on the counter.');
      expect(updated.last.isCurrentUser, true);
    });

    test('respondMeetUp correctly transitions Going, Maybe, and Cant make it counts', () {
      final initialGoing = repo.activeMeetUp.goingCount;
      expect(repo.activeMeetUp.currentUserResponse, 'going');

      repo.respondMeetUp('maybe');
      expect(repo.activeMeetUp.currentUserResponse, 'maybe');
      expect(repo.activeMeetUp.goingCount, initialGoing - 1);
      expect(repo.activeMeetUp.maybeCount, 2);

      repo.respondMeetUp('cant_make_it');
      expect(repo.activeMeetUp.currentUserResponse, 'cant_make_it');
      expect(repo.activeMeetUp.maybeCount, 1);
      expect(repo.activeMeetUp.cantMakeCount, 1);
    });

    test('Personalized greeting hierarchy accurately resolves nickname, first name, and fallback', () {
      // 1. With nickname
      final profile1 = UserProfile(
        id: 'u1',
        displayName: 'Jon Paul Berana',
        handle: '@jpberana',
        fullName: 'Jon Paul Berana',
        nickname: 'JP',
      );
      expect(profile1.effectiveGreetingName, 'JP');

      // 2. With fullName but no nickname
      final profile2 = UserProfile(
        id: 'u2',
        displayName: 'Maria Santos',
        handle: '@maria',
        fullName: 'Maria Santos',
        nickname: null,
      );
      expect(profile2.effectiveGreetingName, 'Maria');

      // 3. With only displayName
      final profile3 = UserProfile(
        id: 'u3',
        displayName: 'Dave',
        handle: '@dave',
        fullName: null,
        nickname: null,
      );
      expect(profile3.effectiveGreetingName, 'Dave');

      // 4. Default fallback when empty
      final profile4 = UserProfile(
        id: 'u4',
        displayName: '',
        handle: '@empty',
        fullName: null,
        nickname: null,
      );
      expect(profile4.effectiveGreetingName, 'Kasama');
    });

    test(
      'Maintenance tasks maintain dueDate and support calendar scheduling',
      () {
        final task = repo.tasks.first;
        expect(task.dueDate, isNotNull);
        final due = task.dueDate!;

        // Completing the task preserves dueDate
        repo.completeTask(task.id);
        final updatedTask = repo.tasks.firstWhere((t) => t.id == task.id);
        expect(updatedTask.status, TaskStatus.done);
        expect(updatedTask.dueDate, due);
      },
    );

    test('User search filters by handle or name, excluding current household members, and preserves privacy', () {
      // 1. Search for non-member Miguel
      final results = repo.searchUsers('miguel');
      expect(results.length, 1);
      expect(results.first.displayName, 'Miguel Ramos');
      expect(results.first.handle, '@miguel');

      // 2. Search for existing member Maria - excluded from results
      final memberResults = repo.searchUsers('maria');
      expect(memberResults.isEmpty, true);

      // 3. Blank search returns empty list
      expect(repo.searchUsers('').isEmpty, true);
    });

    test('Household invitation flow: sending, duplicate prevention, and accepting adds new member to household', () {
      final initialMembersCount = repo.members.length;

      // 1. Send invitation to Clara
      final sent = repo.sendInvitation(
        inviteeEmailOrHandle: '@clara',
        inviteeName: 'Clara Reyes',
      );
      expect(sent, true);
      expect(repo.invitations.first.inviteeEmailOrHandle, '@clara');
      expect(repo.invitations.first.status, InvitationStatus.pending);

      // 2. Duplicate invitation prevented
      final duplicate = repo.sendInvitation(inviteeEmailOrHandle: '@clara');
      expect(duplicate, false);

      // 3. Inviting existing member prevented
      final existing = repo.sendInvitation(inviteeEmailOrHandle: '@maria');
      expect(existing, false);

      // 4. Accept invitation adds member to household
      final invId = repo.invitations.first.id;
      final accepted = repo.acceptInvitation(invId);
      expect(accepted, true);
      expect(repo.invitations.first.status, InvitationStatus.accepted);
      expect(repo.members.length, initialMembersCount + 1);
      expect(repo.members.any((m) => m.profile.handle == '@clara'), true);
    });

    test('Household invitation flow: declining invitation marks status declined without adding member', () {
      final initialMembersCount = repo.members.length;

      repo.sendInvitation(
        inviteeEmailOrHandle: '@bea',
        inviteeName: 'Bea Gomez',
      );
      final invId = repo.invitations.first.id;

      final declined = repo.declineInvitation(invId);
      expect(declined, true);
      expect(repo.invitations.first.status, InvitationStatus.declined);
      expect(repo.members.length, initialMembersCount);
      expect(repo.members.any((m) => m.profile.handle == '@bea'), false);
    });

    test('Household authorization check correctly distinguishes verified members from unauthorized external users', () {
      // Verified members
      expect(repo.isHousemateAuthorized('maria'), true);
      expect(repo.isHousemateAuthorized('alex'), true);
      expect(repo.isHousemateAuthorized('ria'), true);
      expect(repo.isHousemateAuthorized('@jpberana'), true);

      // Unauthorized external users
      expect(repo.isHousemateAuthorized('hacker_99'), false);
      expect(repo.isHousemateAuthorized('unknown_guest'), false);
      expect(repo.isHousemateAuthorized('@stranger'), false);
    });

    test('Individual messaging records separate conversation history per housemate', () {
      final mariaInitial = repo.getDirectMessages('maria').length;
      final alexInitial = repo.getDirectMessages('alex').length;

      repo.sendDirectMessage('maria', 'Can you check the front door?');

      expect(repo.getDirectMessages('maria').length, mariaInitial + 1);
      expect(
        repo.getDirectMessages('maria').last.content,
        'Can you check the front door?',
      );
      // Unrelated conversation unaffected
      expect(repo.getDirectMessages('alex').length, alexInitial);
    });

    test('updateProfile edits full name, nickname, age and reactively updates greeting name', () {
      repo.updateProfile(
        fullName: 'Jon Paul Berana Jr.',
        nickname: 'JPB',
        age: 22,
      );

      expect(repo.currentUser.fullName, 'Jon Paul Berana Jr.');
      expect(repo.currentUser.nickname, 'JPB');
      expect(repo.currentUser.age, 22);
      expect(repo.effectiveGreetingName, 'JPB');

      // Clearing nickname falls back to first name
      repo.updateProfile(clearNickname: true);
      expect(repo.currentUser.nickname, null);
      expect(repo.effectiveGreetingName, 'Jon');
    });

    test('updateProfile supports replacing and removing profile pictures', () {
      // 1. Upload/replace picture
      repo.updateProfile(avatarUrl: 'https://example.com/new_avatar.jpg');
      expect(repo.currentUser.avatarUrl, 'https://example.com/new_avatar.jpg');

      // 2. Remove picture (clearAvatar: true)
      repo.updateProfile(clearAvatar: true);
      expect(repo.currentUser.avatarUrl, null);
    });

    test('pointHistory tracks initial balance and records new audit entries upon earning points', () {
      expect(repo.pointHistory.isNotEmpty, true);
      final initialEntries = repo.pointHistory.length;
      final initialPoints = repo.kasamaPoints;

      // Receive a parcel (+5 pts)
      repo.receiveParcel('p1');
      expect(repo.kasamaPoints, initialPoints + 5);
      expect(repo.pointHistory.length, initialEntries + 1);
      expect(repo.pointHistory.first.category, 'parcel');
      expect(repo.pointHistory.first.points, 5);

      // Complete a task (+5 or +2 pts)
      repo.completeTask('t1');
      expect(repo.pointHistory.first.category, 'task');
      expect(repo.pointHistory.first.points, 5);
    });

    test('updateNotificationPreferences updates and persists toggles', () {
      expect(repo.notificationPreferences.householdUpdates, true);
      expect(repo.notificationPreferences.parcelNotifications, true);

      repo.updateNotificationPreferences(
        householdUpdates: false,
        parcelNotifications: false,
      );

      expect(repo.notificationPreferences.householdUpdates, false);
      expect(repo.notificationPreferences.parcelNotifications, false);
      expect(repo.notificationPreferences.taskReminders, true);
      expect(repo.notificationPreferences.chatNotifications, true);
    });

    test('ChatSpace: creation, joining by invitation code, and adding members directly', () {
      final initialSpacesCount = repo.chatSpaces.length;

      // 1. Create a custom chat space
      final space = repo.createChatSpace(
        name: 'Game Night 🎮',
        description: 'Board games and video games night coordination',
        iconEmoji: '🎮',
        initialMembers: ['Maria Santos'],
      );

      expect(repo.chatSpaces.length, initialSpacesCount + 1);
      expect(space.name, 'Game Night 🎮');
      expect(space.inviteCode, startsWith('SPC-'));
      expect(space.memberNames, containsAll(['You', 'Maria Santos']));
      expect(space.messages.length, 1);
      expect(space.messages.first.inviteCode, space.inviteCode);

      // 2. Add another member directly
      repo.addMemberToSpace(space.id, 'Alex Rivera');
      final updatedSpace = repo.chatSpaces.firstWhere((s) => s.id == space.id);
      expect(updatedSpace.memberNames, contains('Alex Rivera'));

      // 3. Join space by invitation code
      final joined = repo.joinChatSpaceByCode(space.inviteCode);
      expect(joined, isNotNull);
      expect(joined!.id, space.id);

      // Invalid code returns null
      final invalid = repo.joinChatSpaceByCode('INVALID_CODE');
      expect(invalid, isNull);
    });

    test('Unread counts and read receipts: marks group chat, space, and notifications as read', () {
      // Initially group chat has unread messages and notifications has unread count
      expect(repo.groupChatUnreadCount, 2);
      expect(repo.unreadNotificationCount, 1);
      expect(repo.totalUnreadChatCount, greaterThanOrEqualTo(2));

      // Mark group chat as read
      repo.markGroupChatAsRead();
      expect(repo.groupChatUnreadCount, 0);

      // Mark notifications as read
      repo.markAllNotificationsAsRead();
      expect(repo.unreadNotificationCount, 0);

      // Mark chat space as read
      final spaceId = repo.chatSpaces.first.id;
      repo.markSpaceChatAsRead(spaceId);
      final space = repo.chatSpaces.firstWhere((s) => s.id == spaceId);
      expect(space.unreadCount, 0);
    });

    test('Sharing invite code into group chat and direct chat creates rich invite messages', () {
      final initialGroupCount = repo.groupMessages.length;
      final initialDirectCount = repo.getDirectMessages('maria').length;

      // Share code to group chat
      repo.shareInviteCodeToGroupChat(code: 'CASA204', title: 'Casa 204');
      expect(repo.groupMessages.length, initialGroupCount + 1);
      final lastGroup = repo.groupMessages.last;
      expect(lastGroup.inviteCode, 'CASA204');
      expect(lastGroup.inviteSpaceName, 'Casa 204');

      // Share code to direct chat
      repo.shareInviteCodeToDirectChat(
        contactKey: 'maria',
        code: 'SPC-101',
        title: 'Grocery 🛒',
      );
      final dm = repo.getDirectMessages('maria');
      expect(dm.length, initialDirectCount + 1);
      final lastDm = dm.last;
      expect(lastDm.inviteCode, 'SPC-101');
      expect(lastDm.inviteSpaceName, 'Grocery 🛒');
    });
  });

  group('Casama ThemeNotifier Unit Tests', () {
    test('Defaults to ThemeMode.light and allows changing or toggling', () {
      final notifier = ThemeNotifier();
      expect(notifier.state, ThemeMode.light);

      notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);

      notifier.toggleTheme();
      expect(notifier.state, ThemeMode.light);

      notifier.toggleTheme();
      expect(notifier.state, ThemeMode.dark);
    });

    test(
      'Persists theme mode to SharedPreferences and restores across instances',
      () async {
        SharedPreferences.setMockInitialValues({'casama_theme_mode': 'dark'});
        final prefs = await SharedPreferences.getInstance();

        final notifier1 = ThemeNotifier(prefs);
        expect(notifier1.state, ThemeMode.dark);

        await notifier1.setThemeMode(ThemeMode.light);
        expect(notifier1.state, ThemeMode.light);
        expect(prefs.getString('casama_theme_mode'), 'light');

        await notifier1.setThemeMode(ThemeMode.system);
        expect(notifier1.state, ThemeMode.system);
        expect(prefs.getString('casama_theme_mode'), 'system');

        // Restored on new instance
        final notifier2 = ThemeNotifier(prefs);
        expect(notifier2.state, ThemeMode.system);
      },
    );
  });

  group('Bills & Payments Feature Tests', () {
    test('addBill stores a new bill and increments unread notifications if reminder enabled', () {
      final repo = MockRepository();
      final initialCount = repo.bills.length;
      final initialUnread = repo.unreadNotificationCount;

      repo.addBill(
        category: BillCategory.electricity,
        billName: 'Test Electric Bill',
        amount: 1500.0,
        deadline: DateTime.now().add(const Duration(days: 4)),
        reminderEnabled: true,
        reminderTiming: ReminderTiming.oneDayBefore,
      );

      expect(repo.bills.length, initialCount + 1);
      final newBill = repo.bills.first;
      expect(newBill.billName, 'Test Electric Bill');
      expect(newBill.effectiveBillName, 'Test Electric Bill');
      expect(newBill.effectiveCategoryLabel, 'Electricity');
      expect(newBill.amount, 1500.0);
      expect(newBill.status, BillStatus.unpaid);
      expect(repo.unreadNotificationCount, initialUnread + 1);
    });

    test('markBillPaid awards +5 points and updates bill status', () {
      final repo = MockRepository();
      final initialPoints = repo.kasamaPoints;

      // Find an unpaid bill
      final unpaidBill = repo.bills.firstWhere(
        (b) => b.status == BillStatus.unpaid,
      );
      repo.markBillPaid(unpaidBill.id);

      expect(repo.kasamaPoints, initialPoints + 5);
      final paidBill = repo.bills.firstWhere((b) => b.id == unpaidBill.id);
      expect(paidBill.status, BillStatus.paid);
      expect(paidBill.paidByName, repo.currentUser.displayName);
      expect(paidBill.paidAt, isNotNull);

      // Duplicate payment does not award double points
      repo.markBillPaid(unpaidBill.id);
      expect(repo.kasamaPoints, initialPoints + 5);
    });

    test('reopenBill reverts paid status to unpaid', () {
      final repo = MockRepository();
      final paidBill = repo.bills.firstWhere(
        (b) => b.status == BillStatus.paid,
      );
      repo.reopenBill(paidBill.id);

      final reopened = repo.bills.firstWhere((b) => b.id == paidBill.id);
      expect(reopened.status, BillStatus.unpaid);
    });

    test('deleteBill removes the bill when requested by creator', () {
      final repo = MockRepository();
      final createdBill = repo.bills.firstWhere(
        (b) => b.creatorId == repo.currentUser.id,
      );
      final countBefore = repo.bills.length;

      repo.deleteBill(createdBill.id);
      expect(repo.bills.length, countBefore - 1);
      expect(repo.bills.any((b) => b.id == createdBill.id), isFalse);
    });

    test(
      'overdue bills are auto-detected when deadline has passed and unpaid',
      () {
        final bill = HouseholdBill(
          id: 'overdue_test',
          householdId: 'h1',
          creatorId: 'c1',
          creatorName: 'JP',
          category: BillCategory.internet,
          deadline: DateTime.now().subtract(const Duration(days: 2)),
          status: BillStatus.unpaid,
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        );

        expect(bill.effectiveStatus, BillStatus.overdue);
      },
    );
  });

  group('QuickSnap (Locket-style) Feature Tests', () {
    test(
      'sendQuickSnap adds new snap to repository and broadcasts to chat',
      () {
        final repo = MockRepository();
        final initialCount = repo.quickSnaps.length;
        final initialMessages = repo.groupMessages.length;

        repo.sendQuickSnap(
          imageUrl: 'https://images.unsplash.com/photo-test',
          caption: 'Balcony sunrise with dormmates 🌅',
          recipientType: QuickSnapRecipientType.everyone,
        );

        expect(repo.quickSnaps.length, initialCount + 1);
        final newSnap = repo.quickSnaps.first;
        expect(newSnap.caption, 'Balcony sunrise with dormmates 🌅');
        expect(newSnap.senderName, repo.currentUser.displayName);
        expect(newSnap.recipientType, QuickSnapRecipientType.everyone);

        // Verify broadcast to household chat
        expect(repo.groupMessages.length, initialMessages + 1);
        expect(repo.groupMessages.last.content, contains('Shared a QuickSnap'));
      },
    );

    test('reactToQuickSnap adds reaction to the target snap', () {
      final repo = MockRepository();
      repo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'First photo',
        recipientType: QuickSnapRecipientType.everyone,
      );
      final snap = repo.quickSnaps.first;
      final initialReactions = snap.reactions.length;

      repo.reactToQuickSnap(snap.id, '🔥');

      final updatedSnap = repo.quickSnaps.firstWhere((s) => s.id == snap.id);
      expect(updatedSnap.reactions.length, initialReactions + 1);
      expect(updatedSnap.reactions.last.emoji, '🔥');
      expect(updatedSnap.reactions.last.userName, repo.currentUser.displayName);
    });

    test('commentOnQuickSnap adds comment to target snap', () {
      final repo = MockRepository();
      repo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'First photo',
        recipientType: QuickSnapRecipientType.everyone,
      );
      final snap = repo.quickSnaps.first;
      final initialComments = snap.comments.length;

      repo.commentOnQuickSnap(snap.id, 'Love this view!');

      final updatedSnap = repo.quickSnaps.firstWhere((s) => s.id == snap.id);
      expect(updatedSnap.comments.length, initialComments + 1);
      expect(updatedSnap.comments.last.text, 'Love this view!');
      expect(updatedSnap.comments.last.userName, repo.currentUser.displayName);
    });

    test('quickSnapStreak calculates consecutive day streaks', () {
      final repo = MockRepository();
      expect(repo.quickSnapStreak, 0);

      repo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'Today snap',
        recipientType: QuickSnapRecipientType.everyone,
      );
      expect(repo.quickSnapStreak, 1);
    });
  });
}
