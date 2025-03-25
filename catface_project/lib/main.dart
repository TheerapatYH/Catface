import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ไฟล์นี้จะถูก generate โดย FlutterFire CLI
import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_page.dart';
import 'home.dart';
import 'sign_up.dart';
import 'sign_in.dart';
import 'post.dart';
import 'account.dart';
import 'Map.dart';
import 'edit_post.dart';
import 'my_posts.dart';
import 'register.dart';
import 'landingpage1.dart';
import 'notification_service.dart'; // Import notification_service.dart เพื่อใช้ MyExtendedNotificationItem

/// Handler สำหรับ background message ของ FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ตั้งค่า background message handler สำหรับ FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Instance สำหรับ Local Notifications
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initializeLocalNotifications();
    _setupFirebaseMessaging();
  }

  // ตั้งค่า Firebase Messaging สำหรับ foreground messages
  void _setupFirebaseMessaging() async {
    await FirebaseMessaging.instance.requestPermission();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Received a foreground message: ${message.messageId}");
      print("Data payload: ${message.data}");
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        // แปลง data จาก Map<String, dynamic> เป็น Map<String, String>
        final Map<String, String> dataPayload = message.data.map(
          (key, value) => MapEntry(key, value.toString()),
        );
        // แสดง Local Notification โดยส่งข้อมูล dataPayload ไปด้วย
        _notificationService.showNotification(notification, data: dataPayload);
        // บันทึก notification ลง repository พร้อมข้อมูล payload โดยใช้ MyExtendedNotificationItem
        NotificationRepository().addNotification(
          MyExtendedNotificationItem(
            title: notification.title ?? 'No Title',
            body: notification.body ?? '',
            data: dataPayload,
          ),
        );
        // รีเฟรชหน้าจอถ้าจำเป็น
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/sign-up',
      routes: {
        '/first': (context) => HomePage(userId: ''),
        '/home': (context) => HomePage(userId: ''),
        '/sign-up': (context) => SignUpPage(),
        '/sign-in': (context) => SignInPage(),
        '/post': (context) => PostPage(userId: ''),
        '/account': (context) => AccountPage(userId: ''),
        '/register': (context) => RegisterCatPage(userId: ''),
        '/map': (context) => MapPage(),
        '/myposts': (context) => MyPostsPage(userId: ''),
        '/editpost': (context) => const EditPostPage(postData: {}),
        '/notification': (context) => const NotificationPage(),
        '/landing': (context) => const LandingPage1(),
      },
    );
  }
}
