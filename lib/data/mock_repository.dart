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
      members: List<MemberPresence>.from(_members),
      parcels: List<ParcelItem>.from(_parcels),
      items: List<LostFoundItem>.from(_items),
      tasks: List<MaintenanceTask>.from(_tasks),
      rouletteRecords: List<ChoreRouletteRecord>.from(_rouletteRecords),
      housematesAgendaInvitations: List<HousematesAgendaInvitation>.from(
        _housematesAgendaInvitations,
      ),
      activeHousematesAgenda: _activeHousematesAgenda,
      groupMessages: List<ChatMessage>.from(_groupMessages),
      chatSpaces: List<ChatSpace>.from(_chatSpaces),
      directMessages: {
        for (final entry in _directMessages.entries)
          entry.key: List<ChatMessage>.from(entry.value),
      },
      directUnreadCounts: Map<String, int>.from(_directUnreadCounts),
      quickSnaps: List<QuickSnap>.from(_quickSnaps),
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
    _rouletteRecords
      ..clear()
      ..addAll(ws.rouletteRecords);
    _housematesAgendaInvitations
      ..clear()
      ..addAll(ws.housematesAgendaInvitations);
    _activeHousematesAgenda = ws.activeHousematesAgenda;
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
    _rouletteRecords.clear();
    _housematesAgendaInvitations.clear();
    _activeHousematesAgenda = HousematesAgendaInvitation(
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
    _rouletteRecords.clear();
    _housematesAgendaInvitations.clear();
    _activeHousematesAgenda = HousematesAgendaInvitation(
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
          displayName: _currentUser.preferredName,
          avatarUrl: _currentUser.avatarUrl,
          points: _kasamaPoints,
          isCurrentUser: true,
        ),
        LeaderboardStanding(
          userId: '22222222-2222-2222-2222-222222222222',
          displayName: 'Maria Santos',
          points: 85 + (_memberBonusPoints['22222222-2222-2222-2222-222222222222'] ?? 0),
          isCurrentUser: _currentUser.id == '22222222-2222-2222-2222-222222222222',
        ),
        LeaderboardStanding(
          userId: '33333333-3333-3333-3333-333333333333',
          displayName: 'Alex Rivera',
          points: 65 + (_memberBonusPoints['33333333-3333-3333-3333-333333333333'] ?? 0),
          isCurrentUser: _currentUser.id == '33333333-3333-3333-3333-333333333333',
        ),
        LeaderboardStanding(
          userId: '44444444-4444-4444-4444-444444444444',
          displayName: 'Ria Garcia',
          points: 55 + (_memberBonusPoints['44444444-4444-4444-4444-444444444444'] ?? 0),
          isCurrentUser: _currentUser.id == '44444444-4444-4444-4444-444444444444',
        ),
      ]..sort((a, b) => b.points.compareTo(a.points));
    }

    return _members.map((m) {
      final isMe = m.profile.id == _currentUser.id;
      return LeaderboardStanding(
        userId: m.profile.id,
        displayName: isMe ? _currentUser.preferredName : m.preferredName,
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
      firstName: p.firstName,
      lastName: p.lastName,
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

  List<HouseholdNotificationItem> get notifications => List.unmodifiable(
    _notifications.where((n) => n.isSupportedNotification),
  );

  void _pushNotification({
    required String type,
    required String title,
    required String subtitle,
    Map<String, dynamic> payload = const {},
  }) {
    final now = DateTime.now();
    _notifications.insert(
      0,
      HouseholdNotificationItem(
        id: 'notif_${now.microsecondsSinceEpoch}_${++_nextIdSeq}',
        type: type,
        title: title,
        subtitle: subtitle,
        createdAt: now,
        isRead: false,
        payload: {
          'title': title,
          'message': subtitle,
          'actor_id': _currentUser.id,
          'actor_name': _currentUser.displayName,
          ...payload,
        },
      ),
    );
  }

  void _purgeNotificationsForEntity({
    required String entityType,
    required String entityId,
  }) {
    _notifications.removeWhere(
      (n) => n.matchesEntity(entityType: entityType, entityId: entityId),
    );
  }

  void deleteParcelForTest(String parcelId) {
    _parcels.removeWhere((p) => p.id == parcelId);
    _purgeNotificationsForEntity(entityType: 'parcel', entityId: parcelId);
    notifyListeners();
  }

  void deleteTaskForTest(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    _rouletteRecords.removeWhere((r) => r.taskId == taskId);
    _purgeNotificationsForEntity(entityType: 'task', entityId: taskId);
    notifyListeners();
  }

  void deleteItemForTest(String itemId) {
    _items.removeWhere((i) => i.id == itemId);
    _purgeNotificationsForEntity(entityType: 'lost_item', entityId: itemId);
    _purgeNotificationsForEntity(entityType: 'found_item', entityId: itemId);
    notifyListeners();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    if (_tasks[idx].createdBy != _currentUser.id) return;
    _tasks.removeAt(idx);
    _rouletteRecords.removeWhere((r) => r.taskId == taskId);
    _purgeNotificationsForEntity(entityType: 'task', entityId: taskId);
    notifyListeners();
  }

  @override
  Future<void> deleteLostItem(String lostItemId) async {
    final idx = _items.indexWhere(
      (i) => i.id == lostItemId && i.type == ItemType.lost,
    );
    if (idx == -1) return;
    if (_items[idx].ownerId != _currentUser.id) return;
    final linkedFoundIds = _items
        .where((i) => i.lostItemId == lostItemId)
        .map((i) => i.id)
        .toList();
    _items.removeWhere((i) => i.id == lostItemId || i.lostItemId == lostItemId);
    _purgeNotificationsForEntity(entityType: 'lost_item', entityId: lostItemId);
    for (final fid in linkedFoundIds) {
      _purgeNotificationsForEntity(entityType: 'found_item', entityId: fid);
    }
    notifyListeners();
  }

  @override
  Future<void> deleteFoundItem(String foundItemId) async {
    final idx = _items.indexWhere(
      (i) => i.id == foundItemId && i.type == ItemType.found,
    );
    if (idx == -1) return;
    if (_items[idx].finderId != _currentUser.id) return;
    _items.removeAt(idx);
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.type == ItemType.lost &&
          item.resolvedFoundItemId == foundItemId) {
        _items[i] = LostFoundItem(
          id: item.id,
          householdId: item.householdId,
          type: item.type,
          title: item.title,
          description: item.description,
          location: item.location,
          imageUrl: item.imageUrl,
          status: item.status,
          reportedBy: item.reportedBy,
          reportedByName: item.reportedByName,
          foundById: item.foundById,
          foundByName: item.foundByName,
          claimedById: item.claimedById,
          claimedByName: item.claimedByName,
          lostItemId: item.lostItemId,
          resolvedFoundItemId: null,
          foundAt: item.foundAt,
          claimedAt: item.claimedAt,
          returnedAt: item.returnedAt,
          rejectedAt: item.rejectedAt,
          createdAt: item.createdAt,
        );
      }
    }
    _purgeNotificationsForEntity(entityType: 'found_item', entityId: foundItemId);
    notifyListeners();
  }

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
  final List<ChoreRouletteRecord> _rouletteRecords = [];
  final List<HousematesAgendaInvitation> _housematesAgendaInvitations = [];
  HousematesAgendaInvitation _activeHousematesAgenda =
      HousematesAgendaInvitation(
        id: 'placeholder_m',
        activity: '',
        location: '',
        scheduledTime: DateTime.now().add(const Duration(days: 30)),
        goingCount: 0,
        maybeCount: 0,
        cantMakeCount: 0,
      );

  void _recomputeActiveHousematesAgenda() {
    final active = _housematesAgendaInvitations
        .where((m) => m.hasValidData && m.isActive)
        .toList()
      ..sort((a, b) {
        if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
    if (active.isNotEmpty) {
      _activeHousematesAgenda = active.first;
      return;
    }
    final valid = _housematesAgendaInvitations
        .where((m) => m.hasValidData)
        .toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    if (valid.isNotEmpty) {
      _activeHousematesAgenda = valid.first;
      return;
    }
    _activeHousematesAgenda = HousematesAgendaInvitation(
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
  final List<PointAuditEntry> _pointHistory = [];
  final Set<String> _takenNicknames = {};

  /// Seeds taken nicknames (case-insensitive) for testing unique nickname validation.
  void seedTakenNicknamesForTest(Iterable<String> nicknames) {
    _takenNicknames
      ..clear()
      ..addAll(
        nicknames.map((n) => n.trim().toLowerCase()).where((n) => n.isNotEmpty),
      );
  }

  void _loadInitialSeedData() {
    _isAuthenticated = true;
    _currentUser = UserProfile(
      id: '11111111-1111-1111-1111-111111111111',
      displayName: 'Jon Paul Berana',
      firstName: 'Jon Paul',
      lastName: 'Berana',
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
        firstName: 'Jon Paul',
        lastName: 'Berana',
        fullName: 'Jon Paul Berana',
        nickname: 'JP',
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
        firstName: 'Maria',
        lastName: 'Santos',
        fullName: 'Maria Santos',
        nickname: 'Maria',
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
        firstName: 'Alex',
        lastName: 'Rivera',
        fullName: 'Alex Rivera',
        nickname: 'Alex',
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
        firstName: 'Ria',
        lastName: 'Garcia',
        fullName: 'Ria Garcia',
        nickname: 'Ria',
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
      ),
    ]);

    // Housemates Agenda Invitation
    final seededAgenda = HousematesAgendaInvitation(
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
          HousematesAgendaResponse(
            userId: _members[i].profile.id,
            displayName: _members[i].profile.displayName,
            avatarUrl: _members[i].profile.avatarUrl,
            response: i == 3 ? 'maybe' : 'going',
          ),
      ],
    );
    _housematesAgendaInvitations
      ..clear()
      ..add(seededAgenda);
    _activeHousematesAgenda = seededAgenda;

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
  List<ParcelItem> get parcels => List.unmodifiable(_parcels);
  List<LostFoundItem> get items => List.unmodifiable(_items);
  List<MaintenanceTask> get tasks => List.unmodifiable(_tasks);
  List<ChoreRouletteRecord> get rouletteRecords =>
      List.unmodifiable(_rouletteRecords);
  ChoreRouletteRecord? rouletteRecordForTask(String taskId) {
    for (final r in _rouletteRecords) {
      if (r.taskId == taskId) return r;
    }
    return null;
  }
  HousematesAgendaInvitation get activeHousematesAgenda =>
      _activeHousematesAgenda;
  List<HousematesAgendaInvitation> get housematesAgendaInvitations =>
      List.unmodifiable(_housematesAgendaInvitations);

  List<ChatMessage> get groupMessages => List.unmodifiable(_groupMessages);
  List<ChatMessage> getDirectMessages(String contactKey) =>
      List.unmodifiable(_directMessages[contactKey.toLowerCase()] ?? []);
  int getDirectUnreadCount(String contactKey) =>
      _directUnreadCounts[contactKey.toLowerCase()] ?? 0;
  List<ChatSpace> get chatSpaces => List.unmodifiable(_chatSpaces);
  int get groupChatUnreadCount => _groupChatUnreadCount;
  int get unreadNotificationCount =>
      _notifications.where((n) => n.isSupportedNotification && n.isUnread).length;
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
      final userId = 'usr_${email.hashCode}';
      _currentUser = UserProfile(
        id: userId,
        displayName: name,
        firstName: name,
        fullName: name,
        nickname: name,
        birthday: DateTime(2000, 1, 1),
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
      _rouletteRecords.clear();
      _chatSpaces.clear();
      _directMessages.clear();
      _groupMessages.clear();
      _housematesAgendaInvitations.clear();
      _activeHousematesAgenda = HousematesAgendaInvitation(
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
    final userId = 'usr_${DateTime.now().millisecondsSinceEpoch}';
    _currentUser = UserProfile(
      id: userId,
      displayName: name,
      fullName: null,
      nickname: null,
      birthday: null,
      avatarUrl: null,
      hasConsentedTerms: false,
      hasCompletedOnboarding: false,
    );
    _currentHousehold = const Household(id: '', name: '', inviteCode: '');
    _workspaces.clear();
    _householdOrder.clear();
    _members.clear();
    _parcels.clear();
    _items.clear();
    _tasks.clear();
    _rouletteRecords.clear();
    _chatSpaces.clear();
    _directMessages.clear();
    _directUnreadCounts.clear();
    _groupMessages.clear();
    _pointHistory.clear();
    _quickSnaps.clear();
    _kasamaPoints = 0;
    _groupChatUnreadCount = 0;
    _notifications.clear();
    _housematesAgendaInvitations.clear();
    _activeHousematesAgenda = HousematesAgendaInvitation(
      id: 'placeholder_m',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
      goingCount: 0,
      maybeCount: 0,
      cantMakeCount: 0,
    );
    notifyListeners();
  }

  void clearActiveHouseholdForTest() {
    _currentHousehold = const Household(id: '', name: '', inviteCode: '');
    _workspaces.clear();
    _householdOrder.clear();
    _members.clear();
    _parcels.clear();
    _items.clear();
    _tasks.clear();
    _rouletteRecords.clear();
    _chatSpaces.clear();
    _directMessages.clear();
    _directUnreadCounts.clear();
    _groupMessages.clear();
    _pointHistory.clear();
    _quickSnaps.clear();
    _kasamaPoints = 0;
    _groupChatUnreadCount = 0;
    _notifications.clear();
    _housematesAgendaInvitations.clear();
    _activeHousematesAgenda = HousematesAgendaInvitation(
      id: 'placeholder_m',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
      goingCount: 0,
      maybeCount: 0,
      cantMakeCount: 0,
    );
    notifyListeners();
  }

  void logout() {
    _flushAllPendingSnapReactionsSync(notify: false);
    _isAuthenticated = false;
    notifyListeners();
  }

  bool _isNicknameTaken(String candidate) {
    final normalized = candidate.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final currentNormalized = _currentUser.nickname?.trim().toLowerCase();
    if (currentNormalized == normalized) return false;
    if (_takenNicknames.contains(normalized)) return true;
    for (final m in _members) {
      if (m.profile.id != _currentUser.id &&
          (m.profile.nickname?.trim().toLowerCase() == normalized)) {
        return true;
      }
    }
    for (final ws in _workspaces.values) {
      for (final m in ws.members) {
        if (m.profile.id != _currentUser.id &&
            (m.profile.nickname?.trim().toLowerCase() == normalized)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<String?> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? fullName,
    String? nickname,
    DateTime? birthday,
    String? avatarUrl,
    bool? hasConsentedTerms,
    bool? hasCompletedOnboarding,
    bool clearAvatar = false,
    bool clearNickname = false,
    bool clearBirthday = false,
  }) async {
    final trimmedNickname = nickname?.trim();
    if (!clearNickname &&
        trimmedNickname != null &&
        trimmedNickname.isNotEmpty &&
        _isNicknameTaken(trimmedNickname)) {
      return CasamaRepository.duplicateNicknameMessage;
    }

    final normalizedBirthday = birthday != null
        ? DateTime(birthday.year, birthday.month, birthday.day)
        : null;
    final String? effectiveFirstName;
    final String? effectiveLastName;
    if (firstName != null || lastName != null) {
      final f = (firstName ?? _currentUser.firstName ?? '').trim();
      final l = (lastName ?? _currentUser.lastName ?? '').trim();
      effectiveFirstName = f.isNotEmpty ? f : null;
      effectiveLastName = l.isNotEmpty ? l : null;
    } else if (fullName != null && fullName.trim().isNotEmpty) {
      final parts = UserProfile.splitFullName(fullName);
      effectiveFirstName =
          parts.firstName.isNotEmpty ? parts.firstName : null;
      effectiveLastName = parts.lastName.isNotEmpty ? parts.lastName : null;
    } else {
      effectiveFirstName = _currentUser.firstName;
      effectiveLastName = _currentUser.lastName;
    }

    final joinedName = UserProfile.joinFullName(
      effectiveFirstName ?? '',
      effectiveLastName ?? '',
    );
    final effectiveFullName = joinedName.isNotEmpty
        ? joinedName
        : (fullName?.trim().isNotEmpty == true
            ? fullName!.trim()
            : _currentUser.fullName);
    final effectiveDisplayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : (effectiveFullName != null && effectiveFullName.trim().isNotEmpty
            ? effectiveFullName.trim()
            : _currentUser.displayName);

    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: effectiveDisplayName,
      firstName: effectiveFirstName,
      lastName: effectiveLastName,
      fullName: effectiveFullName,
      nickname: clearNickname
          ? null
          : ((trimmedNickname != null && trimmedNickname.isNotEmpty)
              ? trimmedNickname
              : (nickname != null ? null : _currentUser.nickname)),
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
    return null;
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
    _currentUser = _currentUser.copyWith(hasConsentedTerms: true);
    notifyListeners();
  }

  void completeOnboardingTutorial() {
    _currentUser = _currentUser.copyWith(hasCompletedOnboarding: true);
    notifyListeners();
  }

  void updatePresence({required bool isHome, String? note}) {
    final index = _members.indexWhere((m) => m.profile.id == _currentUser.id);
    if (index != -1) {
      _members[index] = MemberPresence(
        profile: _members[index].profile,
        isHome: isHome,
        note: note,
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
        codSettled: isSelfClaim,
        claimedById: _currentUser.id,
        claimedByName: _currentUser.displayName,
        claimedAt: now,
        settledAt: isSelfClaim ? now : null,
      );
      _pushNotification(
        type: 'parcel_claimed',
        title: '${_currentUser.displayName} received ${p.courier} parcel',
        subtitle: isSelfClaim
            ? 'Marked your ${p.courier} delivery as received.'
            : 'Claimed ${p.buyerName}\'s ${p.courier} delivery — awaiting settlement.',
        payload: {
          'entity_type': 'parcel',
          'entity_id': p.id,
          'parcel_id': p.id,
          'courier': p.courier,
          'receiver_id': _currentUser.id,
          'receiver_name': _currentUser.displayName,
        },
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
    final parcelId = 'p_${DateTime.now().millisecondsSinceEpoch}_${++_nextIdSeq}';
    _parcels.insert(
      0,
      ParcelItem(
        id: parcelId,
        householdId: _currentHousehold.id,
        buyerId: _currentUser.id,
        buyerName: _currentUser.displayName,
        courier: courier,
        expectedArrival: arrival,
        paymentType: paymentType,
        codAmount: codAmount,
        status: ParcelStatus.expected,
        notes: notes,
      ),
    );
    _pushNotification(
      type: 'parcel_posted',
      title: 'New $courier parcel for ${_currentUser.displayName}',
      subtitle: paymentType == ParcelPaymentType.cod && codAmount != null
          ? 'COD ₱${codAmount.toStringAsFixed(0)} — check if you can receive it.'
          : 'Prepaid delivery — expected soon.',
      payload: {
        'entity_type': 'parcel',
        'entity_id': parcelId,
        'parcel_id': parcelId,
        'courier': courier,
        'cod_amount': codAmount,
      },
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
      final now = DateTime.now();
      _tasks[index] = t.copyWith(
        status: TaskStatus.done,
        completedById: _currentUser.id,
        completedByName: _currentUser.displayName,
        completedAt: now,
      );
      final rouletteRecord = rouletteRecordForTask(taskId);
      if (rouletteRecord != null) {
        final rIdx = _rouletteRecords.indexWhere(
          (r) => r.id == rouletteRecord.id,
        );
        if (rIdx != -1) {
          _rouletteRecords[rIdx] = _rouletteRecords[rIdx].copyWith(
            status: 'completed',
            completedAt: now,
          );
        }
      }
      final isSelfCreated =
          t.createdBy.isNotEmpty && t.createdBy == _currentUser.id;
      final pts = t.rewardPointsForUser(
        _currentUser.id,
        rouletteRecord: rouletteRecord,
      );
      if (pts > 0) {
        _awardPointsToUser(
          userId: _currentUser.id,
          points: pts,
          title: 'Completed task: ${t.title}',
          category: 'task',
        );
      }
      _pushNotification(
        type: 'task_completed',
        title: '${_currentUser.displayName} completed "${t.title}"',
        subtitle: isSelfCreated
            ? 'Task marked as done.'
            : 'Earned +$pts pts for the household!',
        payload: {
          'entity_type': 'task',
          'entity_id': t.id,
          'task_id': t.id,
          'task_title': t.title,
          'is_self_created': isSelfCreated,
          'points': pts,
        },
      );
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
    final nextCod = nextPay == ParcelPaymentType.cod
        ? (codAmount ?? p.codAmount)
        : null;
    if ((paymentType != null || codAmount != null) &&
        nextPay == ParcelPaymentType.cod &&
        (nextCod == null || nextCod <= 0)) {
      throw ArgumentError('COD parcels require an amount greater than 0.');
    }
    final nextStatus = status ?? p.status;
    final normalizedNotes =
        notes == null ? p.notes : (notes.trim().isEmpty ? null : notes.trim());
    _parcels[index] = ParcelItem(
      id: p.id,
      householdId: p.householdId,
      buyerId: p.buyerId,
      buyerName: p.buyerName,
      courier: courier ?? p.courier,
      expectedArrival: arrival ?? p.expectedArrival,
      paymentType: nextPay,
      codAmount: nextCod,
      status: nextStatus,
      notes: normalizedNotes,
      codSettled: p.codSettled,
      claimedById: p.claimedById,
      claimedByName: p.claimedByName,
      claimedAt: p.claimedAt,
      settledAt: p.settledAt,
    );
    if (nextStatus == ParcelStatus.cancelled && p.status != ParcelStatus.cancelled) {
      _pushNotification(
        type: 'parcel_cancelled',
        title: '${p.courier} parcel cancelled',
        subtitle: '${p.buyerName} cancelled this delivery.',
        payload: {
          'entity_type': 'parcel',
          'entity_id': p.id,
          'parcel_id': p.id,
          'courier': p.courier,
        },
      );
    } else if (nextStatus == ParcelStatus.arrived && p.status != ParcelStatus.arrived) {
      _pushNotification(
        type: 'parcel_arrived',
        title: '📦 ${p.courier} parcel is arriving now!',
        subtitle: 'Delivery for ${p.buyerName} is expected now.',
        payload: {
          'entity_type': 'parcel',
          'entity_id': p.id,
          'parcel_id': p.id,
          'courier': p.courier,
        },
      );
    }
    notifyListeners();
  }

  Future<void> cancelParcel(String parcelId) =>
      updateParcel(parcelId: parcelId, status: ParcelStatus.cancelled);

  @override
  Future<void> deleteParcel(String parcelId) async {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index == -1) return;
    if (_parcels[index].buyerId != _currentUser.id) return;
    _parcels.removeAt(index);
    _purgeNotificationsForEntity(entityType: 'parcel', entityId: parcelId);
    notifyListeners();
  }

  Future<void> settleParcelClaim(String parcelId) async {
    final index = _parcels.indexWhere((p) => p.id == parcelId);
    if (index == -1) return;
    final p = _parcels[index];
    if (!p.isClaimed || p.isSettled) return;

    final now = DateTime.now();
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
      codSettled: true,
      claimedById: p.claimedById,
      claimedByName: p.claimedByName,
      claimedAt: p.claimedAt,
      settledAt: now,
    );

    final receiverId = p.claimedById;
    if (receiverId != null &&
        receiverId.isNotEmpty &&
        receiverId != p.buyerId) {
      _awardPointsToUser(
        userId: receiverId,
        points: 5,
        title: 'Received parcel: ${p.courier} for ${p.buyerName}',
        category: 'parcel',
      );
    }

    _pushNotification(
      type: 'parcel_settled',
      title: '${p.courier} parcel settled',
      subtitle: 'COD handoff completed cleanly.',
      payload: {
        'entity_type': 'parcel',
        'entity_id': p.id,
        'parcel_id': p.id,
        'courier': p.courier,
      },
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
  }) {
    final taskId = 't_${DateTime.now().millisecondsSinceEpoch}_${++_nextIdSeq}';
    _tasks.insert(
      0,
      MaintenanceTask(
        id: taskId,
        householdId: _currentHousehold.id,
        title: title,
        description: description,
        category: category,
        urgency: urgency,
        status: TaskStatus.open,
        createdBy: _currentUser.id,
        createdByName: _currentUser.displayName,
        createdAt: DateTime.now(),
      ),
    );
    _pushNotification(
      type: 'task_created',
      title: 'New task: $title',
      subtitle: '${_currentUser.displayName} posted a ${urgency.label.toLowerCase()} ${category.label.toLowerCase()} task.',
      payload: {
        'entity_type': 'task',
        'entity_id': taskId,
        'task_id': taskId,
        'task_title': title,
      },
    );
    notifyListeners();
  }

  String _resolveMockMemberName(String userId) {
    if (userId == _currentUser.id) {
      final nick = _currentUser.nickname?.trim();
      if (nick != null && nick.isNotEmpty) return nick;
      return _currentUser.displayName;
    }
    if (userId == _seededPrimaryUserId) {
      return 'Jon Paul Berana';
    }
    for (final m in _members) {
      if (m.profile.id == userId) {
        final raw = m.profile.displayName.trim();
        if (raw.isNotEmpty && raw != 'You') return raw;
      }
    }
    return 'Housemate';
  }

  Future<ChoreRouletteRecord> spinTaskRoulette(
    String taskId,
    String selectedUserId,
  ) async {
    final taskIndex = _tasks.indexWhere((t) => t.id == taskId);
    if (taskIndex == -1) {
      throw StateError('Task not found.');
    }
    final task = _tasks[taskIndex];
    if (task.status == TaskStatus.done) {
      throw StateError('Cannot spin a completed task.');
    }
    if (_rouletteRecords.any((r) => r.taskId == taskId)) {
      throw StateError('This task has already been spun.');
    }
    if (task.createdBy.isNotEmpty && selectedUserId == task.createdBy) {
      throw StateError('The task creator cannot be chosen by Task Roulette.');
    }

    final now = DateTime.now();
    final spinnerName = _resolveMockMemberName(_currentUser.id);
    final chosenName = _resolveMockMemberName(selectedUserId);
    const bonusPts = 4;
    final basePts = task.computedPoints;
    final totalPts = basePts + bonusPts;

    final record = ChoreRouletteRecord(
      id: 'spin_${now.microsecondsSinceEpoch}_${++_nextIdSeq}',
      householdId: _currentHousehold.id,
      taskId: taskId,
      choreTitle: task.title,
      selectedUserId: selectedUserId,
      selectedUserName: chosenName,
      spunByUserId: _currentUser.id,
      spunByName: spinnerName,
      status: 'assigned',
      bonusPoints: bonusPts,
      createdAt: now,
    );

    _rouletteRecords.insert(0, record);

    final isChosenCreator =
        task.createdBy.isNotEmpty && selectedUserId == task.createdBy;
    final notifTitle = '🎡 You were chosen for "${task.title}"!';
    final notifMessage = isChosenCreator
        ? '$spinnerName spun the wheel and picked you for "${task.title}"!'
        : '$spinnerName spun the wheel and picked you — earn +$bonusPts bonus pts ($totalPts pts total)!';

    _notifications.insert(
      0,
      HouseholdNotificationItem(
        id: 'notif_roulette_${now.microsecondsSinceEpoch}_${++_nextIdSeq}',
        type: 'roulette_chosen',
        title: notifTitle,
        subtitle: notifMessage,
        createdAt: now,
        isRead: false,
        payload: {
          'entity_type': 'task',
          'entity_id': task.id,
          'actor_id': _currentUser.id,
          'roulette_id': record.id,
          'task_id': task.id,
          'task_title': task.title,
          'spinner_id': _currentUser.id,
          'spinner_name': spinnerName,
          'selected_user_id': selectedUserId,
          'base_points': basePts,
          'bonus_points': bonusPts,
          'total_points': totalPts,
          'title': notifTitle,
          'message': notifMessage,
        },
      ),
    );

    notifyListeners();
    return record;
  }

  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? location,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    final itemId = 'i_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}';
    _items.insert(
      0,
      LostFoundItem(
        id: itemId,
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
    final isLost = type == ItemType.lost;
    _pushNotification(
      type: isLost ? 'lost_item_posted' : 'found_item_posted',
      title: isLost ? 'Lost item: $title' : 'Found item: $title',
      subtitle: isLost
          ? '${_currentUser.displayName} reported a missing item${location != null && location.isNotEmpty ? ' ($location)' : ''}.'
          : '${_currentUser.displayName} found an item${location != null && location.isNotEmpty ? ' at $location' : ''}.',
      payload: {
        'entity_type': isLost ? 'lost_item' : 'found_item',
        'entity_id': itemId,
        if (isLost) 'lost_item_id': itemId else 'found_item_id': itemId,
        'item_title': title,
      },
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

  Future<void> createHousematesAgendaInvitation({
    required String activity,
    required String location,
    required DateTime scheduledTime,
    String? announcementText,
  }) async {
    if (activity.trim().isEmpty && location.trim().isEmpty) {
      _housematesAgendaInvitations.clear();
      _recomputeActiveHousematesAgenda();
      notifyListeners();
      return;
    }

    final otherMembers = _members
        .where((m) => m.profile.id != _currentUser.id)
        .toList();
    final seededResponders = <HousematesAgendaResponse>[
      HousematesAgendaResponse(
        userId: _currentUser.id,
        displayName: _currentUser.displayName,
        avatarUrl: _currentUser.avatarUrl,
        response: 'going',
      ),
      for (final m in otherMembers)
        HousematesAgendaResponse(
          userId: m.profile.id,
          displayName: m.profile.displayName,
          avatarUrl: m.profile.avatarUrl,
          response: 'maybe',
        ),
    ];

    final created = HousematesAgendaInvitation(
      id: 'ha_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}',
      creatorId: _currentUser.id,
      activity: activity,
      location: location,
      scheduledTime: scheduledTime.toLocal(),
      status: 'upcoming',
      reminderSent: false,
      arrivalHandled: false,
      goingCount: 1,
      maybeCount: otherMembers.length,
      cantMakeCount: 0,
      currentUserResponse: 'going',
      responders: seededResponders,
    );
    _housematesAgendaInvitations.add(created);
    _housematesAgendaInvitations.sort(
      (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
    );
    _pushNotification(
      type: 'housemates_agenda_created',
      title: 'New Housemates Agenda: $activity',
      subtitle: '$location — tap to RSVP!',
      payload: {
        'entity_type': 'housemates_agenda',
        'entity_id': created.id,
        'invitation_id': created.id,
        'creator_id': _currentUser.id,
        'location': location,
      },
    );
    _recomputeActiveHousematesAgenda();
    notifyListeners();
  }

  Future<void> updateHousematesAgendaStatus(
    String invitationId,
    String status,
  ) async {
    if (status != 'done' && status != 'missed') {
      throw ArgumentError.value(status, 'status', "Must be 'done' or 'missed'");
    }
    final idx = _housematesAgendaInvitations.indexWhere(
      (m) => m.id == invitationId,
    );
    if (idx != -1) {
      final inv = _housematesAgendaInvitations[idx];
      _housematesAgendaInvitations[idx] = inv.copyWith(status: status);
      _pushNotification(
        type: 'housemates_agenda_resolved',
        title: '${inv.activity} marked ${status == 'done' ? 'Done' : 'Missed'}',
        subtitle: '${inv.location} • Updated by ${_currentUser.displayName}.',
        payload: {
          'entity_type': 'housemates_agenda',
          'entity_id': inv.id,
          'invitation_id': inv.id,
          'creator_id': inv.creatorId,
          'location': inv.location,
        },
      );
      _recomputeActiveHousematesAgenda();
      notifyListeners();
    }
  }

  Future<void> deleteHousematesAgendaInvitation(String invitationId) async {
    _housematesAgendaInvitations.removeWhere((m) => m.id == invitationId);
    _purgeNotificationsForEntity(
      entityType: 'housemates_agenda',
      entityId: invitationId,
    );
    _recomputeActiveHousematesAgenda();
    notifyListeners();
  }

  void setActiveHousematesAgendaForTest(HousematesAgendaInvitation agenda) {
    _housematesAgendaInvitations
      ..clear()
      ..addAll([if (agenda.hasValidData) agenda]);
    _activeHousematesAgenda = agenda;
    notifyListeners();
  }

  void addHousematesAgendaForTest(HousematesAgendaInvitation agenda) {
    _housematesAgendaInvitations.add(agenda);
    _housematesAgendaInvitations.sort(
      (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
    );
    _recomputeActiveHousematesAgenda();
    notifyListeners();
  }

  void addGroupMessageForTest(ChatMessage message) {
    _groupMessages.add(message);
    if (!message.isCurrentUser) {
      _groupChatUnreadCount++;
    }
    notifyListeners();
  }

  void addSpaceMessageForTest(String spaceId, ChatMessage message) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1) {
      final space = _chatSpaces[idx];
      _chatSpaces[idx] = space.copyWith(
        messages: [...space.messages, message],
        unreadCount: message.isCurrentUser
            ? space.unreadCount
            : space.unreadCount + 1,
      );
      notifyListeners();
    }
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

  void respondToHousematesAgendaInvitation(
    String response, {
    String? invitationId,
  }) {
    final targetId = invitationId ?? _activeHousematesAgenda.id;
    final idx = _housematesAgendaInvitations.indexWhere(
      (m) => m.id == targetId,
    );
    final target =
        idx != -1 ? _housematesAgendaInvitations[idx] : _activeHousematesAgenda;
    if (!target.hasValidData || !target.isUpcoming) return;

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
      HousematesAgendaResponse(
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
      _housematesAgendaInvitations[idx] = updated;
    }
    _recomputeActiveHousematesAgenda();
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
              m.profile.preferredName.toLowerCase().contains(key) ||
              (m.profile.nickname?.toLowerCase().contains(key) ?? false) ||
              (m.profile.fullName?.toLowerCase().contains(key) ?? false) ||
              m.profile.displayName.toLowerCase().contains(key),
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

    final foundId = 'fi_${DateTime.now().microsecondsSinceEpoch}_${++_nextIdSeq}';
    _items.insert(
      0,
      LostFoundItem(
        id: foundId,
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
    _pushNotification(
      type: 'lost_item_find_submitted',
      title: '${_currentUser.displayName} may have found "${lostItem.title}"!',
      subtitle: 'Tap to review and confirm match.',
      payload: {
        'entity_type': 'lost_item',
        'entity_id': lostItem.id,
        'lost_item_id': lostItem.id,
        'found_item_id': foundId,
        'item_title': lostItem.title,
      },
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
    _pushNotification(
      type: 'lost_item_find_accepted',
      title: 'Match confirmed for "${lost.title}"!',
      subtitle: '${found.reportedByName} earned +5 pts for returning it.',
      payload: {
        'entity_type': 'lost_item',
        'entity_id': lost.id,
        'lost_item_id': lost.id,
        'found_item_id': found.id,
        'item_title': lost.title,
        'points': 5,
      },
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
    _pushNotification(
      type: 'lost_item_find_rejected',
      title: 'Not a match for "${_items[lostIdx].title}"',
      subtitle: '${_currentUser.displayName} is still looking for this item.',
      payload: {
        'entity_type': 'lost_item',
        'entity_id': _items[lostIdx].id,
        'lost_item_id': _items[lostIdx].id,
        'found_item_id': found.id,
        'item_title': _items[lostIdx].title,
      },
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
    _pushNotification(
      type: 'lost_item_self_resolved',
      title: '"${lost.title}" was found!',
      subtitle: '${_currentUser.displayName} marked it resolved.',
      payload: {
        'entity_type': 'lost_item',
        'entity_id': lost.id,
        'lost_item_id': lost.id,
        'item_title': lost.title,
      },
    );
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
    _pushNotification(
      type: 'found_item_claimed',
      title: '${_currentUser.displayName} claimed "${item.title}"',
      subtitle: '${item.reportedByName} earned +2 pts!',
      payload: {
        'entity_type': 'found_item',
        'entity_id': item.id,
        'found_item_id': item.id,
        'item_title': item.title,
        'points': 2,
      },
    );
    notifyListeners();
    return null;
  }

  // ==========================================
  // PART 5: Housemate Management
  // ==========================================

  bool isHousemateAuthorized(String contactKey) {
    final key = contactKey.toLowerCase().replaceAll('@', '').trim();
    return _members.any((m) {
      final mPref = m.preferredName.toLowerCase().trim();
      final mNick = (m.profile.nickname ?? '').toLowerCase().trim();
      final mFull = (m.profile.fullName ?? '').toLowerCase().trim();
      final mName = m.profile.displayName.toLowerCase().trim();
      final mId = m.profile.id.toLowerCase().trim();
      return mPref == key ||
          mNick == key ||
          mFull == key ||
          mName == key ||
          mId == key;
    });
  }

  void resetMembersForNewUserTest() {
    _members.retainWhere((m) => m.profile.id == _currentUser.id);
    _ensureCurrentWorkspaceRegistered();
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
  final List<MemberPresence> members;
  final List<ParcelItem> parcels;
  final List<LostFoundItem> items;
  final List<MaintenanceTask> tasks;
  final List<ChoreRouletteRecord> rouletteRecords;
  final List<HousematesAgendaInvitation> housematesAgendaInvitations;
  final HousematesAgendaInvitation activeHousematesAgenda;
  final List<ChatMessage> groupMessages;
  final List<ChatSpace> chatSpaces;
  final Map<String, List<ChatMessage>> directMessages;
  final Map<String, int> directUnreadCounts;
  final List<QuickSnap> quickSnaps;
  final List<PointAuditEntry> pointHistory;

  const _MockHouseholdWorkspace({
    required this.household,
    required this.kasamaPoints,
    required this.groupChatUnreadCount,
    required this.notifications,
    required this.members,
    required this.parcels,
    required this.items,
    required this.tasks,
    this.rouletteRecords = const [],
    required this.housematesAgendaInvitations,
    required this.activeHousematesAgenda,
    required this.groupMessages,
    required this.chatSpaces,
    required this.directMessages,
    this.directUnreadCounts = const {},
    required this.quickSnaps,
    required this.pointHistory,
  });
}
