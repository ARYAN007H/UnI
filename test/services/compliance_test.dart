import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:couple_chat/services/account_deletion_service.dart';
import 'package:couple_chat/services/crypto_service.dart';
import 'package:couple_chat/services/local_cache_service.dart';
import 'package:couple_chat/services/moderation_service.dart';
import 'package:couple_chat/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('account deletion — local wipe orchestration', () {
    late Directory tempDir;
    late LocalCacheService cache;
    late InMemoryKeyStore keyStore;
    late CryptoService crypto;
    late AccountDeletionService deletion;
    late File mediaFile;

    const userId = 'user-to-delete';
    const coupleId = 'couple-to-delete';

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('uni_wipe_test');
      cache = LocalCacheService();
      await cache.initialize(directory: tempDir.path);

      keyStore = InMemoryKeyStore();
      crypto = CryptoService(keyStore: keyStore);
      deletion = AccountDeletionService(
        crypto: crypto,
        cache: cache,
      ); // no client override — never touched by wipeLocalData

      // Seed: a message, a cached media file that exists on disk, and keys.
      mediaFile = File('${tempDir.path}/media/test.jpg');
      await mediaFile.create(recursive: true);
      await mediaFile.writeAsBytes([1, 2, 3, 4]);

      await cache.saveMessage(
        Message(
          id: 'm1',
          channelId: 'ch1',
          senderId: userId,
          coupleId: coupleId,
          content: 'doomed message',
          createdAt: DateTime.parse('2026-10-30T10:00:00Z'),
          updatedAt: DateTime.parse('2026-10-30T10:00:00Z'),
        ),
        synced: true,
      );
      await cache.cacheMediaPath('ref/test.jpg', mediaFile.path, sizeBytes: 4);

      await crypto.ensureDeviceKeypair(userId);
      crypto.trackCoupleKey(coupleId);
      // simulate a derived couple key existing on the device
      final pub =
          base64Decode((await keyStore.read('device_pub_$userId'))!);
      final priv =
          base64Decode((await keyStore.read('device_priv_$userId'))!);
      final key = await CryptoService.deriveCoupleKey(
        myPrivateKey: priv,
        partnerPublicKey: pub, // self-pairing for the test only
        coupleId: coupleId,
      );
      await crypto.storeKeyForTest(coupleId, key);
    });

    tearDown(() async {
      await cache.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('wipeLocalData destroys files, rows, and keys', () async {
      // Pre-state
      expect(await mediaFile.exists(), isTrue);
      expect(await cache.getMessages('ch1'), isNotEmpty);
      expect((await cache.listCachedMedia()), isNotEmpty);
      expect(await crypto.hasCoupleKey(coupleId, userId), isTrue);
      expect(await crypto.readPrivateKeyForTest(userId), isNotNull);

      await deletion.wipeLocalData(userId);

      expect(await mediaFile.exists(), isFalse, reason: 'media file deleted');
      expect(await cache.getMessages('ch1'), isEmpty,
          reason: 'messages cleared');
      expect(await cache.listCachedMedia(), isEmpty,
          reason: 'media index cleared');
      expect(await cache.getPendingOutbox(), isEmpty,
          reason: 'outbox cleared');
      expect(await crypto.readPrivateKeyForTest(userId), isNull,
          reason: 'device private key wiped');
    });

    test('wipeLocalData is safe to run twice', () async {
      await deletion.wipeLocalData(userId);
      await deletion.wipeLocalData(userId); // no throw
    });
  });

  group('moderation service guards (offline-pure parts)', () {
    test('isBlocked is false before initialize', () {
      final svc = ModerationService();
      expect(svc.isBlocked('anyone'), isFalse);
      expect(svc.initialized, isFalse);
    });

    test('self-report and self-block are rejected before any network call',
        () async {
      final svc = ModerationService();
      expect(
        await svc.report(
            reporterId: 'u1', reportedUserId: 'u1', reason: ReportReason.spam),
        isFalse,
      );
      expect(await svc.blockUser('u1', 'u1'), isFalse);
    });

    test('ReportReason names match migration 011 reasons', () {
      expect(
        ReportReason.values.map((r) => r.name).toSet(),
        equals({'harassment', 'ncii', 'minor', 'spam', 'other'}),
      );
    });
  });
}
