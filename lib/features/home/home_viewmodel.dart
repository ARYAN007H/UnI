import 'package:flutter/foundation.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/daily_question_service.dart';

/// Thin state holder for Home (docs/design/home.md). Loads today's question
/// + reveal state; computes unread + next countdown from ChatService.
class HomeViewModel extends ChangeNotifier {
  final AuthService authService;
  final ChatService chatService;
  final DailyQuestionService dailyQuestionService;

  DailyQuestion? question;
  DailyAnswerState? answerState;
  bool loadingQuestion = true;

  HomeViewModel({
    required this.authService,
    required this.chatService,
    required this.dailyQuestionService,
  });

  Couple? get couple => authService.couple;
  Profile? get partner => authService.partnerProfile;
  String? get myId => authService.currentUser?.id;
  String? get partnerId => couple == null || myId == null
      ? null
      : couple!.partnerId(myId!);

  String? get _generalChannelId {
    for (final c in chatService.channels) {
      if (c.type == ChannelType.general) return c.id;
    }
    return chatService.channels.isEmpty ? null : chatService.channels.first.id;
  }

  int get unreadFromPartner {
    final channelId = _generalChannelId;
    if (channelId == null || partnerId == null || myId == null) return 0;
    return chatService
        .messagesForChannel(channelId)
        .where((m) => m.senderId == partnerId && !m.isReadBy(myId!))
        .length;
  }

  Plan? get nextPlan {
    final plansChannelId = _plansChannelId;
    if (plansChannelId == null) return null;
    final now = DateTime.now();
    final upcoming = chatService
        .plansForChannel(plansChannelId)
        .where((p) => !p.isCompleted && p.plannedDate != null && p.plannedDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.plannedDate!.compareTo(b.plannedDate!));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  String? get _plansChannelId {
    for (final c in chatService.channels) {
      if (c.type == ChannelType.plans) return c.id;
    }
    return null;
  }

  int get daysUntilNextPlan {
    final plan = nextPlan;
    if (plan?.plannedDate == null) return 0;
    final today = DateTime.now();
    final target = plan!.plannedDate!;
    final startOfDay = DateTime(today.year, today.month, today.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.difference(startOfDay).inDays;
  }

  Future<void> loadQuestion() async {
    final c = couple;
    final me = myId;
    if (c == null || me == null) {
      loadingQuestion = false;
      notifyListeners();
      return;
    }
    loadingQuestion = true;
    notifyListeners();
    try {
      final q = await dailyQuestionService.questionOfDay(c.id);
      final state = await dailyQuestionService.loadAnswers(
        coupleId: c.id,
        question: q,
        myUserId: me,
        partnerUserId: partnerId,
      );
      question = q;
      answerState = state;
    } catch (e) {
      question = null;
      answerState = null;
    } finally {
      loadingQuestion = false;
      notifyListeners();
    }
  }

  Future<void> submitAnswer(String content) async {
    final c = couple;
    final me = myId;
    final q = question;
    if (c == null || me == null || q == null) return;
    await dailyQuestionService.submitAnswer(
      coupleId: c.id,
      question: q,
      myUserId: me,
      content: content,
    );
    await loadQuestion();
  }

  /// Whether my sealed answer can still be edited (before both answered).
  bool get canEditAnswer =>
      answerState != null && !answerState!.bothAnswered && answerState!.myAnswer != null;

  void refreshCounts() => notifyListeners();
}
