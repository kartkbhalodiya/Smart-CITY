import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/routes.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static const int _liveCallNotificationId = 7011;

  static Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationTap(response.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showAIAssistantNudge({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_assistant_nudges',
      'AI Assistant Nudges',
      channelDescription: 'Smart AI reminders for incomplete complaints',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _plugin.show(
      7001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: AppRoutes.aiChat,
    );
  }

  static Future<void> showLiveCallStatus({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_live_call',
      'AI Live Call',
      channelDescription: 'Ongoing live AI call status',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      onlyAlertOnce: false,
      showWhen: true,
      autoCancel: false,
      enableVibration: false,
      enableLights: false,
      playSound: false,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
    );

    await _plugin.show(
      _liveCallNotificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: AppRoutes.aiChat,
    );
  }

  static Future<void> cancelLiveCallStatus() async {
    await _plugin.cancel(_liveCallNotificationId);
  }

  static void _handleNotificationTap(String? payload) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    final routeName =
        (payload == null || payload.trim().isEmpty) ? AppRoutes.aiChat : payload;
    navigator.pushNamed(routeName);
  }
}
