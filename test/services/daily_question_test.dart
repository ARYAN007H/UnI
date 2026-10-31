import 'package:flutter_test/flutter_test.dart';
import 'package:couple_chat/services/daily_question_service.dart';

void main() {
  group('daily question derivation (§7.4)', () {
    test('same couple + same date → same index', () {
      const couple = '11111111-2222-3333-4444-555555555555';
      final a = DailyQuestionService.deriveQuestionIndex(
          coupleId: couple, dateKey: '2026-10-30', bankLength: 365);
      final b = DailyQuestionService.deriveQuestionIndex(
          coupleId: couple, dateKey: '2026-10-30', bankLength: 365);
      expect(a, b);
    });

    test('different couples → (virtually always) different indexes', () {
      final a = DailyQuestionService.deriveQuestionIndex(
          coupleId: 'couple-aaaa', dateKey: '2026-10-30', bankLength: 365);
      final b = DailyQuestionService.deriveQuestionIndex(
          coupleId: 'couple-bbbb', dateKey: '2026-10-30', bankLength: 365);
      expect(a, isNot(b)); // with 365 buckets this is overwhelming odds
    });

    test('UTC date key rolls over at midnight UTC', () {
      expect(
        DailyQuestionService.dateKeyFor(DateTime.parse('2026-10-30T23:59:59Z')),
        '2026-10-30',
      );
      expect(
        DailyQuestionService.dateKeyFor(DateTime.parse('2026-10-31T00:00:00Z')),
        '2026-10-31',
      );
      // Local evening that is already tomorrow in UTC
      expect(
        DailyQuestionService.dateKeyFor(DateTime.parse('2026-10-31T01:30:00+05:30')),
        '2026-10-30',
      );
    });

    test('index always lands inside the bank', () {
      for (var day = 0; day < 400; day++) {
        final idx = DailyQuestionService.deriveQuestionIndex(
          coupleId: 'couple-x',
          dateKey: '2026-01-${(day % 28 + 1).toString().padLeft(2, '0')}',
          bankLength: 10,
        );
        expect(idx, inInclusiveRange(0, 9));
      }
    });

    test('degenerate banks are safe', () {
      expect(
        DailyQuestionService.deriveQuestionIndex(
            coupleId: 'c', dateKey: 'd', bankLength: 1),
        0,
      );
      expect(
        DailyQuestionService.deriveQuestionIndex(
            coupleId: 'c', dateKey: 'd', bankLength: 0),
        0,
      );
    });

    test('fallback bank is well-formed (both devices derive identically)',
        () {
      final bank = DailyQuestionService.fallbackBank;
      expect(bank.length, 10);
      for (final q in bank) {
        expect(q.text, isNotEmpty);
        expect(q.category, isIn(['ldr', 'playful', 'deep', 'memory']));
      }
    });
  });
}
