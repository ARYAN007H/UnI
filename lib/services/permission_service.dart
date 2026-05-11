import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_storage_stub.dart' if (dart.library.js_interop) 'web_storage.dart' as web_storage;

/// Manages runtime permissions and tracks first-launch setup state.
/// On web, permissions are auto-granted (browser handles its own via HTML5 APIs).
class PermissionService extends ChangeNotifier {
  static const _setupCompleteKey = 'permission_setup_complete';
  static const _backupEnabledKey = 'backup_enabled';

  bool _setupComplete = false;
  bool get setupComplete => _setupComplete;

  bool _cameraGranted = false;
  bool _photosGranted = false;
  bool _microphoneGranted = false;
  bool _notificationGranted = false;
  bool _storageGranted = false;

  bool get cameraGranted => _cameraGranted;
  bool get photosGranted => _photosGranted;
  bool get microphoneGranted => _microphoneGranted;
  bool get notificationGranted => _notificationGranted;
  bool get storageGranted => _storageGranted;
  bool get allCriticalGranted => _notificationGranted && _storageGranted;

  bool _backupEnabled = false;
  bool get backupEnabled => _backupEnabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _setupComplete = prefs.getBool(_setupCompleteKey) ?? false;
    _backupEnabled = prefs.getBool(_backupEnabledKey) ?? false;

    // On web, auto-complete permission setup — browser handles permissions natively
    if (kIsWeb) {
      _cameraGranted = true;
      _photosGranted = true;
      _microphoneGranted = true;
      _notificationGranted = true;
      _storageGranted = true;
      if (!_setupComplete) {
        _setupComplete = true;
        await prefs.setBool(_setupCompleteKey, true);
      }
      notifyListeners();
      return;
    }

    await refreshPermissions();
    notifyListeners();
  }

  Future<void> refreshPermissions() async {
    if (kIsWeb) return;
    _cameraGranted = await Permission.camera.isGranted;
    _photosGranted = await Permission.photos.isGranted || await Permission.storage.isGranted;
    _microphoneGranted = await Permission.microphone.isGranted;
    _notificationGranted = await Permission.notification.isGranted;
    _storageGranted = await Permission.storage.isGranted;
    notifyListeners();
  }

  Future<bool> requestCamera() async {
    if (kIsWeb) { _cameraGranted = true; notifyListeners(); return true; }
    final s = await Permission.camera.request();
    _cameraGranted = s.isGranted;
    notifyListeners();
    return _cameraGranted;
  }

  Future<bool> requestPhotos() async {
    if (kIsWeb) { _photosGranted = true; notifyListeners(); return true; }
    var s = await Permission.photos.request();
    if (!s.isGranted) s = await Permission.storage.request();
    _photosGranted = s.isGranted;
    notifyListeners();
    return _photosGranted;
  }

  Future<bool> requestMicrophone() async {
    if (kIsWeb) { _microphoneGranted = true; notifyListeners(); return true; }
    final s = await Permission.microphone.request();
    _microphoneGranted = s.isGranted;
    notifyListeners();
    return _microphoneGranted;
  }

  Future<bool> requestNotifications() async {
    if (kIsWeb) { _notificationGranted = true; notifyListeners(); return true; }
    final s = await Permission.notification.request();
    _notificationGranted = s.isGranted;
    notifyListeners();
    return _notificationGranted;
  }

  Future<bool> requestStorage() async {
    if (kIsWeb) {
      _storageGranted = await web_storage.requestWebStorage();
    } else {
      final s = await Permission.storage.request();
      _storageGranted = s.isGranted;
    }
    notifyListeners();
    return _storageGranted;
  }

  Future<Map<String, bool>> requestAll() async {
    if (kIsWeb) {
      _cameraGranted = true;
      _photosGranted = true;
      _microphoneGranted = true;
      _notificationGranted = true;
      _storageGranted = await web_storage.requestWebStorage();
      notifyListeners();
      return { 'notifications': true, 'camera': true, 'photos': true, 'microphone': true, 'storage': _storageGranted };
    }
    return {
      'notifications': await requestNotifications(),
      'camera': await requestCamera(),
      'photos': await requestPhotos(),
      'microphone': await requestMicrophone(),
      'storage': await requestStorage(),
    };
  }

  Future<void> completeSetup() async {
    _setupComplete = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey, true);
    notifyListeners();
  }

  Future<void> setBackupEnabled(bool enabled) async {
    _backupEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);
    notifyListeners();
  }

  Future<void> openSettings() async {
    if (kIsWeb) return;
    await openAppSettings();
  }
}
