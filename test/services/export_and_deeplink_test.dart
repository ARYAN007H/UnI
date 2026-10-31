import 'package:flutter_test/flutter_test.dart';
import 'package:couple_chat/services/auth_service.dart';
import 'package:couple_chat/services/export_service.dart';

void main() {
  group('deep-link pairing parse', () {
    test('custom scheme with query code', () {
      expect(
        AuthService.extractPairCode(Uri.parse('uandi://pair?code=abc123')),
        'ABC123',
      );
      expect(
        AuthService.extractPairCode(
            Uri.parse('uandi://pair?invite_code=xyz789')),
        'XYZ789',
      );
    });

    test('web link with query code (any host)', () {
      expect(
        AuthService.extractPairCode(
            Uri.parse('https://uandi.app/pair?code=AbC123')),
        'ABC123',
      );
      expect(
        AuthService.extractPairCode(
            Uri.parse('https://some-cdn.example.com/pair?code=zzz9'),
            ),
        'ZZZ9',
      );
    });

    test('path-form code', () {
      expect(
        AuthService.extractPairCode(Uri.parse('https://uandi.app/pair/AB12CD')),
        'AB12CD',
      );
    });

    test('non-pairing links → null', () {
      expect(
        AuthService.extractPairCode(Uri.parse('https://uandi.app/home')),
        isNull,
      );
      expect(
        AuthService.extractPairCode(Uri.parse('mailto:someone@example.com')),
        isNull,
      );
      expect(AuthService.extractPairCode(Uri.parse('uandi://pair')), isNull);
      expect(AuthService.extractPairCode(Uri.parse('uandi://pair?code=')), isNull);
    });
  });

  group('export manifest (pure builder)', () {
    test('counts and media references are correct', () {
      final manifest = ExportService.buildManifest(
        coupleId: 'c1',
        channels: [
          {'id': 'ch1', 'name': 'general'},
        ],
        messagesByChannel: {
          'ch1': [
            {'id': 'm1', 'content': 'a'},
            {'id': 'm2', 'content': 'b'},
          ],
        },
        dailyAnswers: [
          {'question_id': 1, 'answer_date': '2026-10-30', 'user_id': 'u', 'content': 'x'},
        ],
        mediaEntries: [
          {
            'media_url': 'c1/images/abc.jpg',
            'local_path': '/tmp/media/abc.jpg',
            'size_bytes': 10,
          },
          {'media_url': 'c1/images/def.jpg', 'local_path': null},
        ],
      );

      expect(manifest['format'], 'uandi-export');
      expect(manifest['stats']['messages'], 2);
      expect(manifest['stats']['channels'], 1);
      expect(manifest['stats']['daily_answers'], 1);
      expect(manifest['stats']['media_files'], 1); // only cached ones count

      final media = manifest['media'] as List;
      expect(media.first['file'], 'abc.jpg');
      expect(media.first['cached_locally'], isTrue);
      expect(media.last['cached_locally'], isFalse);

      // legacy http refs map to their filename
      final legacy = ExportService.buildManifest(
        coupleId: 'c1',
        channels: const [],
        messagesByChannel: const {},
        dailyAnswers: const [],
        mediaEntries: [
          {
            'media_url': 'https://example.com/storage/c1/images/legacy.jpg',
            'local_path': '/tmp/legacy.jpg',
          },
        ],
      );
      expect((legacy['media'] as List).first['file'], 'legacy.jpg');
    });
  });
}
