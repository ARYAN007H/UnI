import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/media_service.dart';

/// State for the Us tab (docs/design/us.md): month-grouped photo timeline,
/// voice moments, shared stats. Reads local-first via ChatService (§7.1).
class UsViewModel extends ChangeNotifier {
  final AuthService authService;
  final ChatService chatService;
  final MediaService mediaService;

  UsViewModel({
    required this.authService,
    required this.chatService,
    required this.mediaService,
  });

  Couple? get couple => authService.couple;

  int get daysTogether {
    final start = couple?.anniversaryDate ?? couple?.pairedAt;
    if (start == null) return 0;
    return DateTime.now()
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
  }

  List<Message> get _mediaMessages {
    final out = <Message>[];
    for (final channel in chatService.channels) {
      for (final m in chatService.messagesForChannel(channel.id)) {
        if ((m.type == MessageType.image || m.type == MessageType.voice) && !m.isDeleted) {
          out.add(m);
        }
      }
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  int get photoCount => _mediaMessages.where((m) => m.type == MessageType.image).length;
  int get voiceCount => _mediaMessages.where((m) => m.type == MessageType.voice).length;

  /// Photos grouped by month, newest month first.
  List<MonthGroup> get monthGroups {
    final photos = _mediaMessages
        .where((m) => m.type == MessageType.image)
        .toList()
        .reversed
        .toList();
    final map = <String, List<Message>>{};
    final order = <String>[];
    for (final m in photos) {
      final key = '${m.createdAt.year}-${m.createdAt.month.toString().padLeft(2, '0')}';
      if (!map.containsKey(key)) {
        map[key] = [];
        order.add(key);
      }
      map[key]!.add(m);
    }
    return [for (final key in order) MonthGroup(key, map[key]!)];
  }

  List<Message> get voiceMoments =>
      _mediaMessages.where((m) => m.type == MessageType.voice).toList().reversed.toList();

  Future<String?> resolve(String? url) => mediaService.downloadMedia(url ?? '');
}

class MonthGroup {
  final String key; // 'YYYY-MM'
  final List<Message> messages;
  MonthGroup(this.key, this.messages);

  String get title {
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    final parts = key.split('-');
    return '${months[int.parse(parts[1]) - 1]} ${parts[0]}';
  }
}
