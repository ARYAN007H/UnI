import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages push notification token registration and local notification display.
///
/// NOTE: Full push notification functionality requires:
/// 1. Firebase project setup + google-services.json / GoogleService-Info.plist
/// 2. Adding `firebase_messaging` and `flutter_local_notifications` to pubspec.yaml
/// 3. A Supabase Edge Function to send pushes on new messages
///
/// This service provides the token management and Supabase integration layer.
/// Uncomment the Firebase imports and methods once Firebase is configured.
class NotificationService extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;
  final bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize the notification service.
  /// Call this after authentication is confirmed.
  Future<void> initialize(String userId) async {
    // TODO: Uncomment when Firebase is configured
    //
    // final messaging = FirebaseMessaging.instance;
    //
    // // Request permission
    // final settings = await messaging.requestPermission(
    //   alert: true,
    //   badge: true,
    //   sound: true,
    //   provisional: false,
    // );
    //
    // _permissionGranted = settings.authorizationStatus ==
    //     AuthorizationStatus.authorized;
    //
    // if (!_permissionGranted) {
    //   debugPrint('Notification permission denied');
    //   return;
    // }
    //
    // // Get FCM token
    // _fcmToken = await messaging.getToken();
    // if (_fcmToken != null) {
    //   await _registerToken(userId, _fcmToken!);
    // }
    //
    // // Listen for token refresh
    // messaging.onTokenRefresh.listen((newToken) {
    //   _fcmToken = newToken;
    //   _registerToken(userId, newToken);
    // });
    //
    // // Handle foreground messages
    // FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    //
    // // Handle background/terminated notification taps
    // FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    //
    // notifyListeners();

    debugPrint('[NotificationService] Initialized (Firebase not yet configured)');
  }

  /// Register the FCM token in Supabase.
  // ignore: unused_element - used when Firebase is configured
  Future<void> _registerToken(String userId, String token) async {
    try {
      await _client.from('devices').upsert({
        'user_id': userId,
        'fcm_token': token,
        'platform': _getPlatform(),
        'device_name': 'Flutter App',
      }, onConflict: 'user_id,fcm_token');

      debugPrint('[NotificationService] Token registered');
    } catch (e) {
      debugPrint('[NotificationService] Error registering token: $e');
    }
  }

  /// Remove the FCM token on logout.
  Future<void> removeToken(String userId) async {
    if (_fcmToken == null) return;

    try {
      await _client
          .from('devices')
          .delete()
          .eq('user_id', userId)
          .eq('fcm_token', _fcmToken!);

      debugPrint('[NotificationService] Token removed');
    } catch (e) {
      debugPrint('[NotificationService] Error removing token: $e');
    }
  }

  String _getPlatform() {
    // Detect platform
    if (kIsWeb) return 'web';
    // For mobile, we default to android. When running on iOS, override accordingly.
    return 'android';
  }

  // ── Foreground Message Handler ────────────────────────────

  // void _handleForegroundMessage(RemoteMessage message) {
  //   debugPrint('[NotificationService] Foreground message: ${message.messageId}');
  //
  //   // Show local notification
  //   final notification = message.notification;
  //   if (notification != null) {
  //     _showLocalNotification(
  //       title: notification.title ?? 'U&i',
  //       body: notification.body ?? 'New message',
  //       payload: message.data['channel_id'],
  //     );
  //   }
  // }

  // void _handleNotificationTap(RemoteMessage message) {
  //   debugPrint('[NotificationService] Notification tapped: ${message.data}');
  //   // Navigate to the relevant channel
  //   // This requires a global navigator key or a callback
  // }

  // ── Local Notifications ───────────────────────────────────

  // Future<void> _showLocalNotification({
  //   required String title,
  //   required String body,
  //   String? payload,
  // }) async {
  //   // Use flutter_local_notifications to display
  //   // final details = NotificationDetails(
  //   //   android: AndroidNotificationDetails(
  //   //     'couple_chat_messages',
  //   //     'Messages',
  //   //     channelDescription: 'New message notifications',
  //   //     importance: Importance.high,
  //   //     priority: Priority.high,
  //   //     showWhen: true,
  //   //   ),
  //   //   iOS: DarwinNotificationDetails(
  //   //     presentAlert: true,
  //   //     presentBadge: true,
  //   //     presentSound: true,
  //   //   ),
  //   // );
  //   //
  //   // await flutterLocalNotificationsPlugin.show(
  //   //   DateTime.now().millisecondsSinceEpoch ~/ 1000,
  //   //   title,
  //   //   body,
  //   //   details,
  //   //   payload: payload,
  //   // );
  // }


}
