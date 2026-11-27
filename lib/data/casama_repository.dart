import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';

/// Abstract contract defining all Casama state and operations.
/// Implemented by [SupabaseRepository] (live cloud runtime)
/// and [MockRepository] (explicit test overrides).
abstract class CasamaRepository extends ChangeNotifier {
  // Authentication & Household
  bool get isAuthenticated;
  bool get hasActiveHousehold;
  UserProfile get currentUser;
  Household get currentHousehold;
  List<Household> get userHouseholds;
  int get kasamaPoints;
  String get effectiveGreetingName;

  // Data lists & counts
  List<MemberPresence> get members;
  List<ParcelItem> get parcels;
  List<LostFoundItem> get items;
  List<MaintenanceTask> get tasks;
  List<ChoreRouletteRecord> get rouletteRecords;
  ChoreRouletteRecord? rouletteRecordForTask(String taskId);
  List<ChatMessage> get groupMessages;
  List<ChatSpace> get chatSpaces;
  int get groupChatUnreadCount;
  int get unreadNotificationCount;
  int get totalUnreadChatCount;
  HousematesAgendaInvitation get activeHousematesAgenda;
  List<HousematesAgendaInvitation> get housematesAgendaInvitations;
  List<PointAuditEntry> get pointHistory;
  List<LeaderboardStanding> get leaderboardStandings;
  List<HouseholdNotificationItem> get notifications;
  NotificationPreferences get notificationPreferences;
  List<HouseholdInvitation> get invitations;
  List<QuickSnap> get quickSnaps;
  QuickSnap? get latestQuickSnap;
  int get quickSnapStreak;

  /// Consumes and clears the latest surfaced mutation/sync error, if any.
  RepositoryActionError? consumePendingError();

  // Chat queries
  List<ChatMessage> getDirectMessages(String contactKey);
  int getDirectUnreadCount(String contactKey);
  bool isHousemateAuthorized(String contactKey);
  List<UserProfile> searchUsers(String query);

  // Auth & Profile operations
  Future<void> restoreSession();
  Future<void> signInWithPassword({
    required String email,
    required String password,
  });
  Future<bool> signUpWithPassword({
    required String email,
    required String password,
  });
  Future<void> resendSignupVerificationEmail(String email);
  Future<void> signInWithDemoAccount();
  Future<void> signOut();

  void login({String? email, String? password});
  void register({required String email, required String password});
  void logout();
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
  });
  void updateNotificationPreferences({
    bool? householdUpdates,
    bool? parcelNotifications,
    bool? taskReminders,
    bool? chatNotifications,
  });
  void recordTermsConsent();
  void completeOnboardingTutorial();

  // Households & Setup
  Future<Household> createHousehold({required String name});
  Future<Household> joinHouseholdByCode(String inviteCode);
  Future<void> switchHousehold(String householdId);
  Future<void> refreshUserHouseholds();

  // Presence
  void updatePresence({required bool isHome, String? note});

  // Parcels & Deliveries
  void receiveParcel(String parcelId);
  void addParcel({
    required String courier,
    required DateTime arrival,
    required ParcelPaymentType paymentType,
    double? codAmount,
    String? notes,
  });
  Future<void> updateParcel({
    required String parcelId,
    String? courier,
    DateTime? arrival,
    ParcelPaymentType? paymentType,
    double? codAmount,
    String? notes,
    ParcelStatus? status,
  });
  Future<void> cancelParcel(String parcelId);
  Future<void> settleParcelClaim(String parcelId);
  void toggleParcelAvailability(String parcelId);

  // Maintenance & Tasks
  void completeTask(String taskId);
  Future<void> updateTaskStatus(String taskId, TaskStatus status);
  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? description,
    DateTime? dueDate,
  });

  // Task Roulette
  Future<ChoreRouletteRecord> spinTaskRoulette(
    String taskId,
    String selectedUserId,
  );

  // Lost & Found
  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? location,
    String? imageUrl,
    Uint8List? imageBytes,
  });
  Future<String?> submitLostItemFind({
    required LostFoundItem lostItem,
    String? foundLocation,
    String? description,
    String? imageUrl,
    Uint8List? imageBytes,
    XFile? imageFile,
  });
  Future<String?> acceptLostItemFind(String foundItemId);
  Future<String?> rejectLostItemFind(String foundItemId);
  Future<String?> resolveOwnLostItem(String lostItemId);
  Future<String?> claimStandaloneFoundItem(String foundItemId);

  // Chat & Messaging
  void markGroupChatAsRead();
  void markSpaceChatAsRead(String spaceId);
  void markDirectChatAsRead(String contactKey);
  void markNotificationAsRead(String notificationId);
  void markAllNotificationsAsRead();
  void addMemberToSpace(String spaceId, String memberName);
  ChatSpace createChatSpace({
    required String name,
    required String description,
    String iconEmoji = '💬',
    required List<String> initialMembers,
  });
  ChatSpace? joinChatSpaceByCode(String code);
  void shareInviteCodeToGroupChat({
    required String code,
    required String title,
  });
  void shareInviteCodeToDirectChat({
    required String contactKey,
    required String code,
    required String title,
  });
  void sendChatMessage(
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  });
  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
  });
  void sendSpaceMessage(
    String spaceId,
    String content, {
    String? mediaUrl,
    XFile? attachmentFile,
    String? clientMessageId,
    String? inviteCode,
    String? inviteSpaceName,
  });
  void retryGroupMessage(String messageId);
  void retrySpaceMessage(String spaceId, String messageId);
  void retryDirectMessage(String contactKey, String messageId);
  Future<void> createHousematesAgendaInvitation({
    required String activity,
    required String location,
    required DateTime scheduledTime,
    String? announcementText,
  });
  void respondToHousematesAgendaInvitation(
    String response, {
    String? invitationId,
  });
  Future<void> updateHousematesAgendaStatus(String invitationId, String status);
  Future<void> deleteHousematesAgendaInvitation(String invitationId);

  // Household Invitations
  bool sendInvitation({
    required String inviteeEmailOrHandle,
    String? inviteeName,
  });
  bool acceptInvitation(String invitationId);
  bool declineInvitation(String invitationId);
  void resetMembersForNewUserTest();

  // QuickSnap Locket
  void sendQuickSnap({
    required String imageUrl,
    Uint8List? imageBytes,
    String? caption,
  });
  void queueQuickSnapReaction(String snapId, String emoji);
  Future<void> flushPendingSnapReactions();
  void reactToQuickSnap(String snapId, String emoji);
  void commentOnQuickSnap(String snapId, String text);
  void deleteQuickSnap(String snapId);
}

extension CasamaRepositoryNameX on CasamaRepository {
  /// Resolves a housemate's live canonical UI name (`nickname` -> `fullName`
  /// -> `displayName`) by [userId] from [currentUser] and active [members].
  /// Falls back to [fallback] (or `'Housemate'`) only if not found.
  String resolveHousemateName(
    String? userId, {
    String? fallback,
    bool useYouForCurrentUser = false,
  }) {
    final cleanId = userId?.trim() ?? '';
    if (cleanId.isNotEmpty) {
      if (cleanId == currentUser.id) {
        if (useYouForCurrentUser) return 'You';
        final me = currentUser.preferredName;
        if (me != 'You') return me;
      }
      for (final member in members) {
        if (member.profile.id == cleanId) {
          final name = member.profile.preferredName;
          if (name != 'You') return name;
        }
      }
    }
    final fb = fallback?.trim();
    if (fb != null && fb.isNotEmpty && fb != 'You') {
      return fb;
    }
    return 'Housemate';
  }
}
