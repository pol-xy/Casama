// ignore_for_file: annotate_overrides

import 'dart:math';

import 'package:flutter/foundation.dart';

import 'casama_repository.dart';
import 'models.dart';

/// Pre-populated InMemory / Demo Repository matching Casama Mockup Ui.png
class MockRepository extends ChangeNotifier implements CasamaRepository {
  bool _isAuthenticated = true;
  bool get isAuthenticated => _isAuthenticated;

  // Current user (JP)
  UserProfile _currentUser = const UserProfile(
    id: '11111111-1111-1111-1111-111111111111',
    displayName: 'Jon Paul Berana',
    handle: '@jpberana',
    fullName: 'Jon Paul Berana',
    nickname: 'JP',
    age: 21,
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
    hasConsentedTerms: true,
    hasCompletedOnboarding: true,
  );

  final Household _currentHousehold = const Household(
    id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    name: 'Casa 204',
    inviteCode: 'CASA204',
    createdBy: '11111111-1111-1111-1111-111111111111',
  );

  int _kasamaPoints = 120;

  // Member presence list
  final List<MemberPresence> _members = [
    MemberPresence(
      profile: const UserProfile(
        id: '11111111-1111-1111-1111-111111111111',
        displayName: 'You',
        handle: '@jpberana',
        avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      ),
      isHome: true,
      note: 'Studying',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    MemberPresence(
      profile: const UserProfile(
        id: '22222222-2222-2222-2222-222222222222',
        displayName: 'Maria',
        handle: '@maria',
        avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
      ),
      isHome: true,
      note: 'In living room',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    MemberPresence(
      profile: const UserProfile(
        id: '33333333-3333-3333-3333-333333333333',
        displayName: 'Alex',
        handle: '@alex',
        avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=200&q=80',
      ),
      isHome: false,
      note: 'At class until 5 PM',
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    MemberPresence(
      profile: const UserProfile(
        id: '44444444-4444-4444-4444-444444444444',
        displayName: 'Ria',
        handle: '@ria',
        avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=200&q=80',
      ),
      isHome: true,
      note: 'Resting',
      updatedAt: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
  ];

  // Parcels list
  final List<ParcelItem> _parcels = [
    ParcelItem(
      id: 'p1',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      buyerId: '22222222-2222-2222-2222-222222222222',
      buyerName: 'Maria',
      courier: 'Shopee',
      expectedArrival: DateTime.now(),
      paymentType: ParcelPaymentType.cod,
      codAmount: 350.00,
      status: ParcelStatus.expected,
      notes: 'Fragile - Handle with care!',
      availableMemberNames: ['You', 'Alex', 'Ria'],
    ),
    ParcelItem(
      id: 'p2',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      buyerId: '33333333-3333-3333-3333-333333333333',
      buyerName: 'Alex',
      courier: 'Lazada',
      expectedArrival: DateTime.now().add(const Duration(days: 3)),
      paymentType: ParcelPaymentType.paid,
      status: ParcelStatus.expected,
      notes: 'For group use',
      availableMemberNames: ['You', 'Maria'],
    ),
  ];

  // Lost & Found
  final List<LostFoundItem> _items = [
    LostFoundItem(
      id: 'i1',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      type: ItemType.lost,
      title: 'Lost AirPods',
      description: 'Last seen in the study area.',
      imageUrl: 'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=300&q=80',
      status: ItemStatus.open,
      reportedBy: '11111111-1111-1111-1111-111111111111',
      reportedByName: 'Jon Paul',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    LostFoundItem(
      id: 'i2',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      type: ItemType.found,
      title: 'Found Backpack',
      description: 'Unclaimed in common area.',
      imageUrl: 'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80',
      status: ItemStatus.unclaimed,
      reportedBy: '22222222-2222-2222-2222-222222222222',
      reportedByName: 'Maria',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  // Maintenance & Restock
  final List<MaintenanceTask> _tasks = [
    MaintenanceTask(
      id: 't1',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      title: 'Leaking Faucet',
      category: TaskCategory.landlord,
      urgency: TaskUrgency.urgent,
      status: TaskStatus.open,
      assigneeName: 'Alex',
      assigneeAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
      createdByName: 'Jon Paul',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      dueDate: DateTime.now().add(const Duration(days: 1)),
    ),
    MaintenanceTask(
      id: 't2',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      title: 'Buy Drinking Water',
      category: TaskCategory.restock,
      urgency: TaskUrgency.medium,
      status: TaskStatus.open,
      assigneeName: 'Jon Paul',
      assigneeAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=100&q=80',
      createdByName: 'Maria',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      dueDate: DateTime.now(),
    ),
    MaintenanceTask(
      id: 't3',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      title: 'Defrost Freezer',
      category: TaskCategory.diy,
      urgency: TaskUrgency.low,
      status: TaskStatus.open,
      assigneeName: 'Ria',
      assigneeAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=100&q=80',
      createdByName: 'Alex',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      dueDate: DateTime.now().add(const Duration(days: 4)),
    ),
  ];

  // Meet-up Invitation
  MeetUpInvitation _activeMeetUp = MeetUpInvitation(
    id: 'm1',
    activity: 'Study Session 🎓',
    location: 'Dorm Common Area',
    scheduledTime: DateTime.now().add(const Duration(hours: 3)),
    goingCount: 3,
    maybeCount: 1,
    cantMakeCount: 0,
    currentUserResponse: 'going',
  );

  // Group Messages
  final List<ChatMessage> _groupMessages = [
    ChatMessage(
      id: 'msg1',
      senderId: '22222222-2222-2222-2222-222222222222',
      senderName: 'Maria',
      senderAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
      content: "Hey everyone! Who's available to receive my parcel tomorrow?",
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      isCurrentUser: false,
    ),
    ChatMessage(
      id: 'msg2',
      senderId: '11111111-1111-1111-1111-111111111111',
      senderName: 'Jon Paul',
      content: "I'm available after 2 PM! I can receive it. 😊",
      createdAt: DateTime.now().subtract(const Duration(minutes: 42)),
      isCurrentUser: true,
    ),
    ChatMessage(
      id: 'msg3',
      senderId: '33333333-3333-3333-3333-333333333333',
      senderName: 'Alex',
      senderAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
      content: 'Thanks! Just let us know when it arrives.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      isCurrentUser: false,
    ),
  ];

  // Custom Chat Spaces
  final List<ChatSpace> _chatSpaces = [
    ChatSpace(
      id: 'space_grocery',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      name: 'Grocery & Supplies',
      description: 'Coordinate shared kitchen items and bulk grocery shopping.',
      inviteCode: 'SPC-101',
      creatorId: '11111111-1111-1111-1111-111111111111',
      creatorName: 'Jon Paul',
      memberNames: ['You', 'Maria', 'Alex'],
      iconEmoji: '🛒',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      unreadCount: 1,
      messages: [
        ChatMessage(
          id: 'spc_m1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          content: 'We need paper towels and olive oil!',
          createdAt: DateTime.now().subtract(const Duration(hours: 4)),
          isCurrentUser: false,
        ),
      ],
    ),
  ];

  // Notification and message unread tracking
  int _groupChatUnreadCount = 2;
  int _notificationsUnreadCount = 1;

  // Direct messages mapping
  final Map<String, List<ChatMessage>> _directMessages = {
    'maria': [
      ChatMessage(
        id: 'dm_m1',
        senderId: '22222222-2222-2222-2222-222222222222',
        senderName: 'Maria',
        senderAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
        content: 'Hi JP! Did you get the package from the guard?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 50)),
        isCurrentUser: false,
      ),
      ChatMessage(
        id: 'dm_m2',
        senderId: '11111111-1111-1111-1111-111111111111',
        senderName: 'Jon Paul',
        content: 'Got it! 👍 Placed it on the living room table.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 48)),
        isCurrentUser: true,
      ),
    ],
    'alex': [
      ChatMessage(
        id: 'dm_a1',
        senderId: '33333333-3333-3333-3333-333333333333',
        senderName: 'Alex',
        senderAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
        content: 'See you later at the study session!',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        isCurrentUser: false,
      ),
    ],
    'ria': [
      ChatMessage(
        id: 'dm_r1',
        senderId: '44444444-4444-4444-4444-444444444444',
        senderName: 'Ria',
        senderAvatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=100&q=80',
        content: 'Sent a photo 📷 of the groceries we need.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isCurrentUser: false,
      ),
    ],
  };

  // Searchable Casama public directory (external users not yet in household)
  final List<UserProfile> _allCasamaUsers = [
    const UserProfile(
      id: '55555555-5555-5555-5555-555555555555',
      displayName: 'Miguel Ramos',
      handle: '@miguel',
      fullName: 'Miguel Ramos',
      nickname: 'Miggy',
      avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=200&q=80',
    ),
    const UserProfile(
      id: '66666666-6666-6666-6666-666666666666',
      displayName: 'Clara Reyes',
      handle: '@clara',
      fullName: 'Clara Reyes',
      nickname: 'Clara',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=200&q=80',
    ),
    const UserProfile(
      id: '77777777-7777-7777-7777-777777777777',
      displayName: 'Bea Gomez',
      handle: '@bea',
      fullName: 'Bea Gomez',
      nickname: 'Bea',
      avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=200&q=80',
    ),
  ];

  // Bills & Payments
  final List<HouseholdBill> _bills = [
    HouseholdBill(
      id: 'bill_1',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      creatorId: '11111111-1111-1111-1111-111111111111',
      creatorName: 'Jon Paul',
      category: BillCategory.electricity,
      billName: 'Meralco Bill',
      amount: 2500.00,
      deadline: DateTime.now().add(const Duration(days: 5)),
      reminderEnabled: true,
      reminderTiming: ReminderTiming.oneDayBefore,
      recipientType: BillRecipientType.allMembers,
      responsibleMember: 'Jon Paul',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    HouseholdBill(
      id: 'bill_2',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      creatorId: '22222222-2222-2222-2222-222222222222',
      creatorName: 'Maria',
      category: BillCategory.water,
      billName: 'MWSS Water Bill',
      amount: 850.00,
      deadline: DateTime.now().add(const Duration(days: 12)),
      reminderEnabled: true,
      reminderTiming: ReminderTiming.threeDaysBefore,
      recipientType: BillRecipientType.allMembers,
      responsibleMember: 'Maria',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    HouseholdBill(
      id: 'bill_3',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      creatorId: '11111111-1111-1111-1111-111111111111',
      creatorName: 'Jon Paul',
      category: BillCategory.internet,
      billName: 'PLDT Wi-Fi',
      amount: 1299.00,
      deadline: DateTime.now().subtract(const Duration(days: 3)),
      reminderEnabled: false,
      reminderTiming: ReminderTiming.oneDayBefore,
      recipientType: BillRecipientType.allMembers,
      responsibleMember: 'Alex',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    HouseholdBill(
      id: 'bill_4',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      creatorId: '33333333-3333-3333-3333-333333333333',
      creatorName: 'Alex',
      category: BillCategory.rent,
      billName: 'Monthly Rent',
      amount: 15000.00,
      deadline: DateTime.now().add(const Duration(days: 20)),
      reminderEnabled: true,
      reminderTiming: ReminderTiming.oneWeekBefore,
      recipientType: BillRecipientType.allMembers,
      responsibleMember: 'Jon Paul',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      status: BillStatus.paid,
      paidAt: DateTime.now().subtract(const Duration(days: 1)),
      paidByName: 'Jon Paul',
    ),
  ];

  // QuickSnaps (Locket-style photo moments) - starts empty until users snap photos
  final List<QuickSnap> _quickSnaps = [];

  // Household invitations
  final List<HouseholdInvitation> _invitations = [
    HouseholdInvitation(
      id: 'inv_1',
      householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      householdName: 'Casa 204',
      inviterName: 'Jon Paul',
      inviteeEmailOrHandle: '@miguel',
      inviteeName: 'Miguel Ramos',
      status: InvitationStatus.pending,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  // Point audit ledger
  final List<PointAuditEntry> _pointHistory = [
    PointAuditEntry(
      id: 'pa_1',
      title: 'Received Shopee delivery for Maria',
      points: 5,
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      category: 'parcel',
    ),
    PointAuditEntry(
      id: 'pa_2',
      title: 'Completed maintenance task: Buy Drinking Water',
      points: 5,
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      category: 'task',
    ),
    PointAuditEntry(
      id: 'pa_3',
      title: 'Returned lost student ID in lounge',
      points: 3,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      category: 'lost_found',
    ),
    PointAuditEntry(
      id: 'pa_4',
      title: 'Good Kasama onboarding welcome bonus',
      points: 107,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      category: 'bonus',
    ),
  ];

  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();

  // Getters
  UserProfile get currentUser => _currentUser;
  String get effectiveGreetingName => _currentUser.effectiveGreetingName;
  Household get currentHousehold => _currentHousehold;
  int get kasamaPoints => _kasamaPoints;
  List<PointAuditEntry> get pointHistory => List.unmodifiable(_pointHistory);
  NotificationPreferences get notificationPreferences =>
      _notificationPreferences;
  List<MemberPresence> get members => List.unmodifiable(_members);
  List<HouseholdInvitation> get invitations => List.unmodifiable(_invitations);
  List<ParcelItem> get parcels => List.unmodifiable(_parcels);
  List<LostFoundItem> get items => List.unmodifiable(_items);
  List<MaintenanceTask> get tasks => List.unmodifiable(_tasks);
  MeetUpInvitation get activeMeetUp => _activeMeetUp;

  /// Bills getter — auto-detects overdue on read
  List<HouseholdBill> get bills {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.unmodifiable(
      _bills.map((b) {
        if (b.status == BillStatus.paid) return b;
        final dl = DateTime(b.deadline.year, b.deadline.month, b.deadline.day);
        if (dl.isBefore(today)) {
          return b.copyWith(status: BillStatus.overdue);
        }
        return b;
      }).toList(),
    );
  }

  List<ChatMessage> get groupMessages => List.unmodifiable(_groupMessages);
  List<ChatMessage> getDirectMessages(String contactKey) =>
      List.unmodifiable(_directMessages[contactKey.toLowerCase()] ?? []);
  List<ChatSpace> get chatSpaces => List.unmodifiable(_chatSpaces);
  int get groupChatUnreadCount => _groupChatUnreadCount;
  int get unreadNotificationCount => _notificationsUnreadCount;
  int get totalUnreadChatCount =>
      _groupChatUnreadCount +
      _chatSpaces.fold<int>(0, (sum, s) => sum + s.unreadCount);

  // QuickSnap getters
  List<QuickSnap> get quickSnaps => List.unmodifiable(_quickSnaps);
  QuickSnap? get latestQuickSnap =>
      _quickSnaps.isNotEmpty ? _quickSnaps.first : null;

  int get quickSnapStreak {
    if (_quickSnaps.isEmpty) return 0;
    final days =
        _quickSnaps
            .map(
              (s) => DateTime(
                s.createdAt.year,
                s.createdAt.month,
                s.createdAt.day,
              ),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (days.first.difference(today).inDays.abs() > 1) return 0;

    int streak = 1;
    for (int i = 0; i < days.length - 1; i++) {
      if (days[i].difference(days[i + 1]).inDays == 1) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  // Actions
  void login({String? email, String? password}) {
    _isAuthenticated = true;
    notifyListeners();
  }

  void register({required String email, required String password}) {
    _isAuthenticated = true;
    final handle = '@${email.split('@').first}';
    _currentUser = UserProfile(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: email.split('@').first,
      handle: handle,
      fullName: null,
      nickname: null,
      age: null,
      avatarUrl: null,
      hasConsentedTerms: false,
      hasCompletedOnboarding: false,
    );
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    notifyListeners();
  }

  void updateProfile({
    String? displayName,
    String? handle,
    String? fullName,
    String? nickname,
    int? age,
    String? avatarUrl,
    bool clearNickname = false,
    bool clearAge = false,
    bool clearAvatar = false,
  }) {
    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: displayName ?? _currentUser.displayName,
      handle: handle ?? _currentUser.handle,
      fullName: fullName ?? _currentUser.fullName,
      nickname: clearNickname ? null : (nickname ?? _currentUser.nickname),
      age: clearAge ? null : (age ?? _currentUser.age),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? _currentUser.avatarUrl),
      hasConsentedTerms: _currentUser.hasConsentedTerms,
      hasCompletedOnboarding: _currentUser.hasCompletedOnboarding,
    );

    final index = _members.indexWhere((m) => m.profile.id == _currentUser.id);
    if (index != -1) {
      _members[index] = MemberPresence(
        profile: _currentUser,
        isHome: _members[index].isHome,
        note: _members[index].note,
        updatedAt: DateTime.now(),
      );
    }

    notifyListeners();
  }

  void updateNotificationPreferences({
    bool? householdUpdates,
    bool? parcelNotifications,
    bool? taskReminders,
    bool? chatNotifications,
  }) {
    _notificationPreferences = _notificationPreferences.copyWith(
      householdUpdates: householdUpdates,
      parcelNotifications: parcelNotifications,
      taskReminders: taskReminders,
      chatNotifications: chatNotifications,
    );
    notifyListeners();
  }

  void recordTermsConsent() {
    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: _currentUser.displayName,
      handle: _currentUser.handle,
      fullName: _currentUser.fullName,
      nickname: _currentUser.nickname,
      age: _currentUser.age,
      avatarUrl: _currentUser.avatarUrl,
      hasConsentedTerms: true,
      hasCompletedOnboarding: _currentUser.hasCompletedOnboarding,
    );
    notifyListeners();
  }

  void completeOnboardingTutorial() {
    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: _currentUser.displayName,
      handle: _currentUser.handle,
      fullName: _currentUser.fullName,
      nickname: _currentUser.nickname,
      age: _currentUser.age,
      avatarUrl: _currentUser.avatarUrl,
      hasConsentedTerms: _currentUser.hasConsentedTerms,
      hasCompletedOnboarding: true,
    );
    notifyListeners();
  }

  void updatePresence({required bool isHome, String? note}) {
    final index = _members.indexWhere((m) => m.profile.id == _currentUser.id);
    if (index != -1) {
      _members[index] = MemberPresence(
        profile: _members[index].profile,
        isHome: isHome,
        note: note ?? _members[index].note,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void receiveParcel(String parcelId) {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index != -1) {
      final p = _parcels[index];
      if (p.status == ParcelStatus.received) {
        return; // Prevent duplicate rewards and updates
      }
      _parcels[index] = ParcelItem(
        id: p.id,
        householdId: p.householdId,
        buyerId: p.buyerId,
        buyerName: p.buyerName,
        courier: p.courier,
        expectedArrival: p.expectedArrival,
        paymentType: p.paymentType,
        codAmount: p.codAmount,
        status: ParcelStatus.received,
        notes: p.notes,
        availableMemberNames: p.availableMemberNames,
      );
      _kasamaPoints += 5;
      _pointHistory.insert(
        0,
        PointAuditEntry(
          id: 'pa_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Received parcel: ${p.courier} for ${p.buyerName}',
          points: 5,
          timestamp: DateTime.now(),
          category: 'parcel',
        ),
      );
      notifyListeners();
    }
  }

  void addParcel({
    required String courier,
    required DateTime arrival,
    required ParcelPaymentType paymentType,
    double? codAmount,
    String? notes,
  }) {
    _parcels.insert(
      0,
      ParcelItem(
        id: 'p_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        buyerId: _currentUser.id,
        buyerName: _currentUser.displayName,
        courier: courier,
        expectedArrival: arrival,
        paymentType: paymentType,
        codAmount: codAmount,
        status: ParcelStatus.expected,
        notes: notes,
        availableMemberNames: [_currentUser.displayName],
      ),
    );
    notifyListeners();
  }

  void completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final t = _tasks[index];
      if (t.status == TaskStatus.done) {
        return; // Prevent duplicate rewards and updates
      }
      _tasks[index] = MaintenanceTask(
        id: t.id,
        householdId: t.householdId,
        title: t.title,
        category: t.category,
        urgency: t.urgency,
        status: TaskStatus.done,
        assigneeName: t.assigneeName,
        assigneeAvatar: t.assigneeAvatar,
        createdByName: t.createdByName,
        createdAt: t.createdAt,
        dueDate: t.dueDate,
      );
      final pts = (t.category == TaskCategory.restock ? 2 : 5);
      _kasamaPoints += pts;
      _pointHistory.insert(
        0,
        PointAuditEntry(
          id: 'pa_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Completed chore: ${t.title}',
          points: pts,
          timestamp: DateTime.now(),
          category: 'task',
        ),
      );
      notifyListeners();
    }
  }

  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? assigneeName,
  }) {
    _tasks.insert(
      0,
      MaintenanceTask(
        id: 't_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        title: title,
        category: category,
        urgency: urgency,
        status: TaskStatus.open,
        assigneeName: assigneeName,
        createdByName: _currentUser.displayName,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? imageUrl,
  }) {
    _items.insert(
      0,
      LostFoundItem(
        id: 'i_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        type: type,
        title: title,
        description: description,
        imageUrl: imageUrl,
        status: type == ItemType.lost ? ItemStatus.open : ItemStatus.unclaimed,
        reportedBy: _currentUser.id,
        reportedByName: _currentUser.displayName,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void markGroupChatAsRead() {
    if (_groupChatUnreadCount > 0) {
      _groupChatUnreadCount = 0;
      notifyListeners();
    }
  }

  void markSpaceChatAsRead(String spaceId) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1 && _chatSpaces[idx].unreadCount > 0) {
      _chatSpaces[idx] = _chatSpaces[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    if (_notificationsUnreadCount > 0) {
      _notificationsUnreadCount = 0;
      notifyListeners();
    }
  }

  ChatSpace createChatSpace({
    required String name,
    required String description,
    String iconEmoji = '💬',
    required List<String> initialMembers,
  }) {
    final code = 'SPC-${100 + _chatSpaces.length + 1}';
    final allMembers = <String>{'You', ...initialMembers}.toList();
    final newSpace = ChatSpace(
      id: 'space_${DateTime.now().millisecondsSinceEpoch}',
      householdId: _currentHousehold.id,
      name: name,
      description: description,
      inviteCode: code,
      creatorId: _currentUser.id,
      creatorName: _currentUser.displayName,
      memberNames: allMembers,
      iconEmoji: iconEmoji,
      createdAt: DateTime.now(),
      unreadCount: 0,
      messages: [
        ChatMessage(
          id: 'spc_init_${DateTime.now().millisecondsSinceEpoch}',
          senderId: _currentUser.id,
          senderName: _currentUser.displayName,
          content:
              'Welcome to $name! 🎉 Use invite code $code to invite other housemates.',
          inviteCode: code,
          inviteSpaceName: name,
          createdAt: DateTime.now(),
          isCurrentUser: true,
        ),
      ],
    );
    _chatSpaces.insert(0, newSpace);
    notifyListeners();
    return newSpace;
  }

  ChatSpace? joinChatSpaceByCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    final idx = _chatSpaces.indexWhere(
      (s) => s.inviteCode.toUpperCase() == cleanCode,
    );
    if (idx != -1) {
      final space = _chatSpaces[idx];
      if (!space.memberNames.contains('You')) {
        final updatedMembers = [...space.memberNames, 'You'];
        final updated = space.copyWith(memberNames: updatedMembers);
        _chatSpaces[idx] = updated;
        notifyListeners();
        return updated;
      }
      return space;
    }
    return null;
  }

  void addMemberToSpace(String spaceId, String memberName) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _chatSpaces[idx];
      if (!space.memberNames.contains(memberName)) {
        final updated = [...space.memberNames, memberName];
        _chatSpaces[idx] = space.copyWith(memberNames: updated);
        notifyListeners();
      }
    }
  }

  void sendSpaceMessage(
    String spaceId,
    String content, {
    String? mediaUrl,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _chatSpaces[idx];
      final newMsg = ChatMessage(
        id: 'spc_msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: content,
        mediaUrl: mediaUrl,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      );
      final updatedMessages = [...space.messages, newMsg];
      _chatSpaces[idx] = space.copyWith(messages: updatedMessages);
      notifyListeners();
    }
  }

  void shareInviteCodeToGroupChat({
    required String code,
    required String title,
  }) {
    _groupMessages.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: '🔑 $title Invite Code: $code',
        inviteCode: code,
        inviteSpaceName: title,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );
    notifyListeners();
  }

  void shareInviteCodeToDirectChat({
    required String contactKey,
    required String code,
    required String title,
  }) {
    final key = contactKey.toLowerCase();
    if (!_directMessages.containsKey(key)) {
      _directMessages[key] = [];
    }
    _directMessages[key]!.add(
      ChatMessage(
        id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: '🔑 $title Invite Code: $code',
        inviteCode: code,
        inviteSpaceName: title,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );
    notifyListeners();
  }

  void sendChatMessage(
    String content, {
    String? mediaUrl,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    _groupMessages.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: content,
        mediaUrl: mediaUrl,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );
    notifyListeners();
  }

  void respondMeetUp(String response) {
    int g = _activeMeetUp.goingCount;
    int m = _activeMeetUp.maybeCount;
    int c = _activeMeetUp.cantMakeCount;

    if (_activeMeetUp.currentUserResponse == 'going') g--;
    if (_activeMeetUp.currentUserResponse == 'maybe') m--;
    if (_activeMeetUp.currentUserResponse == 'cant_make_it') c--;

    if (response == 'going') g++;
    if (response == 'maybe') m++;
    if (response == 'cant_make_it') c++;

    _activeMeetUp = MeetUpInvitation(
      id: _activeMeetUp.id,
      activity: _activeMeetUp.activity,
      location: _activeMeetUp.location,
      scheduledTime: _activeMeetUp.scheduledTime,
      goingCount: max(0, g),
      maybeCount: max(0, m),
      cantMakeCount: max(0, c),
      currentUserResponse: response,
    );
    notifyListeners();
  }

  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
    bool autoReply = false,
  }) {
    final key = contactKey.toLowerCase();
    if (!_directMessages.containsKey(key)) {
      _directMessages[key] = [];
    }
    _directMessages[key]!.add(
      ChatMessage(
        id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: content,
        mediaUrl: mediaUrl,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );
    notifyListeners();

    if (autoReply) {
      // Trigger realistic housemate reply for high interactivity
      Future.delayed(const Duration(milliseconds: 1100), () {
        final housemate = _members.firstWhere(
          (m) =>
              m.profile.displayName.toLowerCase().contains(key) ||
              m.profile.handle.toLowerCase().contains(key),
          orElse: () => _members.first,
        );

        String replyText = 'Got your message! Thanks for checking in 😊';
        final lower = content.toLowerCase();
        if (lower.contains('parcel') ||
            lower.contains('package') ||
            lower.contains('delivery')) {
          replyText = 'Thanks for the heads up! I will pick it up as soon as I get home 📦';
        } else if (lower.contains('clean') ||
            lower.contains('trash') ||
            lower.contains('chore')) {
          replyText = 'On it! Doing my turn this evening 👍';
        } else if (lower.contains('meet') ||
            lower.contains('dinner') ||
            lower.contains('food')) {
          replyText = 'Count me in! What time should we gather? 🍕';
        } else if (lower.contains('hello') ||
            lower.contains('hi') ||
            lower.contains('hey')) {
          replyText = 'Hey there! Hope your day is going well! ✨';
        }

        if (_directMessages.containsKey(key)) {
          _directMessages[key]!.add(
            ChatMessage(
              id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
              senderId: housemate.profile.id,
              senderName: housemate.profile.displayName,
              senderAvatar: housemate.profile.avatarUrl,
              content: replyText,
              createdAt: DateTime.now(),
              isCurrentUser: false,
            ),
          );
          notifyListeners();
        }
      });
    }
  }

  void borrowItem(String itemId) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      _items[index] = LostFoundItem(
        id: item.id,
        householdId: item.householdId,
        type: item.type,
        title: item.title,
        description: item.description,
        imageUrl: item.imageUrl,
        status: ItemStatus.claimed,
        reportedBy: item.reportedBy,
        reportedByName: item.reportedByName,
        createdAt: item.createdAt,
      );
      notifyListeners();
    }
  }

  void claimItem(String itemId) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      _items[index] = LostFoundItem(
        id: item.id,
        householdId: item.householdId,
        type: item.type,
        title: item.title,
        description: item.description,
        imageUrl: item.imageUrl,
        status: ItemStatus.claimed,
        reportedBy: item.reportedBy,
        reportedByName: item.reportedByName,
        createdAt: item.createdAt,
      );
      notifyListeners();
    }
  }

  void returnItem(String itemId) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      final item = _items[index];
      _items[index] = LostFoundItem(
        id: item.id,
        householdId: item.householdId,
        type: item.type,
        title: item.title,
        description: item.description,
        imageUrl: item.imageUrl,
        status: ItemStatus.returned,
        reportedBy: item.reportedBy,
        reportedByName: item.reportedByName,
        createdAt: item.createdAt,
      );
      _kasamaPoints += 3; // +3 points for returning lost/found item!
      _pointHistory.insert(
        0,
        PointAuditEntry(
          id: 'pa_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Returned item: ${item.title}',
          points: 3,
          timestamp: DateTime.now(),
          category: 'lost_found',
        ),
      );
      notifyListeners();
    }
  }

  void toggleParcelAvailability(String parcelId) {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index != -1) {
      final p = _parcels[index];
      final currentList = List<String>.from(p.availableMemberNames);
      final myName = _currentUser.displayName.split(' ').first;

      if (currentList.contains('You') || currentList.contains(myName)) {
        currentList.remove('You');
        currentList.remove(myName);
      } else {
        currentList.add('You');
      }

      // Check if all non-buyer members are unavailable
      final isConflict = currentList.isEmpty;

      _parcels[index] = ParcelItem(
        id: p.id,
        householdId: p.householdId,
        buyerId: p.buyerId,
        buyerName: p.buyerName,
        courier: p.courier,
        expectedArrival: p.expectedArrival,
        paymentType: p.paymentType,
        codAmount: p.codAmount,
        currency: p.currency,
        status: p.status,
        notes: p.notes,
        availableMemberNames: currentList,
        isAllUnavailable: isConflict,
      );
      notifyListeners();
    }
  }

  // ==========================================
  // PART 5: Housemate Management & Invitations
  // ==========================================

  List<UserProfile> searchUsers(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    return _allCasamaUsers.where((u) {
      final matchesHandle = u.handle.toLowerCase().contains(q);
      final matchesName =
          u.displayName.toLowerCase().contains(q) ||
          (u.fullName != null && u.fullName!.toLowerCase().contains(q));
      final alreadyMember = _members.any((m) => m.profile.id == u.id);
      return (matchesHandle || matchesName) && !alreadyMember;
    }).toList();
  }

  bool sendInvitation({
    required String inviteeEmailOrHandle,
    String? inviteeName,
  }) {
    final cleanTarget = inviteeEmailOrHandle.trim().toLowerCase();
    if (cleanTarget.isEmpty) return false;

    // Check if user is already a member
    final alreadyMember = _members.any(
      (m) =>
          m.profile.handle.toLowerCase() == cleanTarget ||
          m.profile.displayName.toLowerCase() == cleanTarget,
    );
    if (alreadyMember) return false;

    // Check if an invitation is already pending
    final alreadyPending = _invitations.any(
      (inv) =>
          inv.inviteeEmailOrHandle.toLowerCase() == cleanTarget &&
          inv.status == InvitationStatus.pending,
    );
    if (alreadyPending) return false;

    // Lookup matching profile name if not provided
    final matchedUser = _allCasamaUsers.cast<UserProfile?>().firstWhere(
      (u) => u?.handle.toLowerCase() == cleanTarget,
      orElse: () => null,
    );

    _invitations.insert(
      0,
      HouseholdInvitation(
        id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        householdName: _currentHousehold.name,
        inviterName: _currentUser.displayName,
        inviteeEmailOrHandle: inviteeEmailOrHandle.trim(),
        inviteeName:
            inviteeName ??
            matchedUser?.displayName ??
            inviteeEmailOrHandle.trim(),
        status: InvitationStatus.pending,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return true;
  }

  bool acceptInvitation(String invitationId) {
    final index = _invitations.indexWhere((inv) => inv.id == invitationId);
    if (index == -1) return false;

    final inv = _invitations[index];
    _invitations[index] = HouseholdInvitation(
      id: inv.id,
      householdId: inv.householdId,
      householdName: inv.householdName,
      inviterName: inv.inviterName,
      inviteeEmailOrHandle: inv.inviteeEmailOrHandle,
      inviteeName: inv.inviteeName,
      status: InvitationStatus.accepted,
      createdAt: inv.createdAt,
    );

    // Look up or construct user profile for the new housemate
    final matchedUser = _allCasamaUsers.cast<UserProfile?>().firstWhere(
      (u) => u?.handle.toLowerCase() == inv.inviteeEmailOrHandle.toLowerCase(),
      orElse: () => null,
    );

    final newProfile =
        matchedUser ??
        UserProfile(
          id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
          displayName: inv.inviteeName ?? inv.inviteeEmailOrHandle,
          handle: inv.inviteeEmailOrHandle.startsWith('@')
              ? inv.inviteeEmailOrHandle
              : '@${inv.inviteeEmailOrHandle.split('@').first}',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
        );

    if (!_members.any((m) => m.profile.id == newProfile.id)) {
      _members.add(
        MemberPresence(
          profile: newProfile,
          isHome: true,
          note: 'Just joined the household 🎉',
          updatedAt: DateTime.now(),
        ),
      );
    }

    notifyListeners();
    return true;
  }

  bool declineInvitation(String invitationId) {
    final index = _invitations.indexWhere((inv) => inv.id == invitationId);
    if (index == -1) return false;

    final inv = _invitations[index];
    _invitations[index] = HouseholdInvitation(
      id: inv.id,
      householdId: inv.householdId,
      householdName: inv.householdName,
      inviterName: inv.inviterName,
      inviteeEmailOrHandle: inv.inviteeEmailOrHandle,
      inviteeName: inv.inviteeName,
      status: InvitationStatus.declined,
      createdAt: inv.createdAt,
    );
    notifyListeners();
    return true;
  }

  bool isHousemateAuthorized(String contactKey) {
    final key = contactKey.toLowerCase().replaceAll('@', '').trim();
    return _members.any((m) {
      final mName = m.profile.displayName.toLowerCase().trim();
      final mHandle = m.profile.handle.toLowerCase().replaceAll('@', '').trim();
      final mId = m.profile.id.toLowerCase().trim();
      return mName == key || mHandle == key || mId == key;
    });
  }

  void resetMembersForNewUserTest() {
    _members.retainWhere((m) => m.profile.id == _currentUser.id);
    notifyListeners();
  }

  // ==========================================
  // BILLS & PAYMENTS
  // ==========================================

  void addBill({
    required BillCategory category,
    String? customCategoryLabel,
    String? billName,
    double? amount,
    required DateTime deadline,
    String? notes,
    bool reminderEnabled = true,
    ReminderTiming reminderTiming = ReminderTiming.oneDayBefore,
    BillRecipientType recipientType = BillRecipientType.allMembers,
    List<String> selectedRecipientNames = const [],
    String? responsibleMember,
  }) {
    _bills.insert(
      0,
      HouseholdBill(
        id: 'bill_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        creatorId: _currentUser.id,
        creatorName: _currentUser.displayName,
        category: category,
        customCategoryLabel: customCategoryLabel,
        billName: billName,
        amount: amount,
        deadline: deadline,
        notes: notes,
        reminderEnabled: reminderEnabled,
        reminderTiming: reminderTiming,
        recipientType: recipientType,
        selectedRecipientNames: selectedRecipientNames,
        responsibleMember: responsibleMember ?? _currentUser.displayName,
        createdAt: DateTime.now(),
      ),
    );
    // Trigger in-app reminder notification for newly added bill
    if (reminderEnabled) {
      _notificationsUnreadCount++;
    }
    notifyListeners();
  }

  void updateBill({
    required String billId,
    BillCategory? category,
    String? customCategoryLabel,
    String? billName,
    double? amount,
    DateTime? deadline,
    String? notes,
    bool? reminderEnabled,
    ReminderTiming? reminderTiming,
    BillRecipientType? recipientType,
    List<String>? selectedRecipientNames,
    String? responsibleMember,
  }) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    // Only creator can edit
    if (_bills[idx].creatorId != _currentUser.id) return;
    _bills[idx] = _bills[idx].copyWith(
      category: category,
      customCategoryLabel: customCategoryLabel,
      billName: billName,
      amount: amount,
      deadline: deadline,
      notes: notes,
      reminderEnabled: reminderEnabled,
      reminderTiming: reminderTiming,
      recipientType: recipientType,
      selectedRecipientNames: selectedRecipientNames,
      responsibleMember: responsibleMember,
    );
    notifyListeners();
  }

  /// Any household member can mark a bill as paid. Awards +5 Kasama Points.
  void markBillPaid(String billId) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final bill = _bills[idx];
    if (bill.status == BillStatus.paid) return; // prevent duplicate rewards
    _bills[idx] = bill.copyWith(
      status: BillStatus.paid,
      paidAt: DateTime.now(),
      paidByName: _currentUser.displayName,
    );
    _kasamaPoints += 5;
    _pointHistory.insert(
      0,
      PointAuditEntry(
        id: 'pa_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Paid bill: ${bill.effectiveBillName}',
        points: 5,
        timestamp: DateTime.now(),
        category: 'bill',
      ),
    );
    notifyListeners();
  }

  /// Reopen a mistakenly paid bill (reverts to unpaid). Creator only.
  void reopenBill(String billId) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    _bills[idx] = HouseholdBill(
      id: _bills[idx].id,
      householdId: _bills[idx].householdId,
      creatorId: _bills[idx].creatorId,
      creatorName: _bills[idx].creatorName,
      category: _bills[idx].category,
      customCategoryLabel: _bills[idx].customCategoryLabel,
      billName: _bills[idx].billName,
      amount: _bills[idx].amount,
      deadline: _bills[idx].deadline,
      notes: _bills[idx].notes,
      status: BillStatus.unpaid,
      reminderEnabled: _bills[idx].reminderEnabled,
      reminderTiming: _bills[idx].reminderTiming,
      recipientType: _bills[idx].recipientType,
      selectedRecipientNames: _bills[idx].selectedRecipientNames,
      responsibleMember: _bills[idx].responsibleMember,
      createdAt: _bills[idx].createdAt,
    );
    notifyListeners();
  }

  /// Delete a bill. Only creator can delete.
  void deleteBill(String billId) {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    if (_bills[idx].creatorId != _currentUser.id) return;
    _bills.removeAt(idx);
    notifyListeners();
  }

  // ==========================================
  // QUICKSNAPS (LOCKET-STYLE)
  // ==========================================

  void sendQuickSnap({
    required String imageUrl,
    String? caption,
    QuickSnapRecipientType recipientType = QuickSnapRecipientType.everyone,
    List<String> recipientNames = const [],
  }) {
    final snap = QuickSnap(
      id: 'snap_${DateTime.now().millisecondsSinceEpoch}',
      householdId: _currentHousehold.id,
      senderId: _currentUser.id,
      senderName: _currentUser.displayName,
      senderAvatar: _currentUser.avatarUrl,
      imageUrl: imageUrl,
      caption: caption,
      recipientType: recipientType,
      recipientNames: recipientNames,
      createdAt: DateTime.now(),
      reactions: [],
      comments: [],
    );
    _quickSnaps.insert(0, snap);

    // Also share a quick notification/chat message so dormmates see it
    final targetLabel = recipientType == QuickSnapRecipientType.everyone
        ? 'everyone'
        : recipientNames.join(', ');
    _groupMessages.add(
      ChatMessage(
        id: 'msg_snap_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        senderAvatar: _currentUser.avatarUrl,
        content:
            '📸 Shared a QuickSnap${caption != null && caption.isNotEmpty ? ': "$caption"' : ''} (to $targetLabel)',
        mediaUrl: imageUrl,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );

    notifyListeners();
  }

  void reactToQuickSnap(String snapId, String emoji) {
    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx == -1) return;
    final current = _quickSnaps[idx];
    final newReaction = QuickSnapReaction(
      emoji: emoji,
      userId: _currentUser.id,
      userName: _currentUser.displayName,
      createdAt: DateTime.now(),
    );
    _quickSnaps[idx] = current.copyWith(
      reactions: [...current.reactions, newReaction],
    );
    notifyListeners();
  }

  void commentOnQuickSnap(String snapId, String text) {
    if (text.trim().isEmpty) return;
    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx == -1) return;
    final current = _quickSnaps[idx];
    final newComment = QuickSnapComment(
      id: 'sc_${DateTime.now().millisecondsSinceEpoch}',
      userId: _currentUser.id,
      userName: _currentUser.displayName,
      userAvatar: _currentUser.avatarUrl,
      text: text.trim(),
      createdAt: DateTime.now(),
    );
    _quickSnaps[idx] = current.copyWith(
      comments: [...current.comments, newComment],
    );
    notifyListeners();
  }

  void deleteQuickSnap(String snapId) {
    _quickSnaps.removeWhere(
      (s) => s.id == snapId && s.senderId == _currentUser.id,
    );
    notifyListeners();
  }
}
