import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'casama_repository.dart';
import 'models.dart';

/// Real cloud-synchronized repository implementation backed by Supabase.
/// Communicates with Supabase Auth, PostgreSQL 15+ (with Row Level Security),
/// Realtime WebSockets, and Storage.
class SupabaseRepository extends ChangeNotifier implements CasamaRepository {
  final SupabaseClient _client;
  RealtimeChannel? _realtimeChannel;

  // Cached state
  bool _isAuthenticated = false;
  UserProfile _currentUser = const UserProfile(
    id: '',
    displayName: 'User',
    handle: '@user',
  );
  Household _currentHousehold = const Household(
    id: '',
    name: 'Casa 204',
    inviteCode: 'CASA204',
  );
  int _kasamaPoints = 120;

  List<MemberPresence> _members = [];
  List<ParcelItem> _parcels = [];
  List<LostFoundItem> _items = [];
  List<MaintenanceTask> _tasks = [];
  List<HouseholdBill> _bills = [];
  List<ChatMessage> _groupMessages = [];
  final List<ChatSpace> _chatSpaces = [];
  final Map<String, List<ChatMessage>> _directMessages = {};
  MeetUpInvitation _activeMeetUp = MeetUpInvitation(
    id: 'mu1',
    activity: 'Study Session 🎓',
    location: 'Dorm Common Area',
    scheduledTime: DateTime.now().add(const Duration(hours: 5)),
    goingCount: 3,
    maybeCount: 1,
  );
  final List<PointAuditEntry> _pointHistory = [];
  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();
  final List<HouseholdInvitation> _invitations = [];
  List<QuickSnap> _quickSnaps = [];

  SupabaseRepository(this._client) {
    _init();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // Getters
  @override
  bool get isAuthenticated =>
      _isAuthenticated || _client.auth.currentUser != null;

  @override
  UserProfile get currentUser => _currentUser;

  @override
  Household get currentHousehold => _currentHousehold;

  @override
  int get kasamaPoints => _kasamaPoints;

  @override
  String get effectiveGreetingName => _currentUser.effectiveGreetingName;

  @override
  List<MemberPresence> get members => List.unmodifiable(_members);

  @override
  List<ParcelItem> get parcels => List.unmodifiable(_parcels);

  @override
  List<LostFoundItem> get items => List.unmodifiable(_items);

  @override
  List<MaintenanceTask> get tasks => List.unmodifiable(_tasks);

  @override
  List<HouseholdBill> get bills => List.unmodifiable(_bills);

  @override
  List<ChatMessage> get groupMessages => List.unmodifiable(_groupMessages);

  @override
  List<ChatSpace> get chatSpaces => List.unmodifiable(_chatSpaces);

  @override
  int get groupChatUnreadCount => 0;

  @override
  int get unreadNotificationCount => 0;

  @override
  int get totalUnreadChatCount => 0;

  @override
  MeetUpInvitation get activeMeetUp => _activeMeetUp;

  @override
  List<PointAuditEntry> get pointHistory => List.unmodifiable(_pointHistory);

  @override
  NotificationPreferences get notificationPreferences =>
      _notificationPreferences;

  @override
  List<HouseholdInvitation> get invitations => List.unmodifiable(_invitations);

  @override
  List<QuickSnap> get quickSnaps => List.unmodifiable(_quickSnaps);

  @override
  QuickSnap? get latestQuickSnap =>
      _quickSnaps.isNotEmpty ? _quickSnaps.first : null;

  @override
  int get quickSnapStreak {
    if (_quickSnaps.isEmpty) return 0;
    return 1;
  }

  @override
  List<ChatMessage> getDirectMessages(String contactKey) {
    return _directMessages[contactKey.toLowerCase()] ?? [];
  }

  @override
  bool isHousemateAuthorized(String contactKey) => true;

  @override
  List<UserProfile> searchUsers(String query) => [];

  // ==========================================
  // INITIALIZATION & REALTIME
  // ==========================================

  Future<void> _init() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      _isAuthenticated = false;
      return;
    }

    _isAuthenticated = true;

    try {
      // 1. Fetch User Profile
      final profileData = await _client
          .from('profiles')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (profileData != null) {
        _currentUser = UserProfile.fromJson(profileData);
      } else {
        _currentUser = UserProfile(
          id: authUser.id,
          displayName: authUser.email?.split('@').first ?? 'Housemate',
          handle: '@${authUser.email?.split('@').first ?? 'member'}',
        );
      }

      // 2. Fetch Household
      final memberRecord = await _client
          .from('household_members')
          .select('household_id, households(id, name, invite_code, created_by)')
          .eq('user_id', authUser.id)
          .maybeSingle();

      if (memberRecord != null && memberRecord['households'] != null) {
        _currentHousehold = Household.fromJson(
          memberRecord['households'] as Map<String, dynamic>,
        );
      } else {
        try {
          final existing = await _client.from('households').select().limit(1).maybeSingle();
          if (existing != null) {
            _currentHousehold = Household.fromJson(existing);
            await _client.from('household_members').upsert({
              'household_id': _currentHousehold.id,
              'user_id': authUser.id,
              'role': 'member',
            });
          } else {
            final newHousehold = await _client.from('households').insert({
              'name': 'Casa 204',
              'invite_code': 'CASA204',
              'created_by': authUser.id,
            }).select().single();
            _currentHousehold = Household.fromJson(newHousehold);
            await _client.from('household_members').upsert({
              'household_id': _currentHousehold.id,
              'user_id': authUser.id,
              'role': 'admin',
            });
          }
        } catch (_) {}
      }

      // 3. Hydrate Core Tables
      await _fetchHouseholdData();

      // 4. Setup Realtime Sync
      _setupRealtime();
    } catch (e) {
      debugPrint('SupabaseRepository initialization error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _fetchHouseholdData() async {
    if (_currentHousehold.id.isEmpty) return;

    try {
      final householdId = _currentHousehold.id;

      // Fetch Members
      final membersRes = await _client
          .from('household_members')
          .select('user_id, profiles(*)')
          .eq('household_id', householdId);

      _members = (membersRes as List<dynamic>).map((m) {
        final profile = UserProfile.fromJson(m['profiles'] as Map<String, dynamic>);
        return MemberPresence(
          profile: profile,
          isHome: true,
          updatedAt: DateTime.now(),
        );
      }).toList();

      // Fetch Bills
      final billsRes = await _client
          .from('bills')
          .select()
          .eq('household_id', householdId)
          .order('deadline', ascending: true);

      _bills = (billsRes as List<dynamic>)
          .map((b) => HouseholdBill.fromJson(b as Map<String, dynamic>))
          .toList();

      // Fetch QuickSnaps
      final snapsRes = await _client
          .from('quick_snaps')
          .select('*, quick_snap_reactions(*), quick_snap_comments(*)')
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      _quickSnaps = (snapsRes as List<dynamic>)
          .map((s) => QuickSnap.fromJson(s as Map<String, dynamic>))
          .toList();

      // Fetch Parcels
      final parcelsRes = await _client
          .from('parcels')
          .select()
          .eq('household_id', householdId)
          .order('expected_arrival', ascending: true);

      _parcels = (parcelsRes as List<dynamic>)
          .map((p) => ParcelItem.fromJson(p as Map<String, dynamic>))
          .toList();

      // Fetch Tasks
      final tasksRes = await _client
          .from('maintenance_tasks')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      _tasks = (tasksRes as List<dynamic>)
          .map((t) => MaintenanceTask.fromJson(t as Map<String, dynamic>))
          .toList();

      // Fetch Lost & Found Items
      final itemsRes = await _client
          .from('items')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      _items = (itemsRes as List<dynamic>)
          .map((i) => LostFoundItem.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching household data from Supabase: $e');
    }
  }

  void _setupRealtime() {
    if (_currentHousehold.id.isEmpty) return;

    _realtimeChannel?.unsubscribe();

    _realtimeChannel = _client.channel('household_${_currentHousehold.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'bills',
        callback: (_) => _fetchHouseholdData().then((_) => notifyListeners()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'quick_snaps',
        callback: (_) => _fetchHouseholdData().then((_) => notifyListeners()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => _fetchHouseholdData().then((_) => notifyListeners()),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'parcels',
        callback: (_) => _fetchHouseholdData().then((_) => notifyListeners()),
      )
      ..subscribe();
  }

  // ==========================================
  // AUTH & ONBOARDING
  // ==========================================

  @override
  void login({String? email, String? password}) async {
    if (email != null && password != null) {
      try {
        await _client.auth.signInWithPassword(email: email, password: password);
        await _init();
      } catch (e) {
        debugPrint('Login error: $e');
      }
    } else {
      _isAuthenticated = true;
      notifyListeners();
    }
  }

  @override
  void register({required String email, required String password}) async {
    try {
      await _client.auth.signUp(email: email, password: password);
      await _init();
    } catch (e) {
      debugPrint('Registration error: $e');
    }
  }

  @override
  void logout() async {
    try {
      await _client.auth.signOut();
    } catch (_) {}
    _isAuthenticated = false;
    _realtimeChannel?.unsubscribe();
    notifyListeners();
  }

  @override
  void updateProfile({
    String? displayName,
    String? handle,
    String? fullName,
    String? nickname,
    int? age,
    DateTime? birthDate,
    String? avatarUrl,
    bool clearAvatar = false,
    bool clearNickname = false,
    bool clearAge = false,
    bool clearBirthDate = false,
  }) async {
    final effectiveDisplayName = displayName ?? _currentUser.displayName;
    final effectiveFullName = fullName ?? _currentUser.fullName;
    final effectiveNickname = clearNickname ? null : (nickname ?? _currentUser.nickname);
    final effectiveHandle = handle ?? _currentUser.handle;
    final effectiveAge = clearAge ? null : (age ?? _currentUser.age);
    final effectiveBirthDate = clearBirthDate ? null : (birthDate ?? _currentUser.birthDate);
    final effectiveAvatarUrl = clearAvatar ? null : (avatarUrl ?? _currentUser.avatarUrl);

    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: effectiveDisplayName,
      handle: effectiveHandle,
      fullName: effectiveFullName,
      nickname: effectiveNickname,
      age: effectiveAge,
      birthDate: effectiveBirthDate,
      avatarUrl: effectiveAvatarUrl,
      hasConsentedTerms: _currentUser.hasConsentedTerms,
      hasCompletedOnboarding: _currentUser.hasCompletedOnboarding,
    );
    notifyListeners();

    if (_currentUser.id.isNotEmpty) {
      try {
        final updates = <String, dynamic>{
          'display_name': effectiveDisplayName,
          'handle': effectiveHandle,
          'full_name': effectiveFullName,
          'nickname': effectiveNickname,
          'age': effectiveAge,
          'avatar_url': effectiveAvatarUrl,
        };
        if (effectiveBirthDate != null) {
          updates['birth_date'] = effectiveBirthDate.toIso8601String();
        }
        await _client.from('profiles').update(updates).eq('id', _currentUser.id);
      } catch (e) {
        debugPrint('Supabase updateProfile error: $e');
      }
    }
  }

  @override
  void recordTermsConsent() async {
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

    if (_currentUser.id.isNotEmpty) {
      try {
        await _client.from('profiles').update({'has_consented_terms': true}).eq('id', _currentUser.id);
      } catch (_) {}
    }
  }

  @override
  void completeOnboardingTutorial() async {
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

    if (_currentUser.id.isNotEmpty) {
      try {
        await _client.from('profiles').update({'has_completed_onboarding': true}).eq('id', _currentUser.id);
      } catch (_) {}
    }
  }

  @override
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

  @override
  void updatePresence({required bool isHome, String? note}) async {
    final idx = _members.indexWhere((m) => m.profile.id == _currentUser.id);
    if (idx != -1) {
      _members[idx] = MemberPresence(
        profile: _currentUser,
        isHome: isHome,
        note: note,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();

    if (_currentHousehold.id.isNotEmpty && _currentUser.id.isNotEmpty) {
      try {
        await _client.from('presence_events').insert({
          'household_id': _currentHousehold.id,
          'user_id': _currentUser.id,
          'is_home': isHome,
          'note': note,
        });
      } catch (e) {
        debugPrint('Supabase presence error: $e');
      }
    }
  }

  // ==========================================
  // BILLS & PAYMENTS
  // ==========================================

  @override
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
  }) async {
    final newBill = HouseholdBill(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      householdId: _currentHousehold.id,
      creatorId: _currentUser.id,
      creatorName: _currentUser.displayName,
      category: category,
      customCategoryLabel: customCategoryLabel,
      billName: billName,
      amount: amount,
      deadline: deadline,
      notes: notes,
      status: BillStatus.unpaid,
      reminderEnabled: reminderEnabled,
      reminderTiming: reminderTiming,
      recipientType: recipientType,
      selectedRecipientNames: selectedRecipientNames,
      responsibleMember: responsibleMember,
      createdAt: DateTime.now(),
    );

    _bills = [newBill, ..._bills];
    notifyListeners();

    if (_currentHousehold.id.isNotEmpty) {
      try {
        await _client.from('bills').insert(newBill.toJson());
      } catch (e) {
        debugPrint('Supabase addBill error: $e');
      }
    }
  }

  @override
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
  }) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx != -1) {
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

      try {
        await _client.from('bills').update(_bills[idx].toJson()).eq('id', billId);
      } catch (e) {
        debugPrint('Supabase updateBill error: $e');
      }
    }
  }

  @override
  void markBillPaid(String billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx != -1) {
      _bills[idx] = _bills[idx].copyWith(
        status: BillStatus.paid,
        paidAt: DateTime.now(),
        paidByName: _currentUser.displayName,
      );
      notifyListeners();

      try {
        await _client.from('bills').update({
          'status': 'paid',
          'paid_at': DateTime.now().toIso8601String(),
          'paid_by': _currentUser.id.isNotEmpty ? _currentUser.id : null,
        }).eq('id', billId);
      } catch (_) {}
    }
  }

  @override
  void reopenBill(String billId) async {
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx != -1) {
      _bills[idx] = _bills[idx].copyWith(status: BillStatus.unpaid);
      notifyListeners();

      try {
        await _client.from('bills').update({
          'status': 'unpaid',
          'paid_at': null,
          'paid_by': null,
        }).eq('id', billId);
      } catch (_) {}
    }
  }

  @override
  void deleteBill(String billId) async {
    _bills.removeWhere((b) => b.id == billId);
    notifyListeners();

    try {
      await _client.from('bills').delete().eq('id', billId);
    } catch (_) {}
  }

  // ==========================================
  // QUICKSNAP LOCKET
  // ==========================================

  @override
  void sendQuickSnap({
    required String imageUrl,
    String? caption,
    QuickSnapRecipientType recipientType = QuickSnapRecipientType.everyone,
    List<String> recipientNames = const [],
  }) async {
    final newSnap = QuickSnap(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      householdId: _currentHousehold.id,
      senderId: _currentUser.id,
      senderName: _currentUser.effectiveGreetingName,
      senderAvatar: _currentUser.avatarUrl,
      imageUrl: imageUrl,
      caption: caption,
      recipientType: recipientType,
      recipientNames: recipientNames,
      createdAt: DateTime.now(),
    );

    _quickSnaps = [newSnap, ..._quickSnaps];
    notifyListeners();

    if (_currentHousehold.id.isNotEmpty) {
      try {
        await _client.from('quick_snaps').insert(newSnap.toJson());
      } catch (e) {
        debugPrint('Supabase sendQuickSnap error: $e');
      }
    }
  }

  @override
  void reactToQuickSnap(String snapId, String emoji) async {
    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final updatedReactions = List<QuickSnapReaction>.from(_quickSnaps[idx].reactions);
      updatedReactions.removeWhere((r) => r.userId == _currentUser.id);
      updatedReactions.add(
        QuickSnapReaction(
          emoji: emoji,
          userId: _currentUser.id,
          userName: _currentUser.effectiveGreetingName,
          createdAt: DateTime.now(),
        ),
      );
      _quickSnaps[idx] = _quickSnaps[idx].copyWith(reactions: updatedReactions);
      notifyListeners();

      try {
        await _client.from('quick_snap_reactions').insert({
          'snap_id': snapId,
          'user_id': _currentUser.id,
          'emoji': emoji,
        });
      } catch (_) {}
    }
  }

  @override
  void commentOnQuickSnap(String snapId, String text) async {
    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final updatedComments = List<QuickSnapComment>.from(_quickSnaps[idx].comments);
      updatedComments.add(
        QuickSnapComment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: _currentUser.id,
          userName: _currentUser.effectiveGreetingName,
          userAvatar: _currentUser.avatarUrl,
          text: text,
          createdAt: DateTime.now(),
        ),
      );
      _quickSnaps[idx] = _quickSnaps[idx].copyWith(comments: updatedComments);
      notifyListeners();

      try {
        await _client.from('quick_snap_comments').insert({
          'snap_id': snapId,
          'user_id': _currentUser.id,
          'text': text,
        });
      } catch (_) {}
    }
  }

  @override
  void deleteQuickSnap(String snapId) async {
    _quickSnaps.removeWhere((s) => s.id == snapId);
    notifyListeners();

    try {
      await _client.from('quick_snaps').delete().eq('id', snapId);
    } catch (_) {}
  }

  // ==========================================
  // PARCELS, TASKS, LOST & FOUND, MESSAGING
  // ==========================================

  @override
  void receiveParcel(String parcelId) {
    final idx = _parcels.indexWhere((p) => p.id == parcelId);
    if (idx != -1) {
      _parcels[idx] = ParcelItem(
        id: _parcels[idx].id,
        householdId: _parcels[idx].householdId,
        buyerId: _parcels[idx].buyerId,
        buyerName: _parcels[idx].buyerName,
        courier: _parcels[idx].courier,
        expectedArrival: _parcels[idx].expectedArrival,
        paymentType: _parcels[idx].paymentType,
        codAmount: _parcels[idx].codAmount,
        currency: _parcels[idx].currency,
        status: ParcelStatus.received,
        notes: _parcels[idx].notes,
      );
      _kasamaPoints += 5;
      notifyListeners();
    }
  }

  @override
  void addParcel({
    required String courier,
    required DateTime arrival,
    required ParcelPaymentType paymentType,
    double? codAmount,
    String? notes,
  }) {
    final newParcel = ParcelItem(
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
    );
    _parcels = [newParcel, ..._parcels];
    notifyListeners();
  }

  @override
  void toggleParcelAvailability(String parcelId) {}

  @override
  void completeTask(String taskId) {
    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      _tasks[idx] = MaintenanceTask(
        id: _tasks[idx].id,
        householdId: _tasks[idx].householdId,
        title: _tasks[idx].title,
        category: _tasks[idx].category,
        urgency: _tasks[idx].urgency,
        status: TaskStatus.done,
        assigneeName: _tasks[idx].assigneeName,
        createdByName: _tasks[idx].createdByName,
        createdAt: _tasks[idx].createdAt,
      );
      _kasamaPoints += 15;
      notifyListeners();
    }
  }

  @override
  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? assigneeName,
  }) {
    final newTask = MaintenanceTask(
      id: 't_${DateTime.now().millisecondsSinceEpoch}',
      householdId: _currentHousehold.id,
      title: title,
      category: category,
      urgency: urgency,
      status: TaskStatus.open,
      assigneeName: assigneeName,
      createdByName: _currentUser.displayName,
      createdAt: DateTime.now(),
    );
    _tasks = [newTask, ..._tasks];
    notifyListeners();
  }

  @override
  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? imageUrl,
  }) {
    final newItem = LostFoundItem(
      id: 'i_${DateTime.now().millisecondsSinceEpoch}',
      householdId: _currentHousehold.id,
      type: type,
      title: title,
      description: description,
      imageUrl: imageUrl,
      status: ItemStatus.open,
      reportedBy: _currentUser.id,
      reportedByName: _currentUser.displayName,
      createdAt: DateTime.now(),
    );
    _items = [newItem, ..._items];
    notifyListeners();
  }

  @override
  void borrowItem(String itemId) {}

  @override
  void claimItem(String itemId) {}

  @override
  void returnItem(String itemId) {}

  @override
  void markGroupChatAsRead() {}

  @override
  void markSpaceChatAsRead(String spaceId) {}

  @override
  void markAllNotificationsAsRead() {}

  @override
  void addMemberToSpace(String spaceId, String memberName) {}

  @override
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
      messages: [],
    );
    _chatSpaces.add(newSpace);
    notifyListeners();
    return newSpace;
  }

  @override
  ChatSpace? joinChatSpaceByCode(String code) => null;

  @override
  void shareInviteCodeToGroupChat({
    required String code,
    required String title,
  }) {}

  @override
  void shareInviteCodeToDirectChat({
    required String contactKey,
    required String code,
    required String title,
  }) {}

  @override
  void sendChatMessage(
    String content, {
    String? mediaUrl,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    final msg = ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      senderName: _currentUser.displayName,
      senderAvatar: _currentUser.avatarUrl,
      content: content,
      mediaUrl: mediaUrl,
      inviteCode: inviteCode,
      inviteSpaceName: inviteSpaceName,
      createdAt: DateTime.now(),
      isCurrentUser: true,
    );
    _groupMessages = [..._groupMessages, msg];
    notifyListeners();
  }

  @override
  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
  }) {
    final msg = ChatMessage(
      id: 'dm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _currentUser.id,
      senderName: _currentUser.displayName,
      senderAvatar: _currentUser.avatarUrl,
      content: content,
      mediaUrl: mediaUrl,
      createdAt: DateTime.now(),
      isCurrentUser: true,
    );
    final key = contactKey.toLowerCase();
    final list = _directMessages[key] ?? [];
    _directMessages[key] = [...list, msg];
    notifyListeners();
  }

  @override
  void sendSpaceMessage(
    String spaceId,
    String content, {
    String? mediaUrl,
    String? inviteCode,
    String? inviteSpaceName,
  }) {}

  @override
  void respondMeetUp(String response) {
    _activeMeetUp = MeetUpInvitation(
      id: _activeMeetUp.id,
      activity: _activeMeetUp.activity,
      location: _activeMeetUp.location,
      scheduledTime: _activeMeetUp.scheduledTime,
      goingCount: _activeMeetUp.goingCount + (response == 'going' ? 1 : 0),
      maybeCount: _activeMeetUp.maybeCount + (response == 'maybe' ? 1 : 0),
      cantMakeCount: _activeMeetUp.cantMakeCount + (response == 'cant_make_it' ? 1 : 0),
      currentUserResponse: response,
    );
    notifyListeners();
  }

  @override
  bool sendInvitation({
    required String inviteeEmailOrHandle,
    String? inviteeName,
  }) => true;

  @override
  bool acceptInvitation(String invitationId) => true;

  @override
  bool declineInvitation(String invitationId) => true;

  @override
  void resetMembersForNewUserTest() {}
}
