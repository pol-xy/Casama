import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/date_time_utils.dart';
import 'casama_repository.dart';
import 'models.dart';
import 'supabase_config.dart';

/// Live cloud-synchronized repository implementation backed by Supabase Auth,
/// PostgreSQL (with Row Level Security), Realtime WebSockets, and Storage.
class SupabaseRepository extends ChangeNotifier implements CasamaRepository {
  static const Uuid _uuid = Uuid();

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  Future<void>? _hydratingFuture;
  String? _hydratingUserId;
  bool _disposed = false;

  // Auth & household state
  bool _isAuthenticated = false;
  UserProfile _currentUser = const UserProfile(
    id: '',
    displayName: 'Housemate',
    handle: '@housemate',
  );
  Household _currentHousehold = const Household(
    id: '',
    name: 'Casama Household',
    inviteCode: '',
  );
  List<Household> _userHouseholds = [];

  // Cached household collections
  int _kasamaPoints = 0;
  List<MemberPresence> _members = [];
  List<ParcelItem> _parcels = [];
  List<LostFoundItem> _items = [];
  List<MaintenanceTask> _tasks = [];
  List<ChoreRouletteRecord> _rouletteRecords = [];
  String? _groupConversationId;
  List<ChatMessage> _groupMessages = [];
  int _groupChatUnreadCount = 0;
  List<ChatSpace> _chatSpaces = [];
  Map<String, String> _directConversationIdsByKey = {};
  Map<String, List<ChatMessage>> _directMessages = {};
  Map<String, int> _directUnreadCounts = {};
  final Map<String, XFile> _pendingAttachmentFilesByMessageId = {};
  List<HousematesAgendaInvitation> _housematesAgendaInvitations = [];
  HousematesAgendaInvitation _activeHousematesAgenda =
      HousematesAgendaInvitation(
        id: '',
        activity: '',
        location: '',
        scheduledTime: DateTime.now().add(const Duration(days: 30)),
      );
  List<PointAuditEntry> _pointHistory = [];
  List<LeaderboardStanding> _leaderboardStandings = [];
  List<HouseholdNotificationItem> _notifications = [];
  NotificationPreferences _notificationPreferences =
      const NotificationPreferences();
  final List<HouseholdInvitation> _invitations = [];
  static const Duration quickSnapReactionDebounce = Duration(
    milliseconds: 1200,
  );

  List<QuickSnap> _serverQuickSnaps = [];
  List<QuickSnap> _quickSnaps = [];
  final Map<String, Map<String, int>> _pendingReactionDeltas = {};
  final Map<String, Map<String, int>> _inFlightReactionDeltas = {};
  final Map<String, Timer> _reactionFlushTimers = {};
  final Set<String> _flushingSnapIds = {};
  final Map<String, Future<void>> _inFlightFlushFutures = {};
  List<UserProfile> _cachedUserSearch = [];
  String _lastSearchQuery = '';
  RepositoryActionError? _pendingError;

  SupabaseRepository(this._client) {
    final client = _client;
    if (client != null) {
      _authSub = client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (data.event == AuthChangeEvent.signedOut || session == null) {
          _resetSignedOutState();
        } else if (data.event == AuthChangeEvent.signedIn ||
            data.event == AuthChangeEvent.tokenRefreshed) {
          if (_currentUser.id != session.user.id || !_isAuthenticated) {
            _hydrateAuthenticatedUser(session.user);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _realtimeDebounce?.cancel();
    for (final timer in _reactionFlushTimers.values) {
      timer.cancel();
    }
    _reactionFlushTimers.clear();
    _authSub?.cancel();
    _teardownRealtime();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase is not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or .env.',
      );
    }
    return client;
  }

  void _recordError(
    String message, {
    Future<void> Function()? onRetry,
    Object? error,
  }) {
    if (error != null) {
      debugPrint('SupabaseRepository error: $message ($error)');
    }
    _pendingError = RepositoryActionError(message, onRetry: onRetry);
    _safeNotify();
  }

  @override
  RepositoryActionError? consumePendingError() {
    final err = _pendingError;
    _pendingError = null;
    return err;
  }

  // =========================================================================
  // GETTERS
  // =========================================================================

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get hasActiveHousehold => _currentHousehold.id.trim().isNotEmpty;

  @override
  UserProfile get currentUser => _currentUser;

  @override
  Household get currentHousehold => _currentHousehold;

  @override
  List<Household> get userHouseholds => List.unmodifiable(_userHouseholds);

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
  List<ChoreRouletteRecord> get rouletteRecords =>
      List.unmodifiable(_rouletteRecords);

  @override
  ChoreRouletteRecord? rouletteRecordForTask(String taskId) {
    for (final r in _rouletteRecords) {
      if (r.taskId == taskId) return r;
    }
    return null;
  }

  @override
  List<ChatMessage> get groupMessages => List.unmodifiable(_groupMessages);

  @override
  List<ChatSpace> get chatSpaces => List.unmodifiable(_chatSpaces);

  @override
  int get groupChatUnreadCount => _groupChatUnreadCount;

  @override
  int get unreadNotificationCount =>
      _notifications.where((n) => n.isSupportedNotification && n.isUnread).length;

  @override
  int get totalUnreadChatCount {
    final spaceUnread = _chatSpaces.fold<int>(
      0,
      (sum, s) => sum + s.unreadCount,
    );
    final dmUnread = _directUnreadCounts.values.fold<int>(0, (a, b) => a + b);
    return _groupChatUnreadCount + spaceUnread + dmUnread;
  }

  @override
  HousematesAgendaInvitation get activeHousematesAgenda =>
      _activeHousematesAgenda;

  @override
  List<HousematesAgendaInvitation> get housematesAgendaInvitations =>
      List.unmodifiable(_housematesAgendaInvitations);

  HousematesAgendaInvitation _pickActiveHousematesAgenda(
    List<HousematesAgendaInvitation> invitations,
  ) {
    final active = invitations
        .where((m) => m.hasValidData && m.isActive)
        .toList()
      ..sort((a, b) {
        if (a.isOngoing != b.isOngoing) return a.isOngoing ? -1 : 1;
        return a.scheduledTime.compareTo(b.scheduledTime);
      });
    if (active.isNotEmpty) return active.first;
    final valid = invitations.where((m) => m.hasValidData).toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    if (valid.isNotEmpty) return valid.first;
    return HousematesAgendaInvitation(
      id: '',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
  }

  @override
  List<PointAuditEntry> get pointHistory => List.unmodifiable(_pointHistory);

  @override
  List<LeaderboardStanding> get leaderboardStandings =>
      List.unmodifiable(_leaderboardStandings);

  @override
  List<HouseholdNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

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
    final days = _quickSnaps
        .map(
          (s) => DateTime(s.createdAt.year, s.createdAt.month, s.createdAt.day),
        )
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (days.first != cursor) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (days.first != yesterday) return 0;
      cursor = yesterday;
    }

    var streak = 0;
    for (final day in days) {
      if (day == cursor) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      } else if (day.isBefore(cursor)) {
        break;
      }
    }
    return streak;
  }

  @override
  List<ChatMessage> getDirectMessages(String contactKey) {
    final member = _resolveMemberByKey(contactKey);
    if (member == null) return const [];
    return List.unmodifiable(_directMessages[member.profile.id] ?? const []);
  }

  @override
  int getDirectUnreadCount(String contactKey) {
    final member = _resolveMemberByKey(contactKey);
    if (member == null) return 0;
    return _directUnreadCounts[member.profile.id] ?? 0;
  }

  @override
  bool isHousemateAuthorized(String contactKey) {
    return _resolveMemberByKey(contactKey) != null;
  }

  @override
  List<UserProfile> searchUsers(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      _lastSearchQuery = '';
      _cachedUserSearch = [];
      return const [];
    }
    if (clean != _lastSearchQuery && _client != null && isAuthenticated) {
      _lastSearchQuery = clean;
      unawaited(_refreshUserSearch(clean));
    }
    return List.unmodifiable(_cachedUserSearch);
  }

  Future<void> _refreshUserSearch(String query) async {
    final client = _client;
    if (client == null) return;
    try {
      final memberIds = _members.map((m) => m.profile.id).toSet();
      final res = await client
          .from('profiles')
          .select()
          .or('handle.ilike.%$query%,display_name.ilike.%$query%')
          .limit(20);
      final parsed = (res as List<dynamic>)
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .where((p) => !memberIds.contains(p.id) && p.id != _currentUser.id)
          .toList();
      _cachedUserSearch = parsed;
      _safeNotify();
    } catch (e) {
      debugPrint('Supabase searchUsers error: $e');
    }
  }

  // =========================================================================
  // AUTH, SESSION & PROFILE
  // =========================================================================

  @override
  Future<void> restoreSession() async {
    final client = _client;
    if (client == null) return;
    final session = client.auth.currentSession;
    if (session == null) {
      _resetSignedOutState();
      return;
    }
    await _hydrateAuthenticatedUser(session.user);
  }

  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final res = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = res.user ?? client.auth.currentUser;
    if (user == null) {
      throw StateError('Sign-in succeeded without a user session.');
    }
    await _hydrateAuthenticatedUser(user);
  }

  @override
  Future<bool> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    final client = _requireClient();
    final trimmedEmail = email.trim();
    final prefix = trimmedEmail.split('@').first;
    final defaultHandle = UserProfile.buildFallbackHandle(
      preferred: prefix,
      userId: _uuid.v4(),
    );
    final res = await client.auth.signUp(
      email: trimmedEmail,
      password: password,
      data: {'full_name': prefix, 'handle': defaultHandle},
    );
    final user = res.user;
    if (res.session != null && user != null) {
      await _hydrateAuthenticatedUser(user);
      return true;
    }
    return false;
  }

  @override
  Future<void> resendSignupVerificationEmail(String email) async {
    final client = _requireClient();
    await client.auth.resend(
      type: OtpType.signup,
      email: email.trim(),
    );
  }

  @override
  Future<void> signInWithDemoAccount() async {
    if (!SupabaseConfig.isConfigured || !SupabaseConfig.hasDemoCredentials) {
      throw StateError(
        'Demo login is not configured. Set SUPABASE_DEMO_EMAIL and SUPABASE_DEMO_PASSWORD via --dart-define or .env.',
      );
    }
    await signInWithPassword(
      email: SupabaseConfig.demoEmail,
      password: SupabaseConfig.demoPassword,
    );
  }

  @override
  Future<void> signOut() async {
    await flushPendingSnapReactions();
    _teardownRealtime();
    try {
      await _client?.auth.signOut();
    } catch (e) {
      debugPrint('Supabase signOut warning: $e');
    }
    _resetSignedOutState();
  }

  @override
  void login({String? email, String? password}) {
    if (email != null && password != null) {
      unawaited(
        signInWithPassword(email: email, password: password).catchError((
          Object e,
        ) {
          _recordError('Could not sign in. Please check your credentials.', error: e);
        }),
      );
    } else {
      unawaited(
        signInWithDemoAccount().catchError((Object e) {
          _recordError(e.toString(), error: e);
        }),
      );
    }
  }

  @override
  void register({required String email, required String password}) {
    unawaited(
      signUpWithPassword(email: email, password: password).catchError((
        Object e,
      ) {
        _recordError('Unable to create account right now.', error: e);
        return false;
      }),
    );
  }

  @override
  void logout() {
    unawaited(signOut());
  }

  String _activeHouseholdPrefKey(String userId) =>
      'casama_active_household_$userId';

  Future<String?> _readSavedActiveHouseholdId(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_activeHouseholdPrefKey(userId));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveActiveHouseholdId(String userId, String householdId) async {
    if (userId.isEmpty || householdId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeHouseholdPrefKey(userId), householdId);
    } catch (_) {}
  }

  void _clearHouseholdScopedCache() {
    _teardownRealtime();
    _kasamaPoints = 0;
    _members = [];
    _parcels = [];
    _items = [];
    _tasks = [];
    _rouletteRecords = [];
    _groupConversationId = null;
    _groupMessages = [];
    _groupChatUnreadCount = 0;
    _chatSpaces = [];
    _directConversationIdsByKey = {};
    _directMessages = {};
    _directUnreadCounts = {};
    _housematesAgendaInvitations = [];
    _activeHousematesAgenda = HousematesAgendaInvitation(
      id: '',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
    _pointHistory = [];
    _leaderboardStandings = [];
    _notifications = [];
    for (final timer in _reactionFlushTimers.values) {
      timer.cancel();
    }
    _reactionFlushTimers.clear();
    _pendingReactionDeltas.clear();
    _inFlightReactionDeltas.clear();
    _flushingSnapIds.clear();
    _inFlightFlushFutures.clear();
    _serverQuickSnaps = [];
    _quickSnaps = [];
    _cachedUserSearch = [];
  }

  void _upsertUserHousehold(Household household, {bool moveToFront = false}) {
    final next = List<Household>.from(_userHouseholds);
    final idx = next.indexWhere((h) => h.id == household.id);
    if (idx != -1) {
      final existing = next[idx];
      final merged = household.copyWith(
        memberCount: household.memberCount ?? existing.memberCount,
        spaceType: household.spaceType ?? existing.spaceType,
      );
      if (moveToFront) {
        next.removeAt(idx);
        next.insert(0, merged);
      } else {
        next[idx] = merged;
      }
    } else if (moveToFront) {
      next.insert(0, household);
    } else {
      next.add(household);
    }
    _userHouseholds = next;
  }

  Future<void> _fetchUserHouseholds(String userId) async {
    final client = _client;
    if (client == null || userId.isEmpty) {
      _userHouseholds = [];
      return;
    }

    final rows = await client
        .from('household_members')
        .select('household_id, joined_at, households(id, name, invite_code, created_by)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    final parsed = <Household>[];
    final seenIds = <String>{};
    for (final raw in rows as List<dynamic>) {
      final map = raw as Map<String, dynamic>;
      final hhJson = map['households'] as Map<String, dynamic>?;
      if (hhJson == null) continue;
      final hh = Household.fromJson(hhJson);
      if (hh.id.isNotEmpty && seenIds.add(hh.id)) {
        parsed.add(hh);
      }
    }

    final countsByHousehold = <String, int>{};
    if (parsed.isNotEmpty) {
      try {
        final ids = parsed.map((h) => h.id).toList();
        final rosterRows = await client
            .from('household_members')
            .select('household_id')
            .inFilter('household_id', ids);
        for (final raw in rosterRows as List<dynamic>) {
          final hid = (raw as Map<String, dynamic>)['household_id'] as String?;
          if (hid != null && hid.isNotEmpty) {
            countsByHousehold[hid] = (countsByHousehold[hid] ?? 0) + 1;
          }
        }
      } catch (e) {
        debugPrint('Supabase member count lookup warning: $e');
      }
    }

    _userHouseholds = parsed
        .map(
          (h) => h.copyWith(
            memberCount: countsByHousehold[h.id] ?? h.memberCount ?? 1,
          ),
        )
        .toList();
  }

  void _resetSignedOutState() {
    _clearHouseholdScopedCache();
    _isAuthenticated = false;
    _hydratingFuture = null;
    _hydratingUserId = null;
    _currentUser = const UserProfile(
      id: '',
      displayName: 'Housemate',
      handle: '@housemate',
    );
    _currentHousehold = const Household(
      id: '',
      name: 'Casama Household',
      inviteCode: '',
    );
    _userHouseholds = [];
    _safeNotify();
  }

  Future<UserProfile> _ensureProfileRow(User authUser) async {
    final client = _requireClient();
    final existing = await client
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .maybeSingle();

    if (existing != null) {
      return UserProfile.fromJson(existing);
    }

    final emailPrefix = authUser.email?.split('@').first ?? 'housemate';
    final displayName =
        (authUser.userMetadata?['full_name'] as String?)?.trim().isNotEmpty ==
            true
        ? (authUser.userMetadata!['full_name'] as String).trim()
        : emailPrefix;

    final payload = <String, dynamic>{
      'id': authUser.id,
      'display_name': displayName,
      'full_name': displayName,
      'handle': UserProfile.buildFallbackHandle(
        preferred: emailPrefix,
        userId: authUser.id,
      ),
      'avatar_url': authUser.userMetadata?['avatar_url'],
      'has_consented_terms': false,
      'has_completed_onboarding': false,
    };

    try {
      final inserted = await client
          .from('profiles')
          .upsert(payload, onConflict: 'id')
          .select()
          .single();
      return UserProfile.fromJson(inserted);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        payload['handle'] = UserProfile.buildCollisionRetryHandle(
          baseHandle: payload['handle'] as String,
          randomSuffix: _uuid.v4().substring(0, 4),
        );
        final inserted = await client
            .from('profiles')
            .upsert(payload, onConflict: 'id')
            .select()
            .single();
        return UserProfile.fromJson(inserted);
      }
      rethrow;
    }
  }

  Future<void> _hydrateAuthenticatedUser(User authUser) {
    if (_hydratingFuture != null && _hydratingUserId == authUser.id) {
      return _hydratingFuture!;
    }
    _hydratingUserId = authUser.id;
    final future = _runHydrateAuthenticatedUser(authUser);
    _hydratingFuture = future;
    return future;
  }

  Future<void> _runHydrateAuthenticatedUser(User authUser) async {
    try {
      final profile = await _ensureProfileRow(authUser);
      _currentUser = profile;
      _isAuthenticated = true;
      await _fetchUserHouseholds(authUser.id);

      if (_userHouseholds.isNotEmpty) {
        final savedId = await _readSavedActiveHouseholdId(authUser.id);
        Household selected = _userHouseholds.first;
        if (savedId != null && savedId.isNotEmpty) {
          for (final hh in _userHouseholds) {
            if (hh.id == savedId) {
              selected = hh;
              break;
            }
          }
        } else if (_currentHousehold.id.isNotEmpty) {
          for (final hh in _userHouseholds) {
            if (hh.id == _currentHousehold.id) {
              selected = hh;
              break;
            }
          }
        }
        _currentHousehold = selected;
        await _fetchHouseholdData();
        _setupRealtime();
      } else {
        _clearHouseholdScopedCache();
        _currentHousehold = const Household(
          id: '',
          name: '',
          inviteCode: '',
        );
      }
    } catch (e) {
      _recordError(
        'Failed to load your household workspace.',
        onRetry: () => _hydrateAuthenticatedUser(authUser),
        error: e,
      );
    } finally {
      _hydratingFuture = null;
      _hydratingUserId = null;
      _safeNotify();
    }
  }

  @override
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
    unawaited(
      _updateProfileAsync(
        displayName: displayName,
        handle: handle,
        fullName: fullName,
        nickname: nickname,
        birthday: birthday,
        avatarUrl: avatarUrl,
        hasConsentedTerms: hasConsentedTerms,
        hasCompletedOnboarding: hasCompletedOnboarding,
        clearAvatar: clearAvatar,
        clearNickname: clearNickname,
        clearBirthday: clearBirthday,
      ),
    );
  }

  void _syncCurrentUserInMembers(UserProfile updated) {
    final idx = _members.indexWhere((m) => m.profile.id == updated.id);
    if (idx == -1) return;
    final next = List<MemberPresence>.from(_members);
    next[idx] = MemberPresence(
      profile: updated,
      isHome: next[idx].isHome,
      note: next[idx].note,
      updatedAt: next[idx].updatedAt,
    );
    _members = next;
  }

  @visibleForTesting
  static Map<String, dynamic> buildProfileUpdateMap({
    required String displayName,
    String? explicitHandle,
    String? existingHandle,
    String? fullName,
    String? nickname,
    DateTime? birthday,
    String? avatarUrl,
    required bool hasConsentedTerms,
    required bool hasCompletedOnboarding,
  }) {
    final trimmedExplicit = explicitHandle?.trim();
    final trimmedExisting = existingHandle?.trim();
    final resolvedHandle =
        (trimmedExplicit != null && trimmedExplicit.isNotEmpty)
            ? trimmedExplicit
            : (trimmedExisting != null && trimmedExisting.isNotEmpty
                ? trimmedExisting
                : null);

    return <String, dynamic>{
      'display_name': displayName,
      'handle': ?resolvedHandle,
      'full_name': fullName,
      'nickname': nickname,
      'birthday': UserProfile.formatDateOnly(birthday),
      'avatar_url': avatarUrl,
      'has_consented_terms': hasConsentedTerms,
      'has_completed_onboarding': hasCompletedOnboarding,
    };
  }

  Future<void> _updateProfileAsync({
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
  }) async {
    final prevUser = _currentUser;
    final effectiveFullName = fullName ?? _currentUser.fullName;
    final effectiveDisplayName = displayName ??
        (fullName != null && fullName.trim().isNotEmpty
            ? fullName.trim()
            : _currentUser.displayName);
    final effectiveNickname = clearNickname
        ? null
        : (nickname ?? _currentUser.nickname);
    final trimmedExplicitHandle = handle?.trim();
    final existingHandle = _currentUser.handle.trim();
    var effectiveHandle =
        (trimmedExplicitHandle != null && trimmedExplicitHandle.isNotEmpty)
            ? trimmedExplicitHandle
            : existingHandle;
    final normalizedBirthday = birthday != null
        ? DateTime(birthday.year, birthday.month, birthday.day)
        : null;
    final effectiveBirthday = clearBirthday
        ? null
        : (normalizedBirthday ?? _currentUser.birthday);
    var effectiveAvatarUrl = clearAvatar
        ? null
        : (avatarUrl ?? _currentUser.avatarUrl);
    final effectiveHasConsentedTerms =
        hasConsentedTerms ?? _currentUser.hasConsentedTerms;
    final effectiveHasCompletedOnboarding =
        hasCompletedOnboarding ?? _currentUser.hasCompletedOnboarding;

    _currentUser = UserProfile(
      id: _currentUser.id,
      displayName: effectiveDisplayName,
      handle: effectiveHandle,
      fullName: effectiveFullName,
      nickname: effectiveNickname,
      birthday: effectiveBirthday,
      avatarUrl: effectiveAvatarUrl,
      hasConsentedTerms: effectiveHasConsentedTerms,
      hasCompletedOnboarding: effectiveHasCompletedOnboarding,
    );
    _syncCurrentUserInMembers(_currentUser);
    _safeNotify();

    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      _recordError('Sign in to update your profile.');
      return;
    }

    try {
      if (!clearAvatar &&
          effectiveAvatarUrl != null &&
          _needsStorageUpload(effectiveAvatarUrl)) {
        effectiveAvatarUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.avatarsBucket,
          pathPrefix: _currentUser.id,
          rawSource: effectiveAvatarUrl,
        );
      }

      final updates = buildProfileUpdateMap(
        displayName: effectiveDisplayName,
        explicitHandle: trimmedExplicitHandle,
        existingHandle: existingHandle,
        fullName: effectiveFullName,
        nickname: effectiveNickname,
        birthday: effectiveBirthday,
        avatarUrl: effectiveAvatarUrl,
        hasConsentedTerms: effectiveHasConsentedTerms,
        hasCompletedOnboarding: effectiveHasCompletedOnboarding,
      );

      try {
        await client
            .from('profiles')
            .update(updates)
            .eq('id', _currentUser.id);
      } on PostgrestException catch (e) {
        final isHandleCollision =
            e.code == '23505' &&
            (e.message.contains('profiles_handle_key') ||
                e.message.contains('handle'));
        if (!isHandleCollision) rethrow;

        final retryHandle = UserProfile.buildCollisionRetryHandle(
          baseHandle:
              (updates['handle'] as String?) ??
              effectiveNickname ??
              effectiveDisplayName,
          randomSuffix: _uuid.v4().substring(0, 4),
        );
        updates['handle'] = retryHandle;
        effectiveHandle = retryHandle;
        await client
            .from('profiles')
            .update(updates)
            .eq('id', _currentUser.id);
      }

      _currentUser = UserProfile(
        id: _currentUser.id,
        displayName: effectiveDisplayName,
        handle: effectiveHandle,
        fullName: effectiveFullName,
        nickname: effectiveNickname,
        birthday: effectiveBirthday,
        avatarUrl: effectiveAvatarUrl,
        hasConsentedTerms: effectiveHasConsentedTerms,
        hasCompletedOnboarding: effectiveHasCompletedOnboarding,
      );
      _syncCurrentUserInMembers(_currentUser);
      _safeNotify();
    } catch (e) {
      _currentUser = prevUser;
      _syncCurrentUserInMembers(prevUser);
      _recordError('Failed to save profile changes.', error: e);
    }
  }

  @override
  void recordTermsConsent() {
    final prev = _currentUser;
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
    _safeNotify();

    final client = _client;
    if (client != null && _currentUser.id.isNotEmpty) {
      unawaited(
        client
            .from('profiles')
            .update({'has_consented_terms': true})
            .eq('id', _currentUser.id)
            .then<void>((_) {}, onError: (Object e) {
              _currentUser = prev;
              _recordError('Could not save consent status.', error: e);
            }),
      );
    }
  }

  @override
  void completeOnboardingTutorial() {
    final prev = _currentUser;
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
    _safeNotify();

    final client = _client;
    if (client != null && _currentUser.id.isNotEmpty) {
      unawaited(
        client
            .from('profiles')
            .update({'has_completed_onboarding': true})
            .eq('id', _currentUser.id)
            .then<void>((_) {}, onError: (Object e) {
              _currentUser = prev;
              _recordError('Could not save onboarding status.', error: e);
            }),
      );
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
    _safeNotify();
  }

  // =========================================================================
  // HOUSEHOLDS & SETUP
  // =========================================================================

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random.secure();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  @override
  Future<void> refreshUserHouseholds() async {
    if (_client == null || _currentUser.id.isEmpty) return;
    await _fetchUserHouseholds(_currentUser.id);
    _safeNotify();
  }

  @override
  Future<void> switchHousehold(String householdId) async {
    var idx = _userHouseholds.indexWhere((h) => h.id == householdId);
    if (idx == -1) {
      await refreshUserHouseholds();
      idx = _userHouseholds.indexWhere((h) => h.id == householdId);
    }
    if (idx == -1) {
      throw StateError('Household not found.');
    }
    final target = _userHouseholds[idx];
    if (target.id == _currentHousehold.id) return;

    await flushPendingSnapReactions();
    _clearHouseholdScopedCache();
    _currentHousehold = target;
    await _saveActiveHouseholdId(_currentUser.id, target.id);
    _safeNotify();

    await _fetchHouseholdData();
    _setupRealtime();
    _safeNotify();
  }

  @override
  Future<Household> createHousehold({required String name}) async {
    final client = _requireClient();
    final userId = client.auth.currentUser?.id ?? _currentUser.id;
    if (userId.isEmpty) {
      throw StateError('Please sign in before creating a household.');
    }

    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Household name cannot be empty.');
    }

    final householdId = _uuid.v4();
    final code = _generateInviteCode();

    final created = await client
        .from('households')
        .insert({
          'id': householdId,
          'name': trimmed,
          'invite_code': code,
          'created_by': userId,
        })
        .select()
        .single();

    await client.from('household_members').insert({
      'household_id': householdId,
      'user_id': userId,
      'role': 'owner',
    });

    _clearHouseholdScopedCache();
    final createdHousehold = Household.fromJson(created).copyWith(memberCount: 1);
    _currentHousehold = createdHousehold;
    _upsertUserHousehold(createdHousehold, moveToFront: true);
    await _saveActiveHouseholdId(userId, createdHousehold.id);
    await _ensureGroupConversationExists(householdId, userId);
    await _fetchHouseholdData();
    _setupRealtime();
    _safeNotify();
    return _currentHousehold;
  }

  @override
  Future<Household> joinHouseholdByCode(String inviteCode) async {
    final client = _requireClient();
    final userId = client.auth.currentUser?.id ?? _currentUser.id;
    if (userId.isEmpty) {
      throw StateError('Please sign in before joining a household.');
    }

    final cleanCode = inviteCode.trim().toUpperCase();
    if (cleanCode.isEmpty) {
      throw ArgumentError('Invite code cannot be empty.');
    }

    final householdData = await client
        .from('households')
        .select()
        .eq('invite_code', cleanCode)
        .maybeSingle();

    if (householdData == null) {
      throw StateError('No household found with invite code "$cleanCode".');
    }

    final household = Household.fromJson(householdData);
    var alreadyMember = false;
    try {
      await client.from('household_members').insert({
        'household_id': household.id,
        'user_id': userId,
        'role': 'member',
      });
    } on PostgrestException catch (e) {
      final isDuplicate =
          e.code == '23505' ||
          e.message.contains('uq_household_members_household_user');
      if (!isDuplicate) rethrow;
      alreadyMember = true;
    }

    _clearHouseholdScopedCache();
    _currentHousehold = household;
    _upsertUserHousehold(household, moveToFront: true);
    await _saveActiveHouseholdId(userId, household.id);
    await _ensureGroupConversationExists(household.id, userId);
    await _fetchHouseholdData();
    if (!alreadyMember) {
      final actorName = _currentUser.preferredName;
      final notifRows = _members
          .where((m) => m.profile.id != userId)
          .map(
            (m) => {
              'household_id': household.id,
              'user_id': m.profile.id,
              'type': 'housemate_joined',
              'payload': {
                'entity_type': 'household',
                'actor_id': userId,
                'actor_name': actorName,
                'household_name': household.name,
                'title': '$actorName joined ${household.name}',
                'message': 'Say hello to your new housemate!',
              },
            },
          )
          .toList();
      if (notifRows.isNotEmpty) {
        try {
          await client.from('notifications').insert(notifRows);
        } catch (e) {
          debugPrint('Supabase housemate_joined notification insert error: $e');
        }
      }
    }
    _setupRealtime();
    _safeNotify();
    return _currentHousehold;
  }

  // =========================================================================
  // HYDRATION & REALTIME
  // =========================================================================

  Future<void> _fetchHouseholdData() async {
    final client = _client;
    final householdId = _currentHousehold.id;
    final userId = _currentUser.id;
    if (client == null || householdId.isEmpty || userId.isEmpty) return;

    try {
      // 1. Members + Presence
      final membersFuture = client
          .from('household_members')
          .select('user_id, role, profiles(*)')
          .eq('household_id', householdId);
      final presenceFuture = client
          .from('presence_events')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false)
          .limit(200);

      // 2. Parcels + Claims
      final parcelsFuture = client
          .from('parcels')
          .select()
          .eq('household_id', householdId)
          .order('expected_arrival', ascending: true);
      final claimsFuture = client
          .from('parcel_claims')
          .select()
          .eq('household_id', householdId);

      // 3. Tasks + Roulette
      final tasksFuture = client
          .from('maintenance_tasks')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      final rouletteFuture = client
          .from('chore_roulette_records')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      // 4. Lost & Found (lost_items & found_items; zero queries on retired items)
      final lostFuture = client
          .from('lost_items')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      final foundFuture = client
          .from('found_items')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      // 5. QuickSnaps
      final snapsFuture = client
          .from('quick_snaps')
          .select(
            'id, household_id, creator_id, creator_name, image_url, caption, created_at, quick_snap_reactions(*), quick_snap_comments(*)',
          )
          .eq('household_id', householdId)
          .order('created_at', ascending: false);

      // 6. Points Ledger & Notifications
      final pointsFuture = client
          .from('points_ledger')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: false);
      final notifFuture = client
          .from('notifications')
          .select()
          .eq('household_id', householdId)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      // 7. Conversations
      final convFuture = client
          .from('conversations')
          .select()
          .eq('household_id', householdId)
          .order('created_at', ascending: true);

      final results = await Future.wait<dynamic>([
        membersFuture,
        presenceFuture,
        parcelsFuture,
        claimsFuture,
        tasksFuture,
        rouletteFuture,
        lostFuture,
        foundFuture,
        snapsFuture,
        pointsFuture,
        notifFuture,
        convFuture,
      ]);

      final membersRes = results[0] as List<dynamic>;
      final presenceRes = results[1] as List<dynamic>;
      final parcelsRes = results[2] as List<dynamic>;
      final claimsRes = results[3] as List<dynamic>;
      final tasksRes = results[4] as List<dynamic>;
      final rouletteRes = results[5] as List<dynamic>;
      final lostRes = results[6] as List<dynamic>;
      final foundRes = results[7] as List<dynamic>;
      final snapsRes = results[8] as List<dynamic>;
      final pointsRes = results[9] as List<dynamic>;
      final notifRes = results[10] as List<dynamic>;
      final convRes = results[11] as List<dynamic>;

      // Build profile lookup
      final profileMap = <String, UserProfile>{};
      for (final row in membersRes) {
        final rawProfile = row['profiles'] as Map<String, dynamic>?;
        if (rawProfile == null) continue;
        final profile = UserProfile.fromJson(rawProfile);
        profileMap[profile.id] = profile;
        if (profile.id == userId) {
          _currentUser = profile;
        }
      }

      // Latest presence per user
      final latestPresenceByUser = <String, Map<String, dynamic>>{};
      for (final row in presenceRes) {
        final map = row as Map<String, dynamic>;
        final uid = map['user_id'] as String? ?? '';
        if (uid.isNotEmpty && !latestPresenceByUser.containsKey(uid)) {
          latestPresenceByUser[uid] = map;
        }
      }
      _members = profileMap.values.map((profile) {
        final ev = latestPresenceByUser[profile.id];
        return MemberPresence(
          profile: profile,
          isHome: ev?['is_home'] as bool? ?? true,
          note: ev?['note'] as String?,
          updatedAt: parseSupabaseTimestamp(ev?['created_at']),
        );
      }).toList();
      _currentHousehold = _currentHousehold.copyWith(memberCount: _members.length);
      _upsertUserHousehold(_currentHousehold);

      // Parcels + Claims
      final claimByParcel = <String, Map<String, dynamic>>{};
      for (final row in claimsRes) {
        final map = row as Map<String, dynamic>;
        final pid = map['parcel_id'] as String? ?? '';
        if (pid.isNotEmpty) claimByParcel[pid] = map;
      }
      _parcels = parcelsRes.map((row) {
        final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
        final pid = map['id'] as String;
        final buyerId = map['buyer_id'] as String? ?? '';
        final claim = claimByParcel[pid];
        final receiverId = claim?['receiver_id'] as String?;
        map['buyer_name'] =
            profileMap[buyerId]?.preferredName ?? 'Housemate';
        map['cod_settled'] = claim?['settled'] as bool? ?? false;
        map['claimed_by_id'] = receiverId;
        map['claimed_by_name'] = receiverId != null
            ? profileMap[receiverId]?.preferredName
            : null;
        map['claimed_at'] = claim?['received_at'];
        map['settled_at'] = claim?['settled_at'];
        return ParcelItem.fromJson(map);
      }).toList();

      // Maintenance Tasks
      _tasks = tasksRes.map((row) {
        final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
        final createdById = map['created_by'] as String? ?? '';
        final completedById = map['completed_by'] as String?;
        map['created_by_name'] =
            profileMap[createdById]?.preferredName ?? 'Housemate';
        if (completedById != null && profileMap.containsKey(completedById)) {
          map['completed_by_name'] = profileMap[completedById]!.preferredName;
        }
        return MaintenanceTask.fromJson(map);
      }).toList();

      // Task Roulette records
      _rouletteRecords = rouletteRes.map((row) {
        final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
        final selectedId = map['selected_user_id'] as String? ?? '';
        final spunById = map['spun_by_user_id'] as String? ?? '';
        if (profileMap.containsKey(selectedId)) {
          map['selected_user_name'] = profileMap[selectedId]!.preferredName;
        } else if ((map['selected_user_name'] as String?)?.trim().isEmpty ?? true) {
          map['selected_user_name'] = 'Housemate';
        }
        if (profileMap.containsKey(spunById)) {
          map['spun_by_name'] = profileMap[spunById]!.preferredName;
        } else if ((map['spun_by_name'] as String?)?.trim().isEmpty ?? true) {
          map['spun_by_name'] = 'Housemate';
        }
        return ChoreRouletteRecord.fromJson(map);
      }).toList();

      // Lost & Found Items (`lost_items` + `found_items`)
      final combinedItems = <LostFoundItem>[
        ...lostRes.map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final ownerId = map['owner_id'] as String? ?? '';
          final foundById = map['found_by_id'] as String?;
          map['reported_by_name'] =
              profileMap[ownerId]?.preferredName ?? 'Housemate';
          if (foundById != null && profileMap.containsKey(foundById)) {
            map['found_by_name'] = profileMap[foundById]!.preferredName;
          }
          return LostFoundItem.fromJson(map, forcedType: ItemType.lost);
        }),
        ...foundRes.map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final finderId = map['finder_id'] as String? ?? '';
          final claimedById = map['claimed_by_id'] as String?;
          map['reported_by_name'] =
              profileMap[finderId]?.preferredName ?? 'Housemate';
          if (claimedById != null && profileMap.containsKey(claimedById)) {
            map['claimed_by_name'] = profileMap[claimedById]!.preferredName;
          }
          return LostFoundItem.fromJson(map, forcedType: ItemType.found);
        }),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items = combinedItems;

      // QuickSnaps (household-wide)
      _serverQuickSnaps = snapsRes
          .map(
            (raw) =>
                QuickSnap.fromJson(Map<String, dynamic>.from(raw as Map<String, dynamic>)),
          )
          .toList();
      _rebuildEffectiveQuickSnaps();

      // Points Ledger & Leaderboard
      final pointsByUser = <String, int>{};
      final myHistory = <PointAuditEntry>[];
      for (final row in pointsRes) {
        final map = row as Map<String, dynamic>;
        final uid = map['user_id'] as String? ?? '';
        final pts = (map['points'] as num?)?.toInt() ?? 0;
        pointsByUser[uid] = (pointsByUser[uid] ?? 0) + pts;
        if (uid == userId) {
          final actionType = map['action_type'] as String? ?? 'bonus';
          myHistory.add(
            PointAuditEntry(
              id: map['id'] as String? ?? _uuid.v4(),
              title: _formatPointActionTitle(actionType),
              points: pts,
              timestamp: parseSupabaseTimestamp(map['created_at']),
              category: _mapPointCategory(actionType),
            ),
          );
        }
      }
      _kasamaPoints = pointsByUser[userId] ?? 0;
      _pointHistory = myHistory;
      _leaderboardStandings = profileMap.values.map((p) {
        return LeaderboardStanding(
          userId: p.id,
          displayName: p.preferredName,
          handle: p.handle,
          avatarUrl: p.avatarUrl,
          points: pointsByUser[p.id] ?? 0,
          isCurrentUser: p.id == userId,
        );
      }).toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      // Notifications
      _notifications = notifRes
          .map((row) => parseNotificationRow(Map<String, dynamic>.from(row as Map)))
          .where((n) => n.isSupportedNotification)
          .toList();

      // Conversations, Messages, Reads & Housemates Agenda
      await _hydrateConversations(convRes, profileMap, userId);
    } catch (e) {
      debugPrint('Supabase _fetchHouseholdData error: $e');
    }
  }

  Future<void> _ensureGroupConversationExists(
    String householdId,
    String userId,
  ) async {
    final client = _client;
    if (client == null || householdId.isEmpty) return;

    final existing = await client
        .from('conversations')
        .select('id')
        .eq('household_id', householdId)
        .eq('type', 'group')
        .limit(1)
        .maybeSingle();

    String groupId;
    if (existing != null) {
      groupId = existing['id'] as String;
    } else {
      groupId = _uuid.v4();
      await client.from('conversations').insert({
        'id': groupId,
        'household_id': householdId,
        'type': 'group',
        'name': '${_currentHousehold.name} Group Chat',
        'created_by': userId,
      });
    }
    _groupConversationId = groupId;
    await client.from('conversation_members').upsert(
      {'conversation_id': groupId, 'user_id': userId},
      onConflict: 'conversation_id,user_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> _hydrateConversations(
    List<dynamic> convRes,
    Map<String, UserProfile> profileMap,
    String userId,
  ) async {
    final client = _client;
    if (client == null) return;

    String? groupId;
    final spaceRows = <Map<String, dynamic>>[];
    final directConvIds = <String>[];

    for (final raw in convRes) {
      final map = raw as Map<String, dynamic>;
      final type = map['type'] as String? ?? 'group';
      if (type == 'group' && groupId == null) {
        groupId = map['id'] as String;
      } else if (type == 'space') {
        spaceRows.add(map);
      } else if (type == 'direct') {
        directConvIds.add(map['id'] as String);
      }
    }

    if (groupId == null) {
      await _ensureGroupConversationExists(_currentHousehold.id, userId);
      groupId = _groupConversationId;
    } else {
      _groupConversationId = groupId;
      await client.from('conversation_members').upsert(
        {'conversation_id': groupId, 'user_id': userId},
        onConflict: 'conversation_id,user_id',
        ignoreDuplicates: true,
      );
    }

    final allConvIds = <String>[
      ?groupId,
      ...spaceRows.map((s) => s['id'] as String),
      ...directConvIds,
    ];
    if (allConvIds.isEmpty) return;

    final msgsFuture = client
        .from('messages')
        .select()
        .inFilter('conversation_id', allConvIds)
        .order('created_at', ascending: true);
    final readsFuture = client
        .from('conversation_reads')
        .select()
        .eq('user_id', userId)
        .inFilter('conversation_id', allConvIds);
    final dmMembersFuture = directConvIds.isEmpty
        ? Future.value(<dynamic>[])
        : client
            .from('conversation_members')
            .select()
            .inFilter('conversation_id', directConvIds);
    final agendasFuture = groupId == null
        ? Future.value(<dynamic>[])
        : client
            .from('housemates_agenda_invitations')
            .select('*, housemates_agenda_responses(*)')
            .eq('conversation_id', groupId)
            .order('scheduled_time', ascending: true);

    final convData = await Future.wait<dynamic>([
      msgsFuture,
      readsFuture,
      dmMembersFuture,
      agendasFuture,
    ]);

    final msgsRes = convData[0] as List<dynamic>;
    final readsRes = convData[1] as List<dynamic>;
    final dmMembersRes = convData[2] as List<dynamic>;
    final agendasRes = convData[3] as List<dynamic>;

    final lastReadByConv = <String, DateTime>{};
    for (final raw in readsRes) {
      final map = raw as Map<String, dynamic>;
      final cid = map['conversation_id'] as String? ?? '';
      final ts = map['last_read_at'] as String?;
      if (cid.isNotEmpty && ts != null) {
        final parsed = parseSupabaseTimestampOrNull(ts);
        if (parsed != null) lastReadByConv[cid] = parsed;
      }
    }

    final msgsByConv = <String, List<ChatMessage>>{};
    final seenIdsByConv = <String, Set<String>>{};
    final seenClientIdsByConv = <String, Set<String>>{};
    for (final raw in msgsRes) {
      final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final cid = map['conversation_id'] as String? ?? '';
      final msgId = map['id'] as String? ?? '';
      final clientMsgId = map['client_message_id'] as String? ?? '';
      final seenIds = seenIdsByConv.putIfAbsent(cid, () => <String>{});
      final seenClientIds = seenClientIdsByConv.putIfAbsent(
        cid,
        () => <String>{},
      );
      if (msgId.isNotEmpty && !seenIds.add(msgId)) continue;
      if (clientMsgId.isNotEmpty && !seenClientIds.add(clientMsgId)) continue;
      final senderId = map['sender_id'] as String? ?? '';
      map['sender_name'] = profileMap[senderId]?.preferredName ?? 'Housemate';
      map['sender_avatar'] = profileMap[senderId]?.avatarUrl;
      final msg = ChatMessage.fromJson(map, currentUserId: userId);
      msgsByConv.putIfAbsent(cid, () => []).add(msg);
    }

    int countUnread(String cid) {
      final lastRead = lastReadByConv[cid];
      final list = msgsByConv[cid] ?? const <ChatMessage>[];
      return list.where((m) {
        if (m.senderId == userId) return false;
        if (lastRead == null) return true;
        return m.createdAt.isAfter(lastRead);
      }).length;
    }

    if (groupId != null) {
      _groupMessages = msgsByConv[groupId] ?? const [];
      _groupChatUnreadCount = countUnread(groupId);
    }

    final allMemberNames = profileMap.values.map((p) => p.preferredName).toList();
    _chatSpaces = spaceRows.map((map) {
      final sid = map['id'] as String;
      final creatorId = map['created_by'] as String? ?? '';
      return ChatSpace(
        id: sid,
        householdId: _currentHousehold.id,
        name: map['name'] as String? ?? 'Space',
        description: map['description'] as String? ?? '',
        inviteCode: '',
        creatorId: creatorId,
        creatorName: profileMap[creatorId]?.preferredName ?? 'Housemate',
        memberNames: allMemberNames,
        iconEmoji: map['icon'] as String? ?? '💬',
        createdAt: parseSupabaseTimestamp(map['created_at']),
        messages: msgsByConv[sid] ?? const [],
        unreadCount: countUnread(sid),
      );
    }).toList();

    // Direct chats keyed by peer userId
    final membersByDmConv = <String, Set<String>>{};
    for (final raw in dmMembersRes) {
      final map = raw as Map<String, dynamic>;
      final cid = map['conversation_id'] as String? ?? '';
      final uid = map['user_id'] as String? ?? '';
      if (cid.isNotEmpty && uid.isNotEmpty) {
        membersByDmConv.putIfAbsent(cid, () => <String>{}).add(uid);
      }
    }
    final nextDirectConvIds = <String, String>{};
    final nextDirectMsgs = <String, List<ChatMessage>>{};
    final nextDirectUnread = <String, int>{};
    for (final entry in membersByDmConv.entries) {
      if (!entry.value.contains(userId)) continue;
      final peerId = entry.value.firstWhere(
        (id) => id != userId,
        orElse: () => userId,
      );
      nextDirectConvIds[peerId] = entry.key;
      nextDirectMsgs[peerId] = msgsByConv[entry.key] ?? const [];
      nextDirectUnread[peerId] = countUnread(entry.key);
    }
    _directConversationIdsByKey = nextDirectConvIds;
    _directMessages = nextDirectMsgs;
    _directUnreadCounts = nextDirectUnread;

    // Housemates Agenda (prefer soonest active invitation; fallback to latest done)
    if (agendasRes.isNotEmpty) {
      HousematesAgendaInvitation parseAgenda(Map<String, dynamic> m) {
        final responses =
            (m['housemates_agenda_responses'] as List<dynamic>? ?? const []);
        var going = 0;
        var maybe = 0;
        var cant = 0;
        String? myResp;
        final List<HousematesAgendaResponse> responderList = [];
        for (final raw in responses) {
          final r = raw as Map<String, dynamic>;
          final rUserId = r['user_id'] as String? ?? '';
          final resp = r['response'] as String? ?? '';
          if (resp == 'going') going++;
          if (resp == 'maybe') maybe++;
          if (resp == 'cant_make_it') cant++;
          if (rUserId == userId) myResp = resp;
          if (rUserId.isNotEmpty && resp.isNotEmpty) {
            final profile = profileMap[rUserId];
            responderList.add(
              HousematesAgendaResponse(
                userId: rUserId,
                displayName: profile?.preferredName ?? 'Housemate',
                avatarUrl: profile?.avatarUrl,
                response: resp,
              ),
            );
          }
        }
        return HousematesAgendaInvitation.fromJson(
          m,
          goingCount: going,
          maybeCount: maybe,
          cantMakeCount: cant,
          currentUserResponse: myResp,
          responders: responderList,
        );
      }

      final parsedAgendas = agendasRes
          .map((raw) => parseAgenda(Map<String, dynamic>.from(raw as Map)))
          .toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      _housematesAgendaInvitations = parsedAgendas;
      _activeHousematesAgenda = _pickActiveHousematesAgenda(parsedAgendas);
    } else {
      _housematesAgendaInvitations = [];
      _activeHousematesAgenda = HousematesAgendaInvitation(
        id: '',
        activity: '',
        location: '',
        scheduledTime: DateTime.now().add(const Duration(days: 30)),
      );
    }
  }

  void _setupRealtime() {
    final client = _client;
    final hid = _currentHousehold.id;
    if (client == null || hid.isEmpty) return;

    _teardownRealtime();

    void scheduleRefresh(PostgresChangePayload _) {
      _realtimeDebounce?.cancel();
      _realtimeDebounce = Timer(const Duration(milliseconds: 180), () {
        _fetchHouseholdData().then((_) => _safeNotify());
      });
    }

    final channel = client.channel('household_$hid');
    const householdScopedTables = [
      'household_members',
      'presence_events',
      'parcels',
      'parcel_claims',
      'maintenance_tasks',
      'chore_roulette_records',
      'lost_items',
      'found_items',
      'quick_snaps',
      'conversations',
      'points_ledger',
    ];
    for (final table in householdScopedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: hid,
        ),
        callback: scheduleRefresh,
      );
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: hid,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        final targetUserId = (newRecord['user_id'] as String?)?.trim() ?? '';
        if (newRecord.isNotEmpty &&
            (targetUserId.isEmpty || targetUserId == _currentUser.id)) {
          final parsed = parseNotificationRow(
            Map<String, dynamic>.from(newRecord),
          );
          if (parsed.isSupportedNotification &&
              !_notifications.any((n) => n.id == parsed.id)) {
            _notifications = [parsed, ..._notifications];
            _safeNotify();
          }
        }
        scheduleRefresh(payload);
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'household_id',
        value: hid,
      ),
      callback: (payload) {
        final newRecord = payload.newRecord;
        final updatedId = (newRecord['id'] as String?)?.trim() ?? '';
        if (updatedId.isNotEmpty) {
          final readAt = parseSupabaseTimestampOrNull(newRecord['read_at']);
          var changed = false;
          _notifications = _notifications.map((n) {
            if (n.id == updatedId) {
              changed = true;
              return n.copyWith(isRead: readAt != null, readAt: readAt);
            }
            return n;
          }).toList();
          if (changed) {
            _safeNotify();
          }
        }
        scheduleRefresh(payload);
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notifications',
      callback: (payload) {
        final next = applyNotificationRealtimeDelete(
          _notifications,
          payload.oldRecord,
        );
        if (next.length != _notifications.length) {
          _notifications = next;
          _safeNotify();
        }
        scheduleRefresh(payload);
      },
    );
    const conversationScopedTables = [
      'conversation_reads',
      'messages',
      'housemates_agenda_responses',
      'quick_snap_reactions',
      'quick_snap_comments',
    ];
    for (final table in conversationScopedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: scheduleRefresh,
      );
    }
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'housemates_agenda_invitations',
      callback: (payload) {
        final deletedId = payload.oldRecord['id'] as String?;
        if (deletedId != null && deletedId.isNotEmpty) {
          final before = _housematesAgendaInvitations.length;
          _housematesAgendaInvitations = _housematesAgendaInvitations
              .where((m) => m.id != deletedId)
              .toList();
          if (_housematesAgendaInvitations.length != before ||
              _activeHousematesAgenda.id == deletedId) {
            _activeHousematesAgenda = _pickActiveHousematesAgenda(
              _housematesAgendaInvitations,
            );
            _safeNotify();
          }
        }
        scheduleRefresh(payload);
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'housemates_agenda_invitations',
      callback: scheduleRefresh,
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'housemates_agenda_invitations',
      callback: scheduleRefresh,
    );
    _realtimeChannel = channel..subscribe();
  }

  void _teardownRealtime() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = null;
    final ch = _realtimeChannel;
    _realtimeChannel = null;
    if (ch != null) {
      unawaited(ch.unsubscribe());
    }
  }

  // =========================================================================
  // PRESENCE
  // =========================================================================

  @override
  void updatePresence({required bool isHome, String? note}) {
    unawaited(_updatePresenceAsync(isHome: isHome, note: note));
  }

  Future<void> _updatePresenceAsync({
    required bool isHome,
    String? note,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join or create a household to update your status.');
      return;
    }

    final prevMembers = List<MemberPresence>.from(_members);
    final idx = _members.indexWhere((m) => m.profile.id == _currentUser.id);
    if (idx != -1) {
      _members[idx] = MemberPresence(
        profile: _currentUser,
        isHome: isHome,
        note: note,
        updatedAt: DateTime.now(),
      );
      _safeNotify();
    }

    try {
      await client.from('presence_events').insert({
        'household_id': _currentHousehold.id,
        'user_id': _currentUser.id,
        'is_home': isHome,
        'note': note,
      });
    } catch (e) {
      _members = prevMembers;
      _recordError(
        'Could not update your Home/Out status.',
        onRetry: () => _updatePresenceAsync(isHome: isHome, note: note),
        error: e,
      );
    }
  }

  // =========================================================================
  // PARCELS & DELIVERIES
  // =========================================================================

  @override
  void addParcel({
    required String courier,
    required DateTime arrival,
    required ParcelPaymentType paymentType,
    double? codAmount,
    String? notes,
  }) {
    unawaited(
      _addParcelAsync(
        courier: courier,
        arrival: arrival,
        paymentType: paymentType,
        codAmount: codAmount,
        notes: notes,
      ),
    );
  }

  Future<void> _addParcelAsync({
    required String courier,
    required DateTime arrival,
    required ParcelPaymentType paymentType,
    double? codAmount,
    String? notes,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join or create a household before adding a parcel.');
      return;
    }
    if (paymentType == ParcelPaymentType.cod && (codAmount == null || codAmount <= 0)) {
      _recordError('COD parcels require an amount greater than 0.');
      return;
    }

    final parcelId = _uuid.v4();
    final effectiveCod = paymentType == ParcelPaymentType.cod ? codAmount : null;
    final newParcel = ParcelItem(
      id: parcelId,
      householdId: _currentHousehold.id,
      buyerId: _currentUser.id,
      buyerName: _currentUser.preferredName,
      courier: courier,
      expectedArrival: arrival,
      paymentType: paymentType,
      codAmount: effectiveCod,
      status: ParcelStatus.expected,
      notes: notes,
    );

    final prev = List<ParcelItem>.from(_parcels);
    _parcels = [newParcel, ..._parcels];
    _safeNotify();

    try {
      await client.from('parcels').insert(newParcel.toJson());
    } catch (e) {
      _parcels = prev;
      _recordError(
        'Could not save parcel.',
        onRetry: () => _addParcelAsync(
          courier: courier,
          arrival: arrival,
          paymentType: paymentType,
          codAmount: codAmount,
          notes: notes,
        ),
        error: e,
      );
    }
  }

  @override
  Future<void> updateParcel({
    required String parcelId,
    String? courier,
    DateTime? arrival,
    ParcelPaymentType? paymentType,
    double? codAmount,
    String? notes,
    ParcelStatus? status,
  }) async {
    final client = _requireClient();
    final idx = _parcels.indexWhere((p) => p.id == parcelId);
    if (idx == -1) return;
    final current = _parcels[idx];
    final nextPay = paymentType ?? current.paymentType;
    final nextCod = nextPay == ParcelPaymentType.cod
        ? (codAmount ?? current.codAmount)
        : null;
    if (nextPay == ParcelPaymentType.cod && (nextCod == null || nextCod <= 0)) {
      throw ArgumentError('COD parcels require an amount greater than 0.');
    }

    final normalizedNotes =
        notes == null ? current.notes : (notes.trim().isEmpty ? null : notes.trim());
    final updates = <String, dynamic>{
      'courier': courier ?? current.courier,
      'expected_arrival': toSupabaseUtcIso(arrival ?? current.expectedArrival),
      'payment_type': nextPay == ParcelPaymentType.cod ? 'cod' : 'paid',
      'cod_amount': nextCod,
      'notes': normalizedNotes,
      'status': (status ?? current.status).name,
    };
    await client.from('parcels').update(updates).eq('id', parcelId);
    await _fetchHouseholdData();
    _safeNotify();
  }

  @override
  Future<void> cancelParcel(String parcelId) async {
    await updateParcel(parcelId: parcelId, status: ParcelStatus.cancelled);
  }

  @override
  Future<void> deleteParcel(String parcelId) async {
    final client = _requireClient();
    final prevParcels = List<ParcelItem>.from(_parcels);
    final prevNotifications = List<HouseholdNotificationItem>.from(_notifications);

    _parcels = _parcels.where((p) => p.id != parcelId).toList();
    _notifications = _notifications
        .where(
          (n) => !n.matchesEntity(entityType: 'parcel', entityId: parcelId),
        )
        .toList();
    _safeNotify();

    try {
      await client.from('parcels').delete().eq('id', parcelId);
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _parcels = prevParcels;
      _notifications = prevNotifications;
      _recordError('Could not delete parcel.', error: e);
      _safeNotify();
      rethrow;
    }
  }

  @override
  void receiveParcel(String parcelId) {
    unawaited(_receiveParcelAsync(parcelId));
  }

  Future<void> _receiveParcelAsync(String parcelId) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Sign in to confirm parcel receipt.');
      return;
    }
    final idx = _parcels.indexWhere((p) => p.id == parcelId);
    if (idx == -1) return;
    final parcel = _parcels[idx];
    if (parcel.isClaimed) return;

    final isSelfClaim = parcel.buyerId == _currentUser.id;
    final nowIso = nowSupabaseUtcIso();

    try {
      await client.from('parcel_claims').upsert(
        {
          'household_id': _currentHousehold.id,
          'parcel_id': parcelId,
          'receiver_id': _currentUser.id,
          'received_at': nowIso,
          'amount_owed': isSelfClaim
              ? 0
              : (parcel.paymentType == ParcelPaymentType.cod
                  ? (parcel.codAmount ?? 0)
                  : 0),
          'settled': isSelfClaim,
          'settled_at': isSelfClaim ? nowIso : null,
        },
        onConflict: 'parcel_id',
      );

      await client
          .from('parcels')
          .update({'status': 'received'})
          .eq('id', parcelId);

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError(
        'Could not confirm parcel receipt.',
        onRetry: () => _receiveParcelAsync(parcelId),
        error: e,
      );
    }
  }

  @override
  Future<void> settleParcelClaim(String parcelId) async {
    final client = _requireClient();
    await client.rpc(
      'settle_parcel_claim',
      params: {'p_parcel_id': parcelId},
    );
    await _fetchHouseholdData();
    _safeNotify();
  }

  // =========================================================================
  // HOUSEHOLD TASKS & TASK ROULETTE
  // =========================================================================

  @override
  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? description,
    DateTime? dueDate,
  }) {
    unawaited(
      _addTaskAsync(
        title: title,
        category: category,
        urgency: urgency,
        description: description,
        dueDate: dueDate,
      ),
    );
  }

  Future<void> _addTaskAsync({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? description,
    DateTime? dueDate,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before creating tasks.');
      return;
    }

    final taskId = _uuid.v4();

    final newTask = MaintenanceTask(
      id: taskId,
      householdId: _currentHousehold.id,
      title: title,
      description: description,
      category: category,
      urgency: urgency,
      status: TaskStatus.open,
      createdBy: _currentUser.id,
      createdByName: _currentUser.preferredName,
      createdAt: DateTime.now(),
      dueDate: dueDate,
    );

    final prev = List<MaintenanceTask>.from(_tasks);
    _tasks = [newTask, ..._tasks];
    _safeNotify();

    try {
      await client.from('maintenance_tasks').insert({
        'id': taskId,
        'household_id': _currentHousehold.id,
        'title': title,
        'description': description,
        'category': category.dbValue,
        'urgency': urgency.name,
        'status': 'open',
        'due_date': toSupabaseUtcIsoOrNull(dueDate),
        'created_by': _currentUser.id,
      });
    } catch (e) {
      _tasks = prev;
      _recordError('Could not create task.', error: e);
    }
  }

  @override
  void completeTask(String taskId) {
    unawaited(updateTaskStatus(taskId, TaskStatus.done));
  }

  @override
  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Sign in to update task status.');
      return;
    }

    final idx = _tasks.indexWhere((t) => t.id == taskId);
    if (idx == -1) return;
    final task = _tasks[idx];
    if (status == TaskStatus.done && task.status == TaskStatus.done) return;
    final prev = List<MaintenanceTask>.from(_tasks);
    final prevRoulette = List<ChoreRouletteRecord>.from(_rouletteRecords);
    final isSelfCreated =
        task.createdBy.isNotEmpty && task.createdBy == _currentUser.id;
    final rouletteRecord = rouletteRecordForTask(taskId);
    final rewardPoints = task.rewardPointsForUser(
      _currentUser.id,
      rouletteRecord: rouletteRecord,
    );

    final now = DateTime.now();
    _tasks[idx] = task.copyWith(
      status: status,
      completedById: status == TaskStatus.done ? _currentUser.id : null,
      completedByName: status == TaskStatus.done
          ? _currentUser.preferredName
          : null,
      completedAt: status == TaskStatus.done ? now : null,
      clearCompleted: status != TaskStatus.done,
    );
    if (status == TaskStatus.done && rouletteRecord != null) {
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
    _safeNotify();

    try {
      final dbStatus = switch (status) {
        TaskStatus.open => 'open',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
      };
      await client.from('maintenance_tasks').update({
        'status': dbStatus,
        'completed_by': status == TaskStatus.done ? _currentUser.id : null,
        'completed_at':
            status == TaskStatus.done ? toSupabaseUtcIso(now) : null,
      }).eq('id', taskId);

      if (status == TaskStatus.done && rouletteRecord != null) {
        await client
            .from('chore_roulette_records')
            .update({
              'status': 'completed',
              'completed_at': toSupabaseUtcIso(now),
            })
            .eq('id', rouletteRecord.id);
      }

      if (status == TaskStatus.done && !isSelfCreated && rewardPoints > 0) {
        await _awardPoints(
          userId: _currentUser.id,
          actionType: 'task_completed',
          points: rewardPoints,
          referenceId: taskId,
        );
      }
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _tasks = prev;
      _rouletteRecords = prevRoulette;
      _recordError('Could not update task.', error: e);
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    final client = _requireClient();
    final prevTasks = List<MaintenanceTask>.from(_tasks);
    final prevRoulette = List<ChoreRouletteRecord>.from(_rouletteRecords);
    final prevNotifications = List<HouseholdNotificationItem>.from(_notifications);

    _tasks = _tasks.where((t) => t.id != taskId).toList();
    _rouletteRecords = _rouletteRecords
        .where((r) => r.taskId != taskId)
        .toList();
    _notifications = _notifications
        .where((n) => !n.matchesEntity(entityType: 'task', entityId: taskId))
        .toList();
    _safeNotify();

    try {
      await client.from('maintenance_tasks').delete().eq('id', taskId);
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _tasks = prevTasks;
      _rouletteRecords = prevRoulette;
      _notifications = prevNotifications;
      _recordError('Could not delete task.', error: e);
      _safeNotify();
      rethrow;
    }
  }

  @override
  Future<ChoreRouletteRecord> spinTaskRoulette(
    String taskId,
    String selectedUserId,
  ) async {
    final client = _requireClient();
    final hid = _currentHousehold.id;
    final spunById = _currentUser.id;
    if (hid.isEmpty || spunById.isEmpty) {
      throw StateError('Join a household before spinning Task Roulette.');
    }
    if (_rouletteRecords.any((r) => r.taskId == taskId)) {
      throw StateError('This task has already been spun.');
    }
    final targetTask = _tasks.cast<MaintenanceTask?>().firstWhere(
      (t) => t?.id == taskId,
      orElse: () => null,
    );
    if (targetTask != null &&
        targetTask.createdBy.isNotEmpty &&
        targetTask.createdBy == selectedUserId) {
      throw StateError('The task creator cannot be chosen by Task Roulette.');
    }

    final dynamic raw;
    try {
      raw = await client.rpc(
        'spin_task_roulette',
        params: {
          'p_task_id': taskId,
          'p_selected_user_id': selectedUserId,
        },
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('creator')) {
        throw StateError('The task creator cannot be chosen by Task Roulette.');
      }
      if (e.code == '23505' ||
          msg.contains('uq_chore_roulette_one_spin_per_task') ||
          msg.contains('already') ||
          msg.contains('duplicate')) {
        throw StateError('This task has already been spun.');
      }
      rethrow;
    }

    Map<String, dynamic>? row;
    if (raw is Map<String, dynamic>) {
      row = raw;
    } else if (raw is Map) {
      row = Map<String, dynamic>.from(raw);
    } else if (raw is List && raw.isNotEmpty && raw.first is Map) {
      row = Map<String, dynamic>.from(raw.first as Map);
    }
    if (row == null) {
      throw StateError('Unexpected Task Roulette response.');
    }

    final created = ChoreRouletteRecord.fromJson(row);
    _rouletteRecords = [
      created,
      ..._rouletteRecords.where(
        (r) => r.id != created.id && r.taskId != taskId,
      ),
    ];
    _safeNotify();

    unawaited(_fetchHouseholdData().then((_) => _safeNotify()));
    return created;
  }

  // =========================================================================
  // LOST & FOUND (`lost_items`, `found_items`)
  // =========================================================================

  @override
  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? location,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    unawaited(
      _postItemAsync(
        type: type,
        title: title,
        description: description,
        location: location,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
      ),
    );
  }

  Future<void> _postItemAsync({
    required ItemType type,
    required String title,
    String? description,
    String? location,
    String? imageUrl,
    Uint8List? imageBytes,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before posting to Lost & Found.');
      return;
    }

    final effectiveType = type == ItemType.found ? ItemType.found : ItemType.lost;
    final itemId = _uuid.v4();
    var resolvedImageUrl = imageUrl;

    try {
      if (imageBytes != null ||
          (resolvedImageUrl != null && _needsStorageUpload(resolvedImageUrl))) {
        resolvedImageUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.casnapsBucket,
          pathPrefix: 'items/${_currentHousehold.id}',
          exactStoragePath: 'items/${_currentHousehold.id}/$itemId.jpg',
          rawSource: resolvedImageUrl,
          bytes: imageBytes,
        );
      }

      if (effectiveType == ItemType.lost) {
        await client.from('lost_items').insert({
          'id': itemId,
          'household_id': _currentHousehold.id,
          'owner_id': _currentUser.id,
          'title': title,
          'description': description,
          'last_seen_location': location,
          'image_url': resolvedImageUrl,
          'status': 'open',
        });
      } else {
        await client.from('found_items').insert({
          'id': itemId,
          'household_id': _currentHousehold.id,
          'finder_id': _currentUser.id,
          'title': title,
          'description': description,
          'found_location': location,
          'image_url': resolvedImageUrl,
          'status': 'unclaimed',
        });
      }

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError('Could not post item to Lost & Found.', error: e);
    }
  }

  @override
  Future<String?> submitLostItemFind({
    required LostFoundItem lostItem,
    String? foundLocation,
    String? description,
    String? imageUrl,
    Uint8List? imageBytes,
    XFile? imageFile,
  }) async {
    final client = _client;
    if (client == null ||
        _currentHousehold.id.isEmpty ||
        _currentUser.id.isEmpty) {
      const msg = 'Join a household before reporting a found match.';
      _recordError(msg);
      return msg;
    }
    if (_currentUser.id == lostItem.reportedBy) {
      const msg = 'Use "Found It Myself" to resolve your own lost item.';
      _recordError(msg);
      return msg;
    }
    if (lostItem.type != ItemType.lost || lostItem.status != ItemStatus.open) {
      const msg = 'This lost item is no longer open.';
      _recordError(msg);
      return msg;
    }

    final newId = _uuid.v4();
    var resolvedImageUrl = imageUrl;
    var resolvedBytes = imageBytes;

    try {
      if (resolvedBytes == null && imageFile != null) {
        resolvedBytes = await imageFile.readAsBytes();
      }
      if (resolvedBytes != null ||
          (resolvedImageUrl != null && _needsStorageUpload(resolvedImageUrl))) {
        resolvedImageUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.casnapsBucket,
          pathPrefix: 'items/${_currentHousehold.id}',
          exactStoragePath: 'items/${_currentHousehold.id}/$newId.jpg',
          rawSource: resolvedImageUrl,
          bytes: resolvedBytes,
        );
      }

      await client.from('found_items').insert({
        'id': newId,
        'household_id': _currentHousehold.id,
        'finder_id': _currentUser.id,
        'lost_item_id': lostItem.id,
        'title': lostItem.title,
        'description': description,
        'found_location': foundLocation,
        'image_url': resolvedImageUrl,
        'status': 'pending',
      });

      await _fetchHouseholdData();
      _safeNotify();
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505' ||
          e.message.contains('uq_found_items_one_pending_per_finder')) {
        const msg = 'You already have a pending find awaiting review.';
        _recordError(msg, error: e);
        return msg;
      }
      const msg = 'Could not submit found match.';
      _recordError(msg, error: e);
      return msg;
    } catch (e) {
      const msg = 'Could not submit found match.';
      _recordError(msg, error: e);
      return msg;
    }
  }

  @override
  Future<String?> acceptLostItemFind(String foundItemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      const msg = 'Sign in to confirm a found match.';
      _recordError(msg);
      return msg;
    }
    try {
      await client.rpc(
        'accept_lost_item_find',
        params: {'p_found_item_id': foundItemId},
      );
      await _fetchHouseholdData();
      _safeNotify();
      return null;
    } catch (e) {
      const msg = 'Could not confirm this find.';
      _recordError(msg, error: e);
      return msg;
    }
  }

  @override
  Future<String?> rejectLostItemFind(String foundItemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      const msg = 'Sign in to reject a found match.';
      _recordError(msg);
      return msg;
    }
    try {
      await client.rpc(
        'reject_lost_item_find',
        params: {'p_found_item_id': foundItemId},
      );
      await _fetchHouseholdData();
      _safeNotify();
      return null;
    } catch (e) {
      const msg = 'Could not reject this find.';
      _recordError(msg, error: e);
      return msg;
    }
  }

  @override
  Future<String?> resolveOwnLostItem(String lostItemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      const msg = 'Sign in to resolve your lost item.';
      _recordError(msg);
      return msg;
    }
    try {
      await client.rpc(
        'resolve_own_lost_item',
        params: {'p_lost_item_id': lostItemId},
      );
      await _fetchHouseholdData();
      _safeNotify();
      return null;
    } catch (e) {
      const msg = 'Could not resolve this lost item.';
      _recordError(msg, error: e);
      return msg;
    }
  }

  @override
  Future<String?> claimStandaloneFoundItem(String foundItemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      const msg = 'Sign in to claim a found item.';
      _recordError(msg);
      return msg;
    }
    try {
      await client.rpc(
        'claim_standalone_found_item',
        params: {'p_found_item_id': foundItemId},
      );
      await _fetchHouseholdData();
      _safeNotify();
      return null;
    } catch (e) {
      const msg = 'Could not claim this found item.';
      _recordError(msg, error: e);
      return msg;
    }
  }

  @override
  Future<void> deleteLostItem(String lostItemId) async {
    final client = _requireClient();
    final prevItems = List<LostFoundItem>.from(_items);
    final prevNotifications = List<HouseholdNotificationItem>.from(_notifications);
    final linkedIds = _items
        .where((i) => i.lostItemId == lostItemId)
        .map((i) => i.id)
        .toSet();

    _items = _items
        .where((i) => i.id != lostItemId && i.lostItemId != lostItemId)
        .toList();
    _notifications = _notifications
        .where(
          (n) =>
              !n.matchesEntity(entityType: 'lost_item', entityId: lostItemId) &&
              !linkedIds.any(
                (fid) => n.matchesEntity(entityType: 'found_item', entityId: fid),
              ),
        )
        .toList();
    _safeNotify();

    try {
      await client.from('lost_items').delete().eq('id', lostItemId);
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _items = prevItems;
      _notifications = prevNotifications;
      _recordError('Could not delete item.', error: e);
      _safeNotify();
      rethrow;
    }
  }

  @override
  Future<void> deleteFoundItem(String foundItemId) async {
    final client = _requireClient();
    final prevItems = List<LostFoundItem>.from(_items);
    final prevNotifications = List<HouseholdNotificationItem>.from(_notifications);

    _items = _items.where((i) => i.id != foundItemId).toList();
    _notifications = _notifications
        .where(
          (n) => !n.matchesEntity(entityType: 'found_item', entityId: foundItemId),
        )
        .toList();
    _safeNotify();

    try {
      await client.from('found_items').delete().eq('id', foundItemId);
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _items = prevItems;
      _notifications = prevNotifications;
      _recordError('Could not delete item.', error: e);
      _safeNotify();
      rethrow;
    }
  }

  // =========================================================================
  // QUICKSNAP LOCKET & SUPABASE STORAGE
  // =========================================================================

  @override
  void sendQuickSnap({
    required String imageUrl,
    Uint8List? imageBytes,
    String? caption,
  }) {
    unawaited(
      _sendQuickSnapAsync(
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        caption: caption,
      ),
    );
  }

  Future<void> _sendQuickSnapAsync({
    required String imageUrl,
    Uint8List? imageBytes,
    String? caption,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before sending a CASnap.');
      return;
    }

    final snapId = _uuid.v4();
    try {
      var uploadedUrl = imageUrl;
      if (imageBytes != null || _needsStorageUpload(imageUrl)) {
        uploadedUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.casnapsBucket,
          pathPrefix: '${_currentHousehold.id}/$snapId',
          rawSource: imageUrl,
          bytes: imageBytes,
        );
      }

      final trimmedCaption = caption?.trim() ?? '';
      await client.from('quick_snaps').insert({
        'id': snapId,
        'household_id': _currentHousehold.id,
        'creator_id': _currentUser.id,
        'creator_name': _currentUser.effectiveGreetingName,
        'image_url': uploadedUrl,
        'caption': trimmedCaption.isEmpty ? null : trimmedCaption,
      });

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError(
        'Could not upload and send CASnap.',
        onRetry: () => _sendQuickSnapAsync(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
          caption: caption,
        ),
        error: e,
      );
    }
  }

  void _rebuildEffectiveQuickSnaps() {
    final uid = _currentUser.id;
    final uname = _currentUser.effectiveGreetingName;
    final now = DateTime.now();

    _quickSnaps = _serverQuickSnaps.map((snap) {
      final inFlight = _inFlightReactionDeltas[snap.id];
      final pending = _pendingReactionDeltas[snap.id];
      if ((inFlight == null || inFlight.isEmpty) &&
          (pending == null || pending.isEmpty)) {
        return snap;
      }

      final combined = <String, int>{};
      if (inFlight != null) {
        for (final entry in inFlight.entries) {
          if (entry.value > 0) {
            combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
          }
        }
      }
      if (pending != null) {
        for (final entry in pending.entries) {
          if (entry.value > 0) {
            combined[entry.key] = (combined[entry.key] ?? 0) + entry.value;
          }
        }
      }
      if (combined.isEmpty) return snap;

      final merged = List<QuickSnapReaction>.from(snap.reactions);
      for (final entry in combined.entries) {
        final existingIdx = merged.indexWhere(
          (r) => r.userId == uid && r.emoji == entry.key,
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
              userId: uid,
              userName: uname,
              count: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
      return snap.copyWith(reactions: merged);
    }).toList();
  }

  @override
  void reactToQuickSnap(String snapId, String emoji) {
    queueQuickSnapReaction(snapId, emoji);
  }

  @override
  void queueQuickSnapReaction(String snapId, String emoji) {
    if (_disposed ||
        snapId.isEmpty ||
        _currentUser.id.isEmpty ||
        !kCasSnapReactionEmojis.contains(emoji)) {
      return;
    }

    final snapDeltas = _pendingReactionDeltas.putIfAbsent(
      snapId,
      () => <String, int>{},
    );
    snapDeltas[emoji] = (snapDeltas[emoji] ?? 0) + 1;

    _rebuildEffectiveQuickSnaps();
    _safeNotify();

    _reactionFlushTimers.remove(snapId)?.cancel();
    _reactionFlushTimers[snapId] = Timer(quickSnapReactionDebounce, () {
      _reactionFlushTimers.remove(snapId);
      unawaited(_flushSnapReactions(snapId));
    });
  }

  @override
  Future<void> flushPendingSnapReactions() async {
    final timers = _reactionFlushTimers.values.toList();
    _reactionFlushTimers.clear();
    for (final timer in timers) {
      timer.cancel();
    }

    if (_inFlightFlushFutures.isNotEmpty) {
      await Future.wait(_inFlightFlushFutures.values.toList());
    }

    final attemptedInPass = <String>{};
    while (!_disposed) {
      final pendingIds = _pendingReactionDeltas.entries
          .where((e) => e.value.isNotEmpty && !attemptedInPass.contains(e.key))
          .map((e) => e.key)
          .toList();
      if (pendingIds.isEmpty) break;
      attemptedInPass.addAll(pendingIds);
      await Future.wait(pendingIds.map(_flushSnapReactions));
      if (_inFlightFlushFutures.isNotEmpty) {
        await Future.wait(_inFlightFlushFutures.values.toList());
      }
    }
  }

  Future<void> _flushSnapReactions(String snapId) async {
    _reactionFlushTimers.remove(snapId)?.cancel();
    if (_flushingSnapIds.contains(snapId)) {
      return;
    }

    final rawPending = _pendingReactionDeltas.remove(snapId);
    if (rawPending == null || rawPending.isEmpty) return;

    final batch = <String, int>{
      for (final entry in rawPending.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    if (batch.isEmpty) return;

    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      _mergeReactionDeltasBack(snapId, batch);
      return;
    }

    _flushingSnapIds.add(snapId);
    _inFlightReactionDeltas[snapId] = Map<String, int>.from(batch);

    final future = () async {
      var succeeded = false;
      try {
        await client.rpc(
          'increment_quick_snap_reactions',
          params: {
            'p_snap_id': snapId,
            'p_deltas': batch,
          },
        );

        final rows = await client
            .from('quick_snap_reactions')
            .select()
            .eq('snap_id', snapId);
        final serverReactions = (rows as List<dynamic>)
            .map(
              (e) => QuickSnapReaction.fromJson(
                Map<String, dynamic>.from(e as Map<String, dynamic>),
              ),
            )
            .toList();

        final idx = _serverQuickSnaps.indexWhere((s) => s.id == snapId);
        if (idx != -1) {
          _serverQuickSnaps[idx] = _serverQuickSnaps[idx].copyWith(
            reactions: serverReactions,
          );
        }

        _inFlightReactionDeltas.remove(snapId);
        _rebuildEffectiveQuickSnaps();
        _safeNotify();
        succeeded = true;
      } catch (e) {
        final failedBatch = _inFlightReactionDeltas.remove(snapId);
        if (failedBatch != null && failedBatch.isNotEmpty) {
          _mergeReactionDeltasBack(snapId, failedBatch);
        }
        _rebuildEffectiveQuickSnaps();
        _safeNotify();
        debugPrint(
          'SupabaseRepository: snap reaction flush failed ($snapId): $e',
        );
      } finally {
        _flushingSnapIds.remove(snapId);
        _inFlightFlushFutures.remove(snapId);
        if (succeeded &&
            !_disposed &&
            (_pendingReactionDeltas[snapId]?.isNotEmpty ?? false)) {
          unawaited(_flushSnapReactions(snapId));
        }
      }
    }();

    _inFlightFlushFutures[snapId] = future;
    await future;
  }

  void _mergeReactionDeltasBack(String snapId, Map<String, int> deltas) {
    final target = _pendingReactionDeltas.putIfAbsent(
      snapId,
      () => <String, int>{},
    );
    for (final entry in deltas.entries) {
      if (entry.value > 0) {
        target[entry.key] = (target[entry.key] ?? 0) + entry.value;
      }
    }
  }

  @override
  void commentOnQuickSnap(String snapId, String text) {
    unawaited(_commentOnQuickSnapAsync(snapId, text));
  }

  Future<void> _commentOnQuickSnapAsync(String snapId, String text) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) return;
    final commentId = _uuid.v4();
    final idx = _serverQuickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final updated = List<QuickSnapComment>.from(
        _serverQuickSnaps[idx].comments,
      )
        ..add(
          QuickSnapComment(
            id: commentId,
            userId: _currentUser.id,
            userName: _currentUser.effectiveGreetingName,
            userAvatar: _currentUser.avatarUrl,
            text: text,
            createdAt: DateTime.now(),
          ),
        );
      _serverQuickSnaps[idx] = _serverQuickSnaps[idx].copyWith(
        comments: updated,
      );
      _rebuildEffectiveQuickSnaps();
      _safeNotify();
    }

    try {
      await client.from('quick_snap_comments').insert({
        'id': commentId,
        'snap_id': snapId,
        'user_id': _currentUser.id,
        'user_name': _currentUser.effectiveGreetingName,
        'user_avatar': _currentUser.avatarUrl,
        'message': text,
      });
    } catch (e) {
      _recordError('Could not post comment.', error: e);
    }
  }

  @override
  void deleteQuickSnap(String snapId) {
    unawaited(_deleteQuickSnapAsync(snapId));
  }

  Future<void> _deleteQuickSnapAsync(String snapId) async {
    final client = _client;
    if (client == null) return;
    final prev = List<QuickSnap>.from(_serverQuickSnaps);
    _reactionFlushTimers.remove(snapId)?.cancel();
    _pendingReactionDeltas.remove(snapId);
    _inFlightReactionDeltas.remove(snapId);
    _serverQuickSnaps.removeWhere((s) => s.id == snapId);
    _rebuildEffectiveQuickSnaps();
    _safeNotify();

    try {
      await client.from('quick_snaps').delete().eq('id', snapId);
    } catch (e) {
      _serverQuickSnaps = prev;
      _rebuildEffectiveQuickSnaps();
      _recordError('Could not delete CASnap.', error: e);
    }
  }

  // =========================================================================
  // CASAMA CONNECT (GROUP, SPACES, DIRECT, READS, HOUSEMATES AGENDA)
  // =========================================================================

  @override
  void markGroupChatAsRead() {
    _groupChatUnreadCount = 0;
    _safeNotify();
    final cid = _groupConversationId;
    if (cid != null) {
      unawaited(_upsertConversationRead(cid));
    }
  }

  @override
  void markSpaceChatAsRead(String spaceId) {
    final idx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (idx != -1 && _chatSpaces[idx].unreadCount != 0) {
      _chatSpaces[idx] = _chatSpaces[idx].copyWith(unreadCount: 0);
      _safeNotify();
    }
    unawaited(_upsertConversationRead(spaceId));
  }

  @override
  void markDirectChatAsRead(String contactKey) {
    final member = _resolveMemberByKey(contactKey);
    if (member == null) return;
    final prev = _directUnreadCounts[member.profile.id] ?? 0;
    _directUnreadCounts[member.profile.id] = 0;
    if (prev != 0) {
      _safeNotify();
    }
    final cid = _directConversationIdsByKey[member.profile.id];
    if (cid != null) {
      final latestMessageAt =
          _directMessages[member.profile.id]?.lastOrNull?.createdAt;
      unawaited(
        _upsertConversationRead(cid, latestMessageAt: latestMessageAt),
      );
    }
  }

  Future<void> _upsertConversationRead(
    String conversationId, {
    DateTime? latestMessageAt,
  }) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) return;
    final now = DateTime.now();
    final effectiveReadAt =
        (latestMessageAt != null && latestMessageAt.isAfter(now))
            ? latestMessageAt
            : now;
    try {
      await client.from('conversation_reads').upsert(
        {
          'conversation_id': conversationId,
          'user_id': _currentUser.id,
          'last_read_at': toSupabaseUtcIso(effectiveReadAt),
        },
        onConflict: 'conversation_id,user_id',
      );
    } catch (e) {
      debugPrint('Supabase conversation_reads error: $e');
    }
  }

  @override
  void markNotificationAsRead(String notificationId) {
    final now = DateTime.now();
    var changed = false;
    _notifications = _notifications.map((n) {
      if (n.id == notificationId && n.isUnread) {
        changed = true;
        return n.copyWith(isRead: true, readAt: n.readAt ?? now);
      }
      return n;
    }).toList();
    if (changed) {
      _safeNotify();
    }

    final client = _client;
    if (client != null && _currentUser.id.isNotEmpty) {
      unawaited(
        client
            .from('notifications')
            .update({'read_at': toSupabaseUtcIso(now)})
            .eq('id', notificationId)
            .eq('user_id', _currentUser.id)
            .isFilter('read_at', null),
      );
    }
  }

  @override
  void markAllNotificationsAsRead() {
    final now = DateTime.now();
    _notifications = _notifications
        .map((n) => n.copyWith(isRead: true, readAt: n.readAt ?? now))
        .toList();
    _safeNotify();

    final client = _client;
    if (client != null && _currentUser.id.isNotEmpty && _currentHousehold.id.isNotEmpty) {
      unawaited(
        client
            .from('notifications')
            .update({'read_at': toSupabaseUtcIso(now)})
            .eq('household_id', _currentHousehold.id)
            .eq('user_id', _currentUser.id)
            .isFilter('read_at', null),
      );
    }
  }

  @override
  void addMemberToSpace(String spaceId, String memberName) {
    // Spaces include all household members automatically without per-member rows.
  }

  @override
  ChatSpace createChatSpace({
    required String name,
    required String description,
    String iconEmoji = '💬',
    required List<String> initialMembers,
  }) {
    final spaceId = _uuid.v4();
    final allNames = _members.map((m) => m.preferredName).toList();
    final newSpace = ChatSpace(
      id: spaceId,
      householdId: _currentHousehold.id,
      name: name,
      description: description,
      inviteCode: '',
      creatorId: _currentUser.id,
      creatorName: _currentUser.preferredName,
      memberNames: allNames,
      iconEmoji: iconEmoji,
      createdAt: DateTime.now(),
    );

    _chatSpaces = [..._chatSpaces, newSpace];
    _safeNotify();

    unawaited(_createSpaceAsync(newSpace));
    return newSpace;
  }

  Future<void> _createSpaceAsync(ChatSpace space) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before creating a chat space.');
      return;
    }
    try {
      await client.from('conversations').insert({
        'id': space.id,
        'household_id': _currentHousehold.id,
        'type': 'space',
        'name': space.name,
        'description': space.description,
        'icon': space.iconEmoji,
        'created_by': _currentUser.id,
      });
    } catch (e) {
      _chatSpaces.removeWhere((s) => s.id == space.id);
      _recordError('Could not create chat space.', error: e);
    }
  }

  @override
  ChatSpace? joinChatSpaceByCode(String code) => null;

  @override
  void shareInviteCodeToGroupChat({
    required String code,
    required String title,
  }) {
    sendChatMessage(
      '🔑 $title Invite Code: $code',
      inviteCode: code,
      inviteSpaceName: title,
    );
  }

  @override
  void shareInviteCodeToDirectChat({
    required String contactKey,
    required String code,
    required String title,
  }) {
    unawaited(
      _sendDirectMessageAsync(
        contactKey,
        '🔑 $title Invite Code: $code',
        inviteCode: code,
        inviteSpaceName: title,
      ),
    );
  }

  @override
  void sendChatMessage(
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    unawaited(
      _sendGroupOrSpaceMessageAsync(
        conversationId: _groupConversationId,
        isGroup: true,
        content: content,
        mediaUrl: mediaUrl,
        attachmentFile: attachmentFile,
        clientMessageId: clientMessageId,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
      ),
    );
  }

  @override
  void sendSpaceMessage(
    String spaceId,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    unawaited(
      _sendGroupOrSpaceMessageAsync(
        conversationId: spaceId,
        isGroup: false,
        content: content,
        mediaUrl: mediaUrl,
        attachmentFile: attachmentFile,
        clientMessageId: clientMessageId,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
      ),
    );
  }

  Future<String> _uploadChatAttachment({
    required String conversationId,
    required String clientMessageId,
    required XFile attachmentFile,
  }) async {
    final client = _requireClient();
    final bytes = await attachmentFile.readAsBytes();
    if (bytes.isEmpty) {
      throw StateError('Selected image has no bytes to upload.');
    }
    final storagePath = '$conversationId/$clientMessageId.jpg';
    await client.storage.from(SupabaseConfig.chatAttachmentsBucket).uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return client.storage
        .from(SupabaseConfig.chatAttachmentsBucket)
        .getPublicUrl(storagePath);
  }

  void _updateConversationMessageStatus({
    required bool isGroup,
    required String conversationId,
    required String messageId,
    required MessageDeliveryStatus status,
    String? attachmentUrl,
    bool clearLocalAttachment = false,
  }) {
    if (isGroup) {
      final idx = _groupMessages.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final updated = List<ChatMessage>.from(_groupMessages);
        updated[idx] = updated[idx].copyWith(
          deliveryStatus: status,
          attachmentUrl: attachmentUrl,
          clearLocalAttachment: clearLocalAttachment,
        );
        _groupMessages = updated;
        _safeNotify();
      }
      return;
    }

    final sIdx = _chatSpaces.indexWhere((s) => s.id == conversationId);
    if (sIdx != -1) {
      final space = _chatSpaces[sIdx];
      final mIdx = space.messages.indexWhere((m) => m.id == messageId);
      if (mIdx != -1) {
        final updated = List<ChatMessage>.from(space.messages);
        updated[mIdx] = updated[mIdx].copyWith(
          deliveryStatus: status,
          attachmentUrl: attachmentUrl,
          clearLocalAttachment: clearLocalAttachment,
        );
        _chatSpaces[sIdx] = space.copyWith(messages: updated);
        _safeNotify();
      }
    }
  }

  void _updateDirectMessageStatus({
    required String peerId,
    required String messageId,
    required MessageDeliveryStatus status,
    String? attachmentUrl,
    bool clearLocalAttachment = false,
  }) {
    final existing = _directMessages[peerId];
    if (existing == null) return;
    final idx = existing.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final updated = List<ChatMessage>.from(existing);
      updated[idx] = updated[idx].copyWith(
        deliveryStatus: status,
        attachmentUrl: attachmentUrl,
        clearLocalAttachment: clearLocalAttachment,
      );
      _directMessages[peerId] = updated;
      _safeNotify();
    }
  }

  @override
  void retryGroupMessage(String messageId) {
    final idx = _groupMessages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = _groupMessages[idx];
    if (msg.deliveryStatus != MessageDeliveryStatus.failed) return;
    final pendingFile = _pendingAttachmentFilesByMessageId.remove(messageId);
    _groupMessages = _groupMessages.where((m) => m.id != messageId).toList();
    _safeNotify();
    sendChatMessage(
      msg.content,
      mediaUrl: msg.attachmentUrl,
      attachmentFile: pendingFile,
      clientMessageId: msg.clientMessageId,
      inviteCode: msg.inviteCode,
      inviteSpaceName: msg.inviteSpaceName,
    );
  }

  @override
  void retrySpaceMessage(String spaceId, String messageId) {
    final sIdx = _chatSpaces.indexWhere((s) => s.id == spaceId);
    if (sIdx == -1) return;
    final space = _chatSpaces[sIdx];
    final mIdx = space.messages.indexWhere((m) => m.id == messageId);
    if (mIdx == -1) return;
    final msg = space.messages[mIdx];
    if (msg.deliveryStatus != MessageDeliveryStatus.failed) return;
    final pendingFile = _pendingAttachmentFilesByMessageId.remove(messageId);
    _chatSpaces[sIdx] = space.copyWith(
      messages: space.messages.where((m) => m.id != messageId).toList(),
    );
    _safeNotify();
    sendSpaceMessage(
      spaceId,
      msg.content,
      mediaUrl: msg.attachmentUrl,
      attachmentFile: pendingFile,
      clientMessageId: msg.clientMessageId,
      inviteCode: msg.inviteCode,
      inviteSpaceName: msg.inviteSpaceName,
    );
  }

  @override
  void retryDirectMessage(String contactKey, String messageId) {
    final peer = _resolveMemberByKey(contactKey);
    final peerId = peer?.profile.id ?? contactKey;
    final list = _directMessages[peerId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = list[idx];
    if (msg.deliveryStatus != MessageDeliveryStatus.failed) return;
    final pendingFile = _pendingAttachmentFilesByMessageId.remove(messageId);
    _directMessages[peerId] = list.where((m) => m.id != messageId).toList();
    _safeNotify();
    sendDirectMessage(
      contactKey,
      msg.content,
      mediaUrl: msg.attachmentUrl,
      attachmentFile: pendingFile,
      clientMessageId: msg.clientMessageId,
    );
  }

  Future<void> _sendGroupOrSpaceMessageAsync({
    required String? conversationId,
    required bool isGroup,
    required String content,
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Sign in to send messages.');
      return;
    }

    var targetConvId = conversationId;
    if (isGroup && targetConvId == null) {
      await _ensureGroupConversationExists(_currentHousehold.id, _currentUser.id);
      targetConvId = _groupConversationId;
    }
    if (targetConvId == null || targetConvId.isEmpty) return;

    final trimmedContent = content.trim();
    final messageId = _uuid.v4();
    final effectiveClientMessageId = clientMessageId ?? _uuid.v4();
    if (attachmentFile != null) {
      _pendingAttachmentFilesByMessageId[messageId] = attachmentFile;
    }

    final msg = ChatMessage(
      id: messageId,
      senderId: _currentUser.id,
      senderName: _currentUser.preferredName,
      senderAvatar: _currentUser.avatarUrl,
      content: trimmedContent,
      attachmentUrl: mediaUrl,
      localAttachmentPath: attachmentFile?.path,
      clientMessageId: effectiveClientMessageId,
      inviteCode: inviteCode,
      inviteSpaceName: inviteSpaceName,
      createdAt: DateTime.now(),
      isCurrentUser: true,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    if (isGroup) {
      _groupMessages = [..._groupMessages, msg];
    } else {
      final sIdx = _chatSpaces.indexWhere((s) => s.id == targetConvId);
      if (sIdx != -1) {
        _chatSpaces[sIdx] = _chatSpaces[sIdx].copyWith(
          messages: [..._chatSpaces[sIdx].messages, msg],
        );
      }
    }
    _safeNotify();

    try {
      String? uploadedAttachmentUrl = mediaUrl;
      if (attachmentFile != null) {
        uploadedAttachmentUrl = await _uploadChatAttachment(
          conversationId: targetConvId,
          clientMessageId: effectiveClientMessageId,
          attachmentFile: attachmentFile,
        );
      } else if (uploadedAttachmentUrl != null &&
          _needsStorageUpload(uploadedAttachmentUrl)) {
        uploadedAttachmentUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.chatAttachmentsBucket,
          pathPrefix: targetConvId,
          rawSource: uploadedAttachmentUrl,
        );
      }

      await client.from('messages').upsert(
        {
          'conversation_id': targetConvId,
          'sender_id': _currentUser.id,
          'content': trimmedContent,
          'attachment_url': uploadedAttachmentUrl,
          'client_message_id': effectiveClientMessageId,
        },
        onConflict: 'conversation_id,client_message_id',
        ignoreDuplicates: true,
      );
      await _upsertConversationRead(targetConvId);
      _pendingAttachmentFilesByMessageId.remove(messageId);
      _updateConversationMessageStatus(
        isGroup: isGroup,
        conversationId: targetConvId,
        messageId: messageId,
        status: MessageDeliveryStatus.delivered,
        attachmentUrl: uploadedAttachmentUrl,
        clearLocalAttachment: true,
      );
    } catch (e) {
      _updateConversationMessageStatus(
        isGroup: isGroup,
        conversationId: targetConvId,
        messageId: messageId,
        status: MessageDeliveryStatus.failed,
      );
      _recordError('Could not send message.', error: e);
    }
  }

  @override
  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
  }) {
    unawaited(
      _sendDirectMessageAsync(
        contactKey,
        content,
        mediaUrl: mediaUrl,
        attachmentFile: attachmentFile,
        clientMessageId: clientMessageId,
      ),
    );
  }

  Future<void> _sendDirectMessageAsync(
    String contactKey,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Sign in to send direct messages.');
      return;
    }

    final peer = _resolveMemberByKey(contactKey);
    if (peer == null) {
      _recordError('Housemate not found in your household.');
      return;
    }
    final peerId = peer.profile.id;

    final trimmedContent = content.trim();
    final messageId = _uuid.v4();
    final effectiveClientMessageId = clientMessageId ?? _uuid.v4();
    if (attachmentFile != null) {
      _pendingAttachmentFilesByMessageId[messageId] = attachmentFile;
    }

    final msg = ChatMessage(
      id: messageId,
      senderId: _currentUser.id,
      senderName: _currentUser.preferredName,
      senderAvatar: _currentUser.avatarUrl,
      content: trimmedContent,
      attachmentUrl: mediaUrl,
      localAttachmentPath: attachmentFile?.path,
      clientMessageId: effectiveClientMessageId,
      inviteCode: inviteCode,
      inviteSpaceName: inviteSpaceName,
      createdAt: DateTime.now(),
      isCurrentUser: true,
      deliveryStatus: MessageDeliveryStatus.sending,
    );

    final existing = List<ChatMessage>.from(_directMessages[peerId] ?? []);
    _directMessages[peerId] = [...existing, msg];
    _safeNotify();

    try {
      var convId = _directConversationIdsByKey[peerId];
      if (convId == null) {
        convId = await _findOrCreateDirectConversation(peerId);
        _directConversationIdsByKey[peerId] = convId;
      }

      String? uploadedAttachmentUrl = mediaUrl;
      if (attachmentFile != null) {
        uploadedAttachmentUrl = await _uploadChatAttachment(
          conversationId: convId,
          clientMessageId: effectiveClientMessageId,
          attachmentFile: attachmentFile,
        );
      } else if (uploadedAttachmentUrl != null &&
          _needsStorageUpload(uploadedAttachmentUrl)) {
        uploadedAttachmentUrl = await _uploadMediaToBucket(
          bucket: SupabaseConfig.chatAttachmentsBucket,
          pathPrefix: convId,
          rawSource: uploadedAttachmentUrl,
        );
      }

      await client.from('messages').upsert(
        {
          'conversation_id': convId,
          'sender_id': _currentUser.id,
          'content': trimmedContent,
          'attachment_url': uploadedAttachmentUrl,
          'client_message_id': effectiveClientMessageId,
        },
        onConflict: 'conversation_id,client_message_id',
        ignoreDuplicates: true,
      );
      await _upsertConversationRead(convId);
      _pendingAttachmentFilesByMessageId.remove(messageId);
      _updateDirectMessageStatus(
        peerId: peerId,
        messageId: messageId,
        status: MessageDeliveryStatus.delivered,
        attachmentUrl: uploadedAttachmentUrl,
        clearLocalAttachment: true,
      );
    } catch (e) {
      _updateDirectMessageStatus(
        peerId: peerId,
        messageId: messageId,
        status: MessageDeliveryStatus.failed,
      );
      _recordError('Could not send direct message.', error: e);
    }
  }

  Future<String> _findOrCreateDirectConversation(String peerId) async {
    final client = _requireClient();
    final existingConvs = await client
        .from('conversations')
        .select('id')
        .eq('household_id', _currentHousehold.id)
        .eq('type', 'direct');

    final ids = (existingConvs as List<dynamic>)
        .map((c) => (c as Map<String, dynamic>)['id'] as String)
        .toList();
    if (ids.isNotEmpty) {
      final members = await client
          .from('conversation_members')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', ids);
      final byConv = <String, Set<String>>{};
      for (final m in members) {
        final cid = m['conversation_id'] as String;
        final uid = m['user_id'] as String;
        byConv.putIfAbsent(cid, () => <String>{}).add(uid);
      }
      for (final entry in byConv.entries) {
        if (entry.value.contains(_currentUser.id) &&
            entry.value.contains(peerId)) {
          return entry.key;
        }
      }
    }

    final newId = _uuid.v4();
    await client.from('conversations').insert({
      'id': newId,
      'household_id': _currentHousehold.id,
      'type': 'direct',
      'created_by': _currentUser.id,
    });
    await client.from('conversation_members').upsert(
      [
        {'conversation_id': newId, 'user_id': _currentUser.id},
        {'conversation_id': newId, 'user_id': peerId},
      ],
      onConflict: 'conversation_id,user_id',
      ignoreDuplicates: true,
    );
    return newId;
  }

  @override
  Future<void> createHousematesAgendaInvitation({
    required String activity,
    required String location,
    required DateTime scheduledTime,
    String? announcementText,
  }) async {
    final client = _requireClient();
    if (_currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      throw StateError('Join a household before creating an agenda.');
    }
    var groupId = _groupConversationId;
    if (groupId == null) {
      await _ensureGroupConversationExists(_currentHousehold.id, _currentUser.id);
      groupId = _groupConversationId;
    }
    if (groupId == null) return;

    final invId = _uuid.v4();
    await client.from('housemates_agenda_invitations').insert({
      'id': invId,
      'conversation_id': groupId,
      'creator_id': _currentUser.id,
      'activity': activity,
      'location': location,
      'scheduled_time': toSupabaseUtcIso(scheduledTime),
      'status': 'upcoming',
    });

    await _fetchHouseholdData();
    _safeNotify();
  }

  @override
  Future<void> updateHousematesAgendaStatus(
    String invitationId,
    String status,
  ) async {
    if (status != 'done' && status != 'missed') {
      throw ArgumentError.value(status, 'status', "Must be 'done' or 'missed'");
    }
    final client = _requireClient();
    await client
        .from('housemates_agenda_invitations')
        .update({'status': status})
        .eq('id', invitationId);

    _housematesAgendaInvitations = _housematesAgendaInvitations
        .map((m) => m.id == invitationId ? m.copyWith(status: status) : m)
        .toList();
    _activeHousematesAgenda = _pickActiveHousematesAgenda(
      _housematesAgendaInvitations,
    );
    _safeNotify();
  }

  @override
  Future<void> deleteHousematesAgendaInvitation(String invitationId) async {
    final client = _requireClient();
    await client
        .from('housemates_agenda_invitations')
        .delete()
        .eq('id', invitationId);
    _housematesAgendaInvitations = _housematesAgendaInvitations
        .where((m) => m.id != invitationId)
        .toList();
    _notifications = _notifications
        .where(
          (n) => !n.matchesEntity(
            entityType: 'housemates_agenda',
            entityId: invitationId,
          ),
        )
        .toList();
    _activeHousematesAgenda = _pickActiveHousematesAgenda(
      _housematesAgendaInvitations,
    );
    _safeNotify();
  }

  @override
  void respondToHousematesAgendaInvitation(
    String response, {
    String? invitationId,
  }) {
    unawaited(
      _respondToHousematesAgendaAsync(response, invitationId: invitationId),
    );
  }

  Future<void> _respondToHousematesAgendaAsync(
    String response, {
    String? invitationId,
  }) async {
    final client = _client;
    final targetId = invitationId ?? _activeHousematesAgenda.id;
    final idx = _housematesAgendaInvitations.indexWhere(
      (m) => m.id == targetId,
    );
    final prev =
        idx != -1 ? _housematesAgendaInvitations[idx] : _activeHousematesAgenda;
    if (client == null ||
        _currentUser.id.isEmpty ||
        prev.id.isEmpty ||
        !prev.isUpcoming) {
      return;
    }

    var g = prev.goingCount;
    var m = prev.maybeCount;
    var c = prev.cantMakeCount;
    if (prev.currentUserResponse == 'going') g = max(0, g - 1);
    if (prev.currentUserResponse == 'maybe') m = max(0, m - 1);
    if (prev.currentUserResponse == 'cant_make_it') c = max(0, c - 1);
    if (response == 'going') g++;
    if (response == 'maybe') m++;
    if (response == 'cant_make_it') c++;

    final updatedResponders = [
      ...prev.responders.where((r) => r.userId != _currentUser.id),
      HousematesAgendaResponse(
        userId: _currentUser.id,
        displayName: _currentUser.preferredName,
        avatarUrl: _currentUser.avatarUrl,
        response: response,
      ),
    ];

    final updated = prev.copyWith(
      goingCount: g,
      maybeCount: m,
      cantMakeCount: c,
      currentUserResponse: response,
      responders: updatedResponders,
    );
    final prevList = List<HousematesAgendaInvitation>.from(
      _housematesAgendaInvitations,
    );
    if (idx != -1) {
      final next = List<HousematesAgendaInvitation>.from(
        _housematesAgendaInvitations,
      );
      next[idx] = updated;
      _housematesAgendaInvitations = next;
    }
    _activeHousematesAgenda = _pickActiveHousematesAgenda(
      _housematesAgendaInvitations,
    );
    _safeNotify();

    try {
      await client.from('housemates_agenda_responses').upsert(
        {
          'invitation_id': prev.id,
          'user_id': _currentUser.id,
          'response': response,
          'updated_at': nowSupabaseUtcIso(),
        },
        onConflict: 'invitation_id,user_id',
      );
    } catch (e) {
      _housematesAgendaInvitations = prevList;
      _activeHousematesAgenda = _pickActiveHousematesAgenda(
        _housematesAgendaInvitations,
      );
      _recordError('Could not update agenda RSVP.', error: e);
    }
  }

  // =========================================================================
  // INVITATIONS
  // =========================================================================

  @override
  bool sendInvitation({
    required String inviteeEmailOrHandle,
    String? inviteeName,
  }) =>
      false;

  @override
  bool acceptInvitation(String invitationId) => false;

  @override
  bool declineInvitation(String invitationId) => false;

  @override
  void resetMembersForNewUserTest() {}

  // =========================================================================
  // HELPERS (STORAGE, POINTS, LOOKUPS)
  // =========================================================================

  MemberPresence? _resolveMemberByKey(String key) {
    final clean = key.trim().toLowerCase();
    if (clean.isEmpty) return null;
    for (final m in _members) {
      final p = m.profile;
      if (p.id.toLowerCase() == clean ||
          p.handle.toLowerCase() == clean ||
          p.preferredName.toLowerCase() == clean ||
          (p.nickname?.trim().toLowerCase() == clean) ||
          (p.fullName?.trim().toLowerCase() == clean) ||
          p.displayName.toLowerCase() == clean ||
          p.effectiveGreetingName.toLowerCase() == clean) {
        return m;
      }
    }
    return null;
  }

  bool _needsStorageUpload(String source) {
    final s = source.trim();
    if (s.isEmpty) return false;
    if (s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('assets/')) {
      return false;
    }
    return s.startsWith('data:image') ||
        s.startsWith('/') ||
        s.startsWith('file:') ||
        s.contains('\\') ||
        s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png');
  }

  Future<String> _uploadMediaToBucket({
    required String bucket,
    required String pathPrefix,
    String? exactStoragePath,
    String? rawSource,
    Uint8List? bytes,
  }) async {
    final client = _requireClient();
    Uint8List? uploadBytes = bytes;
    if (uploadBytes == null && rawSource != null) {
      if (rawSource.startsWith('data:image')) {
        final comma = rawSource.indexOf(',');
        final b64 = comma != -1 ? rawSource.substring(comma + 1) : rawSource;
        uploadBytes = base64Decode(b64);
      } else if (!kIsWeb) {
        final path = rawSource.startsWith('file://')
            ? rawSource.replaceFirst('file://', '')
            : rawSource;
        final file = File(path);
        if (await file.exists()) {
          uploadBytes = await file.readAsBytes();
        }
      }
    }

    if (uploadBytes == null || uploadBytes.isEmpty) {
      if (rawSource != null &&
          (rawSource.startsWith('http://') ||
              rawSource.startsWith('https://'))) {
        return rawSource;
      }
      throw StateError('No binary image bytes available for Storage upload.');
    }

    final storagePath = exactStoragePath ??
        '$pathPrefix/${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.jpg';
    await client.storage.from(bucket).uploadBinary(
      storagePath,
      uploadBytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    return client.storage.from(bucket).getPublicUrl(storagePath);
  }

  Future<void> _awardPoints({
    required String userId,
    required String actionType,
    required int points,
    required String referenceId,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty) return;
    try {
      await client.from('points_ledger').upsert(
        {
          'household_id': _currentHousehold.id,
          'user_id': userId,
          'action_type': actionType,
          'points': points,
          'reference_id': referenceId,
        },
        onConflict: 'user_id,action_type,reference_id',
        ignoreDuplicates: true,
      );
    } on PostgrestException catch (e) {
      final isDuplicate =
          e.code == '23505' || e.message.contains('uq_points_ledger_award');
      if (!isDuplicate) rethrow;
    }
  }

  String _formatPointActionTitle(String actionType) {
    switch (actionType) {
      case 'parcel_received':
        return 'Received a delivery';
      case 'task_completed':
        return 'Completed a household task';
      case 'lost_item_found':
        return "Found & returned a housemate's lost item";
      case 'found_item_claimed':
        return 'Found item claimed by a housemate';
      case 'lost_item_returned':
      case 'found_item_returned':
      case 'item_returned':
        return 'Returned a lost & found item';
      default:
        return 'Household contribution';
    }
  }

  String _mapPointCategory(String actionType) {
    if (actionType.contains('parcel')) return 'parcel';
    if (actionType.contains('task') || actionType.contains('roulette')) {
      return 'task';
    }
    if (actionType.contains('item')) return 'lost_found';
    return 'bonus';
  }

  /// Parses a `public.notifications` row into [HouseholdNotificationItem],
  /// prioritizing verbatim `payload['title']` and `payload['message']`.
  static HouseholdNotificationItem parseNotificationRow(
    Map<String, dynamic> map,
  ) {
    final type = map['type'] as String? ?? 'update';
    final rawPayload = map['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : const <String, dynamic>{};
    final readAt = parseSupabaseTimestampOrNull(map['read_at']);
    return HouseholdNotificationItem(
      id: (map['id'] as String?) ?? '',
      type: type,
      title: _notificationTitle(type, payload),
      subtitle: _notificationSubtitle(type, payload),
      createdAt: parseSupabaseTimestamp(map['created_at']),
      isRead: readAt != null,
      readAt: readAt,
      payload: payload,
    );
  }

  /// Removes a deleted notification row from [current] using Realtime `oldRecord`.
  static List<HouseholdNotificationItem> applyNotificationRealtimeDelete(
    List<HouseholdNotificationItem> current,
    Map<String, dynamic> oldRecord,
  ) {
    final deletedId = (oldRecord['id'] as String?)?.trim() ?? '';
    if (deletedId.isEmpty) return current;
    return current.where((n) => n.id != deletedId).toList();
  }

  static String _notificationTitle(String type, Map<String, dynamic> payload) {
    final customTitle = (payload['title'] as String?)?.trim();
    if (customTitle != null && customTitle.isNotEmpty) {
      if ((type == 'housemates_agenda_reminder' || type == 'meetup_reminder') &&
          !payload.containsKey('entity_type') &&
          !customTitle.startsWith('Agenda Reminder:')) {
        return 'Agenda Reminder: $customTitle';
      }
      return customTitle;
    }

    switch (type) {
      case 'parcel_received':
      case 'parcel_claimed':
        return '${payload['receiver_name'] ?? payload['claimer_name'] ?? 'A housemate'} received your ${payload['courier'] ?? 'parcel'}';
      case 'parcel_posted':
        return 'New ${payload['courier'] ?? 'parcel'} delivery posted';
      case 'parcel_reminder':
        return '${payload['courier'] ?? 'Parcel'} arriving soon';
      case 'parcel_arrived':
        return '📦 ${payload['courier'] ?? 'Parcel'} has arrived!';
      case 'parcel_settled':
        return '${payload['courier'] ?? 'Parcel'} COD settled';
      case 'parcel_cancelled':
        return '${payload['courier'] ?? 'Parcel'} delivery cancelled';
      case 'task_created':
        return 'New task: ${payload['task_title'] ?? 'Household task'}';
      case 'task_due_soon':
        return 'Task due soon: ${payload['task_title'] ?? 'Household task'}';
      case 'task_overdue':
        return 'Task overdue: ${payload['task_title'] ?? 'Household task'}';
      case 'task_completed':
        return 'Task completed: ${payload['task_title'] ?? 'Household task'}';
      case 'roulette_chosen':
        return '🎡 You were chosen for "${payload['task_title'] ?? 'a task'}"!';
      case 'lost_item_posted':
        return 'Lost item: ${payload['item_title'] ?? 'Missing item'}';
      case 'lost_item_find_submitted':
        return 'Possible match for "${payload['item_title'] ?? 'your lost item'}"';
      case 'lost_item_find_accepted':
        return 'Match confirmed for "${payload['item_title'] ?? 'lost item'}"!';
      case 'lost_item_find_rejected':
        return 'Match not confirmed for "${payload['item_title'] ?? 'lost item'}"';
      case 'lost_item_self_resolved':
        return 'Lost item resolved: ${payload['item_title'] ?? 'Item'}';
      case 'found_item_posted':
        return 'Found item posted: ${payload['item_title'] ?? 'Found item'}';
      case 'found_item_claimed':
        return 'Found item claimed: ${payload['item_title'] ?? 'Found item'}';
      case 'housemates_agenda_created':
        return 'New Housemates Agenda';
      case 'housemates_agenda_reminder':
      case 'meetup_reminder':
        return 'Agenda Reminder: ${payload['title'] ?? 'Housemates Agenda'}';
      case 'housemates_agenda_started':
        return 'Housemates Agenda starting now!';
      case 'housemates_agenda_resolved':
        return 'Housemates Agenda updated';
      case 'housemate_joined':
        return '${payload['actor_name'] ?? 'A housemate'} joined ${payload['household_name'] ?? 'your household'}';
      default:
        return 'Household update';
    }
  }

  static String _notificationSubtitle(
    String type,
    Map<String, dynamic> payload,
  ) {
    final msg = (payload['message'] as String?)?.trim();
    if (msg != null && msg.isNotEmpty) return msg;

    switch (type) {
      case 'parcel_received':
      case 'parcel_claimed':
        final cod = payload['cod_amount'];
        return cod != null
            ? 'COD ₱$cod • Tap to view Parcels'
            : 'Tap to view Parcels';
      case 'parcel_posted':
      case 'parcel_reminder':
      case 'parcel_arrived':
      case 'parcel_settled':
      case 'parcel_cancelled':
        return 'Tap to view Parcels';
      case 'task_created':
      case 'task_due_soon':
      case 'task_overdue':
      case 'task_completed':
        return 'Tap to view Tasks';
      case 'roulette_chosen':
        final bonus = (payload['bonus_points'] as num?)?.toInt() ?? 4;
        return 'Check out "${payload['task_title'] ?? 'your task'}" — you got +$bonus bonus pts!';
      case 'lost_item_posted':
      case 'lost_item_find_submitted':
      case 'lost_item_find_accepted':
      case 'lost_item_find_rejected':
      case 'lost_item_self_resolved':
      case 'found_item_posted':
      case 'found_item_claimed':
        return 'Tap to view Lost & Found';
      case 'housemates_agenda_reminder':
      case 'meetup_reminder':
        final location = (payload['location'] as String?)?.trim();
        return location != null && location.isNotEmpty
            ? 'Starting soon — $location'
            : 'Starting soon — Housemates Agenda';
      case 'housemates_agenda_created':
      case 'housemates_agenda_started':
      case 'housemates_agenda_resolved':
        final location = (payload['location'] as String?)?.trim();
        return location != null && location.isNotEmpty
            ? location
            : 'Tap to view Housemates Agenda';
      case 'housemate_joined':
        return 'Say hello to your new housemate!';
      default:
        return 'Tap to view';
    }
  }
}
