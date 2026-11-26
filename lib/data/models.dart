/// Casama Core Data Models
library;

import '../core/utils/date_time_utils.dart';

class UserProfile {
  final String id;
  final String displayName;
  final String handle;
  final String? fullName;
  final String? nickname;
  final DateTime? birthday;
  final String? avatarUrl;
  final bool hasConsentedTerms;
  final bool hasCompletedOnboarding;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.handle,
    this.fullName,
    this.nickname,
    this.birthday,
    this.avatarUrl,
    this.hasConsentedTerms = false,
    this.hasCompletedOnboarding = false,
  });

  /// Parses `'YYYY-MM-DD'` or ISO strings into a date-only local [DateTime]
  /// so UTC offsets never shift the calendar day by -1.
  static DateTime? parseDateOnly(dynamic raw) => parseSupabaseDateOnly(raw);

  /// Formats a [DateTime] as calendar `'YYYY-MM-DD'` for `public.profiles.birthday`.
  static String? formatDateOnly(DateTime? date) => formatSupabaseDateOnly(date);

  /// Live age in years derived from [birthday].
  int? get computedAge {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    var age = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      age--;
    }
    return age >= 0 ? age : null;
  }

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
      birthday: parseDateOnly(json['birthday'] ?? json['birth_date']),
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
    'birthday': formatDateOnly(birthday),
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
  final int? memberCount;
  final String? spaceType;

  const Household({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.createdBy,
    this.memberCount,
    this.spaceType,
  });

  String get displaySubtitle =>
      (spaceType != null && spaceType!.trim().isNotEmpty)
          ? spaceType!.trim()
          : 'Community Space';

  Household copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? createdBy,
    int? memberCount,
    String? spaceType,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      memberCount: memberCount ?? this.memberCount,
      spaceType: spaceType ?? this.spaceType,
    );
  }

  factory Household.fromJson(Map<String, dynamic> json) {
    return Household(
      id: json['id'] as String,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      createdBy: json['created_by'] as String?,
      memberCount: (json['member_count'] as num?)?.toInt(),
      spaceType: json['space_type'] as String?,
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

/// Shared Philippine delivery courier options for expected parcel tracking.
class CasamaCouriers {
  static const String jtExpress = 'J&T Express';
  static const String flashExpress = 'Flash Express';
  static const String ninjaVan = 'Ninja Van';
  static const String lbc = 'LBC';
  static const String twoGoExpress = '2GO Express';
  static const String lalamove = 'Lalamove';
  static const String spx = 'SPX';
  static const String other = 'Other';

  static const String defaultCourier = jtExpress;

  static const List<String> options = [
    jtExpress,
    flashExpress,
    ninjaVan,
    lbc,
    twoGoExpress,
    lalamove,
    spx,
    other,
  ];
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
    this.codSettled = false,
    this.claimedById,
    this.claimedByName,
    this.claimedAt,
    this.settledAt,
  });

  final bool codSettled;
  final String? claimedById;
  final String? claimedByName;
  final DateTime? claimedAt;
  final DateTime? settledAt;

  bool get isClaimed =>
      (claimedById != null && claimedById!.isNotEmpty) ||
      status == ParcelStatus.received;

  bool get isSettled => isClaimed && codSettled;

  bool get isUnsettledClaim => isClaimed && !codSettled;

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
      expectedArrival: parseSupabaseTimestamp(json['expected_arrival']),
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
      codSettled: json['cod_settled'] as bool? ?? false,
      claimedById: json['claimed_by_id'] as String?,
      claimedByName: json['claimed_by_name'] as String?,
      claimedAt: parseSupabaseTimestampOrNull(json['claimed_at']),
      settledAt: parseSupabaseTimestampOrNull(json['settled_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'buyer_id': buyerId,
    'courier': courier,
    'expected_arrival': toSupabaseUtcIso(expectedArrival),
    'payment_type': paymentType == ParcelPaymentType.cod ? 'cod' : 'paid',
    'cod_amount': paymentType == ParcelPaymentType.cod ? codAmount : null,
    'currency': currency,
    'status': status.name,
    'notes': notes,
  };
}

enum ItemType { lost, found, shared }

enum ItemStatus { open, unclaimed, pending, rejected, resolved }

class LostFoundItem {
  final String id;
  final String householdId;
  final ItemType type;
  final String title;
  final String? description;
  final String? location;
  final String? imageUrl;
  final ItemStatus status;
  final String reportedBy;
  final String reportedByName;
  final String? foundById;
  final String? foundByName;
  final String? claimedById;
  final String? claimedByName;
  final String? lostItemId;
  final String? resolvedFoundItemId;
  final DateTime? foundAt;
  final DateTime? claimedAt;
  final DateTime? returnedAt;
  final DateTime? rejectedAt;
  final DateTime createdAt;

  const LostFoundItem({
    required this.id,
    required this.householdId,
    required this.type,
    required this.title,
    this.description,
    this.location,
    this.imageUrl,
    required this.status,
    required this.reportedBy,
    required this.reportedByName,
    this.foundById,
    this.foundByName,
    this.claimedById,
    this.claimedByName,
    this.lostItemId,
    this.resolvedFoundItemId,
    this.foundAt,
    this.claimedAt,
    this.returnedAt,
    this.rejectedAt,
    required this.createdAt,
  });

  String get ownerId => type == ItemType.lost ? reportedBy : '';
  String get finderId => type == ItemType.found ? reportedBy : '';
  bool get isLinkedToLost => lostItemId != null;
  bool get isStandalone => lostItemId == null;
  bool get isResolved => status == ItemStatus.resolved;

  LostFoundItem copyWith({
    String? title,
    String? description,
    String? location,
    String? imageUrl,
    ItemStatus? status,
    String? reportedBy,
    String? reportedByName,
    String? foundById,
    String? foundByName,
    String? claimedById,
    String? claimedByName,
    String? lostItemId,
    String? resolvedFoundItemId,
    DateTime? foundAt,
    DateTime? claimedAt,
    DateTime? returnedAt,
    DateTime? rejectedAt,
  }) {
    return LostFoundItem(
      id: id,
      householdId: householdId,
      type: type,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      reportedBy: reportedBy ?? this.reportedBy,
      reportedByName: reportedByName ?? this.reportedByName,
      foundById: foundById ?? this.foundById,
      foundByName: foundByName ?? this.foundByName,
      claimedById: claimedById ?? this.claimedById,
      claimedByName: claimedByName ?? this.claimedByName,
      lostItemId: lostItemId ?? this.lostItemId,
      resolvedFoundItemId: resolvedFoundItemId ?? this.resolvedFoundItemId,
      foundAt: foundAt ?? this.foundAt,
      claimedAt: claimedAt ?? this.claimedAt,
      returnedAt: returnedAt ?? this.returnedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      createdAt: createdAt,
    );
  }

  factory LostFoundItem.fromJson(
    Map<String, dynamic> json, {
    ItemType? forcedType,
  }) {
    ItemType parseType(String? t) {
      if (forcedType != null) return forcedType;
      switch (t?.toLowerCase()) {
        case 'found':
          return ItemType.found;
        case 'shared':
          return ItemType.shared;
        default:
          return ItemType.lost;
      }
    }

    final parsedType = parseType(json['type'] as String?);

    ItemStatus parseStatus(String? s) {
      switch (s?.toLowerCase()) {
        case 'unclaimed':
          return ItemStatus.unclaimed;
        case 'pending':
          return ItemStatus.pending;
        case 'rejected':
          return ItemStatus.rejected;
        case 'resolved':
          return ItemStatus.resolved;
        case 'open':
          return ItemStatus.open;
        default:
          return parsedType == ItemType.found
              ? ItemStatus.unclaimed
              : ItemStatus.open;
      }
    }

    final reporterId = parsedType == ItemType.found
        ? (json['finder_id'] as String? ?? '')
        : (json['owner_id'] as String? ?? '');
    final itemLocation = parsedType == ItemType.found
        ? json['found_location'] as String?
        : json['last_seen_location'] as String?;

    return LostFoundItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      type: parsedType,
      title: json['title'] as String? ?? 'Untitled Item',
      description: json['description'] as String?,
      location: itemLocation,
      imageUrl: json['image_url'] as String?,
      status: parseStatus(json['status'] as String?),
      reportedBy: reporterId,
      reportedByName: json['reported_by_name'] as String? ?? 'Housemate',
      foundById: json['found_by_id'] as String?,
      foundByName: json['found_by_name'] as String?,
      claimedById: json['claimed_by_id'] as String?,
      claimedByName: json['claimed_by_name'] as String?,
      lostItemId: json['lost_item_id'] as String?,
      resolvedFoundItemId: json['resolved_found_item_id'] as String?,
      foundAt: parseSupabaseTimestampOrNull(json['found_at']),
      claimedAt: parseSupabaseTimestampOrNull(json['claimed_at']),
      returnedAt: parseSupabaseTimestampOrNull(json['returned_at']),
      rejectedAt: parseSupabaseTimestampOrNull(json['rejected_at']),
      createdAt: parseSupabaseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    if (type == ItemType.found) ...{
      'finder_id': reportedBy,
      'lost_item_id': lostItemId,
      'found_location': location,
      'claimed_by_id': claimedById,
      'claimed_at': toSupabaseUtcIsoOrNull(claimedAt),
      'rejected_at': toSupabaseUtcIsoOrNull(rejectedAt),
    } else ...{
      'owner_id': reportedBy,
      'last_seen_location': location,
      'found_by_id': foundById,
      'found_at': toSupabaseUtcIsoOrNull(foundAt),
      'resolved_found_item_id': resolvedFoundItemId,
    },
    'title': title,
    'description': description,
    'image_url': imageUrl,
    'status': status.name,
    'returned_at': toSupabaseUtcIsoOrNull(returnedAt),
    'created_at': toSupabaseUtcIso(createdAt),
  };
}

enum TaskCategory {
  cleaning,
  repairMaintenance,
  restock,
  personalRequest,
  diy,
  landlord,
}

extension TaskCategoryDbX on TaskCategory {
  String get dbValue => switch (this) {
    TaskCategory.cleaning || TaskCategory.diy => 'cleaning',
    TaskCategory.repairMaintenance ||
    TaskCategory.landlord => 'repair_maintenance',
    TaskCategory.restock => 'restock',
    TaskCategory.personalRequest => 'personal_request',
  };

  String get label => switch (this) {
    TaskCategory.cleaning || TaskCategory.diy => 'Cleaning',
    TaskCategory.repairMaintenance ||
    TaskCategory.landlord => 'Repair / Maintenance',
    TaskCategory.restock => 'Restock',
    TaskCategory.personalRequest => 'Personal Request',
  };

  int get basePoints => switch (this) {
    TaskCategory.cleaning || TaskCategory.diy => 5,
    TaskCategory.restock => 5,
    TaskCategory.repairMaintenance || TaskCategory.landlord => 8,
    TaskCategory.personalRequest => 8,
  };

  static TaskCategory fromDbValue(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'cleaning':
      case 'diy':
        return TaskCategory.cleaning;
      case 'repair_maintenance':
      case 'landlord':
        return TaskCategory.repairMaintenance;
      case 'restock':
        return TaskCategory.restock;
      case 'personal_request':
        return TaskCategory.personalRequest;
      default:
        return TaskCategory.cleaning;
    }
  }
}

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

  int get bonusPoints => switch (this) {
    TaskUrgency.low => 2,
    TaskUrgency.medium => 4,
    TaskUrgency.urgent => 6,
  };
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
  final String? description;
  final TaskCategory category;
  final TaskUrgency urgency;
  final TaskStatus status;
  final String createdBy;
  final String createdByName;
  final String? completedById;
  final String? completedByName;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime? dueDate;

  const MaintenanceTask({
    required this.id,
    required this.householdId,
    required this.title,
    this.description,
    required this.category,
    required this.urgency,
    required this.status,
    this.createdBy = '',
    required this.createdByName,
    this.completedById,
    this.completedByName,
    this.completedAt,
    required this.createdAt,
    this.dueDate,
  });

  static int computePoints(TaskCategory category, TaskUrgency urgency) =>
      category.basePoints + urgency.bonusPoints;

  int get computedPoints => computePoints(category, urgency);

  MaintenanceTask copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    TaskUrgency? urgency,
    TaskStatus? status,
    String? createdBy,
    String? completedById,
    String? completedByName,
    DateTime? completedAt,
    DateTime? dueDate,
    bool clearCompleted = false,
  }) {
    return MaintenanceTask(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      urgency: urgency ?? this.urgency,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName,
      completedById: clearCompleted
          ? null
          : (completedById ?? this.completedById),
      completedByName: clearCompleted
          ? null
          : (completedByName ?? this.completedByName),
      completedAt: clearCompleted ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      dueDate: dueDate ?? this.dueDate,
    );
  }

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
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
      description: json['description'] as String?,
      category: TaskCategoryDbX.fromDbValue(json['category'] as String?),
      urgency: parseUrg(json['urgency'] as String?),
      status: parseStatus(json['status'] as String?),
      createdBy: json['created_by'] as String? ?? '',
      createdByName: json['created_by_name'] as String? ?? 'Housemate',
      completedById: json['completed_by'] as String?,
      completedByName: json['completed_by_name'] as String?,
      completedAt: parseSupabaseTimestampOrNull(json['completed_at']),
      createdAt: parseSupabaseTimestamp(json['created_at']),
      dueDate: parseSupabaseTimestampOrNull(json['due_date']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'title': title,
    'description': description,
    'category': category.dbValue,
    'urgency': urgency.name,
    'status': status == TaskStatus.inProgress ? 'in_progress' : status.name,
    'created_by': createdBy,
    'completed_by': completedById,
    'completed_at': toSupabaseUtcIsoOrNull(completedAt),
    'created_at': toSupabaseUtcIso(createdAt),
    'due_date': toSupabaseUtcIsoOrNull(dueDate),
  };
}

enum MessageDeliveryStatus { sending, delivered, failed }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String? attachmentUrl;
  final String? localAttachmentPath;
  final String? clientMessageId;
  final String? inviteCode;
  final String? inviteSpaceName;
  final DateTime createdAt;
  final bool isCurrentUser;
  final bool isRead;
  final MessageDeliveryStatus deliveryStatus;
  final MeetUpInvitation? meetUpInvitation;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    String? attachmentUrl,
    String? mediaUrl,
    this.localAttachmentPath,
    this.clientMessageId,
    this.inviteCode,
    this.inviteSpaceName,
    required this.createdAt,
    required this.isCurrentUser,
    this.isRead = true,
    this.deliveryStatus = MessageDeliveryStatus.delivered,
    this.meetUpInvitation,
  }) : attachmentUrl = attachmentUrl ?? mediaUrl;

  String? get mediaUrl => attachmentUrl;

  bool get hasAttachment =>
      (attachmentUrl != null && attachmentUrl!.isNotEmpty) ||
      (localAttachmentPath != null && localAttachmentPath!.isNotEmpty);

  ChatMessage copyWith({
    String? id,
    String? attachmentUrl,
    String? mediaUrl,
    String? localAttachmentPath,
    bool clearLocalAttachment = false,
    String? clientMessageId,
    bool? isRead,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      content: content,
      attachmentUrl: attachmentUrl ?? mediaUrl ?? this.attachmentUrl,
      localAttachmentPath: clearLocalAttachment
          ? null
          : (localAttachmentPath ?? this.localAttachmentPath),
      clientMessageId: clientMessageId ?? this.clientMessageId,
      inviteCode: inviteCode,
      inviteSpaceName: inviteSpaceName,
      createdAt: createdAt,
      isCurrentUser: isCurrentUser,
      isRead: isRead ?? this.isRead,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      meetUpInvitation: meetUpInvitation,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String? ?? '',
      senderName: json['sender_name'] as String? ?? 'Housemate',
      senderAvatar: json['sender_avatar'] as String?,
      content: json['content'] as String? ?? '',
      attachmentUrl:
          json['attachment_url'] as String? ?? json['media_url'] as String?,
      clientMessageId: json['client_message_id'] as String?,
      inviteCode: json['invite_code'] as String?,
      inviteSpaceName: json['invite_space_name'] as String?,
      createdAt: parseSupabaseTimestamp(json['created_at']),
      isCurrentUser: currentUserId != null && json['sender_id'] == currentUserId,
      isRead: json['is_read'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'sender_id': senderId,
    'content': content,
    'attachment_url': attachmentUrl,
    if (clientMessageId != null) 'client_message_id': clientMessageId,
    'created_at': toSupabaseUtcIso(createdAt),
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

class MeetUpResponder {
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String response; // 'going', 'maybe', 'cant_make_it'

  const MeetUpResponder({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.response,
  });
}

class MeetUpInvitation {
  final String id;
  final String activity;
  final String location;
  final DateTime scheduledTime;
  final String status;
  final bool reminderSent;
  final bool arrivalHandled;
  final int goingCount;
  final int maybeCount;
  final int cantMakeCount;
  final String? currentUserResponse; // 'going', 'maybe', 'cant_make_it'
  final List<MeetUpResponder> responders;

  const MeetUpInvitation({
    required this.id,
    required this.activity,
    required this.location,
    required this.scheduledTime,
    this.status = 'active',
    this.reminderSent = false,
    this.arrivalHandled = false,
    this.goingCount = 0,
    this.maybeCount = 0,
    this.cantMakeCount = 0,
    this.currentUserResponse,
    this.responders = const [],
  });

  bool get isActive => status != 'done';
  bool get isDone => status == 'done';

  List<MeetUpResponder> get goingResponders =>
      responders.where((r) => r.response == 'going').toList();

  List<MeetUpResponder> get maybeResponders =>
      responders.where((r) => r.response == 'maybe').toList();

  List<MeetUpResponder> get cantMakeResponders =>
      responders.where((r) => r.response == 'cant_make_it').toList();

  bool get hasValidData =>
      id.isNotEmpty && id != 'placeholder_m' && activity.trim().isNotEmpty;

  factory MeetUpInvitation.fromJson(
    Map<String, dynamic> json, {
    int goingCount = 0,
    int maybeCount = 0,
    int cantMakeCount = 0,
    String? currentUserResponse,
    List<MeetUpResponder> responders = const [],
  }) {
    return MeetUpInvitation(
      id: json['id'] as String? ?? '',
      activity: json['activity'] as String? ?? '',
      location: json['location'] as String? ?? '',
      scheduledTime: parseSupabaseTimestamp(json['scheduled_time']),
      status: json['status'] as String? ?? 'active',
      reminderSent: json['reminder_sent'] as bool? ?? false,
      arrivalHandled: json['arrival_handled'] as bool? ?? false,
      goingCount: goingCount,
      maybeCount: maybeCount,
      cantMakeCount: cantMakeCount,
      currentUserResponse: currentUserResponse,
      responders: responders,
    );
  }

  Map<String, dynamic> toJson({String? conversationId, String? creatorId}) => {
    'id': id,
    'conversation_id': ?conversationId,
    'creator_id': ?creatorId,
    'activity': activity,
    'location': location,
    'scheduled_time': toSupabaseUtcIso(scheduledTime),
    'status': status,
    'reminder_sent': reminderSent,
    'arrival_handled': arrivalHandled,
  };

  MeetUpInvitation copyWith({
    String? id,
    String? activity,
    String? location,
    DateTime? scheduledTime,
    String? status,
    bool? reminderSent,
    bool? arrivalHandled,
    int? goingCount,
    int? maybeCount,
    int? cantMakeCount,
    String? currentUserResponse,
    List<MeetUpResponder>? responders,
  }) {
    return MeetUpInvitation(
      id: id ?? this.id,
      activity: activity ?? this.activity,
      location: location ?? this.location,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      reminderSent: reminderSent ?? this.reminderSent,
      arrivalHandled: arrivalHandled ?? this.arrivalHandled,
      goingCount: goingCount ?? this.goingCount,
      maybeCount: maybeCount ?? this.maybeCount,
      cantMakeCount: cantMakeCount ?? this.cantMakeCount,
      currentUserResponse: currentUserResponse ?? this.currentUserResponse,
      responders: responders ?? this.responders,
    );
  }
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
    final localDeadline = deadline.toLocal();
    final deadlineDate = DateTime(
      localDeadline.year,
      localDeadline.month,
      localDeadline.day,
    );
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
        case 'one_day_before':
          return ReminderTiming.oneDayBefore;
        case '2_days_before':
        case 'two_days_before':
          return ReminderTiming.twoDaysBefore;
        case '3_days_before':
        case 'three_days_before':
          return ReminderTiming.threeDaysBefore;
        case '1_week_before':
        case 'one_week_before':
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
        case 'specific_members':
          return BillRecipientType.selectedMembers;
        default:
          return BillRecipientType.allMembers;
      }
    }

    return HouseholdBill(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      creatorId: json['created_by'] as String? ?? '',
      creatorName:
          json['created_by_name'] as String? ??
          json['creator_name'] as String? ??
          'Housemate',
      category: parseCategory(json['category'] as String?),
      customCategoryLabel:
          json['custom_category_name'] as String? ??
          json['custom_category'] as String?,
      billName: json['title'] as String? ?? json['name'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      deadline: parseSupabaseTimestamp(json['deadline']),
      notes: json['notes'] as String?,
      status: parseStatus(json['status'] as String?),
      reminderEnabled:
          json['reminder_enabled'] as bool? ??
          json['has_reminder'] as bool? ??
          true,
      reminderTiming: parseReminder(json['reminder_timing'] as String?),
      recipientType: parseRecipient(
        json['recipient_type'] as String? ??
            json['reminder_recipients'] as String?,
      ),
      responsibleMember:
          json['responsible_member_name'] as String? ??
          json['responsible_member'] as String?,
      createdAt: parseSupabaseTimestamp(json['created_at']),
      paidAt: parseSupabaseTimestampOrNull(json['paid_at']),
      paidByName: json['paid_by_name'] as String?,
    );
  }

  Map<String, dynamic> toSupabaseJson({bool includeId = true}) {
    final base = <String, dynamic>{
      if (includeId) 'id': id,
      'household_id': householdId,
      'title': billName ?? effectiveCategoryLabel,
      'category': switch (category) {
        BillCategory.associationDues => 'association_dues',
        BillCategory.maintenanceFee => 'maintenance_fee',
        _ => category.name,
      },
      'custom_category_name': customCategoryLabel,
      'amount': amount ?? 0.0,
      'deadline': toSupabaseUtcIso(deadline),
      'status': status.name,
      'responsible_member': responsibleMember,
      'notes': notes,
      'reminder_enabled': reminderEnabled,
      'reminder_timing': switch (reminderTiming) {
        ReminderTiming.onDueDate => 'on_due_date',
        ReminderTiming.oneDayBefore => 'one_day_before',
        ReminderTiming.twoDaysBefore => 'three_days_before',
        ReminderTiming.threeDaysBefore => 'three_days_before',
        ReminderTiming.oneWeekBefore => 'one_week_before',
      },
      'recipient_type': recipientType == BillRecipientType.allMembers
          ? 'all_members'
          : 'specific_members',
      'created_by': creatorId.isNotEmpty ? creatorId : null,
      'created_by_name': creatorName,
      'paid_at': toSupabaseUtcIsoOrNull(paidAt),
      'paid_by_name': paidByName,
    };
    return base;
  }

  Map<String, dynamic> toJson() => toSupabaseJson();

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

/// Allowed CASnap multi-tap reaction emojis in canonical display order.
const List<String> kCasSnapReactionEmojis = [
  '❤️',
  '😂',
  '😍',
  '🔥',
  '👍',
  '👎',
];

class QuickSnapReaction {
  final String emoji;
  final String userId;
  final String userName;
  final int count;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const QuickSnapReaction({
    required this.emoji,
    required this.userId,
    required this.userName,
    this.count = 1,
    required this.createdAt,
    this.updatedAt,
  });

  factory QuickSnapReaction.fromJson(Map<String, dynamic> json) {
    final rawCount = (json['count'] as num?)?.toInt();
    return QuickSnapReaction(
      emoji: json['emoji'] as String? ?? '❤️',
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String? ?? 'Housemate',
      count: (rawCount != null && rawCount > 0) ? rawCount : 1,
      createdAt: parseSupabaseTimestamp(json['created_at']),
      updatedAt: parseSupabaseTimestampOrNull(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'emoji': emoji,
    'user_id': userId,
    'user_name': userName,
    'count': count,
    'created_at': toSupabaseUtcIso(createdAt),
    if (updatedAt != null) 'updated_at': toSupabaseUtcIso(updatedAt!),
  };

  QuickSnapReaction copyWith({
    String? emoji,
    String? userId,
    String? userName,
    int? count,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickSnapReaction(
      emoji: emoji ?? this.emoji,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      count: count ?? this.count,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QuickSnapReactorBreakdown {
  final String userId;
  final String fallbackUserName;
  final int totalCount;
  final List<MapEntry<String, int>> emojiCounts;

  const QuickSnapReactorBreakdown({
    required this.userId,
    required this.fallbackUserName,
    required this.totalCount,
    required this.emojiCounts,
  });
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
      text: (json['message'] ?? json['text'] ?? '') as String,
      createdAt: parseSupabaseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_name': userName,
    'user_avatar': userAvatar,
    'message': text,
    'created_at': toSupabaseUtcIso(createdAt),
  };
}

class QuickSnap {
  final String id;
  final String householdId;
  final String senderId;
  final String senderName;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;
  final List<QuickSnapReaction> reactions;
  final List<QuickSnapComment> comments;

  const QuickSnap({
    required this.id,
    required this.householdId,
    required this.senderId,
    required this.senderName,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
    this.reactions = const [],
    this.comments = const [],
  });

  String get creatorId => senderId;
  String get creatorName => senderName;

  int get totalReactionCount {
    var total = 0;
    for (final r in reactions) {
      if (r.count > 0) total += r.count;
    }
    return total;
  }

  List<MapEntry<String, int>> get emojiTotals {
    final totals = <String, int>{};
    for (final r in reactions) {
      if (r.count <= 0) continue;
      totals[r.emoji] = (totals[r.emoji] ?? 0) + r.count;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        return _compareSnapEmojiOrder(a.key, b.key);
      });
    return entries;
  }

  List<String> topReactionEmojis({int maxCount = 3}) {
    if (maxCount <= 0) return const [];
    return emojiTotals.take(maxCount).map((e) => e.key).toList();
  }

  bool hasUserReacted(String userId, String emoji) {
    if (userId.isEmpty) return false;
    return reactions.any(
      (r) => r.userId == userId && r.emoji == emoji && r.count > 0,
    );
  }

  List<QuickSnapReactorBreakdown> get reactorBreakdowns {
    final byUser = <String, Map<String, int>>{};
    final userNames = <String, String>{};
    for (final r in reactions) {
      if (r.count <= 0) continue;
      final userKey = r.userId.isNotEmpty ? r.userId : r.userName;
      userNames.putIfAbsent(userKey, () => r.userName);
      final map = byUser.putIfAbsent(userKey, () => <String, int>{});
      map[r.emoji] = (map[r.emoji] ?? 0) + r.count;
    }

    final result = <QuickSnapReactorBreakdown>[];
    for (final entry in byUser.entries) {
      final emojiEntries = entry.value.entries.toList()
        ..sort((a, b) {
          final cmp = b.value.compareTo(a.value);
          if (cmp != 0) return cmp;
          return _compareSnapEmojiOrder(a.key, b.key);
        });
      var total = 0;
      for (final e in emojiEntries) {
        total += e.value;
      }
      result.add(
        QuickSnapReactorBreakdown(
          userId: entry.key,
          fallbackUserName: userNames[entry.key] ?? 'Housemate',
          totalCount: total,
          emojiCounts: emojiEntries,
        ),
      );
    }

    result.sort((a, b) {
      final cmp = b.totalCount.compareTo(a.totalCount);
      if (cmp != 0) return cmp;
      return a.fallbackUserName.toLowerCase().compareTo(
        b.fallbackUserName.toLowerCase(),
      );
    });
    return result;
  }

  static int _compareSnapEmojiOrder(String a, String b) {
    final idxA = kCasSnapReactionEmojis.indexOf(a);
    final idxB = kCasSnapReactionEmojis.indexOf(b);
    if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
    if (idxA != -1) return -1;
    if (idxB != -1) return 1;
    return a.compareTo(b);
  }

  factory QuickSnap.fromJson(Map<String, dynamic> json) {
    return QuickSnap(
      id: json['id'] as String,
      householdId: json['household_id'] as String? ?? '',
      senderId:
          json['creator_id'] as String? ?? json['sender_id'] as String? ?? '',
      senderName:
          json['creator_name'] as String? ??
          json['sender_name'] as String? ??
          'Housemate',
      imageUrl: json['image_url'] as String,
      caption: json['caption'] as String?,
      createdAt: parseSupabaseTimestamp(json['created_at']),
      reactions:
          ((json['quick_snap_reactions'] ?? json['reactions'])
                  as List<dynamic>?)
              ?.map((e) => QuickSnapReaction.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      comments:
          ((json['quick_snap_comments'] ?? json['comments']) as List<dynamic>?)
              ?.map((e) => QuickSnapComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'creator_id': senderId,
    'creator_name': senderName,
    'image_url': imageUrl,
    'caption': caption,
    'created_at': toSupabaseUtcIso(createdAt),
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
      imageUrl: imageUrl,
      caption: caption ?? this.caption,
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
      createdAt: parseSupabaseTimestamp(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'household_id': householdId,
    'chore_title': choreTitle,
    'assigned_to': assignedToId,
    'mode': mode,
    'completed': completed,
    'created_at': toSupabaseUtcIso(createdAt),
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

class RepositoryActionError {
  final String message;
  final Future<void> Function()? onRetry;

  const RepositoryActionError(this.message, {this.onRetry});
}

class LeaderboardStanding {
  final String userId;
  final String displayName;
  final String handle;
  final String? avatarUrl;
  final int points;
  final bool isCurrentUser;

  const LeaderboardStanding({
    required this.userId,
    required this.displayName,
    required this.handle,
    this.avatarUrl,
    required this.points,
    this.isCurrentUser = false,
  });
}

class HouseholdNotificationItem {
  final String id;
  final String type;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final bool isRead;
  final DateTime? readAt;
  final Map<String, dynamic> payload;

  const HouseholdNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    required this.isRead,
    this.readAt,
    this.payload = const {},
  });

  bool get isUnread => !isRead && readAt == null;

  String get displayTitle {
    if (type == 'meetup_reminder') {
      if (title.startsWith('Meet-up Reminder:')) return title;
      final rawTitle = (payload['title'] as String?)?.trim();
      final fallback =
          rawTitle != null && rawTitle.isNotEmpty
              ? rawTitle
              : (title.trim().isNotEmpty ? title.trim() : 'Household Meet-up');
      return 'Meet-up Reminder: $fallback';
    }
    return title;
  }

  String get displaySubtitle {
    if (type == 'meetup_reminder') {
      final msg = (payload['message'] as String?)?.trim();
      if (msg != null && msg.isNotEmpty) return msg;
      final sub = subtitle.trim();
      if (sub.isNotEmpty) return sub;
      final location = (payload['location'] as String?)?.trim();
      return 'Starting soon at ${location != null && location.isNotEmpty ? location : 'shared spot'}';
    }
    return subtitle;
  }

  HouseholdNotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
  }) {
    return HouseholdNotificationItem(
      id: id,
      type: type,
      title: title,
      subtitle: subtitle,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      payload: payload,
    );
  }
}
