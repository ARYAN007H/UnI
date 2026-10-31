import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:exif/exif.dart';
import 'local_cache_service.dart';
import 'crypto_service.dart';
import 'media/blurhash.dart';
import 'media/exif_strip.dart';

/// A simple class to hold extracted GPS coordinates
class LocationData {
  final double latitude;
  final double longitude;
  const LocationData(this.latitude, this.longitude);
}

/// Handles media picking, privacy prep (EXIF strip + BlurHash), upload and
/// download for couple media.
///
/// §7.2 pipeline: an Edge Function (`media-url`) mints presigned URLs and the
/// device uploads **directly to a private R2 bucket** — bytes never pass
/// through Supabase and nothing is publicly fetchable. Images additionally
/// get their EXIF stripped client-side (GPS extracted first, for the globe)
/// and a BlurHash stored in the message's thumbnail field so the partner's
/// UI renders an instant placeholder.
///
/// Until the Edge Function + R2 are configured (Phase 3), uploads fall back
/// to the legacy Supabase Storage path so the app stays functional.
class MediaService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  LocalCacheService? _cache;
  bool _ownsCache = false;
  static const _uuid = Uuid();
  static const String _bucket = 'couple-media';

  /// §7.5: when a couple key is available, uploaded blobs are AES-GCM
  /// encrypted client-side ('UIE1' magic) and downloads are decrypted
  /// before caching. Nullable so tests and pre-pairing runs pass through.
  CryptoService? _crypto;
  CryptoService get crypto => _crypto ??= CryptoService();

  MediaService({LocalCacheService? cache, CryptoService? crypto})
      : _cache = cache,
        _crypto = crypto;

  /// The cache is mandatory (§7.1): self-heal if the caller didn't inject one.
  Future<LocalCacheService?> _ensureCache() async {
    if (_cache != null) return _cache;
    final own = LocalCacheService();
    try {
      await own.initialize();
      _cache = own;
      _ownsCache = true;
    } catch (e) {
      debugPrint('[MediaService] self-healed cache init failed: $e');
    }
    return _cache;
  }

  // Upload progress tracking
  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  // ── Image Picking ──────────────────────────────────────────

  /// Pick an image. Defaults to UNCOMPRESSED so EXIF/GPS extraction still
  /// works; [stripJpegExif] removes EXIF before upload (privacy), so the
  /// original size is temporary and never leaves the device uncompressed.
  ///
  /// [maxWidth]/[maxHeight]/[quality] are accepted for v1 call-site
  /// compatibility and deliberately IGNORED: picker-side compression strips
  /// EXIF before we can read the GPS for the globe.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(source: source);
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Pick a video from the gallery.
  Future<XFile?> pickVideo({
    ImageSource source = ImageSource.gallery,
    Duration maxDuration = const Duration(minutes: 5),
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );
    } catch (e) {
      debugPrint('Error picking video: $e');
      return null;
    }
  }

  /// Pick multiple images (uncompressed, see [pickImage]; size params
  /// accepted for v1 compatibility and ignored). Note: image_picker's
  /// pickMultiImage takes no source parameter.
  Future<List<XFile>> pickMultipleImages({
    int? maxWidth,
    int? maxHeight,
    int? quality,
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickMultiImage();
    } catch (e) {
      debugPrint('Error picking images: $e');
      return [];
    }
  }

  // ── Upload ─────────────────────────────────────────────────

  /// Upload a file through the §7.2 pipeline.
  ///
  /// Returns a result whose [MediaUploadResult.url] is the private-bucket
  /// OBJECT PATH (never a public URL) plus the image BlurHash when usable.
  Future<MediaUploadResult?> uploadFile({
    required String coupleId,
    required XFile file,
    required MediaType type,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      final ext = p.extension(file.path).toLowerCase().replaceAll('.', '');
      final fileName = '${_uuid.v4()}.$ext';
      final storagePath = '$coupleId/${type.folder}/$fileName';
      final mimeType = _getMimeType(ext, type);

      Uint8List? bytes; // only loaded when needed (web / images / voice)
      if (kIsWeb || type == MediaType.image) {
        bytes = await file.readAsBytes();
      }

      // Privacy prep for images: GPS was extracted by the caller BEFORE
      // this call (they need it for the globe); now strip EXIF and hash.
      String? blurHash;
      var uploadBytes = bytes;
      if (type == MediaType.image && bytes != null) {
        final stripped = stripJpegExif(bytes);
        if (!identical(stripped, bytes)) {
          debugPrint('[MediaService] EXIF stripped from image');
        }
        uploadBytes = stripped;
        blurHash = await encodeBlurHash(stripped);
      }

      // §7.5: encrypt when the couple key is available. For streamed video
      // this means buffering once (accepted tradeoff — encryption is the
      // normal post-pairing state; pre-pairing runs stream as before).
      final uid = crypto.currentUserId;
      if (uploadBytes == null && uid != null) {
        final willEncrypt = await crypto.hasCoupleKey(coupleId, uid);
        if (willEncrypt) {
          uploadBytes = await file.readAsBytes();
        }
      }
      if (uploadBytes != null && uid != null) {
        uploadBytes = await crypto.protectMedia(
          uploadBytes,
          coupleId: coupleId,
          myUserId: uid,
        );
      }

      MediaUploadResult? result;
      try {
        result = await _presignedUpload(
          storagePath: storagePath,
          mimeType: mimeType,
          file: file,
          bytes: uploadBytes,
          progressFrom: 0.0,
          progressTo: 1.0,
        );
        result = MediaUploadResult(
          url: result.url,
          storagePath: result.storagePath,
          fileName: result.fileName,
          mimeType: result.mimeType,
          sizeBytes: result.sizeBytes,
          blurHash: blurHash,
        );
      } catch (e) {
        debugPrint('[MediaService] presigned path unavailable, legacy fallback: $e');
        result = await _legacyUpload(
          storagePath: storagePath,
          mimeType: mimeType,
          file: file,
          bytes: uploadBytes,
        );
        result = MediaUploadResult(
          url: result.url,
          storagePath: result.storagePath,
          fileName: result.fileName,
          mimeType: result.mimeType,
          sizeBytes: result.sizeBytes,
          blurHash: blurHash,
        );
      }

      _uploadProgress = 1.0;
      _isUploading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// Upload raw bytes (voice recordings) through the same pipeline.
  Future<MediaUploadResult?> uploadBytes({
    required String coupleId,
    required Uint8List bytes,
    required String extension,
    required MediaType type,
  }) async {
    try {
      _isUploading = true;
      _uploadProgress = 0.0;
      notifyListeners();

      final fileName = '${_uuid.v4()}.$extension';
      final storagePath = '$coupleId/${type.folder}/$fileName';
      final mimeType = _getMimeType(extension, type);

      final result = await _presignedUpload(
        storagePath: storagePath,
        mimeType: mimeType,
        bytes: bytes,
        progressFrom: 0.0,
        progressTo: 1.0,
      ).catchError((_) async {
        debugPrint('[MediaService] presigned path unavailable, legacy fallback');
        return _legacyUpload(
          storagePath: storagePath,
          mimeType: mimeType,
          bytes: bytes,
        );
      });

      _isUploading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('Error uploading bytes: $e');
      return null;
    }
  }

  /// Ask the `media-url` Edge Function for a presigned PUT and upload
  /// directly to R2. Native uses a streamed request so large files never
  /// sit fully in RAM; web always has bytes.
  Future<MediaUploadResult> _presignedUpload({
    required String storagePath,
    required String mimeType,
    XFile? file,
    Uint8List? bytes,
    required double progressFrom,
    required double progressTo,
  }) async {
    final fnResponse = await _client.functions.invoke(
      'media-url',
      body: {
        'action': 'upload',
        'path': storagePath,
        'contentType': mimeType,
      },
    );
    final data = fnResponse.data as Map<dynamic, dynamic>;
    final uploadUrl = data['uploadUrl'] as String?;
    if (uploadUrl == null) {
      throw StateError('media-url returned no uploadUrl');
    }

    final uri = Uri.parse(uploadUrl);
    http.BaseResponse response;

    if (bytes != null) {
      // Images (EXIF-stripped bytes — the disk file is NOT what we upload),
      // voice notes, and web: bytes are already in memory.
      response = await http.put(
        uri,
        headers: {'Content-Type': mimeType},
        body: bytes,
      );
      _uploadProgress = progressTo;
      notifyListeners();
    } else if (file != null) {
      // Native video-only path: stream from disk — no full-file RAM spike.
      final length = await file.length();
      final request = http.StreamedRequest('PUT', uri)
        ..headers['Content-Type'] = mimeType
        ..contentLength = length;

      var sent = 0;
      file.openRead().listen(
            (chunk) {
              sent += chunk.length;
              _uploadProgress = progressFrom +
                  (progressTo - progressFrom) * (sent / length);
              notifyListeners();
              request.sink.add(chunk);
            },
            onDone: request.sink.close,
            onError: (Object e) => request.sink.close(),
          );

      response = await http.Response.fromStream(await request.send());
    } else {
      throw StateError('nothing to upload');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('R2 upload failed: HTTP ${response.statusCode}');
    }

    return MediaUploadResult(
      url: storagePath, // object PATH — resolved via signed URLs on read
      storagePath: storagePath,
      fileName: p.basename(storagePath),
      mimeType: mimeType,
      sizeBytes: bytes?.length ?? await file?.length() ?? 0,
    );
  }

  /// Legacy v1 path (Supabase Storage) — kept as fallback until the R2
  /// Edge Function is configured in Phase 3.
  Future<MediaUploadResult> _legacyUpload({
    required String storagePath,
    required String mimeType,
    XFile? file,
    Uint8List? bytes,
  }) async {
    final data = bytes ?? await file!.readAsBytes();
    await _client.storage.from(_bucket).uploadBinary(
          storagePath,
          data,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    final url = _client.storage.from(_bucket).getPublicUrl(storagePath);
    return MediaUploadResult(
      url: url,
      storagePath: storagePath,
      fileName: p.basename(storagePath),
      mimeType: mimeType,
      sizeBytes: data.length,
    );
  }

  // ── Download ───────────────────────────────────────────────

  /// Resolve a media reference to a local file path (cached).
  /// [mediaUrl] is either an object PATH (§7.2) or a legacy http(s) URL.
  Future<String?> downloadMedia(String mediaUrl) async {
    if (kIsWeb) return null;
    try {
      final cache = await _ensureCache();
      final cachedPath = await cache?.getMediaLocalPath(mediaUrl);
      if (cachedPath != null && await File(cachedPath).exists()) {
        return cachedPath;
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName = mediaUrl.contains('/')
          ? Uri.parse(mediaUrl).pathSegments.last
          : mediaUrl;
      final localPath = p.join(dir.path, 'media', fileName);

      final file = File(localPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      http.Response response;
      if (mediaUrl.startsWith('http')) {
        response = await http.get(Uri.parse(mediaUrl));
      } else {
        // §7.2: private R2 object — mint a short-lived signed GET.
        final signed = await _client.functions.invoke(
          'media-url',
          body: {'action': 'download', 'path': mediaUrl},
        );
        final url = (signed.data as Map<dynamic, dynamic>)['downloadUrl'] as String?;
        if (url == null) throw StateError('media-url returned no downloadUrl');
        response = await http.get(Uri.parse(url));
      }

      if (response.statusCode == 200) {
        var blob = response.bodyBytes;

        // §7.5: decrypt before caching. No magic (legacy) → passthrough.
        // Encrypted but no local key → cache the encrypted bytes anyway
        // (chat never breaks; UI shows the BlurHash + "restore access").
        try {
          blob = await crypto.unprotectMedia(
            blob,
            coupleId: coupleIdOfPath(mediaUrl),
            myUserId: crypto.currentUserId ?? '',
          );
        } on MediaKeyMissingException catch (e) {
          debugPrint('[MediaService] key missing, caching encrypted: $e');
        }

        await file.writeAsBytes(blob);
        await cache?.cacheMediaPath(
          mediaUrl,
          localPath,
          sizeBytes: blob.length,
        );
        return localPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading media: $e');
      return null;
    }
  }

  /// The first path segment of an object path is the coupleId (§7.2 layout).
  /// Legacy http URLs have no couple segment — returns the URL itself so the
  /// crypto layer's key lookup simply misses and passes through.
  static String coupleIdOfPath(String mediaUrl) {
    if (mediaUrl.startsWith('http')) return mediaUrl;
    return mediaUrl.split('/').first;
  }

  // ── Delete ─────────────────────────────────────────────────

  /// Delete a file from storage (legacy bucket; R2 cleanup is handled by
  /// the lifecycle rules on the bucket itself).
  Future<bool> deleteFile(String storagePath) async {
    try {
      await _client.storage.from(_bucket).remove([storagePath]);
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  // ── EXIF Data Extraction ───────────────────────────────────

  /// Extracts latitude and longitude from image bytes using the exif package.
  /// MUST be called before upload — the uploader strips EXIF (privacy).
  Future<LocationData?> extractLocationFromImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final data = await readExifFromBytes(bytes);

      if (data.containsKey('GPS GPSLatitude') &&
          data.containsKey('GPS GPSLongitude') &&
          data.containsKey('GPS GPSLatitudeRef') &&
          data.containsKey('GPS GPSLongitudeRef')) {
        final latValues = data['GPS GPSLatitude']!.values.toList();
        final lonValues = data['GPS GPSLongitude']!.values.toList();
        final latRef = data['GPS GPSLatitudeRef']!.printable;
        final lonRef = data['GPS GPSLongitudeRef']!.printable;

        double convertToDecimal(List<dynamic> values, String ref) {
          if (values.length < 3) return 0.0;

          double degrees = _evalRatio(values[0]);
          double minutes = _evalRatio(values[1]);
          double seconds = _evalRatio(values[2]);

          double decimal = degrees + (minutes / 60.0) + (seconds / 3600.0);
          if (ref == 'S' || ref == 'W') {
            decimal = -decimal;
          }
          return decimal;
        }

        final lat = convertToDecimal(latValues, latRef);
        final lon = convertToDecimal(lonValues, lonRef);

        if (lat != 0.0 && lon != 0.0) {
          return LocationData(lat, lon);
        }
      }
    } catch (e) {
      debugPrint('Error extracting EXIF: $e');
    }
    return null;
  }

  double _evalRatio(dynamic val) {
    if (val is Ratio) {
      return val.numerator / val.denominator;
    }
    if (val is int) {
      return val.toDouble();
    }
    if (val is double) {
      return val.toDouble();
    }
    return 0.0;
  }

  // ── Helpers ──────────────────────────────────────────────

  String _getMimeType(String ext, MediaType type) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return type == MediaType.video ? 'video/mp4' : 'audio/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Get signed URL for private bucket access (legacy fallback path).
  Future<String?> getSignedUrl(String storagePath, {int expiresIn = 3600}) async {
    try {
      final url = await _client.storage
          .from(_bucket)
          .createSignedUrl(storagePath, expiresIn);
      return url;
    } catch (e) {
      debugPrint('Error getting signed URL: $e');
      return null;
    }
  }

  @override
  void dispose() {
    if (_ownsCache) {
      _cache?.close();
    }
    super.dispose();
  }
}

// ── Data Classes ─────────────────────────────────────────────

enum MediaType {
  image,
  video,
  voice,
  file;

  String get folder {
    switch (this) {
      case MediaType.image:
        return 'images';
      case MediaType.video:
        return 'videos';
      case MediaType.voice:
        return 'voice';
      case MediaType.file:
        return 'files';
    }
  }
}

class MediaUploadResult {
  /// Object PATH for the §7.2 private-bucket pipeline, or a public URL on
  /// the legacy fallback. The UI never assumes which — always resolve
  /// through [MediaService.downloadMedia].
  final String url;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// BlurHash string for images (null for voice/video/file). UI stores it
  /// in `message.mediaThumbnailUrl` prefixed with `blurhash:`.
  final String? blurHash;

  const MediaUploadResult({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    this.blurHash,
  });
}
