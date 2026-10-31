import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_cache_service.dart';

class DailyQuestion {
  final int id;
  final String text;
  final String category;
  final String emoji;

  const DailyQuestion({
    required this.id,
    required this.text,
    required this.category,
    required this.emoji,
  });

  factory DailyQuestion.fromJson(Map<String, dynamic> json) => DailyQuestion(
        id: json['id'] as int,
        text: json['text'] as String,
        category: json['category'] as String? ?? 'general',
        emoji: json['emoji'] as String? ?? '💭',
      );

  Map<String, dynamic> get asRow => {
        'id': id,
        'text': text,
        'category': category,
        'emoji': emoji,
      };
}

/// State of one day's question for one couple. The reveal rule (§7.4):
/// the partner's answer is only exposed once BOTH have answered.
class DailyAnswerState {
  final DailyQuestion question;
  final String answerDate;
  final String? myAnswer;
  final String? partnerAnswer;
  final bool bothAnswered;

  const DailyAnswerState({
    required this.question,
    required this.answerDate,
    this.myAnswer,
    this.partnerAnswer,
  }) : bothAnswered = myAnswer != null && partnerAnswer != null;
}

/// §7.4 — The daily question ritual, with a DERIVABLE question of the day.
///
/// `questionOfDay` = bank[fnv1a(coupleId + '|' + UTC date) % bank.length],
/// computed on the client. No cron, no delivery to fail; both partners'
/// devices independently land on the same question. The server only stores
/// the question bank and the answers — works fully offline once the bank
/// has been fetched once (and falls back to the built-in bank before that).
class DailyQuestionService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalCacheService? _cache;

  DailyQuestionService({LocalCacheService? cache}) : _cache = cache;

  /// Built-in bank used until the server bank has been cached. Both devices
  /// ship the same constants, so the derivation stays in sync.
  static const List<DailyQuestion> _fallbackBank = [
    DailyQuestion(id: -1, text: "What's a small thing they did today that made you smile?", category: 'playful', emoji: '😊'),
    DailyQuestion(id: -2, text: 'If you could teleport to them for one hour, what would you do?', category: 'ldr', emoji: '✈️'),
    DailyQuestion(id: -3, text: "What's a song that reminds you of them right now?", category: 'playful', emoji: '🎵'),
    DailyQuestion(id: -4, text: 'What is something you are looking forward to doing together?', category: 'ldr', emoji: '🗓️'),
    DailyQuestion(id: -5, text: "What's one thing you learned about yourself this week?", category: 'deep', emoji: '🌱'),
    DailyQuestion(id: -6, text: 'Describe your perfect lazy day together.', category: 'playful', emoji: '🛋️'),
    DailyQuestion(id: -7, text: 'What is a memory of us you replay the most?', category: 'memory', emoji: '📸'),
    DailyQuestion(id: -8, text: "What's something you want to tell them but keep forgetting to?", category: 'deep', emoji: '💌'),
    DailyQuestion(id: -9, text: 'Which timezone moment is hardest: waking up alone or falling asleep alone?', category: 'ldr', emoji: '🌙'),
    DailyQuestion(id: -10, text: "What's a dish you want to cook for them someday?", category: 'playful', emoji: '🍝'),
  ];

  List<DailyQuestion>? _bank;
  bool _bankLoaded = false;

  /// Read-only view of the built-in bank (tests + UI onboarding previews).
  static List<DailyQuestion> get fallbackBank => _fallbackBank;

  /// UTC date key (YYYY-MM-DD) — the derivation's clock input.
  static String dateKeyFor(DateTime now) {
    final utc = now.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  String _dateKey([DateTime? now]) => dateKeyFor(now ?? DateTime.now());

  /// FNV-1a — stable across platforms, no dart:math Random dependency.
  static int fnv1a(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code & 0xff;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
      hash ^= (code >> 8) & 0xff;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash & 0x7FFFFFFF;
  }

  /// §7.4 core derivation — the question of the day is an index into the
  /// bank (which MUST be ordered by id, identically on both devices).
  static int deriveQuestionIndex({
    required String coupleId,
    required String dateKey,
    required int bankLength,
  }) {
    if (bankLength <= 0) return 0;
    return fnv1a('$coupleId|$dateKey') % bankLength;
  }

  List<DailyQuestion> get _activeBank =>
      (_bank != null && _bank!.isNotEmpty) ? _bank! : _fallbackBank;

  /// Load the bank: cache-first (offline), then refresh from the server.
  /// The fallback bank is used until either source provides rows.
  Future<void> ensureBank() async {
    if (_bankLoaded && _bank != null && _bank!.isNotEmpty) return;
    _bankLoaded = true;

    final cached = await _cache?.getDailyQuestions();
    if (cached != null && cached.isNotEmpty) {
      _bank = cached.map(DailyQuestion.fromJson).toList();
    }

    try {
      final data = await _client
          .from('daily_questions')
          .select('id,text,category,emoji')
          .order('id');
      final rows = data
          .map((j) => {
                'id': j['id'] as int,
                'text': j['text'] as String,
                'category': j['category'] as String? ?? 'general',
                'emoji': j['emoji'] as String? ?? '💭',
              })
          .toList();
      if (rows.isNotEmpty) {
        _bank = rows.map(DailyQuestion.fromJson).toList();
        await _cache?.saveDailyQuestions(rows);
      }
    } catch (e) {
      debugPrint('[DailyQuestion] bank fetch failed (offline?): $e');
    }
  }

  /// The question of the day for this couple — pure derivation, zero server
  /// calls. Same result on both partners' devices for the same UTC date.
  Future<DailyQuestion> questionOfDay(String coupleId) async {
    await ensureBank();
    final bank = _activeBank;
    final index = deriveQuestionIndex(
      coupleId: coupleId,
      dateKey: _dateKey(),
      bankLength: bank.length,
    );
    return bank[index];
  }

  /// Submit (or edit) my answer for today's question. Local write-through
  /// first, then server upsert; offline submissions re-sync with the outbox
  /// in a future pass — for now the server write retries on next submit.
  Future<void> submitAnswer({
    required String coupleId,
    required DailyQuestion question,
    required String myUserId,
    required String content,
  }) async {
    final dateKey = _dateKey();

    await _cache?.saveDailyAnswer(
      coupleId: coupleId,
      questionId: question.id,
      answerDate: dateKey,
      userId: myUserId,
      content: content,
    );
    notifyListeners();

    try {
      await _client.from('daily_answers').upsert({
        'couple_id': coupleId,
        'question_id': question.id,
        'answer_date': dateKey,
        'user_id': myUserId,
        'content': content,
      }, onConflict: 'couple_id,question_id,answer_date,user_id');
    } catch (e) {
      debugPrint('[DailyQuestion] answer upsert failed (offline?): $e');
      rethrow;
    }
  }

  /// Load today's reveal state: local-first, then a server catch-up for the
  /// partner's answer. Partner content is only included once both answered.
  Future<DailyAnswerState> loadAnswers({
    required String coupleId,
    required DailyQuestion question,
    required String myUserId,
    String? partnerUserId,
  }) async {
    final dateKey = _dateKey();

    var answers = await _cache?.getDailyAnswers(
          coupleId: coupleId,
          questionId: question.id,
          answerDate: dateKey,
        ) ??
        <String, String>{};

    try {
      final data = await _client
          .from('daily_answers')
          .select('user_id,content')
          .eq('couple_id', coupleId)
          .eq('question_id', question.id)
          .eq('answer_date', dateKey);
      for (final row in data) {
        answers[row['user_id'] as String] = row['content'] as String;
      }
      // refresh the local copy
      for (final entry in answers.entries) {
        await _cache?.saveDailyAnswer(
          coupleId: coupleId,
          questionId: question.id,
          answerDate: dateKey,
          userId: entry.key,
          content: entry.value,
        );
      }
    } catch (e) {
      debugPrint('[DailyQuestion] answers fetch failed (offline?): $e');
    }

    final myAnswer = answers[myUserId];
    final partnerAnswer =
        partnerUserId != null ? answers[partnerUserId] : null;

    return DailyAnswerState(
      question: question,
      answerDate: dateKey,
      myAnswer: myAnswer,
      partnerAnswer: partnerAnswer,
    );
  }
}
