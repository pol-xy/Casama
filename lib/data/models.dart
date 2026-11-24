/// Casama Core Data Models
library;

class UserProfile {
  final String id;
  final String displayName;
  final String handle;
  final String? fullName;
  final String? nickname;
  final int? age;
  final String? avatarUrl;
  final bool hasConsentedTerms;
  final bool hasCompletedOnboarding;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    this.fullName,
    this.nickname,
    this.age,
    this.avatarUrl,
    this.hasConsentedTerms = false,
    this.hasCompletedOnboarding = false,
  });

  /// Sensible fallback for user greeting throughout the app (uses nickname if available)
  String get effectiveGreetingName {
    if (nickname != null && nickname!.trim().isNotEmpty) {
      return nickname!.trim();
    }
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim().split(' ').first;
    }
    if (displayName.trim().isNotEmpty) {
      return displayName.trim().split(' ').first;
    }
    return 'Kasama';
  }

  /// Default avatar fallback when none provided
  String get effectiveAvatarUrl {
    return avatarUrl ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=200&q=80';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String? ?? 'Housemate',
      handle: json['handle'] as String? ?? '@member',
      fullName: json['full_name'] as String?,
      nickname: json['nickname'] as String?,
      age: json['age'] as int?,
      avatarUrl: json['avatar_url'] as String?,
      hasConsentedTerms: json['has_consented_terms'] as bool? ?? false,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'display_name': displayName,
    'handle': handle,
    'full_name': fullName,
    'nickname': nickname,
    'age': age,
    'avatar_url': avatarUrl,
    'has_consented_terms': hasConsentedTerms,
    'has_completed_onboarding': hasCompletedOnboarding,
  };
}

class Household {
  final String id;
  final String name;
  final String inviteCode;
  final String? createdBy;

  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.createdBy,
  });

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'invite_code': inviteCode,
    'created_by': createdBy,
  };
}

enum InvitationStatus { pending, accepted, declined }

class HouseholdInvitation {
  final String id;
  final String householdId;
  final String householdName;
  final String inviterName;
  final String inviteeEmailOrHandle;
  final String? inviteeName;
  final InvitationStatus status;
  final DateTime createdAt;

  const HouseholdInvitation({
    required this.id,
    required this.householdId,
    required this.householdName,
    required this.inviterName,
    required this.inviteeEmailOrHandle,
    this.inviteeName,
    this.status = InvitationStatus.pending,
    required this.createdAt,
  });
}

class MemberPresence {
  final UserProfile profile;
  final bool isHome;
  final String? note;
  final DateTime updatedAt;

  const MemberPresence({
    required this.profile,
    required this.isHome,
    this.note,
    required this.updatedAt,
  });
}

enum ParcelPaymentType { paid, cod }

enum ParcelStatus { expected, arrived, received, cancelled }

extension ParcelStatusX on ParcelStatus {
  String get label {
    switch (this) {
      case ParcelStatus.expected:
        return 'Expected';
      case ParcelStatus.arrived:
        return 'Arrived';
      case ParcelStatus.received:
        return 'Received';
      case ParcelStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class ParcelItem {
  final String id;
  final String householdId;
  final String buyerId;
  final String buyerName;
  final String courier;
  final DateTime expectedArrival;
  final ParcelPaymentType paymentType;
  final double? codAmount;
  final String currency;
  final ParcelStatus status;
  final String? notes;
  final List<String> availableMemberNames;
  final bool isAllUnavailable;

  const ParcelItem({
    required this.id,
    required this.householdId,
    required this.buyerId,
    required this.buyerName,
    required this.courier,
    required this.expectedArrival,
    required this.paymentType,
    this.codAmount,
    this.currency = 'PHP',
    required this.status,
    this.notes,
    this.availableMemberNames = const [],
    this.isAllUnavailable = false,
  });

  factory ParcelItem.fromJson(Map<String, dynamic> json) {
    ParcelStatus parseStatus(String? st) {
      switch (st?.toLowerCase()) {
        case 'arrived':
          return ParcelStatus.arrived;
        case 'received':
          return ParcelStatus.received;
        case 'cancelled':
          return ParcelStatus.cancelled;
        default:
          return ParcelStatus.expected;
      }
    }

    return ParcelItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      buyerId: json['buyer_id'] as String? ?? '',
      buyerName: json['buyer_name'] as String? ?? 'Housemate',
      courier: json['courier'] as String? ?? 'Courier',
      expectedArrival: json['expected_arrival'] != null
          ? DateTime.parse(json['expected_arrival'] as String)
          : DateTime.now(),
      paymentType: (json['payment_type'] as String?) == 'cod'
          ? ParcelPaymentType.cod
          : ParcelPaymentType.paid,
      codAmount: (json['cod_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'PHP',
      status: parseStatus(json['status'] as String?),
      notes: json['notes'] as String?,
      availableMemberNames: (json['available_members'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAllUnavailable: json['is_all_unavailable'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'buyer_id': buyerId,
    'courier': courier,
    'expected_arrival': expectedArrival.toIso8601String(),
    'payment_type': paymentType == ParcelPaymentType.cod ? 'cod' : 'paid',
    'cod_amount': codAmount,
    'currency': currency,
    'status': status.name,
    'notes': notes,
  };
}

enum ItemType { lost, found, shared }

enum ItemStatus { open, unclaimed, claimed, returned }

class LostFoundItem {
  final String id;
  final String householdId;
  final ItemType type;
  final String title;
  final String? description;
  final String? imageUrl;
  final ItemStatus status;
  final String reportedBy;
  final String reportedByName;
  final DateTime createdAt;

  const LostFoundItem({
    required this.id,
    required this.householdId,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    required this.status,
    required this.reportedBy,
    required this.reportedByName,
    required this.createdAt,
  });

  factory LostFoundItem.fromJson(Map<String, dynamic> json) {
    ItemType parseType(String? t) {
      switch (t?.toLowerCase()) {
        case 'found':
          return ItemType.found;
        case 'shared':
          return ItemType.shared;
        default:
          return ItemType.lost;
      }
    }

    ItemStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'unclaimed':
          return ItemStatus.unclaimed;
        case 'claimed':
          return ItemStatus.claimed;
        case 'returned':
          return ItemStatus.returned;
        default:
          return ItemStatus.open;
      }
    }

    return LostFoundItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      type: parseType(json['type'] as String?),
      title: json['title'] as String? ?? 'Untitled Item',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      status: parseStatus(json['status'] as String?),
      reportedBy: json['reported_by'] as String? ?? '',
      reportedByName: json['reported_by_name'] as String? ?? 'Housemate',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'type': type.name,
    'title': title,
    'description': description,
    'image_url': imageUrl,
    'status': status.name,
    'reported_by': reportedBy,
    'created_at': createdAt.toIso8601String(),
  };
}

enum TaskCategory { diy, landlord, restock }

enum TaskUrgency { low, medium, urgent }

enum TaskStatus { open, inProgress, done }

extension TaskUrgencyX on TaskUrgency {
  String get label {
    switch (this) {
      case TaskUrgency.urgent:
        return 'Urgent';
      case TaskUrgency.medium:
        return 'Medium';
      case TaskUrgency.low:
        return 'Low';
    }
  }
}

extension TaskStatusX on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.open:
        return 'Open';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.done:
        return 'Done';
    }
  }
}

class MaintenanceTask {
  final String id;
  final String householdId;
  final String title;
  final TaskCategory category;
  final TaskUrgency urgency;
  final TaskStatus status;
  final String? assigneeName;
  final String? assigneeAvatar;
  final String createdByName;
  final DateTime createdAt;
  final DateTime? dueDate;

  const MaintenanceTask({
    required this.id,
    required this.householdId,
    required this.title,
    required this.category,
    required this.urgency,
    required this.status,
    this.assigneeName,
    this.assigneeAvatar,
    required this.createdByName,
    required this.createdAt,
    this.dueDate,
  });

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    TaskCategory parseCat(String? c) {
      switch (c?.toLowerCase()) {
        case 'landlord':
          return TaskCategory.landlord;
        case 'restock':
          return TaskCategory.restock;
        default:
          return TaskCategory.diy;
      }
    }

    TaskUrgency parseUrg(String? u) {
      switch (u?.toLowerCase()) {
        case 'urgent':
          return TaskUrgency.urgent;
        case 'low':
          return TaskUrgency.low;
        default:
          return TaskUrgency.medium;
      }
    }

    TaskStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'in_progress':
        case 'inprogress':
          return TaskStatus.inProgress;
        case 'done':
          return TaskStatus.done;
        default:
          return TaskStatus.open;
      }
    }

    return MaintenanceTask(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Task',
      category: parseCat(json['category'] as String?),
      urgency: parseUrg(json['urgency'] as String?),
      status: parseStatus(json['status'] as String?),
      assigneeName: json['assignee_name'] as String?,
      assigneeAvatar: json['assignee_avatar'] as String?,
      createdByName: json['created_by_name'] as String? ?? 'Housemate',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'title': title,
    'category': category.name,
    'urgency': urgency.name,
    'status': status == TaskStatus.inProgress ? 'in_progress' : status.name,
    'created_at': createdAt.toIso8601String(),
    'due_date': dueDate?.toIso8601String(),
  };
}

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String? mediaUrl;
  final String? inviteCode;
  final String? inviteSpaceName;
  final DateTime createdAt;
  final bool isCurrentUser;
  final bool isRead;
  final MeetUpInvitation? meetUpInvitation;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.mediaUrl,
    this.inviteCode,
    this.inviteSpaceName,
    required this.createdAt,
    required this.isCurrentUser,
    this.isRead = true,
    this.meetUpInvitation,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Housemate',
      senderAvatar: json['sender_avatar'] as String?,
      content: json['content'] as String? ?? '',
      mediaUrl: json['media_url'] as String?,
      inviteCode: json['invite_code'] as String?,
      inviteSpaceName: json['invite_space_name'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isCurrentUser: currentUserId != null && json['sender_id'] == currentUserId,
      isRead: json['is_read'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'content': content,
    'media_url': mediaUrl,
    'invite_code': inviteCode,
    'invite_space_name': inviteSpaceName,
    'created_at': createdAt.toIso8601String(),
  };
}

class ChatSpace {
  final String id;
  final String householdId;
  final String name;
  final String description;
  final String inviteCode;
  final String creatorId;
  final String creatorName;
  final List<String> memberNames;
  final String iconEmoji;
  final DateTime createdAt;
  final List<ChatMessage> messages;
  final int unreadCount;

  const ChatSpace({
    required this.id,
    required this.householdId,
    required this.name,
    required this.description,
    required this.inviteCode,
    required this.creatorId,
    required this.creatorName,
    required this.memberNames,
    this.iconEmoji = '💬',
    required this.createdAt,
    this.messages = const [],
    this.unreadCount = 0,
  });

  ChatSpace copyWith({
    String? name,
    String? description,
    List<String>? memberNames,
    List<ChatMessage>? messages,
    int? unreadCount,
  }) {
    return ChatSpace(
      id: id,
      householdId: householdId,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteCode: inviteCode,
      creatorId: creatorId,
      creatorName: creatorName,
      memberNames: memberNames ?? this.memberNames,
      iconEmoji: iconEmoji,
      createdAt: createdAt,
      messages: messages ?? this.messages,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class MeetUpInvitation {
  final String id;
  final String activity;
  final String location;
  final DateTime scheduledTime;
  final int goingCount;
  final int maybeCount;
  final int cantMakeCount;
  final String? currentUserResponse; // 'going', 'maybe', 'cant_make_it'

  const MeetUpInvitation({
    required this.id,
    required this.activity,
    required this.location,
    required this.scheduledTime,
    this.goingCount = 0,
    this.maybeCount = 0,
    this.cantMakeCount = 0,
    this.currentUserResponse,
  });
}

class PointAuditEntry {
  final String id;
  final String title;
  final int points;
  final DateTime timestamp;
  final String category; // 'parcel', 'task', 'lost_found', 'bonus'

  const PointAuditEntry({
    required this.id,
    required this.title,
    required this.points,
    required this.timestamp,
    required this.category,
  });
}

// ==========================================
// BILLS & PAYMENTS MODELS
// ==========================================

enum BillCategory {
  electricity,
  water,
  internet,
  appliance,
  rent,
  associationDues,
  gas,
  maintenanceFee,
  other,
}

extension BillCategoryX on BillCategory {
  String get label {
    switch (this) {
      case BillCategory.electricity:
        return 'Electricity';
      case BillCategory.water:
        return 'Water';
      case BillCategory.internet:
        return 'Internet';
      case BillCategory.appliance:
        return 'Appliance';
      case BillCategory.rent:
        return 'Rent';
      case BillCategory.associationDues:
        return 'Association Dues';
      case BillCategory.gas:
        return 'Gas';
      case BillCategory.maintenanceFee:
        return 'Maintenance Fee';
      case BillCategory.other:
        return 'Other';
    }
  }

  String get emoji {
    switch (this) {
      case BillCategory.electricity:
        return '⚡';
      case BillCategory.water:
        return '💧';
      case BillCategory.internet:
        return '🌐';
      case BillCategory.appliance:
        return '🖥';
      case BillCategory.rent:
        return '🏠';
      case BillCategory.associationDues:
        return '🏢';
      case BillCategory.gas:
        return '🔥';
      case BillCategory.maintenanceFee:
        return '🔧';
      case BillCategory.other:
        return '📋';
    }
  }
}

enum BillStatus { unpaid, paid, overdue }

extension BillStatusX on BillStatus {
  String get label {
    switch (this) {
      case BillStatus.unpaid:
        return 'Unpaid';
      case BillStatus.paid:
        return 'Paid';
      case BillStatus.overdue:
        return 'Overdue';
    }
  }
}

enum ReminderTiming {
  onDueDate,
  oneDayBefore,
  twoDaysBefore,
  threeDaysBefore,
  oneWeekBefore,
}

extension ReminderTimingX on ReminderTiming {
  String get label {
    switch (this) {
      case ReminderTiming.onDueDate:
        return 'On the due date';
      case ReminderTiming.oneDayBefore:
        return '1 day before';
      case ReminderTiming.twoDaysBefore:
        return '2 days before';
      case ReminderTiming.threeDaysBefore:
        return '3 days before';
      case ReminderTiming.oneWeekBefore:
        return '1 week before';
    }
  }

  int get daysBeforeDue {
    switch (this) {
      case ReminderTiming.onDueDate:
        return 0;
      case ReminderTiming.oneDayBefore:
        return 1;
      case ReminderTiming.twoDaysBefore:
        return 2;
      case ReminderTiming.threeDaysBefore:
        return 3;
      case ReminderTiming.oneWeekBefore:
        return 7;
    }
  }
}

enum BillRecipientType { onlyMe, allMembers, selectedMembers }

extension BillRecipientTypeX on BillRecipientType {
  String get label {
    switch (this) {
      case BillRecipientType.onlyMe:
        return 'Only Me';
      case BillRecipientType.allMembers:
        return 'All Household Members';
      case BillRecipientType.selectedMembers:
        return 'Selected Members';
    }
  }
}

class HouseholdBill {
  final String id;
  final String householdId;
  final String creatorId;
  final String creatorName;
  final BillCategory category;
  final String? customCategoryLabel; // set when category == other
  final String? billName;
  final double? amount;
  final DateTime deadline;
  final String? notes;
  final BillStatus status;
  final bool reminderEnabled;
  final ReminderTiming reminderTiming;
  final BillRecipientType recipientType;
  final List<String> selectedRecipientNames;
  final String? responsibleMember; // who is responsible for paying
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? paidByName;

  const HouseholdBill({
    required this.id,
    required this.householdId,
    required this.creatorId,
    required this.creatorName,
    required this.category,
    this.customCategoryLabel,
    this.billName,
    this.amount,
    required this.deadline,
    this.notes,
    this.status = BillStatus.unpaid,
    this.reminderEnabled = true,
    this.reminderTiming = ReminderTiming.oneDayBefore,
    this.recipientType = BillRecipientType.allMembers,
    this.selectedRecipientNames = const [],
    this.responsibleMember,
    required this.createdAt,
    this.paidAt,
    this.paidByName,
  });

  String get effectiveCategoryLabel {
    if (category == BillCategory.other &&
        customCategoryLabel != null &&
        customCategoryLabel!.trim().isNotEmpty) {
      return customCategoryLabel!.trim();
    }
    return category.label;
  }

  String get effectiveBillName {
    if (billName != null && billName!.trim().isNotEmpty) {
      return billName!.trim();
    }
    return effectiveCategoryLabel;
  }

  /// Recompute status based on current time (overdue if past deadline and not paid)
  BillStatus get effectiveStatus {
    if (status == BillStatus.paid) return BillStatus.paid;
    final now = DateTime.now();
    final deadlineDate = DateTime(deadline.year, deadline.month, deadline.day);
    final today = DateTime(now.year, now.month, now.day);
    if (deadlineDate.isBefore(today)) return BillStatus.overdue;
    return BillStatus.unpaid;
  }

  factory HouseholdBill.fromJson(Map<String, dynamic> json) {
    BillCategory parseCategory(String? cat) {
      if (cat == null) return BillCategory.other;
      switch (cat.toLowerCase()) {
        case 'electricity':
          return BillCategory.electricity;
        case 'water':
          return BillCategory.water;
        case 'internet':
          return BillCategory.internet;
        case 'appliance':
          return BillCategory.appliance;
        case 'rent':
          return BillCategory.rent;
        case 'association_dues':
        case 'associationdues':
          return BillCategory.associationDues;
        case 'gas':
          return BillCategory.gas;
        case 'maintenance_fee':
        case 'maintenancefee':
          return BillCategory.maintenanceFee;
        default:
          return BillCategory.other;
      }
    }

    BillStatus parseStatus(String? st) {
      switch (st?.toLowerCase()) {
        case 'paid':
          return BillStatus.paid;
        case 'overdue':
          return BillStatus.overdue;
        default:
          return BillStatus.unpaid;
      }
    }

    ReminderTiming parseReminder(String? rem) {
      switch (rem) {
        case 'on_due_date':
          return ReminderTiming.onDueDate;
        case '1_day_before':
          return ReminderTiming.oneDayBefore;
        case '2_days_before':
          return ReminderTiming.twoDaysBefore;
        case '3_days_before':
          return ReminderTiming.threeDaysBefore;
        case '1_week_before':
          return ReminderTiming.oneWeekBefore;
        default:
          return ReminderTiming.oneDayBefore;
      }
    }

    BillRecipientType parseRecipient(String? rec) {
      switch (rec) {
        case 'only_me':
          return BillRecipientType.onlyMe;
        case 'selected_members':
          return BillRecipientType.selectedMembers;
        default:
          return BillRecipientType.allMembers;
      }
    }

    return HouseholdBill(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      creatorId: json['created_by'] as String? ?? '',
      creatorName: json['creator_name'] as String? ?? 'Housemate',
      category: parseCategory(json['category'] as String?),
      customCategoryLabel: json['custom_category'] as String?,
      billName: json['name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : DateTime.now(),
      notes: json['notes'] as String?,
      status: parseStatus(json['status'] as String?),
      reminderEnabled: json['has_reminder'] as bool? ?? true,
      reminderTiming: parseReminder(json['reminder_timing'] as String?),
      recipientType: parseRecipient(json['reminder_recipients'] as String?),
      responsibleMember: json['responsible_member_name'] as String? ??
          json['responsible_member'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      paidByName: json['paid_by_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    String categoryString() {
      switch (category) {
        case BillCategory.electricity:
          return 'electricity';
        case BillCategory.water:
          return 'water';
        case BillCategory.internet:
          return 'internet';
        case BillCategory.appliance:
          return 'appliance';
        case BillCategory.rent:
          return 'rent';
        case BillCategory.associationDues:
          return 'association_dues';
        case BillCategory.gas:
          return 'gas';
        case BillCategory.maintenanceFee:
          return 'maintenance_fee';
        case BillCategory.other:
          return 'other';
      }
    }

    String statusString() {
      switch (status) {
        case BillStatus.paid:
          return 'paid';
        case BillStatus.overdue:
          return 'overdue';
        case BillStatus.unpaid:
          return 'unpaid';
      }
    }

    String reminderString() {
      switch (reminderTiming) {
        case ReminderTiming.onDueDate:
          return 'on_due_date';
        case ReminderTiming.oneDayBefore:
          return '1_day_before';
        case ReminderTiming.twoDaysBefore:
          return '2_days_before';
        case ReminderTiming.threeDaysBefore:
          return '3_days_before';
        case ReminderTiming.oneWeekBefore:
          return '1_week_before';
      }
    }

    String recipientString() {
      switch (recipientType) {
        case BillRecipientType.onlyMe:
          return 'only_me';
        case BillRecipientType.allMembers:
          return 'all_members';
        case BillRecipientType.selectedMembers:
          return 'selected_members';
      }
    }

    return {
      'id': id,
      'household_id': householdId,
      'name': billName ?? effectiveCategoryLabel,
      'category': categoryString(),
      'custom_category': customCategoryLabel,
      'amount': amount ?? 0.0,
      'currency': 'PHP',
      'deadline': deadline.toIso8601String().split('T').first,
      'status': statusString(),
      'has_reminder': reminderEnabled,
      'reminder_timing': reminderString(),
      'reminder_recipients': recipientString(),
      'notes': notes,
      'created_by': creatorId,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
    };
  }

  HouseholdBill copyWith({
    String? billName,
    double? amount,
    DateTime? deadline,
    String? notes,
    BillStatus? status,
    bool? reminderEnabled,
    ReminderTiming? reminderTiming,
    BillRecipientType? recipientType,
    List<String>? selectedRecipientNames,
    String? responsibleMember,
    String? paidByName,
    DateTime? paidAt,
    String? customCategoryLabel,
    BillCategory? category,
  }) {
    return HouseholdBill(
      id: id,
      householdId: householdId,
      creatorId: creatorId,
      creatorName: creatorName,
      category: category ?? this.category,
      customCategoryLabel: customCategoryLabel ?? this.customCategoryLabel,
      billName: billName ?? this.billName,
      amount: amount ?? this.amount,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTiming: reminderTiming ?? this.reminderTiming,
      recipientType: recipientType ?? this.recipientType,
      selectedRecipientNames:
          selectedRecipientNames ?? this.selectedRecipientNames,
      responsibleMember: responsibleMember ?? this.responsibleMember,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      paidByName: paidByName ?? this.paidByName,
    );
  }
}

// ==========================================
// QUICKSNAP (LOCKET-STYLE) MODELS
// ==========================================

enum QuickSnapRecipientType { everyone, selectedHousemates }

class QuickSnapReaction {
  final String emoji;
  final String userId;
  final String userName;
  final DateTime createdAt;

  const QuickSnapReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  factory QuickSnapReaction.fromJson(Map<String, dynamic> json) {
    return QuickSnapReaction(
      emoji: json['emoji'] as String? ?? '❤️',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Housemate',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'user_id': userId,
    'created_at': createdAt.toIso8601String(),
  };
}

class QuickSnapComment {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String text;
  final DateTime createdAt;

  const QuickSnapComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.text,
    required this.createdAt,
  });

  factory QuickSnapComment.fromJson(Map<String, dynamic> json) {
    return QuickSnapComment(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Housemate',
      userAvatar: json['user_avatar'] as String?,
      text: json['text'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'text': text,
    'created_at': createdAt.toIso8601String(),
  };
}

class QuickSnap {
  final String id;
  final String householdId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String imageUrl;
  final String? caption;
  final QuickSnapRecipientType recipientType;
  final List<String> recipientNames;
  final DateTime createdAt;
  final List<QuickSnapReaction> reactions;
  final List<QuickSnapComment> comments;

  const QuickSnap({
    required this.id,
    required this.householdId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.imageUrl,
    this.caption,
    this.recipientType = QuickSnapRecipientType.everyone,
    this.recipientNames = const [],
    required this.createdAt,
    this.reactions = const [],
    this.comments = const [],
  });

  factory QuickSnap.fromJson(Map<String, dynamic> json) {
    return QuickSnap(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      senderId: json['creator_id'] as String? ?? json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Housemate',
      senderAvatar: json['sender_avatar'] as String?,
      imageUrl: json['image_url'] as String,
      caption: json['caption'] as String?,
      recipientType: (json['recipient_type'] as String?) == 'selected'
          ? QuickSnapRecipientType.selectedHousemates
          : QuickSnapRecipientType.everyone,
      recipientNames: (json['recipient_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((e) => QuickSnapReaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      comments: (json['comments'] as List<dynamic>?)
              ?.map((e) => QuickSnapComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'creator_id': senderId,
    'image_url': imageUrl,
    'caption': caption,
    'recipient_type':
        recipientType == QuickSnapRecipientType.selectedHousemates
            ? 'selected'
            : 'everyone',
    'created_at': createdAt.toIso8601String(),
  };

  QuickSnap copyWith({
    String? caption,
    List<QuickSnapReaction>? reactions,
    List<QuickSnapComment>? comments,
  }) {
    return QuickSnap(
      id: id,
      householdId: householdId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      imageUrl: imageUrl,
      caption: caption ?? this.caption,
      recipientType: recipientType,
      recipientNames: recipientNames,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      comments: comments ?? this.comments,
    );
  }
}

class ChoreRouletteRecord {
  final String id;
  final String householdId;
  final String choreTitle;
  final String assignedToName;
  final String? assignedToId;
  final String spunByName;
  final String mode; // 'random_dormmate' or 'just_for_me'
  final bool completed;
  final DateTime createdAt;

  const ChoreRouletteRecord({
    required this.id,
    required this.householdId,
    required this.choreTitle,
    required this.assignedToName,
    this.assignedToId,
    required this.spunByName,
    required this.mode,
    this.completed = false,
    required this.createdAt,
  });

  factory ChoreRouletteRecord.fromJson(Map<String, dynamic> json) {
    return ChoreRouletteRecord(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      choreTitle: json['chore_title'] as String? ?? 'Chore',
      assignedToName: json['assigned_to_name'] as String? ?? 'Dormmate',
      assignedToId: json['assigned_to'] as String?,
      spunByName: json['spun_by_name'] as String? ?? 'Housemate',
      mode: json['mode'] as String? ?? 'random_dormmate',
      completed: json['completed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'chore_title': choreTitle,
    'assigned_to': assignedToId,
    'mode': mode,
    'completed': completed,
    'created_at': createdAt.toIso8601String(),
  };
}

class NotificationPreferences {
  final bool householdUpdates;
  final bool parcelNotifications;
  final bool taskReminders;
  final bool chatNotifications;

  const NotificationPreferences({
    this.householdUpdates = true,
    this.parcelNotifications = true,
    this.taskReminders = true,
    this.chatNotifications = true,
  });

  NotificationPreferences copyWith({
    bool? householdUpdates,
    bool? parcelNotifications,
    bool? taskReminders,
    bool? chatNotifications,
  }) {
    return NotificationPreferences(
      householdUpdates: householdUpdates ?? this.householdUpdates,
      parcelNotifications: parcelNotifications ?? this.parcelNotifications,
      taskReminders: taskReminders ?? this.taskReminders,
      chatNotifications: chatNotifications ?? this.chatNotifications,
    );
  }
}
