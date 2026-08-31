import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisan_sewa_kendra/utils/meta_events.dart';

class AttributionService {
  static final AttributionService _instance = AttributionService._internal();
  factory AttributionService() => _instance;
  AttributionService._internal();

  /// Call once on app start — initializes attribution and install referrer
  Future<void> init() async {
    if (kDebugMode) {
      debugPrint("🚀 Attribution Service Initialized (Meta SDK & Install Referrer Mode)");
    }
    await _initInstallReferrer();
  }

  /// Checks Google Play Install Referrer on Android for first-time app installs
  Future<void> _initInstallReferrer() async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        final alreadyProcessed = prefs.getBool('install_referrer_processed') ?? false;
        
        if (!alreadyProcessed) {
          final referrerDetails =
              await PlayInstallReferrer.installReferrer;
          final rawReferrer = referrerDetails.installReferrer;

          if (kDebugMode) {
            debugPrint("📦 [InstallReferrer] Raw referrer received: $rawReferrer");
          }

          if (rawReferrer != null && rawReferrer.isNotEmpty) {
            final parsedParams = _parseReferrerString(rawReferrer);
            if (parsedParams.isNotEmpty) {
              if (kDebugMode) {
                debugPrint("🎯 [InstallReferrer] Parsed params: $parsedParams");
              }
              await saveAttributionFromMap(parsedParams);
            }
          }

          await prefs.setBool('install_referrer_processed', true);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ [InstallReferrer] Could not fetch install referrer: $e");
      }
    }
  }

  /// Parses a raw install referrer string (e.g. "utm_source=meta&utm_medium=cpc..." or URL-encoded)
  Map<String, String> _parseReferrerString(String raw) {
    final Map<String, String> result = {};
    try {
      String decoded = raw;
      // Handle multi-level URL encoding if present
      if (decoded.contains('%26') || decoded.contains('%3D') || decoded.contains('%25')) {
        try {
          decoded = Uri.decodeFull(decoded);
        } catch (_) {}
      }

      // If it looks like a full URL, parse query parameters directly
      if (decoded.startsWith('http://') || decoded.startsWith('https://')) {
        final uri = Uri.tryParse(decoded);
        if (uri != null && uri.queryParameters.isNotEmpty) {
          return uri.queryParameters;
        }
      }

      // Parse key-value query string
      final pairs = decoded.split('&');
      for (final pair in pairs) {
        final idx = pair.indexOf('=');
        if (idx != -1) {
          final key = Uri.decodeComponent(pair.substring(0, idx).trim());
          final value = Uri.decodeComponent(pair.substring(idx + 1).trim());
          if (key.isNotEmpty && value.isNotEmpty) {
            result[key] = value;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("⚠️ [InstallReferrer] Error parsing string '$raw': $e");
      }
    }
    return result;
  }

  /// Call this when building checkout — returns all attribution values
  Future<Map<String, String>> getAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'utm_source': prefs.getString('utm_source') ?? 'organic',
      'utm_medium': prefs.getString('utm_medium') ?? 'app',
      'utm_campaign': prefs.getString('utm_campaign') ?? '',
      'utm_term': prefs.getString('utm_term') ?? '',
      'utm_content': prefs.getString('utm_content') ?? '',
      'fbclid': prefs.getString('fbclid') ?? '',
      'gclid': prefs.getString('gclid') ?? '',
    };
    if (kDebugMode) {
      debugPrint("📦 Loaded UTM/Meta Attribution: $data");
    }
    return data;
  }

  /// Call this when a push notification is tapped
  Future<void> handlePushNotification(RemoteMessage? message) async {
    if (message == null) return;

    final prefs = await SharedPreferences.getInstance();
    final campaign = message.data['campaign'] ?? 'push_campaign';
    
    await prefs.setString('utm_source', 'push_notification');
    await prefs.setString('utm_medium', 'app');
    await prefs.setString('utm_campaign', campaign);
    await prefs.setString('utm_content', message.data['notification_id'] ?? '');
    await prefs.setString('utm_term', '');

    if (kDebugMode) {
      debugPrint("🔔 Captured UTM Push Notification: push_notification | Campaign: $campaign");
    }
  }

  /// Helper to check if a UTM parameter has meaningful value (filters out (not set), none, null, organic, etc.)
  static bool isValidUtm(String? val) {
    if (val == null) return false;
    final trimmed = val.trim().toLowerCase();
    if (trimmed.isEmpty) return false;
    if (trimmed == 'organic' ||
        trimmed == 'none' ||
        trimmed == 'null' ||
        trimmed == 'undefined' ||
        trimmed == 'unknown' ||
        trimmed == '(not set)' ||
        trimmed == '(notset)' ||
        trimmed == 'not set' ||
        trimmed == 'not_set' ||
        trimmed == 'notset') {
      return false;
    }
    return true;
  }

  /// Save UTM parameters directly from map (e.g. from deep link query params or install referrer)
  Future<void> saveAttributionFromMap(Map<String, String> queryParams) async {
    final prefs = await SharedPreferences.getInstance();
    
    String? rawSource = queryParams['utm_source'] ?? queryParams['source'];
    String? rawMedium = queryParams['utm_medium'] ?? queryParams['medium'];
    String? rawCampaign = queryParams['utm_campaign'] ?? queryParams['campaign'] ?? queryParams['campaign_id'];
    String? rawContent = queryParams['utm_content'] ?? queryParams['content'] ?? queryParams['ad_id'];
    String? rawTerm = queryParams['utm_term'] ?? queryParams['term'] ?? queryParams['adset_id'];
    
    final fbclid = queryParams['fbclid'];
    final gclid = queryParams['gclid'];

    String? source = isValidUtm(rawSource) ? rawSource : null;
    String? medium = isValidUtm(rawMedium) ? rawMedium : null;
    String? campaign = isValidUtm(rawCampaign) ? rawCampaign : null;
    String? content = isValidUtm(rawContent) ? rawContent : null;
    String? term = isValidUtm(rawTerm) ? rawTerm : null;

    // 1. Capture Meta Click ID (fbclid) if present
    if (fbclid != null && fbclid.isNotEmpty && isValidUtm(fbclid)) {
      await prefs.setString('fbclid', fbclid);
      if (kDebugMode) debugPrint("🔵 Captured Meta Click ID (fbclid): $fbclid");
      
      // Auto-infer Meta source if utm_source is missing or was (not set)
      if (source == null) {
        source = 'meta';
        medium = medium ?? 'cpc';
      }
    }

    // 2. Capture Google Click ID (gclid) if present
    if (gclid != null && gclid.isNotEmpty && isValidUtm(gclid)) {
      await prefs.setString('gclid', gclid);
      if (kDebugMode) debugPrint("🟢 Captured Google Click ID (gclid): $gclid");

      if (source == null) {
        source = 'google';
        medium = medium ?? 'cpc';
      }
    }

    if (source != null && source.isNotEmpty) {
      await prefs.setString('utm_source', source);
      await prefs.setString('utm_medium', medium ?? 'app');
      await prefs.setString('utm_campaign', campaign ?? '');
      await prefs.setString('utm_content', content ?? '');
      await prefs.setString('utm_term', term ?? '');
      
      // Store initial acquisition source if not already recorded
      if (!prefs.containsKey('initial_utm_source')) {
        await prefs.setString('initial_utm_source', source);
        await prefs.setString('initial_utm_campaign', campaign ?? '');
      }

      if (kDebugMode) {
        debugPrint("🎯 Stored UTM Attribution: $source | Medium: $medium | Campaign: $campaign | Content: $content");
      }
    }
  }

  /// Clear attribution after a successful order to prevent multi-order attribution to same click
  Future<void> clearAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('utm_source');
    await prefs.remove('utm_medium');
    await prefs.remove('utm_campaign');
    await prefs.remove('utm_term');
    await prefs.remove('utm_content');
    await prefs.remove('fbclid');
    await prefs.remove('gclid');
    if (kDebugMode) {
      debugPrint("🧹 Attribution Data Cleared");
    }
  }

  // Track Purchase/Revenue in Meta SDK
  static Future<void> logPurchase(double amount, List<String> productIds, {String? orderId}) async {
    await MetaEvents.purchase(totalValue: amount, contentIds: productIds, orderId: orderId);
    if (kDebugMode) {
      debugPrint("💰 Meta SDK Purchase Logged: ₹$amount for Products $productIds | Order: $orderId");
    }
  }

  // Track Add to Cart
  static Future<void> logAddToCart(String id, String? name, double price) async {
    await MetaEvents.addToCart(id: id, name: name, price: price.toString());
    if (kDebugMode) {
      debugPrint("🛒 Meta SDK AddToCart Logged: $id | ₹$price");
    }
  }

  // Track Initiate Checkout
  static Future<void> logInitiateCheckout(double amount, List<String> productIds) async {
    await MetaEvents.initiateCheckout(totalValue: amount, contentIds: productIds);
    if (kDebugMode) {
      debugPrint("💳 Meta SDK Initiate Checkout Logged: ₹$amount | Products: $productIds");
    }
  }

  // Track Login
  static Future<void> logLogin() async {
    await MetaEvents.login();
    if (kDebugMode) {
      debugPrint("🔑 Meta SDK Login Logged");
    }
  }

  // Track View Content (Product View)
  static Future<void> logViewContent(String id, String name, String price) async {
    await MetaEvents.viewContent(id: id, name: name, price: price);
    if (kDebugMode) {
      debugPrint("👁️ Meta SDK ViewContent Logged: $name (₹$price)");
    }
  }

  // Track Search
  static Future<void> logSearch(String query) async {
    await MetaEvents.search(query: query);
    if (kDebugMode) {
      debugPrint("🔍 Meta SDK Search Logged: $query");
    }
  }

  // Track Remove from Cart
  static Future<void> logRemoveFromCart(String id, double price) async {
    await MetaEvents.removeFromCart(id: id, price: price);
    if (kDebugMode) {
      debugPrint("🗑️ Meta SDK RemoveFromCart Logged: $id | ₹$price");
    }
  }
}
