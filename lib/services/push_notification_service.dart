import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level handler for FCM when the app is backgrounded / terminated.
/// iOS still shows system banners from the APNs `alert` payload without this;
/// the handler keeps Android data messages and tap routing consistent.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // Config missing on this isolate — ignore.
  }
}

/// FCM + local banners for friend pings / chat / requests.
class PushNotificationService {
  PushNotificationService();

  static const _androidChannelId = 'blind_tiger_social';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _firebaseReady = false;
  String? _deviceToken;
  String? _apnsToken;
  void Function(String token)? onDeviceToken;
  void Function(String token)? onApnsToken;
  void Function(Map<String, dynamic> payload)? onNotificationTap;
  /// Fired for FCM messages while the app is in the foreground.
  void Function(Map<String, dynamic> data)? onForegroundMessage;
  /// When false, skip local OS banners (in-app island handles delivery).
  bool Function()? shouldShowLocalInForeground;

  String? get deviceToken => _deviceToken;
  String? get apnsToken => _apnsToken;
  bool get isFirebaseReady => _firebaseReady;

  Future<void> init() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        onNotificationTap?.call({'payload': raw});
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _androidChannelId,
        'Blind Tiger Social',
        description: 'Friend pings, chat, and requests',
        importance: Importance.high,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint(
        'Firebase not configured yet (add GoogleService-Info.plist / '
        'google-services.json): $e',
      );
      _ready = true;
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      // Island banner owns foreground UX; OS banners are for background.
      alert: false,
      badge: true,
      sound: true,
    );

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    await _refreshToken();
    messaging.onTokenRefresh.listen((token) {
      _deviceToken = token;
      onDeviceToken?.call(token);
    });

    FirebaseMessaging.onMessage.listen((message) {
      final data = Map<String, dynamic>.from(message.data);
      onForegroundMessage?.call(data);

      final showLocal = shouldShowLocalInForeground?.call() ?? true;
      if (!showLocal) return;

      final title = message.notification?.title ??
          message.data['title'] as String? ??
          'Blind Tiger';
      final body = message.notification?.body ??
          message.data['body'] as String? ??
          '';
      final id = message.messageId ??
          message.data['notification_id'] as String? ??
          title;
      unawaited(showSocialAlert(id: id, title: title, body: body));
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onNotificationTap?.call(Map<String, dynamic>.from(message.data));
    });

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      onNotificationTap?.call(Map<String, dynamic>.from(initial.data));
    }

    _ready = true;
  }

  /// Re-fetch APNs + FCM tokens (call after login / resume).
  Future<void> refreshTokens() => _refreshToken();

  Future<void> _refreshToken() async {
    try {
      if (Platform.isIOS) {
        // APNs token must exist before FCM can mint an iOS registration token.
        for (var attempt = 0; attempt < 8; attempt++) {
          final apns = await FirebaseMessaging.instance.getAPNSToken();
          if (apns != null && apns.isNotEmpty) {
            if (_apnsToken != apns) {
              _apnsToken = apns;
              onApnsToken?.call(apns);
              debugPrint('APNs token ready (${apns.substring(0, 12)}…)');
            }
            break;
          }
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
        if (_apnsToken == null) {
          debugPrint(
            'APNs token still null — ensure Push capability, '
            'registerForRemoteNotifications, and notification permission.',
          );
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      if (_deviceToken != token) {
        _deviceToken = token;
        onDeviceToken?.call(token);
        debugPrint('FCM token ready (${token.substring(0, 12)}…)');
      }
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
    }
  }

  Future<void> showSocialAlert({
    required String id,
    required String title,
    required String body,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;

    final android = AndroidNotificationDetails(
      _androidChannelId,
      'Blind Tiger Social',
      channelDescription: 'Friend pings, chat, and requests',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
    );
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: android, iOS: ios),
      payload: id,
    );
  }
}
