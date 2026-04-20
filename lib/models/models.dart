// Data models for the Couple Chat application.
// Matches the Supabase PostgreSQL schema.

class Profile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String statusText;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final bool emailVerified;
  final DateTime? emailVerifiedAt;

  const Profile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.statusText = '',
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.emailVerified = false,
    this.emailVerifiedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      statusText: json['status_text'] as String? ?? '',
      isOnline: json['is_online'] as bool? ?? false,
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      emailVerified: json['email_verified'] as bool? ?? false,
      emailVerifiedAt: json['email_verified_at'] != null ? DateTime.parse(json['email_verified_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'status_text': statusText,
        'is_online': isOnline,
        'last_seen': lastSeen?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'email_verified': emailVerified,
        'email_verified_at': emailVerifiedAt?.toIso8601String(),
      };

  /// Whether the 24-hour grace period has expired without verification.
  bool get isGracePeriodExpired {
    if (emailVerified) return false;
    return DateTime.now().difference(createdAt).inHours >= 24;
  }

  /// Remaining duration in the grace period.
  Duration get gracePeriodRemaining {
    final elapsed = DateTime.now().difference(createdAt);
    final remaining = const Duration(hours: 24) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Profile copyWith({
    String? username,
    String? displayName,
    String? avatarUrl,
    String? statusText,
    bool? isOnline,
    DateTime? lastSeen,
    bool? emailVerified,
    DateTime? emailVerifiedAt,
  }) {
    return Profile(
      id: id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      statusText: statusText ?? this.statusText,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
    );
  }
}

class Couple {
  final String id;
  final String user1;
  final String user2;
  final DateTime pairedAt;
  final DateTime? anniversaryDate;
  final String? coupleName;
  final String? inviteCode;

  const Couple({
    required this.id,
    required this.user1,
    required this.user2,
    required this.pairedAt,
    this.anniversaryDate,
    this.coupleName,
    this.inviteCode,
  });

  factory Couple.fromJson(Map<String, dynamic> json) {
    return Couple(
      id: json['id'] as String,
      user1: json['user_1'] as String,
      user2: json['user_2'] as String,
      pairedAt: DateTime.parse(json['paired_at'] as String),
      anniversaryDate: json['anniversary_date'] != null
          ? DateTime.parse(json['anniversary_date'] as String)
          : null,
      coupleName: json['couple_name'] as String?,
      inviteCode: json['invite_code'] as String?,
    );
  }

  /// Returns the partner's ID given the current user's ID.
  String partnerId(String myId) => myId == user1 ? user2 : user1;
}

class Channel {
  final String id;
  final String coupleId;
  final String name;
  final String icon;
  final String description;
  final int position;
  final bool isDefault;
  final DateTime createdAt;
  // Computed fields (populated from queries)
  final String? lastMessageContent;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const Channel({
    required this.id,
    required this.coupleId,
    required this.name,
    this.icon = '💬',
    this.description = '',
    this.position = 0,
    this.isDefault = false,
    required this.createdAt,
    this.lastMessageContent,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'] as String,
      coupleId: json['couple_id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '💬',
      description: json['description'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Channel copyWith({
    String? lastMessageContent,
    DateTime? lastMessageAt,
    int? unreadCount,
  }) {
    return Channel(
      id: id,
      coupleId: coupleId,
      name: name,
      icon: icon,
      description: description,
      position: position,
      isDefault: isDefault,
      createdAt: createdAt,
      lastMessageContent: lastMessageContent ?? this.lastMessageContent,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

enum MessageType { text, image, video, voice, file, system }

class Message {
  final String id;
  final String channelId;
  final String senderId;
  final String? content;
  final MessageType type;
  final String? mediaUrl;
  final String? replyTo;
  final bool isEdited;
  final bool isDeleted;
  final List<String> readBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Local-only state for optimistic UI
  final bool isPending;

  const Message({
    required this.id,
    required this.channelId,
    required this.senderId,
    this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.replyTo,
    this.isEdited = false,
    this.isDeleted = false,
    this.readBy = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isPending = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      channelId: json['channel_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String?,
      type: _parseMessageType(json['type'] as String?),
      mediaUrl: json['media_url'] as String?,
      replyTo: json['reply_to'] as String?,
      isEdited: json['is_edited'] as bool? ?? false,
      isDeleted: json['is_deleted'] as bool? ?? false,
      readBy: (json['read_by'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'id': id,
        'channel_id': channelId,
        'sender_id': senderId,
        'content': content,
        'type': type.name,
        'media_url': mediaUrl,
        'reply_to': replyTo,
      };

  bool isReadBy(String userId) => readBy.contains(userId);

  static MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      case 'system':
        return MessageType.system;
      default:
        return MessageType.text;
    }
  }
}
