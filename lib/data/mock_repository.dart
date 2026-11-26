// ignore_for_file: annotate_overrides

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'casama_repository.dart';
import 'models.dart';

/// Pre-populated InMemory / Demo Repository matching Casama Mockup Ui.png
class MockRepository extends ChangeNotifier implements CasamaRepository {
  final bool loadSeedData;
  final Duration reactionDebounceDuration;

  MockRepository({
    this.loadSeedData = true,
    this.reactionDebounceDuration = const Duration(milliseconds: 1200),
  }) {
    if (loadSeedData) {
      _loadInitialSeedData();
    }
    _ensureCurrentWorkspaceRegistered();
  }

  MockRepository.clean({
    this.reactionDebounceDuration = const Duration(milliseconds: 1200),
  }) : loadSeedData = false {
    _ensureCurrentWorkspaceRegistered();
  }

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasActiveHousehold => _currentHousehold.id.isNotEmpty;
  DateTime? _lastRouletteSpinAt;
  DateTime? get lastRouletteSpinAt => _lastRouletteSpinAt;
  RepositoryActionError? consumePendingError() => null;

  Future<void> restoreSession() async {}

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    login(email: email, password: password);
  }

  Future<bool> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    register(email: email, password: password);
    return true;
  }

  Future<void> resendSignupVerificationEmail(String email) async {}

  Future<void> signInWithDemoAccount() async {
    login();
  }

  Future<void> signOut() async {
    await flushPendingSnapReactions();
    logout();
  }

  final Map<String, _MockHouseholdWorkspace> _workspaces = {};
  final List<String> _householdOrder = [];

  void _ensureCurrentWorkspaceRegistered() {
    if (_currentHousehold.id.isEmpty) return;
    if (!_householdOrder.contains(_currentHousehold.id)) {
      _householdOrder.add(_currentHousehold.id);
    }
    _saveCurrentWorkspace();
  }

  void _saveCurrentWorkspace() {
    if (_currentHousehold.id.isEmpty) return;
    _workspaces[_currentHousehold.id] = _MockHouseholdWorkspace(
      household: _currentHousehold.copyWith(memberCount: _members.length),
      kasamaPoints: _kasamaPoints,
      groupChatUnreadCount: _groupChatUnreadCount,
      notifications: List<HouseholdNotificationItem>.from(_notifications),
      lastRouletteSpinAt: _lastRouletteSpinAt,
      members: List<MemberPresence>.from(_members),
      parcels: List<ParcelItem>.from(_parcels),
      items: List<LostFoundItem>.from(_items),
      tasks: List<MaintenanceTask>.from(_tasks),
      bills: List<HouseholdBill>.from(_bills),
      meetUpInvitations: List<MeetUpInvitation>.from(_meetUpInvitations),
      activeMeetUp: _activeMeetUp,
      groupMessages: List<ChatMessage>.from(_groupMessages),
      chatSpaces: List<ChatSpace>.from(_chatSpaces),
      directMessages: {
        for (final entry in _directMessages.entries)
          entry.key: List<ChatMessage>.from(entry.value),
      },
      directUnreadCounts: Map<String, int>.from(_directUnreadCounts),
      quickSnaps: List<QuickSnap>.from(_quickSnaps),
      invitations: List<HouseholdInvitation>.from(_invitations),
      pointHistory: List<PointAuditEntry>.from(_pointHistory),
    );
  }

  void _loadWorkspace(_MockHouseholdWorkspace ws) {
    _currentHousehold = ws.household.copyWith(memberCount: ws.members.length);
    _kasamaPoints = ws.kasamaPoints;
    _groupChatUnreadCount = ws.groupChatUnreadCount;
    _notifications
      ..clear()
      ..addAll(ws.notifications);
    _lastRouletteSpinAt = ws.lastRouletteSpinAt;
    _members
      ..clear()
      ..addAll(ws.members);
    _parcels
      ..clear()
      ..addAll(ws.parcels);
    _items
      ..clear()
      ..addAll(ws.items);
    _tasks
      ..clear()
      ..addAll(ws.tasks);
    _bills
      ..clear()
      ..addAll(ws.bills);
    _meetUpInvitations
      ..clear()
      ..addAll(ws.meetUpInvitations);
    _activeMeetUp = ws.activeMeetUp;
    _groupMessages
      ..clear()
      ..addAll(ws.groupMessages);
    _chatSpaces
      ..clear()
      ..addAll(ws.chatSpaces);
    _directMessages
      ..clear()
      ..addAll({
        for (final entry in ws.directMessages.entries)
          entry.key: List<ChatMessage>.from(entry.value),
      });
    _directUnreadCounts
      ..clear()
      ..addAll(ws.directUnreadCounts);
    _quickSnaps
      ..clear()
      ..addAll(ws.quickSnaps);
    _invitations
      ..clear()
      ..addAll(ws.invitations);
    _pointHistory
      ..clear()
      ..addAll(ws.pointHistory);
  }

  String _generateMockInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    final existingCodes = {
      _currentHousehold.inviteCode.toUpperCase(),
      ..._workspaces.values.map((w) => w.household.inviteCode.toUpperCase()),
    };
    while (true) {
      final candidate = List.generate(
        6,
        (_) => chars[rand.nextInt(chars.length)],
      ).join();
      if (!existingCodes.contains(candidate)) {
        return candidate;
      }
    }
  }

  List<Household> get userHouseholds {
    if (_householdOrder.isEmpty) {
      return hasActiveHousehold
          ? [_currentHousehold.copyWith(memberCount: _members.length)]
          : const [];
    }
    final result = <Household>[];
    for (final id in _householdOrder) {
      if (id == _currentHousehold.id) {
        result.add(_currentHousehold.copyWith(memberCount: _members.length));
      } else {
        final ws = _workspaces[id];
        if (ws != null) {
          result.add(ws.household.copyWith(memberCount: ws.members.length));
        }
      }
    }
    return List.unmodifiable(result);
  }

  Future<void> refreshUserHouseholds() async {}

  Future<void> switchHousehold(String householdId) async {
    if (householdId == _currentHousehold.id) return;
    final target = _workspaces[householdId];
    if (target == null) {
      throw StateError('Household not found.');
    }
    _flushAllPendingSnapReactionsSync(notify: false);
    _saveCurrentWorkspace();
    _loadWorkspace(target);
    notifyListeners();
  }

  Future<Household> createHousehold({required String name}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Household name cannot be empty.');
    }
    if (_currentHousehold.id.isNotEmpty) {
      _saveCurrentWorkspace();
    }

    final newId =
        'hh_${_householdOrder.length + 1}_${DateTime.now().microsecondsSinceEpoch}';
    final created = Household(
      id: newId,
      name: trimmed,
      inviteCode: _generateMockInviteCode(),
      createdBy: _currentUser.id,
      memberCount: 1,
    );

    _currentHousehold = created;
    _kasamaPoints = 0;
    _groupChatUnreadCount = 0;
    _notifications.clear();
    _lastRouletteSpinAt = null;
    _members
      ..clear()
      ..add(
        MemberPresence(
          profile: _currentUser,
          isHome: true,
          updatedAt: DateTime.now(),
        ),
      );
    _parcels.clear();
    _items.clear();
    _tasks.clear();
    _bills.clear();
    _meetUpInvitations.clear();
    _activeMeetUp = MeetUpInvitation(
      id: 'placeholder_$newId',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
    _groupMessages.clear();
    _chatSpaces.clear();
    _directMessages.clear();
    _directUnreadCounts.clear();
    _quickSnaps.clear();
    _invitations.clear();
    _pointHistory.clear();

    _householdOrder.remove(newId);
    _householdOrder.insert(0, newId);
    _saveCurrentWorkspace();
    notifyListeners();
    return _currentHousehold;
  }

  Future<Household> joinHouseholdByCode(String inviteCode) async {
    final clean = inviteCode.trim().toUpperCase();
    if (clean.isEmpty) {
      throw ArgumentError('Please enter an invite code.');
    }

    for (final entry in _workspaces.entries) {
      if (entry.value.household.inviteCode.toUpperCase() == clean) {
        await switchHousehold(entry.key);
        return _currentHousehold;
      }
    }

    if (_currentHousehold.inviteCode.toUpperCase() == clean &&
        _currentHousehold.id.isNotEmpty) {
      _ensureCurrentWorkspaceRegistered();
      notifyListeners();
      return _currentHousehold;
    }

    if (_currentHousehold.id.isNotEmpty) {
      _saveCurrentWorkspace();
    }

    final newId = 'hh_join_$clean';
    final joined = Household(
      id: newId,
      name: clean == 'CASA204' ? 'Casa 204' : 'Household $clean',
      inviteCode: clean,
      createdBy: _currentUser.id,
      memberCount: 1,
    );

    _currentHousehold = joined;
    _kasamaPoints = 0;
    _groupChatUnreadCount = 0;
    _notifications.clear();
    _lastRouletteSpinAt = null;
    _members
      ..clear()
      ..add(
        MemberPresence(
          profile: _currentUser,
          isHome: true,
          updatedAt: DateTime.now(),
        ),
      );
    _parcels.clear();
    _items.clear();
    _tasks.clear();
    _bills.clear();
    _meetUpInvitations.clear();
    _activeMeetUp = MeetUpInvitation(
      id: 'placeholder_$newId',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
    _groupMessages.clear();
    _chatSpaces.clear();
    _directMessages.clear();
    _directUnreadCounts.clear();
    _quickSnaps.clear();
    _invitations.clear();
    _pointHistory.clear();

    _householdOrder.remove(newId);
    _householdOrder.insert(0, newId);
    _saveCurrentWorkspace();
    notifyListeners();
    return _currentHousehold;
  }

  List<LeaderboardStanding> get leaderboardStandings {
    if (_currentHousehold.id == 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' &&
        _members.length > 1) {
      return [
        LeaderboardStanding(
          userId: _currentUser.id,
          displayName: _currentUser.fullName ?? _currentUser.displayName,
          handle: _currentUser.handle,
          avatarUrl: _currentUser.avatarUrl,
          points: _kasamaPoints,
          isCurrentUser: true,
        ),
        LeaderboardStanding(
          userId: '22222222-2222-2222-2222-222222222222',
          displayName: 'Maria Santos',
          handle: '@maria',
          points: 85 + (_memberBonusPoints['22222222-2222-2222-2222-222222222222'] ?? 0),
          isCurrentUser: _currentUser.id == '22222222-2222-2222-2222-222222222222',
        ),
        LeaderboardStanding(
          userId: '33333333-3333-3333-3333-333333333333',
          displayName: 'Alex Rivera',
          handle: '@alex',
          points: 65 + (_memberBonusPoints['33333333-3333-3333-3333-333333333333'] ?? 0),
          isCurrentUser: _currentUser.id == '33333333-3333-3333-3333-333333333333',
        ),
        LeaderboardStanding(
          userId: '44444444-4444-4444-4444-444444444444',
          displayName: 'Ria Garcia',
          handle: '@ria',
          points: 55 + (_memberBonusPoints['44444444-4444-4444-4444-444444444444'] ?? 0),
          isCurrentUser: _currentUser.id == '44444444-4444-4444-4444-444444444444',
        ),
      ]..sort((a, b) => b.points.compareTo(a.points));
    }

    return _members.map((m) {
      final isMe = m.profile.id == _currentUser.id;
      return LeaderboardStanding(
        userId: m.profile.id,
        displayName: isMe
            ? (_currentUser.fullName ?? _currentUser.displayName)
            : (m.profile.fullName ?? m.profile.displayName),
        handle: m.profile.handle,
        avatarUrl: m.profile.avatarUrl,
        points: isMe ? _kasamaPoints : (_memberBonusPoints[m.profile.id] ?? 0),
        isCurrentUser: isMe,
      );
    }).toList()
      ..sort((a, b) => b.points.compareTo(a.points));
  }

  final Map<String, int> _memberBonusPoints = {};
  int _nextIdSeq = 0;

  static const String _seededPrimaryUserId =
      '11111111-1111-1111-1111-111111111111';
  static const Map<String, int> _seededMemberBasePoints = {
    '22222222-2222-2222-2222-222222222222': 85,
    '33333333-3333-3333-3333-333333333333': 65,
    '44444444-4444-4444-4444-444444444444': 55,
  };

  int pointsForUser(String userId) {
    if (_currentHousehold.id == 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11') {
      if (userId == _seededPrimaryUserId) return _kasamaPoints;
      if (_seededMemberBasePoints.containsKey(userId)) {
        return _seededMemberBasePoints[userId]! +
            (_memberBonusPoints[userId] ?? 0);
      }
    }
    if (userId == _currentUser.id) return _kasamaPoints;
    return _memberBonusPoints[userId] ?? 0;
  }

  /// Switches the active user in tests to verify multi-user workflows cleanly.
  void setCurrentUserForTest(String userId) {
    MemberPresence? found;
    for (final m in _members) {
      if (m.profile.id == userId) {
        found = m;
        break;
      }
    }
    if (found == null) return;
    final p = found.profile;
    final normalizedName =
        p.id == _seededPrimaryUserId && p.displayName == 'You'
        ? 'Jon Paul Berana'
        : p.displayName;
    _currentUser = UserProfile(
      id: p.id,
      displayName: normalizedName,
      handle: p.handle,
      fullName: p.fullName ?? normalizedName,
      nickname: p.nickname,
      birthday: p.birthday,
      avatarUrl: p.avatarUrl,
      hasConsentedTerms: true,
      hasCompletedOnboarding: true,
    );
    notifyListeners();
  }

  void _awardPointsToUser({
    required String userId,
    required int points,
    required String title,
    required String category,
  }) {
    final isPrimarySeeded =
        _currentHousehold.id == 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' &&
        userId == _seededPrimaryUserId;
    final isNonSeededCurrent =
        _currentHousehold.id != 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11' &&
        userId == _currentUser.id;
    if (isPrimarySeeded || isNonSeededCurrent) {
      _kasamaPoints += points;
      _pointHistory.insert(
        0,
        PointAuditEntry(
          id: 'pa_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
          title: title,
          points: points,
          timestamp: DateTime.now(),
          category: category,
        ),
      );
    } else {
      _memberBonusPoints[userId] = (_memberBonusPoints[userId] ?? 0) + points;
    }
  }

  List<HouseholdNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  void setNotificationsForTest(List<HouseholdNotificationItem> items) {
    _notifications
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  void setMembersForTest(List<MemberPresence> members) {
    _members
      ..clear()
      ..addAll(members);
    notifyListeners();
  }

  // Current user (defaults to clean placeholder)
  UserProfile _currentUser = const UserProfile(
    id: 'user_initial',
    displayName: 'Housemate',
    handle: '@housemate',
    hasConsentedTerms: false,
    hasCompletedOnboarding: false,
  );

  Household _currentHousehold = const Household(
    id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    name: 'Casa 204',
    inviteCode: 'CASA204',
    createdBy: '11111111-1111-1111-1111-111111111111',
  );

  int _kasamaPoints = 0;
  int _groupChatUnreadCount = 0;
  final List<HouseholdNotificationItem> _notifications = [];

  // Member presence list
  final List<MemberPresence> _members = [];
  final List<ParcelItem> _parcels = [];
  final List<LostFoundItem> _items = [];
  final List<MaintenanceTask> _tasks = [];
  final List<HouseholdBill> _bills = [];
  final List<MeetUpInvitation> _meetUpInvitations = [];
  MeetUpInvitation _activeMeetUp = MeetUpInvitation(
    id: 'placeholder_m',
    activity: '',
    location: '',
    scheduledTime: DateTime.now().add(const Duration(days: 30)),
    goingCount: 0,
    maybeCount: 0,
    cantMakeCount: 0,
  );

  void _recomputeActiveMeetUp() {
    final active = _meetUpInvitations
        .where((m) => m.hasValidData && m.isActive)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (active.isNotEmpty) {
      _activeMeetUp = active.first;
      return;
    }
    final valid = _meetUpInvitations.where((m) => m.hasValidData).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    if (valid.isNotEmpty) {
      _activeMeetUp = valid.first;
      return;
    }
    _activeMeetUp = MeetUpInvitation(
      id: 'placeholder_m',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
  }
  final List<ChatMessage> _groupMessages = [];
  final List<ChatSpace> _chatSpaces = [];
  final Map<String, List<ChatMessage>> _directMessages = {};
  final Map<String, int> _directUnreadCounts = {};
  final List<QuickSnap> _quickSnaps = [];
  final Map<String, Map<String, int>> _pendingReactionDeltas = {};
  final Map<String, Timer> _reactionFlushTimers = {};
  final List<({String snapId, Map<String, int> deltas})>
  _flushedReactionBatches = [];

  List<({String snapId, Map<String, int> deltas})>
  get flushedReactionBatches => List.unmodifiable(_flushedReactionBatches);

  bool get hasPendingSnapReactions =>
      _pendingReactionDeltas.values.any((m) => m.isNotEmpty);
  final List<HouseholdInvitation> _invitations = [];
  final List<PointAuditEntry> _pointHistory = [];

  void _loadInitialSeedData() {
    _isAuthenticated = true;
    _currentUser = UserProfile(
      id: '11111111-1111-1111-1111-111111111111',
      displayName: 'Jon Paul Berana',
      handle: '@jpberana',
      fullName: 'Jon Paul Berana',
      nickname: 'JP',
      birthday: DateTime(2005, 5, 15),
      avatarUrl:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80',
      hasConsentedTerms: true,
      hasCompletedOnboarding: true,
    );
    _kasamaPoints = 120;
    _members.addAll([
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
    ]);

    // Parcels list
    _parcels.addAll([
      ParcelItem(
        id: 'p1',
        householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        buyerId: '22222222-2222-2222-2222-222222222222',
        buyerName: 'Maria',
        courier: CasamaCouriers.jtExpress,
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
        courier: CasamaCouriers.flashExpress,
        expectedArrival: DateTime.now().add(const Duration(days: 3)),
        paymentType: ParcelPaymentType.paid,
        status: ParcelStatus.expected,
        notes: 'For group use',
        availableMemberNames: ['You', 'Maria'],
      ),
    ]);

    // Lost & Found
    _items.addAll([
      LostFoundItem(
        id: 'i1',
        householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        type: ItemType.lost,
        title: 'Lost AirPods',
        description: 'Last seen in the study area.',
        location: 'Study Area',
        imageUrl:
            'https://images.unsplash.com/photo-1600294037681-c80b4cb5b434?auto=format&fit=crop&w=300&q=80',
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
        location: 'Common Area',
        imageUrl:
            'https://images.unsplash.com/photo-1553062407-98eeb64c6a62?auto=format&fit=crop&w=300&q=80',
        status: ItemStatus.unclaimed,
        reportedBy: '22222222-2222-2222-2222-222222222222',
        reportedByName: 'Maria',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ]);

    // Maintenance & Restock
    _tasks.addAll([
      MaintenanceTask(
        id: 't1',
        householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        title: 'Leaking Faucet',
        category: TaskCategory.landlord,
        urgency: TaskUrgency.urgent,
        status: TaskStatus.open,
        createdBy: '11111111-1111-1111-1111-111111111111',
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
        createdBy: '22222222-2222-2222-2222-222222222222',
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
        createdBy: '33333333-3333-3333-3333-333333333333',
        createdByName: 'Alex',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        dueDate: DateTime.now().add(const Duration(days: 4)),
      ),
    ]);

    // Meet-up Invitation
    final seededMeetup = MeetUpInvitation(
      id: 'm1',
      creatorId: _currentUser.id,
      activity: 'Study Session 🎓',
      location: 'Dorm Common Area',
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
      goingCount: 3,
      maybeCount: 1,
      cantMakeCount: 0,
      currentUserResponse: 'going',
      responders: [
        for (var i = 0; i < _members.length && i < 4; i++)
          MeetUpResponder(
            userId: _members[i].profile.id,
            displayName: _members[i].profile.displayName,
            avatarUrl: _members[i].profile.avatarUrl,
            response: i == 3 ? 'maybe' : 'going',
          ),
      ],
    );
    _meetUpInvitations
      ..clear()
      ..add(seededMeetup);
    _activeMeetUp = seededMeetup;

    // Group Messages
    _groupMessages.addAll([
      ChatMessage(
        id: 'msg1',
        senderId: '22222222-2222-2222-2222-222222222222',
        senderName: 'Maria',
        senderAvatar:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
        content:
            "Hey everyone! Who's available to receive my parcel tomorrow?",
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
        senderAvatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
        content: 'Thanks! Just let us know when it arrives.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        isCurrentUser: false,
      ),
    ]);

    // Custom Chat Spaces
    _chatSpaces.addAll([
      ChatSpace(
        id: 'space_grocery',
        householdId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        name: 'Grocery & Supplies',
        description:
            'Coordinate shared kitchen items and bulk grocery shopping.',
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
    ]);

    _groupChatUnreadCount = 2;
    _notifications
      ..clear()
      ..add(
        HouseholdNotificationItem(
          id: 'notif_seed_1',
          type: 'parcel_received',
          title: 'Parcel arrived',
          subtitle: 'J&T Express delivery is ready at the lobby.',
          createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
          isRead: false,
        ),
      );

    // Direct messages mapping
    _directMessages.addAll({
      'maria': [
        ChatMessage(
          id: 'dm_m1',
          senderId: '22222222-2222-2222-2222-222222222222',
          senderName: 'Maria',
          senderAvatar:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=100&q=80',
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
          senderAvatar:
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=100&q=80',
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
          senderAvatar:
              'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?auto=format&fit=crop&w=100&q=80',
          content: 'Sent a photo 📷 of the groceries we need.',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          isCurrentUser: false,
        ),
      ],
    });

    // Household bills
    _bills.addAll([
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
    ]);

    // Household invitations
    _invitations.addAll([
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
    ]);

    // Point audit ledger
    _pointHistory.addAll([
      PointAuditEntry(
        id: 'pa_1',
        title: 'Received J&T Express delivery for Maria',
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
    ]);
  }

  // Searchable Casama public directory (external users not yet in household)
  final List<UserProfile> _allCasamaUsers = const [
    UserProfile(
      id: '55555555-5555-5555-5555-555555555555',
      displayName: 'Miguel Ramos',
      handle: '@miguel',
      fullName: 'Miguel Ramos',
      nickname: 'Miggy',
      avatarUrl:
          'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?auto=format&fit=crop&w=200&q=80',
    ),
    UserProfile(
      id: '66666666-6666-6666-6666-666666666666',
      displayName: 'Clara Reyes',
      handle: '@clara',
      fullName: 'Clara Reyes',
      nickname: 'Clara',
      avatarUrl:
          'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=200&q=80',
    ),
    UserProfile(
      id: '77777777-7777-7777-7777-777777777777',
      displayName: 'Bea Gomez',
      handle: '@bea',
      fullName: 'Bea Gomez',
      nickname: 'Bea',
      avatarUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=200&q=80',
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
  List<MeetUpInvitation> get meetUpInvitations =>
      List.unmodifiable(_meetUpInvitations);

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
  int getDirectUnreadCount(String contactKey) =>
      _directUnreadCounts[contactKey.toLowerCase()] ?? 0;
  List<ChatSpace> get chatSpaces => List.unmodifiable(_chatSpaces);
  int get groupChatUnreadCount => _groupChatUnreadCount;
  int get unreadNotificationCount =>
      _notifications.where((n) => n.isUnread).length;
  int get totalUnreadChatCount =>
      _groupChatUnreadCount +
      _chatSpaces.fold<int>(0, (sum, s) => sum + s.unreadCount) +
      _directUnreadCounts.values.fold<int>(0, (sum, c) => sum + c);

  // QuickSnap getters
  List<QuickSnap> get quickSnaps {
    if (_pendingReactionDeltas.isEmpty) {
      return List.unmodifiable(_quickSnaps);
    }
    final now = DateTime.now();
    return List.unmodifiable(
      _quickSnaps.map((snap) {
        final pending = _pendingReactionDeltas[snap.id];
        if (pending == null || pending.isEmpty) return snap;
        final merged = List<QuickSnapReaction>.from(snap.reactions);
        for (final entry in pending.entries) {
          if (entry.value <= 0) continue;
          final existingIdx = merged.indexWhere(
            (r) => r.userId == _currentUser.id && r.emoji == entry.key,
          );
          if (existingIdx != -1) {
            final existing = merged[existingIdx];
            merged[existingIdx] = existing.copyWith(
              count: existing.count + entry.value,
              updatedAt: now,
            );
          } else {
            merged.add(
              QuickSnapReaction(
                emoji: entry.key,
                userId: _currentUser.id,
                userName: _currentUser.displayName,
                count: entry.value,
                createdAt: now,
                updatedAt: now,
              ),
            );
          }
        }
        return snap.copyWith(reactions: merged);
      }),
    );
  }

  QuickSnap? get latestQuickSnap =>
      quickSnaps.isNotEmpty ? quickSnaps.first : null;

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
    if (email != null && email.contains('@') && !email.startsWith('jp@')) {
      final name = email.split('@').first;
      _currentUser = UserProfile(
        id: 'usr_${email.hashCode}',
        displayName: name,
        handle: '@$name',
        hasConsentedTerms: true,
        hasCompletedOnboarding: true,
      );
      _members.clear();
      _members.add(
        MemberPresence(
          profile: _currentUser,
          isHome: true,
          updatedAt: DateTime.now(),
        ),
      );
      _parcels.clear();
      _items.clear();
      _tasks.clear();
      _bills.clear();
      _chatSpaces.clear();
      _directMessages.clear();
      _groupMessages.clear();
      _meetUpInvitations.clear();
      _activeMeetUp = MeetUpInvitation(
        id: 'placeholder_m',
        activity: '',
        location: '',
        scheduledTime: DateTime.now().add(const Duration(days: 30)),
        goingCount: 0,
        maybeCount: 0,
        cantMakeCount: 0,
      );
    } else {
      if (_members.isEmpty) {
        _members.add(
          MemberPresence(
            profile: _currentUser,
            isHome: true,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    _ensureCurrentWorkspaceRegistered();
    notifyListeners();
  }

  void register({required String email, required String password}) {
    _isAuthenticated = true;
    final name = email.split('@').first;
    final handle = '@$name';
    _currentUser = UserProfile(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      displayName: name,
      handle: handle,
      fullName: null,
      nickname: null,
      birthday: null,
      avatarUrl: null,
      hasConsentedTerms: false,
      hasCompletedOnboarding: false,
    );
    _members.clear();
    _members.add(
      MemberPresence(
        profile: _currentUser,
        isHome: true,
        updatedAt: DateTime.now(),
      ),
    );
    _parcels.clear();
    _items.clear();
    _tasks.clear();
    _bills.clear();
    _chatSpaces.clear();
    _directMessages.clear();
    _directUnreadCounts.clear();
    _groupMessages.clear();
    _invitations.clear();
    _pointHistory.clear();
    _quickSnaps.clear();
    _kasamaPoints = 0;
    _groupChatUnreadCount = 0;
    _notifications.clear();
    _meetUpInvitations.clear();
    _activeMeetUp = MeetUpInvitation(
      id: 'placeholder_m',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
      goingCount: 0,
      maybeCount: 0,
      cantMakeCount: 0,
    );
    _ensureCurrentWorkspaceRegistered();
    notifyListeners();
  }

  void logout() {
    _flushAllPendingSnapReactionsSync(notify: false);
    _isAuthenticated = false;
    notifyListeners();
  }

  void updateProfile({
    String? displayName,
    String? handle,
    String? fullName,
    String? nickname,
    DateTime? birthday,
    String? avatarUrl,
    bool? hasConsentedTerms,
    bool? hasCompletedOnboarding,
    bool clearAvatar = false,
    bool clearNickname = false,
    bool clearBirthday = false,
  }) {
    final normalizedBirthday = birthday != null
        ? DateTime(birthday.year, birthday.month, birthday.day)
        : null;
    final effectiveFullName = fullName ?? _currentUser.fullName;
    final effectiveDisplayName = displayName ??
        (fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : _currentUser.displayName);

    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: effectiveDisplayName,
      handle: handle ?? _currentUser.handle,
      fullName: effectiveFullName,
      nickname: clearNickname ? null : (nickname ?? _currentUser.nickname),
      birthday: clearBirthday ? null : (normalizedBirthday ?? _currentUser.birthday),
      avatarUrl: clearAvatar ? null : (avatarUrl ?? _currentUser.avatarUrl),
      hasConsentedTerms: hasConsentedTerms ?? _currentUser.hasConsentedTerms,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? _currentUser.hasCompletedOnboarding,
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
      birthday: _currentUser.birthday,
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
      birthday: _currentUser.birthday,
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
      if (p.isClaimed) {
        return; // Prevent duplicate rewards and updates
      }
      final now = DateTime.now();
      final isSelfClaim = p.buyerId == _currentUser.id;
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
        isAllUnavailable: p.isAllUnavailable,
        codSettled: isSelfClaim,
        claimedById: _currentUser.id,
        claimedByName: _currentUser.displayName,
        claimedAt: now,
        settledAt: isSelfClaim ? now : null,
      );
      if (!isSelfClaim) {
        _kasamaPoints += 5;
        _pointHistory.insert(
          0,
          PointAuditEntry(
            id: 'pa_${now.millisecondsSinceEpoch}',
            title: 'Received parcel: ${p.courier} for ${p.buyerName}',
            points: 5,
            timestamp: now,
            category: 'parcel',
          ),
        );
      }
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
      _tasks[index] = t.copyWith(
        status: TaskStatus.done,
        completedById: _currentUser.id,
        completedByName: _currentUser.displayName,
        completedAt: DateTime.now(),
      );
      final isSelfCreated =
          t.createdBy.isNotEmpty && t.createdBy == _currentUser.id;
      if (!isSelfCreated) {
        final pts = t.computedPoints;
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
      }
      notifyListeners();
    }
  }

  Future<void> updateParcel({
    required String parcelId,
    String? courier,
    DateTime? arrival,
    ParcelPaymentType? paymentType,
    double? codAmount,
    String? notes,
    ParcelStatus? status,
  }) async {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index == -1) return;
    final p = _parcels[index];
    final nextPay = paymentType ?? p.paymentType;
    _parcels[index] = ParcelItem(
      id: p.id,
      householdId: p.householdId,
      buyerId: p.buyerId,
      buyerName: p.buyerName,
      courier: courier ?? p.courier,
      expectedArrival: arrival ?? p.expectedArrival,
      paymentType: nextPay,
      codAmount: nextPay == ParcelPaymentType.cod
          ? (codAmount ?? p.codAmount)
          : null,
      status: status ?? p.status,
      notes: notes ?? p.notes,
      availableMemberNames: p.availableMemberNames,
      isAllUnavailable: p.isAllUnavailable,
      codSettled: p.codSettled,
    );
    notifyListeners();
  }

  Future<void> cancelParcel(String parcelId) =>
      updateParcel(parcelId: parcelId, status: ParcelStatus.cancelled);

  Future<void> settleParcelClaim(String parcelId) async {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index == -1) return;
    final p = _parcels[index];
    _parcels[index] = ParcelItem(
      id: p.id,
      householdId: p.householdId,
      buyerId: p.buyerId,
      buyerName: p.buyerName,
      courier: p.courier,
      expectedArrival: p.expectedArrival,
      paymentType: p.paymentType,
      codAmount: p.codAmount,
      status: p.status,
      notes: p.notes,
      availableMemberNames: p.availableMemberNames,
      isAllUnavailable: p.isAllUnavailable,
      codSettled: true,
      claimedById: p.claimedById,
      claimedByName: p.claimedByName,
      claimedAt: p.claimedAt,
      settledAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    if (status == TaskStatus.done) {
      completeTask(taskId);
      return;
    }
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      _tasks[idx] = _tasks[idx].copyWith(status: status, clearCompleted: true);
      notifyListeners();
    }
  }

  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? description,
    DateTime? dueDate,
  }) {
    _tasks.insert(
      0,
      MaintenanceTask(
        id: 't_${DateTime.now().millisecondsSinceEpoch}',
        householdId: _currentHousehold.id,
        title: title,
        description: description,
        category: category,
        urgency: urgency,
        status: TaskStatus.open,
        createdBy: _currentUser.id,
        createdByName: _currentUser.displayName,
        createdAt: DateTime.now(),
        dueDate: dueDate,
      ),
    );
    notifyListeners();
  }

  Future<String?> recordRouletteSpin({
    String? taskId,
    required String taskTitle,
    required String selectedUserId,
  }) async {
    _lastRouletteSpinAt = DateTime.now();
    notifyListeners();
    return 'spin_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> respondToRouletteSpin({
    required String spinId,
    String? taskId,
    required bool accepted,
  }) async {
    if (accepted) {
      _kasamaPoints += 2;
    } else {
      _kasamaPoints -= 3;
    }
    notifyListeners();
  }

  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? location,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    _items.insert(
      0,
      LostFoundItem(
        id: 'i_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
        householdId: _currentHousehold.id,
        type: type,
        title: title,
        description: description,
        location: location,
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

  void markDirectChatAsRead(String contactKey) {
    final key = contactKey.toLowerCase();
    if ((_directUnreadCounts[key] ?? 0) > 0) {
      _directUnreadCounts[key] = 0;
      notifyListeners();
    }
  }

  void addIncomingDirectMessageForTest(
    String contactKey,
    ChatMessage message,
  ) {
    final key = contactKey.toLowerCase();
    _directMessages.putIfAbsent(key, () => []).add(message);
    if (!message.isCurrentUser) {
      _directUnreadCounts[key] = (_directUnreadCounts[key] ?? 0) + 1;
    }
    notifyListeners();
  }

  Future<void> createMeetUp({
    required String activity,
    required String location,
    required DateTime scheduledTime,
    String? announcementText,
  }) async {
    if (activity.trim().isEmpty && location.trim().isEmpty) {
      _meetUpInvitations.clear();
      _recomputeActiveMeetUp();
      notifyListeners();
      return;
    }

    final otherMembers = _members
        .where((m) => m.profile.id != _currentUser.id)
        .toList();
    final seededResponders = <MeetUpResponder>[
      MeetUpResponder(
        userId: _currentUser.id,
        displayName: _currentUser.displayName,
        avatarUrl: _currentUser.avatarUrl,
        response: 'going',
      ),
      for (final m in otherMembers)
        MeetUpResponder(
          userId: m.profile.id,
          displayName: m.profile.displayName,
          avatarUrl: m.profile.avatarUrl,
          response: 'maybe',
        ),
    ];

    final created = MeetUpInvitation(
      id: 'mu_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
      creatorId: _currentUser.id,
      activity: activity,
      location: location,
      scheduledTime: scheduledTime.toLocal(),
      status: 'active',
      reminderSent: false,
      arrivalHandled: false,
      goingCount: 1,
      maybeCount: otherMembers.length,
      cantMakeCount: 0,
      currentUserResponse: 'going',
      responders: seededResponders,
    );
    _meetUpInvitations.add(created);
    _meetUpInvitations.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _recomputeActiveMeetUp();
    notifyListeners();
  }

  Future<void> deleteMeetUpInvitation(String invitationId) async {
    _meetUpInvitations.removeWhere((m) => m.id == invitationId);
    _recomputeActiveMeetUp();
    notifyListeners();
  }

  void setActiveMeetUpForTest(MeetUpInvitation meetup) {
    _meetUpInvitations
      ..clear()
      ..addAll([if (meetup.hasValidData) meetup]);
    _activeMeetUp = meetup;
    notifyListeners();
  }

  void addMeetUpForTest(MeetUpInvitation meetup) {
    _meetUpInvitations.add(meetup);
    _meetUpInvitations.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    _recomputeActiveMeetUp();
    notifyListeners();
  }

  void addGroupMessageForTest(ChatMessage message) {
    _groupMessages.add(message);
    if (!message.isCurrentUser) {
      _groupChatUnreadCount++;
    }
    notifyListeners();
  }

  void markNotificationAsRead(String notificationId) {
    final now = DateTime.now();
    var changed = false;
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.id == notificationId && n.isUnread) {
        _notifications[i] = n.copyWith(isRead: true, readAt: n.readAt ?? now);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    final hasUnread = _notifications.any((n) => n.isUnread);
    if (!hasUnread) return;
    final now = DateTime.now();
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.isUnread) {
        _notifications[i] = n.copyWith(isRead: true, readAt: n.readAt ?? now);
      }
    }
    notifyListeners();
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
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _chatSpaces[idx];
      final trimmed = content.trim();
      final resolvedUrl = attachmentFile?.path ?? mediaUrl;
      final newMsg = ChatMessage(
        id: 'spc_msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: trimmed,
        attachmentUrl: resolvedUrl,
        localAttachmentPath: attachmentFile?.path,
        clientMessageId: clientMessageId,
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

  @override
  void retryGroupMessage(String messageId) {
    final idx = _groupMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1 &&
        _groupMessages[idx].deliveryStatus == MessageDeliveryStatus.failed) {
      _groupMessages[idx] = _groupMessages[idx].copyWith(
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      notifyListeners();
    }
  }

  @override
  void retrySpaceMessage(String spaceId, String messageId) {
    final sIdx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (sIdx == -1) return;
    final space = _chatSpaces[sIdx];
    final mIdx = space.messages.indexWhere((m) => m.id == messageId);
    if (mIdx != -1 &&
        space.messages[mIdx].deliveryStatus == MessageDeliveryStatus.failed) {
      final updated = List<ChatMessage>.from(space.messages);
      updated[mIdx] = updated[mIdx].copyWith(
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      _chatSpaces[sIdx] = space.copyWith(messages: updated);
      notifyListeners();
    }
  }

  @override
  void retryDirectMessage(String contactKey, String messageId) {
    final key = contactKey.toLowerCase();
    final list = _directMessages[key];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx != -1 &&
        list[idx].deliveryStatus == MessageDeliveryStatus.failed) {
      final updated = List<ChatMessage>.from(list);
      updated[idx] = updated[idx].copyWith(
        deliveryStatus: MessageDeliveryStatus.delivered,
      );
      _directMessages[key] = updated;
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
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    final trimmed = content.trim();
    final resolvedUrl = attachmentFile?.path ?? mediaUrl;
    _groupMessages.add(
      ChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: trimmed,
        attachmentUrl: resolvedUrl,
        localAttachmentPath: attachmentFile?.path,
        clientMessageId: clientMessageId,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );
    notifyListeners();
  }

  void respondMeetUp(String response, {String? invitationId}) {
    final targetId = invitationId ?? _activeMeetUp.id;
    final idx = _meetUpInvitations.indexWhere((m) => m.id == targetId);
    final target = idx != -1 ? _meetUpInvitations[idx] : _activeMeetUp;
    if (!target.hasValidData || !target.isActive) return;

    int g = target.goingCount;
    int m = target.maybeCount;
    int c = target.cantMakeCount;

    if (target.currentUserResponse == 'going') g--;
    if (target.currentUserResponse == 'maybe') m--;
    if (target.currentUserResponse == 'cant_make_it') c--;

    if (response == 'going') g++;
    if (response == 'maybe') m++;
    if (response == 'cant_make_it') c++;

    final updatedResponders = [
      ...target.responders.where((r) => r.userId != _currentUser.id),
      MeetUpResponder(
        userId: _currentUser.id,
        displayName: _currentUser.displayName,
        avatarUrl: _currentUser.avatarUrl,
        response: response,
      ),
    ];

    final updated = target.copyWith(
      goingCount: max(0, g),
      maybeCount: max(0, m),
      cantMakeCount: max(0, c),
      currentUserResponse: response,
      responders: updatedResponders,
    );
    if (idx != -1) {
      _meetUpInvitations[idx] = updated;
    }
    _recomputeActiveMeetUp();
    notifyListeners();
  }

  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    bool autoReply = false,
  }) {
    final key = contactKey.toLowerCase();
    if (!_directMessages.containsKey(key)) {
      _directMessages[key] = [];
    }
    final trimmed = content.trim();
    final resolvedUrl = attachmentFile?.path ?? mediaUrl;
    _directMessages[key]!.add(
      ChatMessage(
        id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        content: trimmed,
        attachmentUrl: resolvedUrl,
        localAttachmentPath: attachmentFile?.path,
        clientMessageId: clientMessageId,
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
          _directUnreadCounts[key] = (_directUnreadCounts[key] ?? 0) + 1;
          notifyListeners();
        }
      });
    }
  }

  Future<String?> submitLostItemFind({
    required LostFoundItem lostItem,
    String? foundLocation,
    String? description,
    String? imageUrl,
    Uint8List? imageBytes,
    XFile? imageFile,
  }) async {
    if (_currentUser.id == lostItem.reportedBy) {
      return 'Use "Found It Myself" to resolve your own lost item.';
    }
    if (lostItem.type != ItemType.lost || lostItem.status != ItemStatus.open) {
      return 'This lost item is no longer open.';
    }
    final alreadyPending = _items.any(
      (i) =>
          i.type == ItemType.found &&
          i.lostItemId == lostItem.id &&
          i.reportedBy == _currentUser.id &&
          i.status == ItemStatus.pending,
    );
    if (alreadyPending) {
      return 'You already have a pending find awaiting review.';
    }

    _items.insert(
      0,
      LostFoundItem(
        id: 'fi_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
        householdId: _currentHousehold.id,
        type: ItemType.found,
        title: lostItem.title,
        description: description,
        location: foundLocation,
        imageUrl: imageUrl,
        status: ItemStatus.pending,
        reportedBy: _currentUser.id,
        reportedByName: _currentUser.displayName,
        lostItemId: lostItem.id,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
    return null;
  }

  Future<String?> acceptLostItemFind(String foundItemId) async {
    final foundIdx = _items.indexWhere(
      (i) => i.id == foundItemId && i.type == ItemType.found,
    );
    if (foundIdx == -1) return 'Found submission not found.';
    final found = _items[foundIdx];
    if (found.lostItemId == null || found.status != ItemStatus.pending) {
      return 'This submission is no longer pending.';
    }

    final lostIdx = _items.indexWhere(
      (i) => i.id == found.lostItemId && i.type == ItemType.lost,
    );
    if (lostIdx == -1) return 'Parent lost item not found.';
    final lost = _items[lostIdx];
    if (lost.reportedBy != _currentUser.id) {
      return 'Only the poster can confirm this find.';
    }
    if (lost.status != ItemStatus.open) {
      return 'This lost item is already resolved.';
    }

    final now = DateTime.now();
    _items[foundIdx] = found.copyWith(
      status: ItemStatus.resolved,
      returnedAt: now,
    );
    _items[lostIdx] = lost.copyWith(
      status: ItemStatus.resolved,
      foundById: found.reportedBy,
      foundByName: found.reportedByName,
      foundAt: found.createdAt,
      returnedAt: now,
      resolvedFoundItemId: found.id,
    );

    // Auto-reject any other pending submissions for the same lost item.
    for (var i = 0; i < _items.length; i++) {
      final candidate = _items[i];
      if (candidate.id != found.id &&
          candidate.type == ItemType.found &&
          candidate.lostItemId == lost.id &&
          candidate.status == ItemStatus.pending) {
        _items[i] = candidate.copyWith(
          status: ItemStatus.rejected,
          rejectedAt: now,
        );
      }
    }

    _awardPointsToUser(
      userId: found.reportedBy,
      points: 5,
      title: "Found & returned: ${lost.title}",
      category: 'lost_found',
    );
    notifyListeners();
    return null;
  }

  Future<String?> rejectLostItemFind(String foundItemId) async {
    final foundIdx = _items.indexWhere(
      (i) => i.id == foundItemId && i.type == ItemType.found,
    );
    if (foundIdx == -1) return 'Found submission not found.';
    final found = _items[foundIdx];
    if (found.lostItemId == null || found.status != ItemStatus.pending) {
      return 'This submission is no longer pending.';
    }
    final lostIdx = _items.indexWhere(
      (i) => i.id == found.lostItemId && i.type == ItemType.lost,
    );
    if (lostIdx == -1 || _items[lostIdx].reportedBy != _currentUser.id) {
      return 'Only the poster can reject this find.';
    }

    _items[foundIdx] = found.copyWith(
      status: ItemStatus.rejected,
      rejectedAt: DateTime.now(),
    );
    notifyListeners();
    return null;
  }

  Future<String?> resolveOwnLostItem(String lostItemId) async {
    final lostIdx = _items.indexWhere(
      (i) => i.id == lostItemId && i.type == ItemType.lost,
    );
    if (lostIdx == -1) return 'Lost item not found.';
    final lost = _items[lostIdx];
    if (lost.reportedBy != _currentUser.id) {
      return 'Only the poster can resolve this item.';
    }
    if (lost.status != ItemStatus.open) {
      return 'This lost item is already resolved.';
    }

    final now = DateTime.now();
    _items[lostIdx] = lost.copyWith(
      status: ItemStatus.resolved,
      returnedAt: now,
    );
    for (var i = 0; i < _items.length; i++) {
      final candidate = _items[i];
      if (candidate.type == ItemType.found &&
          candidate.lostItemId == lost.id &&
          candidate.status == ItemStatus.pending) {
        _items[i] = candidate.copyWith(
          status: ItemStatus.rejected,
          rejectedAt: now,
        );
      }
    }
    notifyListeners();
    return null;
  }

  Future<String?> claimStandaloneFoundItem(String foundItemId) async {
    final idx = _items.indexWhere(
      (i) => i.id == foundItemId && i.type == ItemType.found,
    );
    if (idx == -1) return 'Found item not found.';
    final item = _items[idx];
    if (!item.isStandalone || item.status != ItemStatus.unclaimed) {
      return 'This found item is no longer available to claim.';
    }
    if (item.reportedBy == _currentUser.id) {
      return 'You cannot claim your own found item.';
    }

    final now = DateTime.now();
    _items[idx] = item.copyWith(
      status: ItemStatus.resolved,
      claimedById: _currentUser.id,
      claimedByName: _currentUser.displayName,
      claimedAt: now,
      returnedAt: now,
    );

    _awardPointsToUser(
      userId: item.reportedBy,
      points: 2,
      title: 'Found item claimed: ${item.title}',
      category: 'lost_found',
    );
    notifyListeners();
    return null;
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
    _ensureCurrentWorkspaceRegistered();
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
        id: 'bill_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
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
      _notifications.insert(
        0,
        HouseholdNotificationItem(
          id: 'notif_bill_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
          type: 'bill_reminder',
          title: 'Upcoming bill reminder',
          subtitle: '${billName?.trim().isNotEmpty == true ? billName!.trim() : category.label} due soon',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );
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
    Uint8List? imageBytes,
    String? caption,
  }) {
    final trimmedCaption = caption?.trim() ?? '';
    final snap = QuickSnap(
      id: 'snap_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
      householdId: _currentHousehold.id,
      senderId: _currentUser.id,
      senderName: _currentUser.displayName,
      imageUrl: imageUrl,
      caption: trimmedCaption.isEmpty ? null : trimmedCaption,
      createdAt: DateTime.now(),
      reactions: [],
      comments: [],
    );
    _quickSnaps.insert(0, snap);

    // Also share a quick notification/chat message so housemates see it
    _groupMessages.add(
      ChatMessage(
        id: 'msg_snap_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        senderAvatar: _currentUser.avatarUrl,
        content:
            '📸 Shared a QuickSnap${trimmedCaption.isNotEmpty ? ': "$trimmedCaption"' : ''}',
        mediaUrl: imageUrl,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ),
    );

    notifyListeners();
  }

  void reactToQuickSnap(String snapId, String emoji) {
    queueQuickSnapReaction(snapId, emoji);
  }

  void queueQuickSnapReaction(String snapId, String emoji) {
    if (!kCasSnapReactionEmojis.contains(emoji)) return;
    final exists = _quickSnaps.any((s) => s.id == snapId);
    if (!exists) return;

    final deltas = _pendingReactionDeltas.putIfAbsent(
      snapId,
      () => <String, int>{},
    );
    deltas[emoji] = (deltas[emoji] ?? 0) + 1;
    notifyListeners();

    _reactionFlushTimers.remove(snapId)?.cancel();
    _reactionFlushTimers[snapId] = Timer(reactionDebounceDuration, () {
      _reactionFlushTimers.remove(snapId);
      _flushSnapReactionsSync(snapId);
    });
  }

  Future<void> flushPendingSnapReactions() async {
    _flushAllPendingSnapReactionsSync();
  }

  void _flushAllPendingSnapReactionsSync({bool notify = true}) {
    final timers = _reactionFlushTimers.values.toList();
    _reactionFlushTimers.clear();
    for (final timer in timers) {
      timer.cancel();
    }
    final snapIds = _pendingReactionDeltas.keys.toList();
    for (final snapId in snapIds) {
      _flushSnapReactionsSync(snapId, notify: false);
    }
    if (notify && snapIds.isNotEmpty) {
      notifyListeners();
    }
  }

  void _flushSnapReactionsSync(String snapId, {bool notify = true}) {
    _reactionFlushTimers.remove(snapId)?.cancel();
    final raw = _pendingReactionDeltas.remove(snapId);
    if (raw == null || raw.isEmpty) return;

    final batch = <String, int>{
      for (final entry in raw.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (batch.isEmpty) return;

    _flushedReactionBatches.add((
      snapId: snapId,
      deltas: Map<String, int>.unmodifiable(batch),
    ));

    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final now = DateTime.now();
      final merged = List<QuickSnapReaction>.from(_quickSnaps[idx].reactions);
      for (final entry in batch.entries) {
        final existingIdx = merged.indexWhere(
          (r) => r.userId == _currentUser.id && r.emoji == entry.key,
        );
        if (existingIdx != -1) {
          final existing = merged[existingIdx];
          merged[existingIdx] = existing.copyWith(
            count: existing.count + entry.value,
            updatedAt: now,
          );
        } else {
          merged.add(
            QuickSnapReaction(
              emoji: entry.key,
              userId: _currentUser.id,
              userName: _currentUser.displayName,
              count: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
      _quickSnaps[idx] = _quickSnaps[idx].copyWith(reactions: merged);
    }
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final timer in _reactionFlushTimers.values) {
      timer.cancel();
    }
    _reactionFlushTimers.clear();
    super.dispose();
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

class _MockHouseholdWorkspace {
  final Household household;
  final int kasamaPoints;
  final int groupChatUnreadCount;
  final List<HouseholdNotificationItem> notifications;
  final DateTime? lastRouletteSpinAt;
  final List<MemberPresence> members;
  final List<ParcelItem> parcels;
  final List<LostFoundItem> items;
  final List<MaintenanceTask> tasks;
  final List<HouseholdBill> bills;
  final List<MeetUpInvitation> meetUpInvitations;
  final MeetUpInvitation activeMeetUp;
  final List<ChatMessage> groupMessages;
  final List<ChatSpace> chatSpaces;
  final Map<String, List<ChatMessage>> directMessages;
  final Map<String, int> directUnreadCounts;
  final List<QuickSnap> quickSnaps;
  final List<HouseholdInvitation> invitations;
  final List<PointAuditEntry> pointHistory;

  const _MockHouseholdWorkspace({
    required this.household,
    required this.kasamaPoints,
    required this.groupChatUnreadCount,
    required this.notifications,
    required this.lastRouletteSpinAt,
    required this.members,
    required this.parcels,
    required this.items,
    required this.tasks,
    required this.bills,
    required this.meetUpInvitations,
    required this.activeMeetUp,
    required this.groupMessages,
    required this.chatSpaces,
    required this.directMessages,
    this.directUnreadCounts = const {},
    required this.quickSnaps,
    required this.invitations,
    required this.pointHistory,
  });
}
