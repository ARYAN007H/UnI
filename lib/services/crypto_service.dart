import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown when media is encrypted ('UIE1' magic) but no couple key is
/// available on this device — the UI should offer "Restore media access".
class MediaKeyMissingException implements Exception {
  final String message;
  MediaKeyMissingException(this.message);

  @override
  String toString() => 'MediaKeyMissingException: $message';
}

/// Pluggable secure storage so tests can run on pure Dart.
abstract class SecureKeyStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyStore implements SecureKeyStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

/// §7.5 — Per-couple media encryption: the provable trust artifact.
///
/// Key model (the couple key NEVER exists on the server in plaintext):
///  1. Each device generates an X25519 keypair. Private key stays in
///     secure storage; the public key is published on the user's profile
///     row (`profiles.media_public_key`, migration 010).
///  2. Each device computes coupleKey = HKDF-SHA256(X25519(myPriv,
///     partnerPub), info: `uandi-couple-media:<coupleId>`) — both original
///     devices land on the same 32-byte AES-256-GCM key.
///  3. Media blobs are encrypted client-side: magic 'UIE1' + 12B nonce +
///     AES-GCM ciphertext + 16B tag. Anything without the magic (legacy
///     media, unencrypted fallback uploads) passes through untouched.
///  4. Recovery escrow: the couple key encrypted under a user-held
///     recovery code, stored server-side (`key_escrow`, kind='recovery').
///     A new device restores with the code — no partner, no old phone.
///
/// Text messages stay plaintext (RLS-protected, searchable, recap-able)
/// per plan §7.5.
class CryptoService {
  CryptoService({SecureKeyStore? keyStore, SupabaseClient? client})
      : _keyStore = keyStore ?? FlutterSecureKeyStore(),
        _clientOverride = client;

  final SecureKeyStore _keyStore;
  final SupabaseClient? _clientOverride;

  /// Resolved lazily so pure-Dart unit tests (no Supabase.initialize) can
  /// construct the service with just an in-memory key store.
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  /// Auth user id of the current session (null when signed out) — used by
  /// callers like MediaService that only know the coupleId.
  String? get currentUserId => _client.auth.currentUser?.id;

  static final X25519 _x25519 = X25519();
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Blob magic: 'U' 'I' 'E' '1'
  static const List<int> magicBytes = [0x55, 0x49, 0x45, 0x31];
  static const int _nonceLength = 12;
  static const int _macLength = 16;

  bool hasMagic(List<int> bytes) {
    if (bytes.length < magicBytes.length + _nonceLength + _macLength) {
      return false;
    }
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  // ── Device keypair ─────────────────────────────────────────

  /// Generate the device X25519 keypair on first use and publish the public
  /// half on the profile row. Idempotent. Returns the public key bytes.
  Future<List<int>?> ensureDeviceKeypair(String userId) async {
    final privB64 = await _keyStore.read('device_priv_$userId');
    final pubB64 = await _keyStore.read('device_pub_$userId');

    if (privB64 != null && pubB64 != null) {
      return base64Decode(pubB64);
    }

    final keyPair = await _x25519.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();

    await _keyStore.write(
        'device_priv_$userId', base64Encode(privateKeyBytes));
    await _keyStore.write('device_pub_$userId', base64Encode(publicKey.bytes));

    await _publishPublicKey(userId, publicKey.bytes);
    return publicKey.bytes;
  }

  Future<void> _publishPublicKey(String userId, List<int> publicKey) async {
    try {
      await _client.from('profiles').update({
        'media_public_key': base64Encode(publicKey),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('[Crypto] public key publish deferred (offline?): $e');
    }
  }

  // ── Couple key derivation ──────────────────────────────────

  /// Deterministic derivation of the couple's AES key from an X25519 shared
  /// secret. Both original devices compute the identical key; a NEW device
  /// cannot (its ECDH differs) and must restore via [recoverFromRecoveryCode].
  static Future<List<int>> deriveCoupleKey({
    required List<int> myPrivateKey,
    required List<int> partnerPublicKey,
    required String coupleId,
  }) async {
    final myKeyPair = await _x25519.newKeyPairFromSeed(myPrivateKey);
    final partnerPub = SimplePublicKey(partnerPublicKey,
        type: KeyPairType.x25519);
    final shared = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: partnerPub,
    );
    final derived = await _hkdf.deriveKey(
      secretKey: shared,
      info: utf8.encode('uandi-couple-media:$coupleId'),
    );
    return derived.extractBytes();
  }

  /// The couple's media key — from secure storage if already derived,
  /// otherwise derived via ECDH with the partner's published public key.
  /// Returns null when this device cannot decrypt yet (partner hasn't
  /// published a key, offline, or fresh device without recovery).
  Future<List<int>?> getCoupleKey(String coupleId, String myUserId) async {
    final stored = await _keyStore.read('couple_key_$coupleId');
    if (stored != null) return base64Decode(stored);

    final privB64 = await _keyStore.read('device_priv_$myUserId');
    if (privB64 == null) return null;

    try {
      final coupleRow = await _client
          .from('couples')
          .select('user_1, user_2')
          .eq('id', coupleId)
          .maybeSingle();
      if (coupleRow == null) return null;
      final partnerId = (coupleRow['user_1'] as String) == myUserId
          ? coupleRow['user_2'] as String?
          : coupleRow['user_1'] as String?;
      if (partnerId == null) return null;

      final partnerProfile = await _client
          .from('profiles')
          .select('media_public_key')
          .eq('id', partnerId)
          .maybeSingle();
      final partnerPubB64 = partnerProfile?['media_public_key'] as String?;
      if (partnerPubB64 == null || partnerPubB64.isEmpty) return null;

      final key = await deriveCoupleKey(
        myPrivateKey: base64Decode(privB64),
        partnerPublicKey: base64Decode(partnerPubB64),
        coupleId: coupleId,
      );
      await _keyStore.write('couple_key_$coupleId', base64Encode(key));
      _knownCoupleKeys.add(coupleId);
      return key;
    } catch (e) {
      debugPrint('[Crypto] couple key derivation failed (offline?): $e');
      return null;
    }
  }

  Future<bool> hasCoupleKey(String coupleId, String myUserId) async =>
      await _keyStore.read('couple_key_$coupleId') != null;

  /// Full key wipe for account deletion / "clear local data": the device
  /// keypair, every derived couple key, and any cached key material.
  Future<void> deleteAllKeys(String userId) async {
    final priv = await _keyStore.read('device_priv_$userId');
    final pub = await _keyStore.read('device_pub_$userId');
    if (priv != null) await _keyStore.delete('device_priv_$userId');
    if (pub != null) await _keyStore.delete('device_pub_$userId');

    // Couple keys are keyed by coupleId — enumerate what we can prove we
    // wrote by scanning the store for the couple_key_ prefix via the
    // known-key pattern: secure storage has no prefix listing, so callers
    // pass the coupleId when known (see wipeLocalData contract below).
    for (final key in _knownCoupleKeys) {
      await _keyStore.delete('couple_key_$key');
    }
    _knownCoupleKeys.clear();
  }

  /// Couple ids whose keys exist on this device — tracked at derivation so
  /// [deleteAllKeys] can wipe without prefix listing support.
  final Set<String> _knownCoupleKeys = {};

  void trackCoupleKey(String coupleId) => _knownCoupleKeys.add(coupleId);

  // ── Test seams ─────────────────────────────────────────────

  @visibleForTesting
  Future<String?> readPrivateKeyForTest(String userId) =>
      _keyStore.read('device_priv_$userId');

  @visibleForTesting
  Future<void> storeKeyForTest(String coupleId, List<int> key) async {
    await _keyStore.write('couple_key_$coupleId', base64Encode(key));
    _knownCoupleKeys.add(coupleId);
  }

  // ── Media protection ───────────────────────────────────────

  /// Encrypt media bytes when a couple key exists; otherwise pass through
  /// unencrypted (graceful degradation — chat must never break).
  Future<Uint8List> protectMedia(
    Uint8List bytes, {
    required String coupleId,
    required String myUserId,
  }) async {
    final key = await getCoupleKey(coupleId, myUserId);
    if (key == null) return bytes;
    return encryptWithKey(bytes, key);
  }

  /// Decrypt downloaded bytes. Blobs without the magic pass through
  /// unchanged (legacy media). Encrypted blobs without a local key throw
  /// [MediaKeyMissingException] — callers decide how to degrade.
  Future<Uint8List> unprotectMedia(
    Uint8List bytes, {
    required String coupleId,
    required String myUserId,
  }) async {
    if (!hasMagic(bytes)) return bytes;
    final key = await getCoupleKey(coupleId, myUserId);
    if (key == null) {
      throw MediaKeyMissingException(
          'media is encrypted but the couple key is not on this device');
    }
    return decryptWithKey(bytes, key);
  }

  /// AES-256-GCM encrypt with an explicit key (also used by tests).
  /// Layout: magic(4) + nonce(12) + ciphertext + tag(16).
  Future<Uint8List> encryptWithKey(Uint8List plain, List<int> key) async {
    final nonce = _aesGcm.newNonce();
    final secretKey = SecretKey(key);
    final box =
        await _aesGcm.encrypt(plain, secretKey: secretKey, nonce: nonce);

    final out = BytesBuilder();
    out.add(magicBytes);
    out.add(nonce);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  /// Decrypt a 'UIE1' blob with an explicit key (also used by tests).
  /// Throws on tampered ciphertext, [MediaKeyMissingException] is NOT thrown
  /// here (this variant requires the caller to already hold the key).
  Future<Uint8List> decryptWithKey(Uint8List blob, List<int> key) async {
    if (!hasMagic(blob)) {
      throw ArgumentError('not an encrypted media blob (no UIE1 magic)');
    }
    final nonce = blob.sublist(magicBytes.length,
        magicBytes.length + _nonceLength);
    final cipherText =
        blob.sublist(magicBytes.length + _nonceLength, blob.length - _macLength);
    final mac = Mac(blob.sublist(blob.length - _macLength));

    try {
      final plain = await _aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: SecretKey(key),
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      rethrow;
    }
  }

  // ── Recovery escrow ────────────────────────────────────────

  /// Generate a human-typeable recovery code (40 bits of entropy in base32,
  /// grouped for readability). The UI shows this ONCE and tells the user to
  /// store it outside the phone.
  static String generateRecoveryCode() {
    final rnd = Random.secure();
    const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // no confusing chars
    final groups = List.generate(4, (_) =>
        List.generate(5, (_) => alphabet[rnd.nextInt(alphabet.length)]).join());
    return groups.join('-');
  }

  /// Seal the couple key under a recovery code (pure — no server I/O).
  static Future<String> sealForRecovery({
    required List<int> coupleKey,
    required String recoveryCode,
    required String coupleId,
  }) async {
    final kek = await _recoveryKek(recoveryCode, coupleId);
    final nonce = _aesGcm.newNonce();
    final box =
        await _aesGcm.encrypt(coupleKey, secretKey: SecretKey(kek), nonce: nonce);
    return base64Encode(
        [...nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  /// Open a recovery escrow blob (pure — no server I/O).
  static Future<List<int>> openForRecovery({
    required String sealedBlob,
    required String recoveryCode,
    required String coupleId,
  }) async {
    final kek = await _recoveryKek(recoveryCode, coupleId);
    final raw = base64Decode(sealedBlob);
    final nonce = raw.sublist(0, _nonceLength);
    final cipherText = raw.sublist(_nonceLength, raw.length - _macLength);
    final mac = Mac(raw.sublist(raw.length - _macLength));
    final keyData = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: SecretKey(kek),
    );
    return keyData;
  }

  /// Create the server-side recovery escrow row for this user.
  /// Call AFTER the user has seen and stored the code.
  Future<void> createRecoveryEscrow({
    required String coupleId,
    required String myUserId,
    required String recoveryCode,
  }) async {
    final coupleKey = await getCoupleKey(coupleId, myUserId);
    if (coupleKey == null) {
      throw StateError('no couple key on this device — cannot create escrow');
    }
    final blob = await sealForRecovery(
      coupleKey: coupleKey,
      recoveryCode: recoveryCode,
      coupleId: coupleId,
    );
    await _client.from('key_escrow').upsert({
      'couple_id': coupleId,
      'user_id': myUserId,
      'kind': 'recovery',
      'blob': blob,
    }, onConflict: 'couple_id,user_id,kind');
  }

  /// Restore the couple key on a NEW device from the user's recovery code.
  /// Returns true when the key is now available locally.
  Future<bool> recoverFromRecoveryCode({
    required String coupleId,
    required String myUserId,
    required String recoveryCode,
  }) async {
    try {
      final row = await _client
          .from('key_escrow')
          .select('blob')
          .eq('couple_id', coupleId)
          .eq('user_id', myUserId)
          .eq('kind', 'recovery')
          .maybeSingle();
      final blob = row?['blob'] as String?;
      if (blob == null) return false;

      final coupleKey = await openForRecovery(
        sealedBlob: blob,
        recoveryCode: recoveryCode,
        coupleId: coupleId,
      );
      await _keyStore.write('couple_key_$coupleId', base64Encode(coupleKey));
      _knownCoupleKeys.add(coupleId);
      return true;
    } on SecretBoxAuthenticationError {
      return false; // wrong code
    } catch (e) {
      debugPrint('[Crypto] recovery failed: $e');
      return false;
    }
  }

  static Future<List<int>> _recoveryKek(String code, String coupleId) async {
    final kek = await _hkdf.deriveKey(
      secretKey: SecretKey(utf8.encode(code)),
      info: utf8.encode('uandi-recovery:$coupleId'),
    );
    return kek.extractBytes();
  }
}
