import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:kisan_sewa_kendra/services/attribution_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> init() async {
    if (_isInitialized) return;

    // 1. Request Permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Suppress Foreground Notifications from FCM SDK
    // This prevents the OS from showing a default notification while the app is open.
    // We will manually show the notification using flutter_local_notifications.
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // 3. Local Notifications Setup
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(initializationSettings);

    // Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;

    // 3. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      showFlutterNotification(message);
    });

    // 4. Handle Background/Terminated Click
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        debugPrint("🔔 Captured UTM Push Notification: ${message.data}");
      }
      AttributionService().handlePushNotification(message);
    });

    await _firebaseMessaging.subscribeToTopic("all_users");
  }

  static Future<void> showFlutterNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    String? title = notification?.title ?? message.data['title'];
    String? body = notification?.body ?? message.data['body'];

    if (title != null || body != null) {
      String? imageUrl = android?.imageUrl ?? 
                         message.data['image'] ?? 
                         message.data['imageUrl'];

      BigPictureStyleInformation? bigPictureStyleInformation;
      String? largeIconPath;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          final String filePath = await _downloadAndSaveFile(imageUrl, 'notification_img_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}');
          largeIconPath = filePath;
          bigPictureStyleInformation = BigPictureStyleInformation(
            FilePathAndroidBitmap(filePath),
            largeIcon: FilePathAndroidBitmap(filePath),
            contentTitle: title,
            summaryText: body,
          );
        } catch (e) {
          // Fallback to text if download fails
        }
      }

      await _localNotificationsPlugin.show(
        message.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.high,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            styleInformation: bigPictureStyleInformation,
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
          ),
        ),
      );
    }
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getTemporaryDirectory();
    final String filePath = p.join(directory.path, '$fileName${p.extension(url).split('?').first.isEmpty ? ".jpg" : p.extension(url).split('?').first}');
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // If the message contains a notification object, the Android OS/FCM SDK 
    // already displays it automatically in the background.
    // We only manually show it for data-only messages to avoid duplicates.
    // Image support for standard notifications is handled by the OS if a channel is linked.
    if (message.notification == null && message.data.isNotEmpty) {
      await showFlutterNotification(message);
    }
  }
}
