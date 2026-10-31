// Data models for the Couple Chat application.
// Matches the Supabase PostgreSQL schema.
import 'dart:convert';

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
  final bool isVanillaMode;
  final String themeColorHex;

  const Couple({
    required this.id,
    required this.user1,
    required this.user2,
    required this.pairedAt,
    this.anniversaryDate,
    this.coupleName,
    this.inviteCode,
    this.isVanillaMode = false,
    this.themeColorHex = '#FFFF6B6B',
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
      isVanillaMode: json['is_vanilla_mode'] as bool? ?? false,
      themeColorHex: json['theme_color_hex'] as String? ?? '#FFFF6B6B',
    );
  }

  /// Returns the partner's ID given the current user's ID.
  String partnerId(String myId) => myId == user1 ? user2 : user1;

  Couple copyWith({
    String? coupleName,
    String? inviteCode,
    bool? isVanillaMode,
    String? themeColorHex,
  }) {
    return Couple(
      id: id,
      user1: user1,
      user2: user2,
      pairedAt: pairedAt,
      anniversaryDate: anniversaryDate,
      coupleName: coupleName ?? this.coupleName,
      inviteCode: inviteCode ?? this.inviteCode,
      isVanillaMode: isVanillaMode ?? this.isVanillaMode,
      themeColorHex: themeColorHex ?? this.themeColorHex,
    );
  }
}

/// Determines the specialized UI each channel renders.
enum ChannelType {
  general,  // Standard cozy chat
  photos,   // Gallery-first media view
  plans,    // Date planner with cards & countdowns
  random,   // Fun playground with prompts & mini-games
  custom,   // User-created channels (fallback to chat)
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

  /// Derives the channel type from its name for default channels.
  ChannelType get type {
    switch (name.toLowerCase()) {
      case 'general':
        return ChannelType.general;
      case 'photos':
        return ChannelType.photos;
      case 'plans':
        return ChannelType.plans;
      case 'random':
        return ChannelType.random;
      default:
        return ChannelType.custom;
    }
  }

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

enum MessageType { text, image, video, voice, file, system, plan }

class Message {
  final String id;
  final String channelId;
  final String senderId;
  // Server-derived on insert (migration 008); client value is informational.
  final String? coupleId;
  final String? content;
  final MessageType type;
  final String? mediaUrl;
  final String? mediaThumbnailUrl;
  final int? mediaDurationMs;
  final int? mediaSizeBytes;
  final double? latitude;
  final double? longitude;
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
    this.coupleId,
    this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaThumbnailUrl,
    this.mediaDurationMs,
    this.mediaSizeBytes,
    this.latitude,
    this.longitude,
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
      coupleId: json['couple_id'] as String?,
      content: json['content'] as String?,
      type: _parseMessageType(json['type'] as String?),
      mediaUrl: json['media_url'] as String?,
      mediaThumbnailUrl: json['media_thumbnail_url'] as String?,
      mediaDurationMs: json['media_duration_ms'] as int?,
      mediaSizeBytes: json['media_size_bytes'] as int?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
        'couple_id': coupleId,
        'content': content,
        'type': type.name,
        'media_url': mediaUrl,
        'media_thumbnail_url': mediaThumbnailUrl,
        'media_duration_ms': mediaDurationMs,
        'media_size_bytes': mediaSizeBytes,
        'latitude': latitude,
        'longitude': longitude,
        'reply_to': replyTo,
      };

  bool isReadBy(String userId) => readBy.contains(userId);

  /// Local-first edit helper: same message with new content, marked edited.
  Message copyWithContent(String newContent) => Message(
        id: id,
        channelId: channelId,
        senderId: senderId,
        coupleId: coupleId,
        content: newContent,
        type: type,
        mediaUrl: mediaUrl,
        mediaThumbnailUrl: mediaThumbnailUrl,
        mediaDurationMs: mediaDurationMs,
        mediaSizeBytes: mediaSizeBytes,
        latitude: latitude,
        longitude: longitude,
        replyTo: replyTo,
        isEdited: true,
        isDeleted: isDeleted,
        readBy: readBy,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

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
      case 'plan':
        return MessageType.plan;
      default:
        return MessageType.text;
    }
  }
}

/// A date/plan item stored as a structured message in the plans channel.
class Plan {
  final String id;
  final String channelId;
  final String title;
  final String? description;
  final String? location;
  final DateTime? plannedDate;
  final bool isCompleted;
  final String createdBy;
  final DateTime createdAt;

  const Plan({
    required this.id,
    required this.channelId,
    required this.title,
    this.description,
    this.location,
    this.plannedDate,
    this.isCompleted = false,
    required this.createdBy,
    required this.createdAt,
  });

  /// Serialize to JSON for storing in message content field.
  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'location': location,
        'planned_date': plannedDate?.toIso8601String(),
        'is_completed': isCompleted,
      };

  /// Parse from a plan-type message.
  factory Plan.fromMessage(Message msg) {
    // Content is JSON-encoded plan data
    Map<String, dynamic> data = {};
    if (msg.content != null) {
      try {
        data = _parseJsonContent(msg.content!);
      } catch (_) {
        data = {'title': msg.content};
      }
    }

    return Plan(
      id: msg.id,
      channelId: msg.channelId,
      title: data['title'] as String? ?? 'Untitled Plan',
      description: data['description'] as String?,
      location: data['location'] as String?,
      plannedDate: data['planned_date'] != null
          ? DateTime.tryParse(data['planned_date'] as String)
          : null,
      isCompleted: data['is_completed'] as bool? ?? false,
      createdBy: msg.senderId,
      createdAt: msg.createdAt,
    );
  }

  static Map<String, dynamic> _parseJsonContent(String content) {
    try {
      return Map<String, dynamic>.from(jsonDecode(content) as Map);
    } catch (_) {
      return {'title': content};
    }
  }

  Plan copyWith({
    bool? isCompleted,
    String? title,
    String? description,
    String? location,
    DateTime? plannedDate,
  }) {
    return Plan(
      id: id,
      channelId: channelId,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      plannedDate: plannedDate ?? this.plannedDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

/// A conversation prompt for the random channel.
class ConversationPrompt {
  final String text;
  final String category;
  final String emoji;

  const ConversationPrompt({
    required this.text,
    required this.category,
    required this.emoji,
  });
}
