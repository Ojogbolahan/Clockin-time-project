import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'office_clockin_channel';
  static const String channelName = 'Clock-In Alarms';
  static const String channelDesc =
      'High priority alerts to prompt clocking in when connected to office Wi-Fi.';

  Function(String? payload)? onNotificationTapped;
  Function()? onClockInActionTriggered;

  Future<void> initialize({
    Function(String? payload)? onSelectNotification,
    Function()? onClockInAction,
  }) async {
    onNotificationTapped = onSelectNotification;
    onClockInActionTriggered = onClockInAction;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'CLOCK_IN_CATEGORY',
          actions: [
            DarwinNotificationAction.plain(
              'ACTION_CLOCK_IN',
              'Clock In Now',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              'ACTION_DISMISS',
              'Dismiss',
              options: {DarwinNotificationActionOption.destructive},
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final androidChannel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 800]),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.actionId == 'ACTION_CLOCK_IN') {
      onClockInActionTriggered?.call();
    } else {
      onNotificationTapped?.call(response.payload);
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> showClockInPrompt({
    required String wifiSsid,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern:
          enableVibration ? Int64List.fromList([0, 500, 200, 500, 200, 800]) : null,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      actions: const [
        AndroidNotificationAction(
          'ACTION_CLOCK_IN',
          'Clock In Now',
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'ACTION_DISMISS',
          'Dismiss',
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      categoryIdentifier: 'CLOCK_IN_CATEGORY',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      1001,
      '🏢 Welcome to Work!',
      'Connected to "$wifiSsid". Tap here to clock in for your shift.',
      details,
      payload: 'clock_in_payload',
    );
  }

  Future<void> cancelPrompt() async {
    await _notificationsPlugin.cancel(1001);
  }
}
