import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisan_sewa_kendra/utils/meta_events.dart';

class AttributionService {
  static final AttributionService _instance = AttributionService._internal();
  factory AttributionService() => _instance;
  AttributionService._internal();

  // Call once on app start — initializes attribution logic
  Future<void> init() async {
    print("🚀 Attribution Service Initialized (Meta SDK Mode)");
  }

  // Call this when building checkout — returns all attribution values
  Future<Map<String, String>> getAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'utm_source': prefs.getString('utm_source') ?? 'organic',
      'utm_medium': prefs.getString('utm_medium') ?? 'app',
      'utm_campaign': prefs.getString('utm_campaign') ?? '',
      'utm_term': prefs.getString('utm_term') ?? '',
      'utm_content': prefs.getString('utm_content') ?? '',
    };
    if (kDebugMode) {
      debugPrint("📦 Loaded UTM Attribution: $data");
    }
    return data;
  }

  // Call this when a push notification is tapped
  Future<void> handlePushNotification(RemoteMessage? message) async {
    if (message == null) return;

    final prefs = await SharedPreferences.getInstance();
    final campaign = message.data['campaign'] ?? 'push_campaign';
    
    await prefs.setString('utm_source', 'push_notification');
    await prefs.setString('utm_medium', 'app');
    await prefs.setString('utm_campaign', campaign);
    await prefs.setString('utm_content', message.data['notification_id'] ?? '');
    await prefs.setString('utm_term', ''); // Term not typically in push, but cleared for consistency

    if (kDebugMode) {
      debugPrint("🔔 Captured UTM Push Notification: push_notification | Campaign: $campaign");
    }
  }

  // Save UTM parameters directly from map (e.g. from deep link query params)
  Future<void> saveAttributionFromMap(Map<String, String> queryParams) async {
    final prefs = await SharedPreferences.getInstance();
    final source = queryParams['utm_source'];
    if (source != null && source.isNotEmpty && source != 'organic' && source != 'None') {
      await prefs.setString('utm_source', source);
      await prefs.setString('utm_campaign', queryParams['utm_campaign'] ?? '');
      await prefs.setString('utm_medium', queryParams['utm_medium'] ?? 'app');
      await prefs.setString('utm_content', queryParams['utm_content'] ?? '');
      await prefs.setString('utm_term', queryParams['utm_term'] ?? '');
      
      if (kDebugMode) {
        debugPrint("🎯 Stored UTM Attribution: $source | Campaign: ${queryParams['utm_campaign']}");
      }
    }
  }

  // Clear attribution after a successful order to prevent multi-order attribution to same click
  Future<void> clearAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('utm_source');
    await prefs.remove('utm_medium');
    await prefs.remove('utm_campaign');
    await prefs.remove('utm_term');
    await prefs.remove('utm_content');
    print("🧹 Attribution Data Cleared");
  }

  // Track Purchase/Revenue in Meta SDK
  static void logPurchase(double amount, List<String> productIds) {
    MetaEvents.purchase(totalValue: amount, contentIds: productIds);
    print("💰 Meta SDK Purchase Logged: ₹$amount for Products $productIds");
  }

  // Track Add to Cart
  static void logAddToCart(String id, String? name, double price) {
    MetaEvents.addToCart(id: id, name: name, price: price.toString());
    print("🛒 Meta SDK AddToCart Logged: $id | ₹$price");
  }

  // Track Initiate Checkout
  static void logInitiateCheckout(double amount, List<String> productIds) {
    MetaEvents.initiateCheckout(totalValue: amount, contentIds: productIds);
    print("💳 Meta SDK Initiate Checkout Logged: ₹$amount | Products: $productIds");
  }

  // Track Login
  static void logLogin() {
    MetaEvents.login();
    print("🔑 Meta SDK Login Logged");
  }

  // Track View Content (Product View)
  static void logViewContent(String id, String name, String price) {
    MetaEvents.viewContent(id: id, name: name, price: price);
    print("👁️ Meta SDK ViewContent Logged: $name (₹$price)");
  }

  // Track Search
  static void logSearch(String query) {
    MetaEvents.search(query: query);
    print("🔍 Meta SDK Search Logged: $query");
  }

  // Track Remove from Cart
  static void logRemoveFromCart(String id, double price) {
    MetaEvents.removeFromCart(id: id, price: price);
    print("🗑️ Meta SDK RemoveFromCart Logged: $id | ₹$price");
  }
}
