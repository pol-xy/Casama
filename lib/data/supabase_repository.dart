import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  // Cached household collections
  int _kasamaPoints = 0;
  DateTime? _lastRouletteSpinAt;
  List<MemberPresence> _members = [];
  List<ParcelItem> _parcels = [];
  List<LostFoundItem> _items = [];
  List<MaintenanceTask> _tasks = [];
  List<HouseholdBill> _bills = [];
  String? _groupConversationId;
  List<ChatMessage> _groupMessages = [];
  int _groupChatUnreadCount = 0;
  List<ChatSpace> _chatSpaces = [];
  Map<String, String> _directConversationIdsByKey = {};
  Map<String, List<ChatMessage>> _directMessages = {};
  Map<String, int> _directUnreadCounts = {};
  MeetUpInvitation _activeMeetUp = MeetUpInvitation(
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
  List<QuickSnap> _quickSnaps = [];
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
  bool get isAuthenticated =>
      _isAuthenticated || (_client?.auth.currentSession != null);

  @override
  bool get hasActiveHousehold => _currentHousehold.id.trim().isNotEmpty;

  @override
  UserProfile get currentUser => _currentUser;

  @override
  Household get currentHousehold => _currentHousehold;

  @override
  int get kasamaPoints => _kasamaPoints;

  @override
  String get effectiveGreetingName => _currentUser.effectiveGreetingName;

  @override
  DateTime? get lastRouletteSpinAt => _lastRouletteSpinAt;

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
  int get groupChatUnreadCount => _groupChatUnreadCount;

  @override
  int get unreadNotificationCount =>
      _notifications.where((n) => !n.isRead).length;

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
  MeetUpInvitation get activeMeetUp => _activeMeetUp;

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
    final defaultHandle =
        '@${prefix.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase()}';
    final res = await client.auth.signUp(
      email: trimmedEmail,
      password: password,
      data: {'full_name': prefix, 'handle': defaultHandle},
    );
    final user = res.user;
    if (res.session != null && user != null) {
      await _ensureProfileRow(user);
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

  void _resetSignedOutState() {
    _teardownRealtime();
    _isAuthenticated = false;
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
    _kasamaPoints = 0;
    _lastRouletteSpinAt = null;
    _members = [];
    _parcels = [];
    _items = [];
    _tasks = [];
    _bills = [];
    _groupConversationId = null;
    _groupMessages = [];
    _groupChatUnreadCount = 0;
    _chatSpaces = [];
    _directConversationIdsByKey = {};
    _directMessages = {};
    _directUnreadCounts = {};
    _activeMeetUp = MeetUpInvitation(
      id: '',
      activity: '',
      location: '',
      scheduledTime: DateTime.now().add(const Duration(days: 30)),
    );
    _pointHistory = [];
    _leaderboardStandings = [];
    _notifications = [];
    _quickSnaps = [];
    _cachedUserSearch = [];
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
    final safeHandlePrefix = emailPrefix
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '')
        .toLowerCase();
    final suffix = authUser.id.replaceAll('-', '').substring(0, 4);
    final displayName =
        (authUser.userMetadata?['full_name'] as String?)?.trim().isNotEmpty ==
            true
        ? (authUser.userMetadata!['full_name'] as String).trim()
        : emailPrefix;

    final payload = <String, dynamic>{
      'id': authUser.id,
      'display_name': displayName,
      'full_name': displayName,
      'handle': '@${safeHandlePrefix.isNotEmpty ? safeHandlePrefix : 'user'}_$suffix',
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
        payload['handle'] = '@user_${_uuid.v4().substring(0, 6)}';
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

  Future<void> _hydrateAuthenticatedUser(User authUser) async {
    final client = _requireClient();
    _isAuthenticated = true;

    try {
      _currentUser = await _ensureProfileRow(authUser);

      final memberRecord = await client
          .from('household_members')
          .select('household_id, households(id, name, invite_code, created_by)')
          .eq('user_id', authUser.id)
          .order('joined_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (memberRecord != null && memberRecord['households'] != null) {
        _currentHousehold = Household.fromJson(
          memberRecord['households'] as Map<String, dynamic>,
        );
        await _fetchHouseholdData();
        _setupRealtime();
      } else {
        _teardownRealtime();
        _currentHousehold = const Household(
          id: '',
          name: 'Casama Household',
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
      _safeNotify();
    }
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
  }) {
    unawaited(
      _updateProfileAsync(
        displayName: displayName,
        handle: handle,
        fullName: fullName,
        nickname: nickname,
        age: age,
        birthDate: birthDate,
        avatarUrl: avatarUrl,
        clearAvatar: clearAvatar,
        clearNickname: clearNickname,
        clearAge: clearAge,
        clearBirthDate: clearBirthDate,
      ),
    );
  }

  Future<void> _updateProfileAsync({
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
    final prevUser = _currentUser;
    final computedAge = age ?? _computeAgeFromBirthDate(birthDate);
    final effectiveDisplayName = displayName ?? _currentUser.displayName;
    final effectiveFullName = fullName ?? _currentUser.fullName;
    final effectiveNickname = clearNickname
        ? null
        : (nickname ?? _currentUser.nickname);
    final effectiveHandle = handle ?? _currentUser.handle;
    final effectiveAge = clearAge
        ? null
        : (computedAge ?? _currentUser.age);
    final effectiveBirthDate = clearBirthDate
        ? null
        : (birthDate ?? _currentUser.birthDate);
    var effectiveAvatarUrl = clearAvatar
        ? null
        : (avatarUrl ?? _currentUser.avatarUrl);

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

      final updates = <String, dynamic>{
        'display_name': effectiveDisplayName,
        'handle': effectiveHandle,
        'full_name': effectiveFullName,
        'nickname': effectiveNickname,
        'age': effectiveAge,
        'avatar_url': effectiveAvatarUrl,
      };
      await client
          .from('profiles')
          .update(updates)
          .eq('id', _currentUser.id);

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
      _safeNotify();
    } catch (e) {
      _currentUser = prevUser;
      _recordError('Failed to save profile changes.', error: e);
    }
  }

  int? _computeAgeFromBirthDate(DateTime? birthDate) {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age >= 10 && age <= 120 ? age : null;
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
      age: _currentUser.age,
      birthDate: _currentUser.birthDate,
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
      age: _currentUser.age,
      birthDate: _currentUser.birthDate,
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

    _currentHousehold = Household.fromJson(created);
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
    }

    _currentHousehold = household;
    await _ensureGroupConversationExists(household.id, userId);
    await _fetchHouseholdData();
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

      // 2. Parcels + Availability + Claims
      final parcelsFuture = client
          .from('parcels')
          .select()
          .eq('household_id', householdId)
          .order('expected_arrival', ascending: true);
      final availFuture = client
          .from('parcel_availability')
          .select()
          .eq('household_id', householdId);
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
          .eq('spun_by_user_id', userId)
          .order('created_at', ascending: false)
          .limit(1);

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

      // 5. Bills & QuickSnaps
      final billsFuture = client
          .from('bills')
          .select()
          .eq('household_id', householdId)
          .order('deadline', ascending: true);
      final snapsFuture = client
          .from('quick_snaps')
          .select(
            '*, quick_snap_recipients(user_id), quick_snap_reactions(*), quick_snap_comments(*)',
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
        availFuture,
        claimsFuture,
        tasksFuture,
        rouletteFuture,
        lostFuture,
        foundFuture,
        billsFuture,
        snapsFuture,
        pointsFuture,
        notifFuture,
        convFuture,
      ]);

      final membersRes = results[0] as List<dynamic>;
      final presenceRes = results[1] as List<dynamic>;
      final parcelsRes = results[2] as List<dynamic>;
      final availRes = results[3] as List<dynamic>;
      final claimsRes = results[4] as List<dynamic>;
      final tasksRes = results[5] as List<dynamic>;
      final rouletteRes = results[6] as List<dynamic>;
      final lostRes = results[7] as List<dynamic>;
      final foundRes = results[8] as List<dynamic>;
      final billsRes = results[9] as List<dynamic>;
      final snapsRes = results[10] as List<dynamic>;
      final pointsRes = results[11] as List<dynamic>;
      final notifRes = results[12] as List<dynamic>;
      final convRes = results[13] as List<dynamic>;

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
          updatedAt: ev?['created_at'] != null
              ? DateTime.parse(ev!['created_at'] as String)
              : DateTime.now(),
        );
      }).toList();

      // Parcels + Availability + Claims
      final availByParcel = <String, List<String>>{};
      final unavailCountByParcel = <String, int>{};
      for (final row in availRes) {
        final map = row as Map<String, dynamic>;
        final pid = map['parcel_id'] as String? ?? '';
        final uid = map['user_id'] as String? ?? '';
        final isAvail = map['is_available'] as bool? ?? false;
        if (pid.isEmpty) continue;
        if (isAvail) {
          final name = profileMap[uid]?.effectiveGreetingName ?? 'Housemate';
          availByParcel.putIfAbsent(pid, () => []).add(name);
        } else {
          unavailCountByParcel[pid] = (unavailCountByParcel[pid] ?? 0) + 1;
        }
      }
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
            profileMap[buyerId]?.displayName ?? 'Housemate';
        map['available_members'] = availByParcel[pid] ?? const <String>[];
        map['is_all_unavailable'] =
            _members.isNotEmpty &&
            (unavailCountByParcel[pid] ?? 0) >= _members.length;
        map['cod_settled'] = claim?['settled'] as bool? ?? false;
        map['claimed_by_id'] = receiverId;
        map['claimed_by_name'] = receiverId != null
            ? profileMap[receiverId]?.displayName
            : null;
        return ParcelItem.fromJson(map);
      }).toList();

      // Maintenance Tasks
      _tasks = tasksRes.map((row) {
        final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
        final assigneeId = map['assignee_id'] as String?;
        final createdById = map['created_by'] as String? ?? '';
        if (assigneeId != null && profileMap.containsKey(assigneeId)) {
          map['assignee_name'] = profileMap[assigneeId]!.displayName;
          map['assignee_avatar'] = profileMap[assigneeId]!.avatarUrl;
        }
        map['created_by_name'] =
            profileMap[createdById]?.displayName ?? 'Housemate';
        return MaintenanceTask.fromJson(map);
      }).toList();

      // Latest roulette spin for 24h cooldown
      if (rouletteRes.isNotEmpty) {
        final rawCreated =
            (rouletteRes.first as Map<String, dynamic>)['created_at'] as String?;
        _lastRouletteSpinAt = rawCreated != null
            ? DateTime.tryParse(rawCreated)
            : null;
      } else {
        _lastRouletteSpinAt = null;
      }

      // Lost & Found Items (`lost_items` + `found_items`)
      final combinedItems = <LostFoundItem>[
        ...lostRes.map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final reporterId = map['reported_by'] as String? ?? '';
          map['reported_by_name'] =
              profileMap[reporterId]?.displayName ?? 'Housemate';
          return LostFoundItem.fromJson(map, forcedType: ItemType.lost);
        }),
        ...foundRes.map((row) {
          final map = Map<String, dynamic>.from(row as Map<String, dynamic>);
          final reporterId = map['reported_by'] as String? ?? '';
          map['reported_by_name'] =
              profileMap[reporterId]?.displayName ?? 'Housemate';
          return LostFoundItem.fromJson(map, forcedType: ItemType.found);
        }),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items = combinedItems;

      // Bills
      _bills = billsRes
          .map((b) => HouseholdBill.fromJson(b as Map<String, dynamic>))
          .toList();

      // QuickSnaps (enforce recipient visibility)
      _quickSnaps = snapsRes
          .map((raw) {
            final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
            final recipients =
                (map['quick_snap_recipients'] as List<dynamic>? ?? const [])
                    .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
                    .toList();
            map['recipient_names'] = recipients
                .map((uid) => profileMap[uid]?.displayName ?? 'Housemate')
                .toList();
            final snap = QuickSnap.fromJson(map);
            final isVisible =
                snap.recipientType == QuickSnapRecipientType.everyone ||
                snap.senderId == userId ||
                recipients.contains(userId);
            return isVisible ? snap : null;
          })
          .whereType<QuickSnap>()
          .toList();

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
              timestamp: map['created_at'] != null
                  ? DateTime.parse(map['created_at'] as String)
                  : DateTime.now(),
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
          displayName: p.fullName ?? p.displayName,
          handle: p.handle,
          avatarUrl: p.avatarUrl,
          points: pointsByUser[p.id] ?? 0,
          isCurrentUser: p.id == userId,
        );
      }).toList()
        ..sort((a, b) => b.points.compareTo(a.points));

      // Notifications
      _notifications = notifRes.map((row) {
        final map = row as Map<String, dynamic>;
        final type = map['type'] as String? ?? 'update';
        final payload =
            (map['payload'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
        return HouseholdNotificationItem(
          id: map['id'] as String,
          type: type,
          title: _notificationTitle(type, payload),
          subtitle: _notificationSubtitle(type, payload),
          createdAt: map['created_at'] != null
              ? DateTime.parse(map['created_at'] as String)
              : DateTime.now(),
          isRead: map['read_at'] != null,
          payload: payload,
        );
      }).toList();

      // Conversations, Messages, Reads & Meet-ups
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
    final meetupsFuture = groupId == null
        ? Future.value(<dynamic>[])
        : client
            .from('meet_up_invitations')
            .select('*, meet_up_responses(*)')
            .eq('conversation_id', groupId)
            .order('created_at', ascending: false)
            .limit(1);

    final convData = await Future.wait<dynamic>([
      msgsFuture,
      readsFuture,
      dmMembersFuture,
      meetupsFuture,
    ]);

    final msgsRes = convData[0] as List<dynamic>;
    final readsRes = convData[1] as List<dynamic>;
    final dmMembersRes = convData[2] as List<dynamic>;
    final meetupsRes = convData[3] as List<dynamic>;

    final lastReadByConv = <String, DateTime>{};
    for (final raw in readsRes) {
      final map = raw as Map<String, dynamic>;
      final cid = map['conversation_id'] as String? ?? '';
      final ts = map['last_read_at'] as String?;
      if (cid.isNotEmpty && ts != null) {
        final parsed = DateTime.tryParse(ts);
        if (parsed != null) lastReadByConv[cid] = parsed;
      }
    }

    final msgsByConv = <String, List<ChatMessage>>{};
    for (final raw in msgsRes) {
      final map = Map<String, dynamic>.from(raw as Map<String, dynamic>);
      final cid = map['conversation_id'] as String? ?? '';
      final senderId = map['sender_id'] as String? ?? '';
      map['sender_name'] = profileMap[senderId]?.displayName ?? 'Housemate';
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

    final allMemberNames = profileMap.values.map((p) => p.displayName).toList();
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
        creatorName: profileMap[creatorId]?.displayName ?? 'Housemate',
        memberNames: allMemberNames,
        iconEmoji: map['icon'] as String? ?? '💬',
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
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

    // Active Meet-up
    if (meetupsRes.isNotEmpty) {
      final m = meetupsRes.first as Map<String, dynamic>;
      final responses =
          (m['meet_up_responses'] as List<dynamic>? ?? const []);
      var going = 0;
      var maybe = 0;
      var cant = 0;
      String? myResp;
      for (final raw in responses) {
        final r = raw as Map<String, dynamic>;
        final resp = r['response'] as String? ?? '';
        if (resp == 'going') going++;
        if (resp == 'maybe') maybe++;
        if (resp == 'cant_make_it') cant++;
        if (r['user_id'] == userId) myResp = resp;
      }
      _activeMeetUp = MeetUpInvitation(
        id: m['id'] as String,
        activity: m['activity'] as String? ?? '',
        location: m['location'] as String? ?? '',
        scheduledTime: m['scheduled_time'] != null
            ? DateTime.parse(m['scheduled_time'] as String)
            : DateTime.now(),
        goingCount: going,
        maybeCount: maybe,
        cantMakeCount: cant,
        currentUserResponse: myResp,
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
      'parcel_availability',
      'parcel_claims',
      'maintenance_tasks',
      'chore_roulette_records',
      'lost_items',
      'found_items',
      'bills',
      'quick_snaps',
      'conversations',
      'notifications',
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
    const conversationScopedTables = [
      'conversation_reads',
      'messages',
      'meet_up_invitations',
      'meet_up_responses',
    ];
    for (final table in conversationScopedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: scheduleRefresh,
      );
    }
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
      buyerName: _currentUser.displayName,
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

    final updates = <String, dynamic>{
      'courier': courier ?? current.courier,
      'expected_arrival': (arrival ?? current.expectedArrival).toIso8601String(),
      'payment_type': nextPay == ParcelPaymentType.cod ? 'cod' : 'paid',
      'cod_amount': nextCod,
      'notes': notes ?? current.notes,
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
  void toggleParcelAvailability(String parcelId) {
    unawaited(_toggleParcelAvailabilityAsync(parcelId));
  }

  Future<void> _toggleParcelAvailabilityAsync(String parcelId) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household to update availability.');
      return;
    }

    final idx = _parcels.indexWhere((p) => p.id == parcelId);
    final myName = _currentUser.effectiveGreetingName;
    final currentlyAvailable = idx != -1 &&
        _parcels[idx].availableMemberNames.contains(myName);
    final nextAvailable = !currentlyAvailable;

    try {
      await client.from('parcel_availability').upsert(
        {
          'household_id': _currentHousehold.id,
          'parcel_id': parcelId,
          'user_id': _currentUser.id,
          'is_available': nextAvailable,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'parcel_id,user_id',
      );
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError('Could not update parcel availability.', error: e);
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

    try {
      var insertedClaim = true;
      try {
        await client.from('parcel_claims').insert({
          'household_id': _currentHousehold.id,
          'parcel_id': parcelId,
          'receiver_id': _currentUser.id,
          'amount_owed': parcel.paymentType == ParcelPaymentType.cod
              ? parcel.codAmount
              : null,
          'settled': parcel.paymentType == ParcelPaymentType.paid,
        });
      } on PostgrestException catch (e) {
        final isDuplicate =
            e.code == '23505' ||
            e.message.contains('uq_parcel_claims_parcel');
        if (!isDuplicate) rethrow;
        insertedClaim = false;
      }

      await client
          .from('parcels')
          .update({'status': 'received'})
          .eq('id', parcelId);

      if (insertedClaim) {
        await _awardPoints(
          userId: _currentUser.id,
          actionType: 'parcel_received',
          points: 5,
          referenceId: parcelId,
        );
        if (parcel.buyerId.isNotEmpty && parcel.buyerId != _currentUser.id) {
          await client.from('notifications').insert({
            'household_id': _currentHousehold.id,
            'user_id': parcel.buyerId,
            'type': 'parcel_received',
            'payload': {
              'parcel_id': parcelId,
              'courier': parcel.courier,
              'receiver_id': _currentUser.id,
              'receiver_name': _currentUser.displayName,
              'cod_amount': parcel.codAmount,
            },
          });
        }
      }

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
    await client
        .from('parcel_claims')
        .update({
          'settled': true,
          'settled_at': DateTime.now().toIso8601String(),
        })
        .eq('parcel_id', parcelId);
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
    String? assigneeName,
    String? description,
    DateTime? dueDate,
  }) {
    unawaited(
      _addTaskAsync(
        title: title,
        category: category,
        urgency: urgency,
        assigneeName: assigneeName,
        description: description,
        dueDate: dueDate,
      ),
    );
  }

  Future<void> _addTaskAsync({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? assigneeName,
    String? description,
    DateTime? dueDate,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before creating tasks.');
      return;
    }

    final taskId = _uuid.v4();
    final resolvedAssignee = assigneeName != null && assigneeName.trim().isNotEmpty
        ? _resolveMemberByKey(assigneeName)?.profile
        : null;

    final newTask = MaintenanceTask(
      id: taskId,
      householdId: _currentHousehold.id,
      title: title,
      description: description,
      category: category,
      urgency: urgency,
      status: TaskStatus.open,
      assigneeId: resolvedAssignee?.id,
      assigneeName: resolvedAssignee?.displayName,
      assigneeAvatar: resolvedAssignee?.avatarUrl,
      createdByName: _currentUser.displayName,
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
        'due_date': dueDate?.toIso8601String(),
        'assignee_id': resolvedAssignee?.id,
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
    final prev = List<MaintenanceTask>.from(_tasks);

    final now = DateTime.now();
    _tasks[idx] = task.copyWith(
      status: status,
      completedById: status == TaskStatus.done ? _currentUser.id : null,
      completedAt: status == TaskStatus.done ? now : null,
      clearCompleted: status != TaskStatus.done,
    );
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
            status == TaskStatus.done ? now.toIso8601String() : null,
      }).eq('id', taskId);

      if (status == TaskStatus.done) {
        final pts = task.category == TaskCategory.restock ? 2 : 5;
        await _awardPoints(
          userId: _currentUser.id,
          actionType: 'task_completed',
          points: pts,
          referenceId: taskId,
        );
      }
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _tasks = prev;
      _recordError('Could not update task.', error: e);
    }
  }

  @override
  Future<String?> recordRouletteSpin({
    String? taskId,
    required String taskTitle,
    required String selectedUserId,
  }) async {
    final client = _requireClient();
    final hid = _currentHousehold.id;
    final spunById = _currentUser.id;
    if (hid.isEmpty || spunById.isEmpty) {
      throw StateError('Join a household before spinning Task Roulette.');
    }

    final now = DateTime.now().toUtc();
    final windowStart = now.subtract(const Duration(hours: 24)).toIso8601String();
    final recent = await client
        .from('chore_roulette_records')
        .select('created_at')
        .eq('household_id', hid)
        .eq('spun_by_user_id', spunById)
        .gte('created_at', windowStart)
        .order('created_at', ascending: false)
        .limit(1);

    if (recent.isNotEmpty) {
      final raw = recent.first['created_at'] as String?;
      _lastRouletteSpinAt = raw != null ? DateTime.tryParse(raw) : now;
      _safeNotify();
      throw StateError('Daily spin cooldown active (1 spin per 24 hours).');
    }

    final spinId = _uuid.v4();
    final expiresAt = now.add(const Duration(hours: 2));
    await client.from('chore_roulette_records').insert({
      'id': spinId,
      'household_id': hid,
      'task_id': taskId,
      'selected_user_id': selectedUserId,
      'spun_by_user_id': spunById,
      'status': 'pending',
      'decision': null,
      'responded_at': null,
      'expires_at': expiresAt.toIso8601String(),
    });

    await client.from('notifications').insert({
      'household_id': hid,
      'user_id': selectedUserId,
      'type': 'roulette_chosen',
      'payload': {
        'spin_id': spinId,
        'task_id': taskId,
        'task_title': taskTitle,
        'spun_by_user_id': spunById,
        'spun_by_name': _currentUser.displayName,
        'expires_at': expiresAt.toIso8601String(),
      },
    });

    _lastRouletteSpinAt = now;
    _safeNotify();
    return spinId;
  }

  @override
  Future<void> respondToRouletteSpin({
    required String spinId,
    String? taskId,
    required bool accepted,
  }) async {
    final client = _requireClient();
    final record = await client
        .from('chore_roulette_records')
        .select()
        .eq('id', spinId)
        .maybeSingle();

    if (record == null) {
      throw StateError('Roulette spin record not found.');
    }
    if (record['status'] != 'pending') {
      throw StateError('This roulette spin has already been resolved.');
    }

    final rawExpiry = record['expires_at'] as String?;
    if (rawExpiry != null &&
        DateTime.now().toUtc().isAfter(DateTime.parse(rawExpiry).toUtc())) {
      await client
          .from('chore_roulette_records')
          .update({'status': 'expired'})
          .eq('id', spinId);
      throw StateError('This roulette spin has expired.');
    }

    final selectedUserId = record['selected_user_id'] as String?;
    final resolvedTaskId = taskId ?? record['task_id'] as String?;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (accepted) {
      await client
          .from('chore_roulette_records')
          .update({
            'decision': 'accepted',
            'status': 'accepted',
            'responded_at': nowIso,
          })
          .eq('id', spinId)
          .eq('status', 'pending');

      if (resolvedTaskId != null && selectedUserId != null) {
        await client
            .from('maintenance_tasks')
            .update({'assignee_id': selectedUserId})
            .eq('id', resolvedTaskId);
        await client
            .from('chore_roulette_records')
            .update({'status': 'expired'})
            .eq('task_id', resolvedTaskId)
            .eq('status', 'pending')
            .neq('id', spinId);
      }

      if (selectedUserId != null) {
        await _awardPoints(
          userId: selectedUserId,
          actionType: 'roulette_accepted',
          points: 2,
          referenceId: spinId,
        );
      }
    } else {
      await client
          .from('chore_roulette_records')
          .update({
            'decision': 'rejected',
            'status': 'rejected',
            'responded_at': nowIso,
          })
          .eq('id', spinId)
          .eq('status', 'pending');

      if (selectedUserId != null) {
        await _awardPoints(
          userId: selectedUserId,
          actionType: 'roulette_rejected',
          points: -3,
          referenceId: spinId,
        );
      }
    }

    await _fetchHouseholdData();
    _safeNotify();
  }

  // =========================================================================
  // LOST & FOUND (`lost_items`, `found_items`)
  // =========================================================================

  @override
  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? imageUrl,
    Uint8List? imageBytes,
  }) {
    unawaited(
      _postItemAsync(
        type: type,
        title: title,
        description: description,
        imageUrl: imageUrl,
        imageBytes: imageBytes,
      ),
    );
  }

  Future<void> _postItemAsync({
    required ItemType type,
    required String title,
    String? description,
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
          pathPrefix: 'lost_found/${_currentHousehold.id}',
          rawSource: resolvedImageUrl,
          bytes: imageBytes,
        );
      }

      final table = effectiveType == ItemType.lost ? 'lost_items' : 'found_items';
      final status = effectiveType == ItemType.lost ? 'open' : 'unclaimed';
      await client.from(table).insert({
        'id': itemId,
        'household_id': _currentHousehold.id,
        'title': title,
        'description': description,
        'image_url': resolvedImageUrl,
        'status': status,
        'reported_by': _currentUser.id,
      });

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError('Could not post item to Lost & Found.', error: e);
    }
  }

  @override
  void borrowItem(String itemId) {
    // Shared/borrowed items were retired; no-op kept only for interface parity.
  }

  @override
  void claimItem(String itemId) {
    unawaited(_claimItemAsync(itemId));
  }

  Future<void> _claimItemAsync(String itemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      _recordError('Sign in to claim or report found items.');
      return;
    }

    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final item = _items[idx];

    try {
      if (item.type == ItemType.lost) {
        final updated = await client
            .from('lost_items')
            .update({
              'status': 'found',
              'found_by_id': _currentUser.id,
            })
            .eq('id', itemId)
            .eq('status', 'open')
            .select()
            .maybeSingle();
        if (updated == null) {
          _recordError('This lost item has already been marked found.');
          return;
        }
      } else {
        if (item.status != ItemStatus.unclaimed) {
          _recordError('This found item has already been claimed.');
          return;
        }
        final updated = await client
            .from('found_items')
            .update({
              'status': 'claimed',
              'claimed_by_id': _currentUser.id,
            })
            .eq('id', itemId)
            .eq('status', 'unclaimed')
            .select()
            .maybeSingle();
        if (updated == null) {
          _recordError('This found item was already claimed by someone else.');
          return;
        }
      }

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError('Could not update item status.', error: e);
    }
  }

  @override
  void returnItem(String itemId) {
    unawaited(_returnItemAsync(itemId));
  }

  Future<void> _returnItemAsync(String itemId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      _recordError('Sign in to mark an item returned.');
      return;
    }

    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final item = _items[idx];

    try {
      if (item.type == ItemType.lost) {
        await client
            .from('lost_items')
            .update({'status': 'returned'})
            .eq('id', itemId);
        final awardee = item.foundById ?? _currentUser.id;
        await _awardPoints(
          userId: awardee,
          actionType: 'lost_item_returned',
          points: 3,
          referenceId: itemId,
        );
      } else {
        await client
            .from('found_items')
            .update({'status': 'returned'})
            .eq('id', itemId);
        final awardee = item.reportedBy.isNotEmpty
            ? item.reportedBy
            : _currentUser.id;
        await _awardPoints(
          userId: awardee,
          actionType: 'found_item_returned',
          points: 3,
          referenceId: itemId,
        );
      }

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError('Could not mark item returned.', error: e);
    }
  }

  // =========================================================================
  // BILLS & PAYMENTS
  // =========================================================================

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
  }) {
    unawaited(
      _addBillAsync(
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
      ),
    );
  }

  Future<void> _addBillAsync({
    required BillCategory category,
    String? customCategoryLabel,
    String? billName,
    double? amount,
    required DateTime deadline,
    String? notes,
    required bool reminderEnabled,
    required ReminderTiming reminderTiming,
    required BillRecipientType recipientType,
    required List<String> selectedRecipientNames,
    String? responsibleMember,
  }) async {
    final client = _client;
    if (client == null || _currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      _recordError('Join a household before creating a bill.');
      return;
    }

    final newBill = HouseholdBill(
      id: _uuid.v4(),
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

    final prev = List<HouseholdBill>.from(_bills);
    _bills = [newBill, ..._bills];
    _safeNotify();

    try {
      await client.from('bills').insert(newBill.toSupabaseJson());
    } catch (e) {
      _bills = prev;
      _recordError('Could not save bill.', error: e);
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
  }) {
    unawaited(
      _updateBillAsync(
        billId: billId,
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
      ),
    );
  }

  Future<void> _updateBillAsync({
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
    final client = _client;
    if (client == null) {
      _recordError('Supabase is not configured.');
      return;
    }
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final prev = List<HouseholdBill>.from(_bills);
    final updated = _bills[idx].copyWith(
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
    _bills[idx] = updated;
    _safeNotify();

    try {
      await client
          .from('bills')
          .update(updated.toSupabaseJson(includeId: false))
          .eq('id', billId);
    } catch (e) {
      _bills = prev;
      _recordError('Could not update bill.', error: e);
    }
  }

  @override
  void markBillPaid(String billId) {
    unawaited(_markBillPaidAsync(billId));
  }

  Future<void> _markBillPaidAsync(String billId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) {
      _recordError('Sign in to mark a bill as paid.');
      return;
    }
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final prev = List<HouseholdBill>.from(_bills);
    final now = DateTime.now();

    _bills[idx] = _bills[idx].copyWith(
      status: BillStatus.paid,
      paidAt: now,
      paidByName: _currentUser.displayName,
    );
    _safeNotify();

    try {
      await client.from('bills').update({
        'status': 'paid',
        'paid_at': now.toIso8601String(),
        'paid_by': _currentUser.id,
        'paid_by_name': _currentUser.displayName,
      }).eq('id', billId);

      await _awardPoints(
        userId: _currentUser.id,
        actionType: 'bill_paid',
        points: 5,
        referenceId: billId,
      );
      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _bills = prev;
      _recordError('Could not mark bill paid.', error: e);
    }
  }

  @override
  void reopenBill(String billId) {
    unawaited(_reopenBillAsync(billId));
  }

  Future<void> _reopenBillAsync(String billId) async {
    final client = _client;
    if (client == null) return;
    final idx = _bills.indexWhere((b) => b.id == billId);
    if (idx == -1) return;
    final prev = List<HouseholdBill>.from(_bills);
    _bills[idx] = _bills[idx].copyWith(status: BillStatus.unpaid);
    _safeNotify();

    try {
      await client.from('bills').update({
        'status': 'unpaid',
        'paid_at': null,
        'paid_by': null,
        'paid_by_name': null,
      }).eq('id', billId);
    } catch (e) {
      _bills = prev;
      _recordError('Could not reopen bill.', error: e);
    }
  }

  @override
  void deleteBill(String billId) {
    unawaited(_deleteBillAsync(billId));
  }

  Future<void> _deleteBillAsync(String billId) async {
    final client = _client;
    if (client == null) return;
    final prev = List<HouseholdBill>.from(_bills);
    _bills.removeWhere((b) => b.id == billId);
    _safeNotify();

    try {
      await client.from('bills').delete().eq('id', billId);
    } catch (e) {
      _bills = prev;
      _recordError('Could not delete bill.', error: e);
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
    QuickSnapRecipientType recipientType = QuickSnapRecipientType.everyone,
    List<String> recipientNames = const [],
  }) {
    unawaited(
      _sendQuickSnapAsync(
        imageUrl: imageUrl,
        imageBytes: imageBytes,
        caption: caption,
        recipientType: recipientType,
        recipientNames: recipientNames,
      ),
    );
  }

  Future<void> _sendQuickSnapAsync({
    required String imageUrl,
    Uint8List? imageBytes,
    String? caption,
    required QuickSnapRecipientType recipientType,
    required List<String> recipientNames,
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

      final newSnap = QuickSnap(
        id: snapId,
        householdId: _currentHousehold.id,
        senderId: _currentUser.id,
        senderName: _currentUser.effectiveGreetingName,
        senderAvatar: _currentUser.avatarUrl,
        imageUrl: uploadedUrl,
        caption: caption,
        recipientType: recipientType,
        recipientNames: recipientNames,
        createdAt: DateTime.now(),
      );

      await client.from('quick_snaps').insert(newSnap.toJson());

      if (recipientType == QuickSnapRecipientType.selectedHousemates &&
          recipientNames.isNotEmpty) {
        final recipientRows = <Map<String, dynamic>>[];
        for (final name in recipientNames) {
          final member = _resolveMemberByKey(name);
          if (member != null) {
            recipientRows.add({
              'snap_id': snapId,
              'user_id': member.profile.id,
            });
          }
        }
        if (recipientRows.isNotEmpty) {
          await client.from('quick_snap_recipients').upsert(
            recipientRows,
            onConflict: 'snap_id,user_id',
            ignoreDuplicates: true,
          );
        }
      }

      await _fetchHouseholdData();
      _safeNotify();
    } catch (e) {
      _recordError(
        'Could not upload and send CASnap.',
        onRetry: () => _sendQuickSnapAsync(
          imageUrl: imageUrl,
          imageBytes: imageBytes,
          caption: caption,
          recipientType: recipientType,
          recipientNames: recipientNames,
        ),
        error: e,
      );
    }
  }

  @override
  void reactToQuickSnap(String snapId, String emoji) {
    unawaited(_reactToQuickSnapAsync(snapId, emoji));
  }

  Future<void> _reactToQuickSnapAsync(String snapId, String emoji) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) return;

    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final updated = List<QuickSnapReaction>.from(_quickSnaps[idx].reactions)
        ..removeWhere((r) => r.userId == _currentUser.id)
        ..add(
          QuickSnapReaction(
            emoji: emoji,
            userId: _currentUser.id,
            userName: _currentUser.effectiveGreetingName,
            createdAt: DateTime.now(),
          ),
        );
      _quickSnaps[idx] = _quickSnaps[idx].copyWith(reactions: updated);
      _safeNotify();
    }

    try {
      await client.from('quick_snap_reactions').upsert(
        {
          'snap_id': snapId,
          'user_id': _currentUser.id,
          'user_name': _currentUser.effectiveGreetingName,
          'emoji': emoji,
        },
        onConflict: 'snap_id,user_id,emoji',
      );
    } catch (e) {
      _recordError('Could not add reaction.', error: e);
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
    final idx = _quickSnaps.indexWhere((s) => s.id == snapId);
    if (idx != -1) {
      final updated = List<QuickSnapComment>.from(_quickSnaps[idx].comments)
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
      _quickSnaps[idx] = _quickSnaps[idx].copyWith(comments: updated);
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
    final prev = List<QuickSnap>.from(_quickSnaps);
    _quickSnaps.removeWhere((s) => s.id == snapId);
    _safeNotify();

    try {
      await client.from('quick_snaps').delete().eq('id', snapId);
    } catch (e) {
      _quickSnaps = prev;
      _recordError('Could not delete CASnap.', error: e);
    }
  }

  // =========================================================================
  // CASAMA CONNECT (GROUP, SPACES, DIRECT, READS, MEET-UPS)
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
    _directUnreadCounts[member.profile.id] = 0;
    _safeNotify();
    final cid = _directConversationIdsByKey[member.profile.id];
    if (cid != null) {
      unawaited(_upsertConversationRead(cid));
    }
  }

  Future<void> _upsertConversationRead(String conversationId) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty) return;
    try {
      await client.from('conversation_reads').upsert(
        {
          'conversation_id': conversationId,
          'user_id': _currentUser.id,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'conversation_id,user_id',
      );
    } catch (e) {
      debugPrint('Supabase conversation_reads error: $e');
    }
  }

  @override
  void markAllNotificationsAsRead() {
    _notifications = _notifications
        .map(
          (n) => HouseholdNotificationItem(
            id: n.id,
            type: n.type,
            title: n.title,
            subtitle: n.subtitle,
            createdAt: n.createdAt,
            isRead: true,
            payload: n.payload,
          ),
        )
        .toList();
    _safeNotify();

    final client = _client;
    if (client != null && _currentUser.id.isNotEmpty && _currentHousehold.id.isNotEmpty) {
      unawaited(
        client
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
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
    final allNames = _members.map((m) => m.profile.displayName).toList();
    final newSpace = ChatSpace(
      id: spaceId,
      householdId: _currentHousehold.id,
      name: name,
      description: description,
      inviteCode: '',
      creatorId: _currentUser.id,
      creatorName: _currentUser.displayName,
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
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    unawaited(
      _sendGroupOrSpaceMessageAsync(
        conversationId: _groupConversationId,
        isGroup: true,
        content: content,
        mediaUrl: mediaUrl,
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
    String? inviteCode,
    String? inviteSpaceName,
  }) {
    unawaited(
      _sendGroupOrSpaceMessageAsync(
        conversationId: spaceId,
        isGroup: false,
        content: content,
        mediaUrl: mediaUrl,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
      ),
    );
  }

  Future<void> _sendGroupOrSpaceMessageAsync({
    required String? conversationId,
    required bool isGroup,
    required String content,
    String? mediaUrl,
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

    final messageId = _uuid.v4();
    final clientMessageId = _uuid.v4();
    try {
      var uploadedMedia = mediaUrl;
      if (uploadedMedia != null && _needsStorageUpload(uploadedMedia)) {
        uploadedMedia = await _uploadMediaToBucket(
          bucket: SupabaseConfig.casnapsBucket,
          pathPrefix: 'chat/${_currentHousehold.id}',
          rawSource: uploadedMedia,
        );
      }

      final msg = ChatMessage(
        id: messageId,
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        senderAvatar: _currentUser.avatarUrl,
        content: content,
        mediaUrl: uploadedMedia,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
        createdAt: DateTime.now(),
        isCurrentUser: true,
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

      await client.from('messages').upsert(
        {
          'id': messageId,
          'conversation_id': targetConvId,
          'sender_id': _currentUser.id,
          'content': content,
          'media_url': uploadedMedia,
          'invite_code': inviteCode,
          'invite_space_name': inviteSpaceName,
          'client_message_id': clientMessageId,
        },
        onConflict: 'conversation_id,client_message_id',
        ignoreDuplicates: true,
      );
      await _upsertConversationRead(targetConvId);
    } catch (e) {
      _recordError('Could not send message.', error: e);
    }
  }

  @override
  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
  }) {
    unawaited(
      _sendDirectMessageAsync(contactKey, content, mediaUrl: mediaUrl),
    );
  }

  Future<void> _sendDirectMessageAsync(
    String contactKey,
    String content, {
    String? mediaUrl,
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

    try {
      var convId = _directConversationIdsByKey[peerId];
      if (convId == null) {
        convId = await _findOrCreateDirectConversation(peerId);
        _directConversationIdsByKey[peerId] = convId;
      }

      var uploadedMedia = mediaUrl;
      if (uploadedMedia != null && _needsStorageUpload(uploadedMedia)) {
        uploadedMedia = await _uploadMediaToBucket(
          bucket: SupabaseConfig.casnapsBucket,
          pathPrefix: 'chat/${_currentHousehold.id}',
          rawSource: uploadedMedia,
        );
      }

      final messageId = _uuid.v4();
      final clientMessageId = _uuid.v4();
      final msg = ChatMessage(
        id: messageId,
        senderId: _currentUser.id,
        senderName: _currentUser.displayName,
        senderAvatar: _currentUser.avatarUrl,
        content: content,
        mediaUrl: uploadedMedia,
        inviteCode: inviteCode,
        inviteSpaceName: inviteSpaceName,
        createdAt: DateTime.now(),
        isCurrentUser: true,
      );

      final existing = List<ChatMessage>.from(_directMessages[peerId] ?? []);
      _directMessages[peerId] = [...existing, msg];
      _safeNotify();

      await client.from('messages').upsert(
        {
          'id': messageId,
          'conversation_id': convId,
          'sender_id': _currentUser.id,
          'content': content,
          'media_url': uploadedMedia,
          'invite_code': inviteCode,
          'invite_space_name': inviteSpaceName,
          'client_message_id': clientMessageId,
        },
        onConflict: 'conversation_id,client_message_id',
        ignoreDuplicates: true,
      );
      await _upsertConversationRead(convId);
    } catch (e) {
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
  Future<void> createMeetUp({
    required String activity,
    required String location,
    required DateTime scheduledTime,
    String? announcementText,
  }) async {
    final client = _requireClient();
    if (_currentHousehold.id.isEmpty || _currentUser.id.isEmpty) {
      throw StateError('Join a household before creating a meet-up.');
    }
    var groupId = _groupConversationId;
    if (groupId == null) {
      await _ensureGroupConversationExists(_currentHousehold.id, _currentUser.id);
      groupId = _groupConversationId;
    }
    if (groupId == null) return;

    final invId = _uuid.v4();
    await client.from('meet_up_invitations').insert({
      'id': invId,
      'conversation_id': groupId,
      'creator_id': _currentUser.id,
      'activity': activity,
      'location': location,
      'scheduled_time': scheduledTime.toUtc().toIso8601String(),
    });
    await client.from('meet_up_responses').upsert(
      {
        'invitation_id': invId,
        'user_id': _currentUser.id,
        'response': 'going',
      },
      onConflict: 'invitation_id,user_id',
    );

    if (announcementText != null && announcementText.trim().isNotEmpty) {
      sendChatMessage(announcementText.trim());
    }
    await _fetchHouseholdData();
    _safeNotify();
  }

  @override
  void respondMeetUp(String response) {
    unawaited(_respondMeetUpAsync(response));
  }

  Future<void> _respondMeetUpAsync(String response) async {
    final client = _client;
    if (client == null || _currentUser.id.isEmpty || _activeMeetUp.id.isEmpty) {
      return;
    }

    final prev = _activeMeetUp;
    var g = prev.goingCount;
    var m = prev.maybeCount;
    var c = prev.cantMakeCount;
    if (prev.currentUserResponse == 'going') g = max(0, g - 1);
    if (prev.currentUserResponse == 'maybe') m = max(0, m - 1);
    if (prev.currentUserResponse == 'cant_make_it') c = max(0, c - 1);
    if (response == 'going') g++;
    if (response == 'maybe') m++;
    if (response == 'cant_make_it') c++;

    _activeMeetUp = MeetUpInvitation(
      id: prev.id,
      activity: prev.activity,
      location: prev.location,
      scheduledTime: prev.scheduledTime,
      goingCount: g,
      maybeCount: m,
      cantMakeCount: c,
      currentUserResponse: response,
    );
    _safeNotify();

    try {
      await client.from('meet_up_responses').upsert(
        {
          'invitation_id': prev.id,
          'user_id': _currentUser.id,
          'response': response,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'invitation_id,user_id',
      );
    } catch (e) {
      _activeMeetUp = prev;
      _recordError('Could not update meet-up RSVP.', error: e);
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
    if (s.startsWith('http://') || s.startsWith('https://')) return false;
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

    final storagePath =
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
      case 'bill_paid':
        return 'Paid a shared bill';
      case 'lost_item_returned':
      case 'found_item_returned':
      case 'item_returned':
        return 'Returned a lost & found item';
      case 'roulette_accepted':
        return 'Accepted Task Roulette assignment';
      case 'roulette_rejected':
        return 'Rejected Task Roulette assignment';
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

  String _notificationTitle(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'parcel_received':
        return '${payload['receiver_name'] ?? 'A housemate'} received your ${payload['courier'] ?? 'parcel'}';
      case 'roulette_chosen':
        return 'Task Roulette picked you for "${payload['task_title'] ?? 'a task'}"';
      default:
        return 'Household update';
    }
  }

  String _notificationSubtitle(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'parcel_received':
        final cod = payload['cod_amount'];
        return cod != null ? 'COD ₱$cod • Tap to view Parcels' : 'Tap to view Parcels';
      case 'roulette_chosen':
        return 'Spun by ${payload['spun_by_name'] ?? 'a housemate'} • Respond in Tasks';
      default:
        return 'Tap to view';
    }
  }
}
