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
    _isInitialized = true;

    debugPrint("[FCM] Firebase Messaging initialization started");

    // 1. Register Listeners IMMEDIATELY
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("[FCM-AUDIT] Message received");
      debugPrint("[FCM-AUDIT] state: foreground");
      showFlutterNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("[FCM-AUDIT] Message received (Tap)");
      debugPrint("[FCM-AUDIT] state: background-tap");
      _logForensicPayload(message);
      AttributionService().handlePushNotification(message);
    });

    debugPrint("[FCM] onMessage and onMessageOpenedApp listeners registered");

    // 2. Perform Async Setup
    _setupNotificationPipeline();
  }

  static Future<void> _setupNotificationPipeline() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint("[FCM] Permission status: ${settings.authorizationStatus}");

      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("[FCM-AUDIT] Local Notification Clicked: ${response.payload}");
        },
      );
      debugPrint("[FCM] Local notifications initialized");

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max, // Increased to Max
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
      debugPrint("[FCM] Notification channel initialized with Importance.max");

      try {
        await _firebaseMessaging.subscribeToTopic("all_users");
        debugPrint("[FCM] Subscribed to topic: all_users");
      } catch (e) {
        debugPrint("[FCM] Topic subscription failed: $e");
      }

      _initializeTokenHandling();

      RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint("[FCM-AUDIT] Message received (Initial)");
        debugPrint("[FCM-AUDIT] state: terminated-tap");
        _logForensicPayload(initialMessage);
        AttributionService().handlePushNotification(initialMessage);
      }

    } catch (e) {
      debugPrint("[FCM] Critical initialization error: $e");
    }
  }

  static void _initializeTokenHandling() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        debugPrint("[FCM] Token available: true");
        debugPrint("[FCM] Token length: ${token.length}");
        debugPrint("[FCM] Token prefix: ${token.substring(0, token.length > 6 ? 6 : token.length)}");
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        debugPrint("[FCM] Token refreshed (Length: ${newToken.length})");
      });
    } catch (e) {
      debugPrint("[FCM] Token retrieval failed: $e");
    }
  }

  static void _logForensicPayload(RemoteMessage message) {
    if (kDebugMode) {
      final notification = message.notification;
      debugPrint("[FCM-AUDIT] Message ID: ${message.messageId}");
      debugPrint("[FCM-AUDIT] notification title present: ${notification?.title != null}");
      debugPrint("[FCM-AUDIT] notification body present: ${notification?.body != null}");
      
      String? navImageUrl = notification?.android?.imageUrl;
      debugPrint("[FCM-AUDIT] notification image URL present: ${navImageUrl != null}");
      
      debugPrint("[FCM-AUDIT] data keys: ${message.data.keys.toList()}");
      debugPrint("[FCM-AUDIT] data image present: ${message.data['image'] != null}");
      debugPrint("[FCM-AUDIT] data imageUrl present: ${message.data['imageUrl'] != null}");
      
      if (navImageUrl != null) {
        try {
          final uri = Uri.parse(navImageUrl);
          debugPrint("[FCM-AUDIT] notification image URL host: ${uri.host}");
        } catch (_) {}
      }
      
      debugPrint("[FCM-AUDIT] notification.android.imageUrl: $navImageUrl");
      debugPrint("[FCM-AUDIT] data['image']: ${message.data['image']}");
      debugPrint("[FCM-AUDIT] data['imageUrl']: ${message.data['imageUrl']}");
    }
  }

  static Future<void> showFlutterNotification(RemoteMessage message) async {
    _logForensicPayload(message);
    
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    String? title = notification?.title ?? message.data['title'] ?? message.data['header'];
    String? body = notification?.body ?? message.data['body'] ?? message.data['message'];

    if (title != null || body != null) {
      String? imageUrl = android?.imageUrl ?? 
                         message.data['image'] ?? 
                         message.data['imageUrl'] ??
                         message.data['image_url'] ??
                         message.data['big_picture'];

      BigPictureStyleInformation? bigPictureStyleInformation;
      String? largeIconPath;

      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint("[FCM-AUDIT] IMAGE URL FOUND: $imageUrl");
        try {
          final String filePath = await _downloadAndSaveFile(imageUrl, 'notification_img_${message.messageId ?? DateTime.now().millisecondsSinceEpoch}');
          
          if (await File(filePath).exists()) {
            final int size = await File(filePath).length();
            debugPrint("[FCM-AUDIT] LOCAL IMAGE FILE EXISTS: true");
            debugPrint("[FCM-AUDIT] LOCAL IMAGE SIZE: $size bytes");
            debugPrint("[FCM-AUDIT] BIG PICTURE FILE PATH VALID: true");
            
            largeIconPath = filePath;
            
            // CRITICAL: Constructing BigPictureStyleInformation
            bigPictureStyleInformation = BigPictureStyleInformation(
              FilePathAndroidBitmap(filePath),
              largeIcon: FilePathAndroidBitmap(filePath),
              contentTitle: title,
              summaryText: body,
              htmlFormatContentTitle: true,
              htmlFormatSummaryText: true,
              hideExpandedLargeIcon: true,
            );
          } else {
            debugPrint("[FCM-AUDIT] LOCAL IMAGE FILE EXISTS: false");
          }
        } catch (e) {
          debugPrint("[FCM-AUDIT] IMAGE DOWNLOAD: FAILED");
          debugPrint("[FCM-AUDIT] FAILURE REASON: $e");
        }
      } else {
        debugPrint("[FCM-AUDIT] NO IMAGE URL FOUND IN PAYLOAD");
      }

      if (bigPictureStyleInformation != null) {
        debugPrint("[FCM-AUDIT] BUILDING BIG PICTURE NOTIFICATION");
      }

      debugPrint("[FCM-AUDIT] CALLING flutterLocalNotificationsPlugin.show()");
      await _localNotificationsPlugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'This channel is used for important notifications.',
            importance: Importance.max,
            priority: Priority.max,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            styleInformation: bigPictureStyleInformation,
            largeIcon: largeIconPath != null ? FilePathAndroidBitmap(largeIconPath) : null,
            category: AndroidNotificationCategory.promo,
            fullScreenIntent: false,
          ),
        ),
      );
      debugPrint("[FCM-AUDIT] LOCAL NOTIFICATION SHOW COMPLETED");
    }
  }

  static Future<String> _downloadAndSaveFile(String url, String fileName) async {
    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    final Directory directory = await getTemporaryDirectory();
    
    String extension = ".jpg";
    try {
      final uri = Uri.parse(url);
      final ext = p.extension(uri.path);
      if (ext.isNotEmpty) extension = ext;
    } catch (_) {}
    
    final String filePath = p.join(directory.path, '$fileName$extension');
    
    // Add User-Agent and verify response
    final http.Response response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:100.0) Gecko/100.0 Firefox/100.0',
      },
    ).timeout(const Duration(seconds: 15));
    
    debugPrint("[FCM-AUDIT] IMAGE HTTP STATUS: ${response.statusCode}");
    debugPrint("[FCM-AUDIT] IMAGE CONTENT TYPE: ${response.headers['content-type']}");
    debugPrint("[FCM-AUDIT] IMAGE BYTES: ${response.bodyBytes.length}");

    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.startsWith('image/')) {
        debugPrint("[FCM-AUDIT] WARNING: Content-Type is not image: $contentType");
      }
      
      debugPrint("[FCM-AUDIT] IMAGE DOWNLOAD: SUCCESS");
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception("Invalid HTTP response: ${response.statusCode}");
    }
  }

  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    debugPrint("[FCM-AUDIT] Message received");
    debugPrint("[FCM-AUDIT] state: background");
    
    // If standard notification is present, OS displays it.
    // However, if images are missing, we could manually show it.
    // To prevent duplicates, we only manually show for data-only messages.
    if (message.notification == null && message.data.isNotEmpty) {
      debugPrint("[FCM-AUDIT] Handling data-only message in background");
      await showFlutterNotification(message);
    } else if (message.notification != null) {
      debugPrint("[FCM-AUDIT] Standard notification detected. OS likely handling rendering.");
      _logForensicPayload(message);
      
      // If we see this log but NO image in the drawer, then the OS is failing.
      // One solution is to use "data-only" messages from the server/console.
      // Since the user is using the Console, they can try putting the image URL 
      // in BOTH the image field AND a custom data key.
    }
  }
}
