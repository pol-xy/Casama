import 'package:flutter/foundation.dart';

import 'models.dart';

/// Abstract contract defining all Casama state and operations.
/// Implemented by [MockRepository] (for tests & offline demo)
/// and [SupabaseRepository] (for live cloud synchronization).
abstract class CasamaRepository extends ChangeNotifier {
  // Authentication & Household
  bool get isAuthenticated;
  UserProfile get currentUser;
  Household get currentHousehold;
  int get kasamaPoints;
  String get effectiveGreetingName;

  // Data lists & counts
  List<MemberPresence> get members;
  List<ParcelItem> get parcels;
  List<LostFoundItem> get items;
  List<MaintenanceTask> get tasks;
  List<HouseholdBill> get bills;
  List<ChatMessage> get groupMessages;
  List<ChatSpace> get chatSpaces;
  int get groupChatUnreadCount;
  int get unreadNotificationCount;
  int get totalUnreadChatCount;
  MeetUpInvitation get activeMeetUp;
  List<PointAuditEntry> get pointHistory;
  NotificationPreferences get notificationPreferences;
  List<HouseholdInvitation> get invitations;
  List<QuickSnap> get quickSnaps;
  QuickSnap? get latestQuickSnap;
  int get quickSnapStreak;

  // Chat queries
  List<ChatMessage> getDirectMessages(String contactKey);
  bool isHousemateAuthorized(String contactKey);
  List<UserProfile> searchUsers(String query);

  // Auth & Profile operations
  void login({String? email, String? password});
  void register({required String email, required String password});
  void logout();
  void updateProfile({
    String? displayName,
    String? handle,
    String? fullName,
    String? nickname,
    int? age,
    String? avatarUrl,
    bool clearAvatar = false,
    bool clearNickname = false,
    bool clearAge = false,
  });
  void updateNotificationPreferences({
    bool? householdUpdates,
    bool? parcelNotifications,
    bool? taskReminders,
    bool? chatNotifications,
  });
  void recordTermsConsent();
  void completeOnboardingTutorial();

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
  void toggleParcelAvailability(String parcelId);

  // Maintenance & Tasks
  void completeTask(String taskId);
  void addTask({
    required String title,
    required TaskCategory category,
    required TaskUrgency urgency,
    String? assigneeName,
  });

  // Lost & Found
  void postItem({
    required ItemType type,
    required String title,
    String? description,
    String? imageUrl,
  });
  void borrowItem(String itemId);
  void claimItem(String itemId);
  void returnItem(String itemId);

  // Chat & Messaging
  void markGroupChatAsRead();
  void markSpaceChatAsRead(String spaceId);
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
    String? inviteCode,
    String? inviteSpaceName,
  });
  void sendDirectMessage(
    String contactKey,
    String content, {
    String? mediaUrl,
  });
  void sendSpaceMessage(
    String spaceId,
    String content, {
    String? mediaUrl,
    String? inviteCode,
    String? inviteSpaceName,
  });
  void respondMeetUp(String response);

  // Household Invitations
  bool sendInvitation({
    required String inviteeEmailOrHandle,
    String? inviteeName,
  });
  bool acceptInvitation(String invitationId);
  bool declineInvitation(String invitationId);
  void resetMembersForNewUserTest();

  // Bills & Payments
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
  });
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
  });
  void markBillPaid(String billId);
  void reopenBill(String billId);
  void deleteBill(String billId);

  // QuickSnap Locket
  void sendQuickSnap({
    required String imageUrl,
    Uint8List? imageBytes,
    String? caption,
    QuickSnapRecipientType recipientType = QuickSnapRecipientType.everyone,
    List<String> recipientNames = const [],
  });
  void reactToQuickSnap(String snapId, String emoji);
  void commentOnQuickSnap(String snapId, String text);
  void deleteQuickSnap(String snapId);
}
