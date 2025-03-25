import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Model สำหรับ Notification Item
class NotificationItem {
  final String title;
  final String body;
  final DateTime timestamp;
  bool read;

  NotificationItem({
    required this.title,
    required this.body,
    DateTime? timestamp,
    this.read = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Extended model สำหรับ notification ที่เก็บ data payload
class MyExtendedNotificationItem extends NotificationItem {
  final Map<String, String>? data;
  MyExtendedNotificationItem({
    required String title,
    required String body,
    DateTime? timestamp,
    bool read = false,
    this.data,
  }) : super(title: title, body: body, timestamp: timestamp, read: read);
}

/// Repository สำหรับเก็บ Notification Items (Singleton)
class NotificationRepository {
  static final NotificationRepository _instance =
      NotificationRepository._internal();
  factory NotificationRepository() => _instance;
  NotificationRepository._internal();

  final List<NotificationItem> _notifications = [];

  List<NotificationItem> get notifications => _notifications;

  void addNotification(NotificationItem notification) {
    _notifications.insert(0, notification);
  }

  int get unreadCount => _notifications.where((n) => !n.read).length;
}

/// Service สำหรับจัดการ Local Notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("Notification tapped with payload: ${response.payload}");
      },
    );
  }

  Future<void> showNotification(
    RemoteNotification notification, {
    Map<String, String>? data,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'default_channel',
          'Default',
          channelDescription: 'Default channel for notifications',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: data != null ? data.toString() : null,
    );
  }
}
