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

/// A simple class to hold extracted GPS coordinates
class LocationData {
  final double latitude;
  final double longitude;
  const LocationData(this.latitude, this.longitude);
}

/// Handles media picking, compression, upload/download for couple media.
class MediaService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalCacheService? _cache;
  static const _uuid = Uuid();
  static const String _bucket = 'couple-media';

  MediaService({LocalCacheService? cache}) : _cache = cache;

  // Upload progress tracking
  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  // ── Image Picking ──────────────────────────────────────────

  /// Pick an image from the gallery.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickImage(
        source: source,
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
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

  /// Pick multiple images from the gallery.
  Future<List<XFile>> pickMultipleImages({
    int maxWidth = 1920,
    int maxHeight = 1920,
    int quality = 85,
  }) async {
    try {
      final picker = ImagePicker();
      return await picker.pickMultiImage(
        maxWidth: maxWidth.toDouble(),
        maxHeight: maxHeight.toDouble(),
        imageQuality: quality,
      );
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  // ── Upload ─────────────────────────────────────────────────

  /// Upload a file to Supabase Storage.
  /// Returns the public/signed URL of the uploaded file.
  /// Path structure: couple-media/{coupleId}/{type}/{uuid}.{ext}
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

      // Read file bytes
      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;

      // Determine MIME type
      final mimeType = _getMimeType(ext, type);

      // Upload to Supabase Storage
      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      _uploadProgress = 1.0;
      notifyListeners();

      // Get the URL
      final url = _client.storage.from(_bucket).getPublicUrl(storagePath);

      _isUploading = false;
      notifyListeners();

      return MediaUploadResult(
        url: url,
        storagePath: storagePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: fileSize,
      );
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  /// Upload raw bytes (for voice recordings).
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

      await _client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      _uploadProgress = 1.0;
      final url = _client.storage.from(_bucket).getPublicUrl(storagePath);

      _isUploading = false;
      notifyListeners();

      return MediaUploadResult(
        url: url,
        storagePath: storagePath,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: bytes.length,
      );
    } catch (e) {
      _isUploading = false;
      _uploadProgress = 0.0;
      notifyListeners();
      debugPrint('Error uploading bytes: $e');
      return null;
    }
  }

  // ── Download ───────────────────────────────────────────────

  /// Download a media file to local device storage.
  /// Returns the local path if successful, null otherwise.
  Future<String?> downloadMedia(String mediaUrl) async {
    if (kIsWeb) return null;
    try {
      if (_cache != null) {
        final cachedPath = await _cache.getMediaLocalPath(mediaUrl);
        if (cachedPath != null && await File(cachedPath).exists()) {
          return cachedPath;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final uri = Uri.parse(mediaUrl);
      final fileName = uri.pathSegments.last;
      final localPath = p.join(dir.path, 'media', fileName);

      final file = File(localPath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        // Save to cache
        await _cache?.cacheMediaPath(
          mediaUrl,
          localPath,
          sizeBytes: response.bodyBytes.length,
        );
        return localPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading media: $e');
      return null;
    }
  }

  // ── Delete ─────────────────────────────────────────────────

  /// Delete a file from storage.
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
      return val;
    }
    return 0.0;
  }

  // ── Helpers ────────────────────────────────────────────────

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

  /// Get signed URL for private bucket access.
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
  final String url;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  const MediaUploadResult({
    required this.url,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
  });
}
