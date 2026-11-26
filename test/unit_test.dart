import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:casama/core/theme/theme_provider.dart';
import 'package:casama/data/mock_repository.dart';
import 'package:casama/data/models.dart';
import 'package:casama/features/quicksnap/quicksnap_image_view.dart';

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
      expect(repo.currentUser.birthday, DateTime(2005, 5, 15));
      expect(repo.currentUser.computedAge, isNotNull);
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
      'Profile fields: saving birthday and sensible fallbacks when cleared',
      () {
        repo.register(email: 'maria@casama.app', password: 'password123');

        // 1. Incomplete profile with null nickname and birthday
        repo.updateProfile(
          displayName: 'Maria Santos',
          fullName: 'Maria Santos',
          nickname: null,
          birthday: null,
          avatarUrl: null,
        );

        expect(repo.currentUser.displayName, 'Maria Santos');
        expect(repo.currentUser.fullName, 'Maria Santos');
        expect(repo.currentUser.nickname, null);
        expect(repo.currentUser.birthday, null);
        expect(repo.currentUser.computedAge, null);
        // Fallback greeting uses first word of full name
        expect(repo.currentUser.effectiveGreetingName, 'Maria');
        // Fallback avatar returns default asset
        expect(repo.currentUser.effectiveAvatarUrl.isNotEmpty, true);

        // 2. Complete profile details with birthday
        repo.updateProfile(
          displayName: 'Maria Santos',
          fullName: 'Maria Santos',
          nickname: 'Mars',
          birthday: DateTime(2004, 3, 10),
          avatarUrl: 'https://images.unsplash.com/custom_avatar.png',
        );

        expect(repo.currentUser.nickname, 'Mars');
        expect(repo.currentUser.birthday, DateTime(2004, 3, 10));
        expect(repo.currentUser.computedAge, isNotNull);
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
      expect(updatedParcel.isUnsettledClaim, isTrue);
      expect(updatedParcel.claimedById, repo.currentUser.id);
      expect(updatedParcel.claimedAt, isNotNull);
      expect(repo.kasamaPoints, initialPoints + 5);
    });

    test('receiveParcel auto-settles own parcel with 0 points, and housemate claim awards +5 points until settled', () async {
      repo.addParcel(
        courier: 'J&T Express',
        arrival: DateTime.now(),
        paymentType: ParcelPaymentType.cod,
        codAmount: 250,
      );
      final ownParcel = repo.parcels.first;
      expect(ownParcel.buyerId, repo.currentUser.id);
      final pointsBefore = repo.kasamaPoints;

      repo.receiveParcel(ownParcel.id);
      expect(repo.kasamaPoints, pointsBefore);

      final selfClaimed = repo.parcels.firstWhere((p) => p.id == ownParcel.id);
      expect(selfClaimed.isSettled, isTrue);
      expect(selfClaimed.isUnsettledClaim, isFalse);
      expect(selfClaimed.settledAt, isNotNull);

      // Housemate parcel ('p1') awards +5 points and starts unsettled until settled
      final housemateParcel = repo.parcels.firstWhere((p) => p.id == 'p1');
      expect(housemateParcel.buyerId, isNot(repo.currentUser.id));

      repo.receiveParcel('p1');
      expect(repo.kasamaPoints, pointsBefore + 5);

      final claimed = repo.parcels.firstWhere((p) => p.id == 'p1');
      expect(claimed.isUnsettledClaim, isTrue);
      expect(claimed.isSettled, isFalse);

      await repo.settleParcelClaim('p1');
      final settled = repo.parcels.firstWhere((p) => p.id == 'p1');
      expect(settled.isSettled, isTrue);
      expect(settled.settledAt, isNotNull);
    });

    test('addParcel prepends new expected delivery', () {
      final initialCount = repo.parcels.length;

      repo.addParcel(
        courier: 'SPX',
        arrival: DateTime.now().add(const Duration(days: 1)),
        paymentType: ParcelPaymentType.paid,
        notes: 'Important documents',
      );

      expect(repo.parcels.length, initialCount + 1);
      expect(repo.parcels.first.courier, 'SPX');
      expect(repo.parcels.first.notes, 'Important documents');
      expect(repo.parcels.first.status, ParcelStatus.expected);
    });

    test('MaintenanceTask.computePoints and completeTask enforce dynamic scoring and self-completion guard', () {
      // All 8 category x urgency combinations (plus legacy diy/landlord aliases)
      expect(MaintenanceTask.computePoints(TaskCategory.cleaning, TaskUrgency.low), 7);
      expect(MaintenanceTask.computePoints(TaskCategory.cleaning, TaskUrgency.medium), 9);
      expect(MaintenanceTask.computePoints(TaskCategory.cleaning, TaskUrgency.urgent), 11);
      expect(MaintenanceTask.computePoints(TaskCategory.restock, TaskUrgency.low), 7);
      expect(MaintenanceTask.computePoints(TaskCategory.restock, TaskUrgency.medium), 9);
      expect(MaintenanceTask.computePoints(TaskCategory.restock, TaskUrgency.urgent), 11);
      expect(MaintenanceTask.computePoints(TaskCategory.repairMaintenance, TaskUrgency.low), 10);
      expect(MaintenanceTask.computePoints(TaskCategory.repairMaintenance, TaskUrgency.medium), 12);
      expect(MaintenanceTask.computePoints(TaskCategory.repairMaintenance, TaskUrgency.urgent), 14);
      expect(MaintenanceTask.computePoints(TaskCategory.personalRequest, TaskUrgency.low), 10);
      expect(MaintenanceTask.computePoints(TaskCategory.personalRequest, TaskUrgency.medium), 12);
      expect(MaintenanceTask.computePoints(TaskCategory.personalRequest, TaskUrgency.urgent), 14);

      // Own task (t1) awards 0 points
      final ownTask = repo.tasks.firstWhere((t) => t.id == 't1');
      expect(ownTask.createdBy, repo.currentUser.id);
      expect(ownTask.computedPoints, 14);
      final pointsBeforeOwn = repo.kasamaPoints;
      final historyBeforeOwn = repo.pointHistory.length;
      repo.completeTask(ownTask.id);

      final doneOwn = repo.tasks.firstWhere((t) => t.id == ownTask.id);
      expect(doneOwn.status, TaskStatus.done);
      expect(doneOwn.completedById, repo.currentUser.id);
      expect(doneOwn.completedByName, repo.currentUser.displayName);
      expect(doneOwn.completedAt, isNotNull);
      expect(repo.kasamaPoints, pointsBeforeOwn);
      expect(repo.pointHistory.length, historyBeforeOwn);

      // Housemate restock medium task (t2) awards +9 points
      final restockTask = repo.tasks.firstWhere((t) => t.id == 't2');
      expect(restockTask.computedPoints, 9);
      final pointsBeforeRestock = repo.kasamaPoints;
      repo.completeTask(restockTask.id);

      expect(
        repo.tasks.firstWhere((t) => t.id == restockTask.id).status,
        TaskStatus.done,
      );
      expect(repo.kasamaPoints, pointsBeforeRestock + 9);

      // Housemate cleaning/diy low task (t3) awards +7 points
      final cleanTask = repo.tasks.firstWhere((t) => t.id == 't3');
      expect(cleanTask.computedPoints, 7);
      final pointsBeforeClean = repo.kasamaPoints;
      repo.completeTask(cleanTask.id);
      expect(repo.kasamaPoints, pointsBeforeClean + 7);
    });

    test('Lost & Found verification workflow: linked reject -> resubmit -> confirm (+5 pts), owner self-resolve (0 pts), and standalone claim (+2 pts)', () async {
      // 1. Owner (Jon Paul) cannot submit a find for his own lost item (i1)
      final ownLost = repo.items.firstWhere((i) => i.id == 'i1');
      final selfErr = await repo.submitLostItemFind(
        lostItem: ownLost,
        foundLocation: 'Desk',
      );
      expect(selfErr, isNotNull);

      // 2. Maria submits a find for i1 -> pending; duplicate pending blocked
      const mariaId = '22222222-2222-2222-2222-222222222222';
      const alexId = '33333333-3333-3333-3333-333333333333';
      const jpId = '11111111-1111-1111-1111-111111111111';

      repo.setCurrentUserForTest(mariaId);
      expect(
        await repo.submitLostItemFind(
          lostItem: ownLost,
          foundLocation: 'Sofa',
          description: 'Black case',
        ),
        isNull,
      );
      final firstFind = repo.items.firstWhere(
        (i) => i.lostItemId == 'i1' && i.reportedBy == mariaId,
      );
      expect(firstFind.status, ItemStatus.pending);

      final dupErr = await repo.submitLostItemFind(
        lostItem: ownLost,
        foundLocation: 'Kitchen',
      );
      expect(dupErr, 'You already have a pending find awaiting review.');

      // 3. Jon Paul rejects Maria's first find -> rejected w/ rejectedAt, lost stays open
      repo.setCurrentUserForTest(jpId);
      expect(await repo.rejectLostItemFind(firstFind.id), isNull);
      final rejectedFind = repo.items.firstWhere((i) => i.id == firstFind.id);
      expect(rejectedFind.status, ItemStatus.rejected);
      expect(rejectedFind.rejectedAt, isNotNull);
      expect(
        repo.items.firstWhere((i) => i.id == 'i1').status,
        ItemStatus.open,
      );

      // 4. Maria re-submits AND Alex submits a competing pending find
      repo.setCurrentUserForTest(mariaId);
      expect(
        await repo.submitLostItemFind(
          lostItem: ownLost,
          foundLocation: 'Study Desk',
        ),
        isNull,
      );
      final mariaSecondFind = repo.items.firstWhere(
        (i) =>
            i.lostItemId == 'i1' &&
            i.reportedBy == mariaId &&
            i.status == ItemStatus.pending,
      );

      repo.setCurrentUserForTest(alexId);
      expect(
        await repo.submitLostItemFind(
          lostItem: ownLost,
          foundLocation: 'Counter',
        ),
        isNull,
      );
      final alexFind = repo.items.firstWhere(
        (i) =>
            i.lostItemId == 'i1' &&
            i.reportedBy == alexId &&
            i.status == ItemStatus.pending,
      );

      // 5. Jon Paul confirms Maria's second find -> both resolved, Alex auto-rejected, Maria +5 pts
      final mariaPointsBefore = repo.pointsForUser(mariaId);
      repo.setCurrentUserForTest(jpId);
      expect(await repo.acceptLostItemFind(mariaSecondFind.id), isNull);

      final resolvedLost = repo.items.firstWhere((i) => i.id == 'i1');
      expect(resolvedLost.status, ItemStatus.resolved);
      expect(resolvedLost.resolvedFoundItemId, mariaSecondFind.id);
      expect(resolvedLost.foundById, mariaId);
      expect(
        repo.items.firstWhere((i) => i.id == mariaSecondFind.id).status,
        ItemStatus.resolved,
      );
      expect(
        repo.items.firstWhere((i) => i.id == alexFind.id).status,
        ItemStatus.rejected,
      );
      expect(repo.pointsForUser(mariaId), mariaPointsBefore + 5);

      // 6. Owner self-resolve awards 0 points
      repo.postItem(
        type: ItemType.lost,
        title: 'Lost Keys',
        location: 'Hallway',
      );
      final secondLost = repo.items.firstWhere((i) => i.title == 'Lost Keys');
      final jpPointsBefore = repo.kasamaPoints;
      expect(await repo.resolveOwnLostItem(secondLost.id), isNull);
      expect(repo.kasamaPoints, jpPointsBefore);
      expect(
        repo.items.firstWhere((i) => i.id == secondLost.id).status,
        ItemStatus.resolved,
      );

      // 7. Standalone found item claim: finder (Maria) blocked from self-claim; Jon Paul claims -> Maria +2 pts
      repo.setCurrentUserForTest(mariaId);
      final selfClaimErr = await repo.claimStandaloneFoundItem('i2');
      expect(selfClaimErr, isNotNull);

      final mariaPointsBeforeClaim = repo.pointsForUser(mariaId);
      repo.setCurrentUserForTest(jpId);
      expect(await repo.claimStandaloneFoundItem('i2'), isNull);
      final claimedFound = repo.items.firstWhere((i) => i.id == 'i2');
      expect(claimedFound.status, ItemStatus.resolved);
      expect(claimedFound.claimedById, jpId);
      expect(repo.pointsForUser(mariaId), mariaPointsBeforeClaim + 2);
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

      // Completed ('done') meetups block further RSVP changes
      repo.setActiveMeetUpForTest(
        repo.activeMeetUp.copyWith(status: 'done'),
      );
      expect(repo.activeMeetUp.isActive, isFalse);
      repo.respondMeetUp('going');
      expect(repo.activeMeetUp.currentUserResponse, 'cant_make_it');
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

    test('updateProfile edits full name, nickname, birthday and reactively updates greeting name', () {
      repo.updateProfile(
        fullName: 'Jon Paul Berana Jr.',
        nickname: 'JPB',
        birthday: DateTime(2004, 8, 20),
      );

      expect(repo.currentUser.fullName, 'Jon Paul Berana Jr.');
      expect(repo.currentUser.nickname, 'JPB');
      expect(repo.currentUser.birthday, DateTime(2004, 8, 20));
      expect(repo.effectiveGreetingName, 'JPB');

      // Clearing nickname falls back to first name
      repo.updateProfile(clearNickname: true);
      expect(repo.currentUser.nickname, null);
      expect(repo.effectiveGreetingName, 'Jon');
    });

    test('UserProfile.fromJson / toJson parses and serializes YYYY-MM-DD birthday without timezone shifts', () {
      final profile = UserProfile.fromJson({
        'id': 'u1',
        'display_name': 'Clara Reyes',
        'handle': '@clara',
        'birthday': '2007-01-01T00:00:00Z',
        'has_consented_terms': true,
        'has_completed_onboarding': true,
      });

      expect(profile.birthday, DateTime(2007, 1, 1));
      expect(profile.computedAge, isNotNull);
      final json = profile.toJson();
      expect(json['birthday'], '2007-01-01');
      expect(json.containsKey('age'), isFalse);

      expect(UserProfile.parseDateOnly('2026-02-30'), isNull);
      expect(UserProfile.parseDateOnly(null), isNull);
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

      // Complete a housemate's task ('t2', restock medium = +9 pts)
      repo.completeTask('t2');
      expect(repo.pointHistory.first.category, 'task');
      expect(repo.pointHistory.first.points, 9);
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

    test(
      'Multi-household switching, creation, and joining preserve isolated workspaces',
      () async {
        expect(repo.userHouseholds.length, 1);
        expect(repo.userHouseholds.first.name, 'Casa 204');
        expect(repo.userHouseholds.first.memberCount, 4);

        final created = await repo.createHousehold(name: 'TeenTitans');
        expect(created.name, 'TeenTitans');
        expect(created.inviteCode.length, 6);
        expect(created.inviteCode, isNot('CASA204'));
        expect(repo.currentHousehold.id, created.id);
        expect(repo.members.length, 1);
        expect(repo.kasamaPoints, 0);
        expect(repo.userHouseholds.length, 2);

        // Switch back to Casa 204
        await repo.switchHousehold('a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11');
        expect(repo.currentHousehold.name, 'Casa 204');
        expect(repo.members.length, 4);
        expect(repo.kasamaPoints, 120);

        // Join another household by code
        final joined = await repo.joinHouseholdByCode('SYZKB2');
        expect(joined.inviteCode, 'SYZKB2');
        expect(repo.userHouseholds.length, 3);

        // Unknown household ID throws StateError
        expect(
          () => repo.switchHousehold('non-existent-id'),
          throwsStateError,
        );
      },
    );
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
        );

        expect(repo.quickSnaps.length, initialCount + 1);
        final newSnap = repo.quickSnaps.first;
        expect(newSnap.caption, 'Balcony sunrise with dormmates 🌅');
        expect(newSnap.creatorName, repo.currentUser.displayName);

        // Verify creator profile resolution (present avatar -> cleared avatar fallback)
        final resolvedWithAvatar = resolveSnapCreatorProfile(repo, newSnap);
        expect(resolvedWithAvatar.avatarUrl, repo.currentUser.effectiveAvatarUrl);
        expect(resolvedWithAvatar.displayName, repo.currentUser.displayName);

        repo.updateProfile(clearAvatar: true);
        final resolvedWithoutAvatar = resolveSnapCreatorProfile(repo, newSnap);
        expect(resolvedWithoutAvatar.avatarUrl, isNull);
        expect(resolvedWithoutAvatar.displayName, repo.currentUser.displayName);

        // Verify broadcast to household chat
        expect(repo.groupMessages.length, initialMessages + 1);
        expect(repo.groupMessages.last.content, contains('Shared a QuickSnap'));
      },
    );

    test('reactToQuickSnap adds reaction to the target snap and batches multi-taps', () async {
      final repo = MockRepository();
      addTearDown(repo.dispose);
      repo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'First photo',
      );
      final snap = repo.quickSnaps.first;

      repo.queueQuickSnapReaction(snap.id, '🔥');
      repo.queueQuickSnapReaction(snap.id, '🔥');
      repo.queueQuickSnapReaction(snap.id, '🔥');
      repo.queueQuickSnapReaction(snap.id, '❤️');
      repo.queueQuickSnapReaction(snap.id, '❤️');

      // Immediate optimistic UI update before debounce flush
      final optimistic = repo.quickSnaps.firstWhere((s) => s.id == snap.id);
      expect(optimistic.totalReactionCount, 5);
      expect(repo.flushedReactionBatches, isEmpty);
      expect(repo.hasPendingSnapReactions, isTrue);

      await repo.flushPendingSnapReactions();

      // Flushes exactly one batched payload after cooldown / explicit flush
      expect(repo.hasPendingSnapReactions, isFalse);
      expect(repo.flushedReactionBatches.length, 1);
      expect(repo.flushedReactionBatches.single.snapId, snap.id);
      expect(repo.flushedReactionBatches.single.deltas, {'🔥': 3, '❤️': 2});

      final committed = repo.quickSnaps.firstWhere((s) => s.id == snap.id);
      expect(committed.totalReactionCount, 5);
      expect(committed.topReactionEmojis(), ['🔥', '❤️']);
      expect(committed.reactorBreakdowns.single.emojiCounts.map((e) => '${e.key}-${e.value}').toList(), [
        '🔥-3',
        '❤️-2',
      ]);
    });

    test('QuickSnapReaction.fromJson parses count (default 1) and updated_at', () {
      final legacy = QuickSnapReaction.fromJson({
        'emoji': '👍',
        'user_id': 'u1',
        'user_name': 'JP',
        'created_at': '2026-11-26T00:00:00Z',
      });
      expect(legacy.count, 1);
      expect(legacy.updatedAt, isNull);

      final multi = QuickSnapReaction.fromJson({
        'emoji': '🔥',
        'user_id': 'u1',
        'user_name': 'JP',
        'count': 4,
        'created_at': '2026-11-26T00:00:00Z',
        'updated_at': '2026-11-26T00:05:00Z',
      });
      expect(multi.count, 4);
      expect(multi.updatedAt, DateTime.parse('2026-11-26T00:05:00Z').toLocal());
      expect(multi.toJson()['count'], 4);
      expect(multi.toJson()['updated_at'], '2026-11-26T00:05:00.000Z');
    });

    test('commentOnQuickSnap adds comment to target snap', () {
      final repo = MockRepository();
      repo.sendQuickSnap(
        imageUrl: 'https://images.unsplash.com/photo-test',
        caption: 'First photo',
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
      );
      expect(repo.quickSnapStreak, 1);
    });

    test('ChatMessage.fromJson / toJson handles nullable attachment_url and photo-only content', () {
      final photoOnly = ChatMessage.fromJson({
        'id': 'm1',
        'sender_id': 'u1',
        'content': '',
        'attachment_url': 'https://example.com/chat-attachments/c1/cm1.jpg',
        'client_message_id': 'cm1',
        'created_at': '2026-11-26T08:00:00.000Z',
      }, currentUserId: 'u1');

      expect(photoOnly.attachmentUrl, 'https://example.com/chat-attachments/c1/cm1.jpg');
      expect(photoOnly.hasAttachment, isTrue);
      expect(photoOnly.content, '');
      expect(photoOnly.clientMessageId, 'cm1');

      final withLocal = photoOnly.copyWith(localAttachmentPath: '/tmp/local.jpg');
      final json = withLocal.toJson();
      expect(json['attachment_url'], 'https://example.com/chat-attachments/c1/cm1.jpg');
      expect(json['content'], '');
      expect(json['client_message_id'], 'cm1');
      expect(json.containsKey('localAttachmentPath'), isFalse);
      expect(json.containsKey('local_attachment_path'), isFalse);

      final textOnly = ChatMessage.fromJson({
        'id': 'm2',
        'sender_id': 'u2',
        'content': 'Hello',
        'attachment_url': null,
        'created_at': '2026-11-26T08:01:00.000Z',
      });
      expect(textOnly.attachmentUrl, isNull);
      expect(textOnly.hasAttachment, isFalse);
      expect(textOnly.toJson()['attachment_url'], isNull);
    });

    test('MockRepository sends photo-only and captioned attachment messages with clientMessageId', () {
      final mockRepo = MockRepository()..login();
      final xfile = XFile('/tmp/sample_photo.jpg');

      mockRepo.sendChatMessage(
        '',
        attachmentFile: xfile,
        clientMessageId: 'cid-photo-1',
      );
      final photoMsg = mockRepo.groupMessages.last;
      expect(photoMsg.content, '');
      expect(photoMsg.attachmentUrl, '/tmp/sample_photo.jpg');
      expect(photoMsg.localAttachmentPath, '/tmp/sample_photo.jpg');
      expect(photoMsg.clientMessageId, 'cid-photo-1');

      mockRepo.sendDirectMessage(
        'maria',
        '  Check this out  ',
        attachmentFile: xfile,
        clientMessageId: 'cid-dm-1',
      );
      final dmMsg = mockRepo.getDirectMessages('maria').last;
      expect(dmMsg.content, 'Check this out');
      expect(dmMsg.attachmentUrl, '/tmp/sample_photo.jpg');
      expect(dmMsg.clientMessageId, 'cid-dm-1');
    });
  });
}
