import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:couple_chat/services/crypto_service.dart';

void main() {
  late CryptoService alice;
  late CryptoService bob;
  late InMemoryKeyStore aliceStore;
  late InMemoryKeyStore bobStore;

  const coupleId = 'couple-1234';
  const aliceId = 'user-alice';
  const bobId = 'user-bob';

  setUp(() async {
    aliceStore = InMemoryKeyStore();
    bobStore = InMemoryKeyStore();
    alice = CryptoService(keyStore: aliceStore);
    bob = CryptoService(keyStore: bobStore);

    // Both devices publish their public keys (skip the Supabase publish in
    // unit tests by writing the partner's key where getCoupleKey looks).
    final alicePub = await alice.ensureDeviceKeypair(aliceId);
    final bobPub = await bob.ensureDeviceKeypair(bobId);

    // Simulate the profiles table: each device can see the partner's pub.
    // getCoupleKey reads via Supabase, so pre-derive directly instead.
    final alicePriv =
        base64Decode((await aliceStore.read('device_priv_$aliceId'))!);
    final bobPriv = base64Decode((await bobStore.read('device_priv_$bobId'))!);

    final aliceKey = await CryptoService.deriveCoupleKey(
      myPrivateKey: alicePriv,
      partnerPublicKey: bobPub!,
      coupleId: coupleId,
    );
    final bobKey = await CryptoService.deriveCoupleKey(
      myPrivateKey: bobPriv,
      partnerPublicKey: alicePub!,
      coupleId: coupleId,
    );

    await aliceStore.write('couple_key_$coupleId', base64Encode(aliceKey));
    await bobStore.write('couple_key_$coupleId', base64Encode(bobKey));
  });

  group('ECDH couple key derivation', () {
    test('both devices derive the identical 32-byte key', () async {
      final a = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final b = base64Decode((await bobStore.read('couple_key_$coupleId'))!);
      expect(a, hasLength(32));
      expect(a, b);
    });

    test('different coupleId → different key', () async {
      final alicePriv =
          base64Decode((await aliceStore.read('device_priv_$aliceId'))!);
      final bobPub = base64Decode((await bobStore.read('device_pub_$bobId'))!);
      final other = await CryptoService.deriveCoupleKey(
        myPrivateKey: alicePriv,
        partnerPublicKey: bobPub,
        coupleId: 'another-couple',
      );
      final main = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      expect(other, isNot(main));
    });
  });

  group('media blob encryption round-trip', () {
    final media = Uint8List.fromList(
        List.generate(5000, (i) => (i * 37 + 11) & 0xFF)); // fake JPEG bytes

    test('encrypt → decrypt restores exact bytes', () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final encrypted = await alice.encryptWithKey(media, key);

      expect(encrypted, isNot(media));
      expect(alice.hasMagic(encrypted), isTrue);
      // ciphertext must not leak the plaintext header bytes
      expect(encrypted.sublist(4, 20), isNot(media.sublist(0, 16)));

      final decrypted = await bob.decryptWithKey(encrypted, key);
      expect(decrypted, media);
    });

    test('nonce uniqueness — same input encrypts differently', () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final e1 = await alice.encryptWithKey(media, key);
      final e2 = await alice.encryptWithKey(media, key);
      expect(e1, isNot(e2));
    });

    test('tampered ciphertext fails authentication', () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final encrypted = await alice.encryptWithKey(media, key);
      encrypted[encrypted.length - 20] ^= 0xFF; // flip a ciphertext bit

      expect(
        () => bob.decryptWithKey(encrypted, key),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('blobs without magic pass through untouched', () async {
      final legacy = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(alice.hasMagic(legacy), isFalse);

      final out = await alice.unprotectMedia(
        legacy,
        coupleId: coupleId,
        myUserId: aliceId,
      );
      expect(out, legacy);
    });

    test('encrypted blob without local key → MediaKeyMissingException',
        () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final encrypted = await alice.encryptWithKey(media, key);

      // A device that has never derived the couple key
      final fresh = CryptoService(keyStore: InMemoryKeyStore());
      expect(
        () => fresh.unprotectMedia(
          encrypted,
          coupleId: coupleId,
          myUserId: 'user-fresh',
        ),
        throwsA(isA<MediaKeyMissingException>()),
      );
    });
  });

  group('recovery escrow', () {
    test('seal → open round-trip with the right code', () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      const code = 'ABCDE-FGHJK-MNPQR-STUVW';

      final blob = await CryptoService.sealForRecovery(
        coupleKey: key,
        recoveryCode: code,
        coupleId: coupleId,
      );

      final recovered = await CryptoService.openForRecovery(
        sealedBlob: blob,
        recoveryCode: code,
        coupleId: coupleId,
      );
      expect(recovered, key);
    });

    test('wrong code fails authentication', () async {
      final key = base64Decode((await aliceStore.read('couple_key_$coupleId'))!);
      final blob = await CryptoService.sealForRecovery(
        coupleKey: key,
        recoveryCode: 'RIGHT-CODE-HERE-1234',
        coupleId: coupleId,
      );

      expect(
        () => CryptoService.openForRecovery(
          sealedBlob: blob,
          recoveryCode: 'WRONG-CODE-HERE-5678',
          coupleId: coupleId,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('recovery codes avoid confusing characters', () {
      for (var i = 0; i < 50; i++) {
        final code = CryptoService.generateRecoveryCode();
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('I'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.split('-'), hasLength(4));
      }
    });
  });
}
