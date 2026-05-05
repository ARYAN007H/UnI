import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'local_cache_service.dart';

/// Google Drive backup service for the local SQLite database.
/// One-time setup: sign in with Google, then auto-backup.
class BackupService extends ChangeNotifier {
  static const _lastBackupKey = 'last_backup_time';
  static const _driveFileIdKey = 'drive_backup_file_id';
  static const _backupFileName = 'uni_backup.db';

  final LocalCacheService _cacheService;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.appdata'],
  );

  GoogleSignInAccount? _account;
  GoogleSignInAccount? get account => _account;
  bool get isSignedIn => _account != null;

  DateTime? _lastBackup;
  DateTime? get lastBackup => _lastBackup;

  bool _isBackingUp = false;
  bool get isBackingUp => _isBackingUp;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  String? _error;
  String? get error => _error;

  BackupService(this._cacheService);

  /// Initialize — check if already signed in.
  Future<void> initialize() async {
    try {
      _account = await _googleSignIn.signInSilently();
      final prefs = await SharedPreferences.getInstance();
      final lastStr = prefs.getString(_lastBackupKey);
      if (lastStr != null) _lastBackup = DateTime.tryParse(lastStr);
      notifyListeners();
    } catch (e) {
      debugPrint('[Backup] Init error: $e');
    }
  }

  /// Sign in to Google (one-time setup).
  Future<bool> signIn() async {
    try {
      _error = null;
      _account = await _googleSignIn.signIn();
      notifyListeners();
      return _account != null;
    } catch (e) {
      _error = 'Sign-in failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Sign out from Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
    notifyListeners();
  }

  /// Get auth headers for Google Drive API.
  Future<Map<String, String>?> _getHeaders() async {
    final auth = await _account?.authentication;
    if (auth?.accessToken == null) return null;
    return {
      'Authorization': 'Bearer ${auth!.accessToken}',
      'Content-Type': 'application/json',
    };
  }

  // ── Backup ─────────────────────────────────────────────

  /// Backup the SQLite database to Google Drive's appData folder.
  Future<bool> backup() async {
    if (_account == null) return false;

    try {
      _isBackingUp = true;
      _error = null;
      notifyListeners();

      final headers = await _getHeaders();
      if (headers == null) throw Exception('Not authenticated');

      // Get the DB file
      final dbPath = await _cacheService.getDatabasePath();
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) throw Exception('Database not found');

      final bytes = await dbFile.readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      final existingId = prefs.getString(_driveFileIdKey);

      if (existingId != null) {
        // Update existing backup
        final url = Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files/$existingId?uploadType=media');
        final resp = await http.patch(url, headers: {
          ...headers,
          'Content-Type': 'application/x-sqlite3',
        }, body: bytes);

        if (resp.statusCode != 200) {
          throw Exception('Upload failed: ${resp.statusCode}');
        }
      } else {
        // Create new backup file in appData
        // Step 1: Create metadata
        final metaUrl = Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart');

        final boundary = 'backup_boundary_${DateTime.now().millisecondsSinceEpoch}';
        final body = '--$boundary\r\n'
            'Content-Type: application/json; charset=UTF-8\r\n\r\n'
            '{"name":"$_backupFileName","parents":["appDataFolder"]}\r\n'
            '--$boundary\r\n'
            'Content-Type: application/x-sqlite3\r\n\r\n';
        final ending = '\r\n--$boundary--';

        final request = http.Request('POST', metaUrl);
        request.headers.addAll({
          ...headers,
          'Content-Type': 'multipart/related; boundary=$boundary',
        });
        request.bodyBytes = [
          ...body.codeUnits,
          ...bytes,
          ...ending.codeUnits,
        ];

        final resp = await http.Response.fromStream(await request.send());
        if (resp.statusCode == 200) {
          final fileId = RegExp(r'"id"\s*:\s*"([^"]+)"')
              .firstMatch(resp.body)
              ?.group(1);
          if (fileId != null) {
            await prefs.setString(_driveFileIdKey, fileId);
          }
        } else {
          throw Exception('Create failed: ${resp.statusCode}');
        }
      }

      _lastBackup = DateTime.now();
      await prefs.setString(_lastBackupKey, _lastBackup!.toIso8601String());

      _isBackingUp = false;
      notifyListeners();
      debugPrint('[Backup] Backup complete');
      return true;
    } catch (e) {
      _error = 'Backup failed: $e';
      _isBackingUp = false;
      notifyListeners();
      debugPrint('[Backup] Error: $e');
      return false;
    }
  }

  // ── Restore ────────────────────────────────────────────

  /// Restore the SQLite database from Google Drive.
  Future<bool> restore() async {
    if (_account == null) return false;

    try {
      _isRestoring = true;
      _error = null;
      notifyListeners();

      final headers = await _getHeaders();
      if (headers == null) throw Exception('Not authenticated');

      // Find backup file in appData
      final listUrl = Uri.parse(
          'https://www.googleapis.com/drive/v3/files'
          '?spaces=appDataFolder'
          '&q=name%3D%27$_backupFileName%27'
          '&fields=files(id,name,modifiedTime,size)');

      final listResp = await http.get(listUrl, headers: headers);
      if (listResp.statusCode != 200) {
        throw Exception('Failed to list files');
      }

      final fileIdMatch = RegExp(r'"id"\s*:\s*"([^"]+)"')
          .firstMatch(listResp.body);
      if (fileIdMatch == null) {
        throw Exception('No backup found on Google Drive');
      }

      final fileId = fileIdMatch.group(1)!;

      // Download the file
      final dlUrl = Uri.parse(
          'https://www.googleapis.com/drive/v3/files/$fileId?alt=media');
      final dlResp = await http.get(dlUrl, headers: headers);

      if (dlResp.statusCode != 200) {
        throw Exception('Download failed');
      }

      // Close current DB and replace
      await _cacheService.close();

      final dbPath = await _cacheService.getDatabasePath();
      final dbFile = File(dbPath);
      await dbFile.writeAsBytes(dlResp.bodyBytes);

      // Reinitialize
      await _cacheService.initialize();

      // Save the file ID for future updates
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_driveFileIdKey, fileId);

      _isRestoring = false;
      notifyListeners();
      debugPrint('[Backup] Restore complete');
      return true;
    } catch (e) {
      _error = 'Restore failed: $e';
      _isRestoring = false;
      notifyListeners();
      debugPrint('[Backup] Restore error: $e');
      return false;
    }
  }

  /// Check if a backup exists on Drive.
  Future<bool> hasBackup() async {
    if (_account == null) return false;
    try {
      final headers = await _getHeaders();
      if (headers == null) return false;

      final url = Uri.parse(
          'https://www.googleapis.com/drive/v3/files'
          '?spaces=appDataFolder'
          '&q=name%3D%27$_backupFileName%27'
          '&fields=files(id)');
      final resp = await http.get(url, headers: headers);
      return resp.body.contains('"id"');
    } catch (_) {
      return false;
    }
  }
}
