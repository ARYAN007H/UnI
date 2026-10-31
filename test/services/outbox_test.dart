import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:couple_chat/services/local_cache_service.dart';
import 'package:couple_chat/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LocalCacheService cache;
  late Directory tempDir;

  setUp(() async {
    // Real isolation: a fresh temp dir per test (':memory:' joined with the
    // db name becomes a FILE path, so state would persist across tests).
    tempDir = await Directory.systemTemp.createTemp('uni_cache_test');
    cache = LocalCacheService();
    await cache.initialize(directory: tempDir.path);
  });

  tearDown(() async {
    await cache.close();
    await tempDir.delete(recursive: true);
  });

  Message msg(String id, {bool pending = false}) => Message(
        id: id,
        channelId: 'ch1',
        senderId: 'userA',
        coupleId: 'couple1',
        content: 'hello $id',
        createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
        isPending: pending,
      );

  group('outbox', () {
    test('enqueue → pending → bump → delete lifecycle', () async {
      await cache.enqueueOutbox('message.edit', {'id': 'm1', 'content': 'x'});
      await cache.enqueueOutbox('read.mark', {'channel_id': 'ch1', 'user_id': 'u1'});

      final pending = await cache.getPendingOutbox();
      expect(pending.length, 2);
      // FIFO by created_at
      expect(pending.first['op'], 'message.edit');

      await cache.bumpOutboxAttempt(pending.first['id'] as int, 'offline');
      final after = await cache.getPendingOutbox();
      expect((after.first['attempts'] as int), 1);
      expect(after.first['last_error'], 'offline');

      await cache.deleteOutboxEntry(after.first['id'] as int);
      expect((await cache.getPendingOutbox()).length, 1);
      expect(await cache.outboxCount, 1);
    });

    test('unsynced messages round-trip and markSynced', () async {
      await cache.saveMessage(msg('m1'), synced: false);
      await cache.saveMessage(msg('m2'), synced: true);

      final unsynced = await cache.getUnsyncedMessages();
      expect(unsynced.length, 1);
      expect(unsynced.first.id, 'm1');

      await cache.markSynced('m1');
      expect(await cache.getUnsyncedMessages(), isEmpty);
    });

    test('edit/delete tombstones apply locally', () async {
      await cache.saveMessage(msg('m1'), synced: true);

      final edited = (await cache.getMessages('ch1')).first.copyWithContent('edited');
      await cache.saveMessage(edited, synced: true);

      final afterEdit = await cache.getMessages('ch1');
      expect(afterEdit.first.content, 'edited');
      expect(afterEdit.first.isEdited, isTrue);

      await cache.deleteMessage('m1');
      final afterDelete = await cache.getMessages('ch1');
      expect(afterDelete.first.isDeleted, isTrue);
      expect(afterDelete.first.content, isNull);
    });

    test('daily answers save/load per user', () async {
      await cache.saveDailyAnswer(
        coupleId: 'c1',
        questionId: 7,
        answerDate: '2026-10-30',
        userId: 'uA',
        content: 'mine',
      );
      await cache.saveDailyAnswer(
        coupleId: 'c1',
        questionId: 7,
        answerDate: '2026-10-30',
        userId: 'uB',
        content: 'theirs',
      );

      final answers = await cache.getDailyAnswers(
          coupleId: 'c1', questionId: 7, answerDate: '2026-10-30');
      expect(answers['uA'], 'mine');
      expect(answers['uB'], 'theirs');

      final all = await cache.getAllDailyAnswers('c1');
      expect(all.length, 2);
    });
  });
}
