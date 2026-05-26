import 'package:appsflyer_sdk/appsflyer_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kisan_sewa_kendra/main.dart';

class AttributionService {
  static final AttributionService _instance = AttributionService._internal();
  factory AttributionService() => _instance;
  AttributionService._internal();

  static AppsflyerSdk? _sdk;

  // Call once on app start — captures install + re-open attribution
  Future<void> init(AppsflyerSdk sdk) async {
    _sdk = sdk;
    // For NEW installs (first open after ad click)
    sdk.onInstallConversionData((data) async {
      final prefs = await SharedPreferences.getInstance();
      final attrs = data['payload'] ?? {};
      final source = attrs['media_source'] ?? 'organic';
      print("🚀 AppsFlyer Install Data: $source | Campaign: ${attrs['campaign']}");
      
      // ONLY overwrite if it's a REAL campaign (not organic)
      if (source != 'organic' && source != 'None') {
        await prefs.setString('utm_source', source);
        await prefs.setString('utm_campaign', attrs['campaign'] ?? '');
        await prefs.setString('utm_term', attrs['adset'] ?? '');
        await prefs.setString('utm_content', attrs['ad'] ?? '');
        await prefs.setString('utm_medium', 'app');
      }

      // Step 6.2 — Deferred deep link navigation
      final deepLinkValue = attrs['deep_link_value'];
      final productId = attrs['product_id'];
      final category = attrs['category'];

      if (deepLinkValue == 'product' && productId != null) {
        navigatorKey.currentState?.pushNamed('/product/$productId');
      } else if (deepLinkValue == 'category' && category != null) {
        navigatorKey.currentState?.pushNamed('/category/$category');
      } else if (deepLinkValue == 'offer') {
        navigatorKey.currentState?.pushNamed('/offers');
      } else if (deepLinkValue == 'cart') {
        navigatorKey.currentState?.pushNamed('/cart');
      }
    });

    // For EXISTING users opening app via ad
    sdk.onAppOpenAttribution((data) async {
      final prefs = await SharedPreferences.getInstance();
      final attrs = data['payload'] ?? {};
      final source = attrs['media_source'] ?? 'organic';
      print("📱 AppsFlyer App Open Data: $source | Campaign: ${attrs['campaign']}");

      // ONLY overwrite if it's a REAL campaign (not organic)
      if (source != 'organic' && source != 'None') {
        await prefs.setString('utm_source', source);
        await prefs.setString('utm_campaign', attrs['campaign'] ?? '');
        await prefs.setString('utm_term', attrs['adset'] ?? '');
        await prefs.setString('utm_content', attrs['ad'] ?? '');
        await prefs.setString('utm_medium', 'app');
      }
    });
  }

  // Call this when building checkout — returns all attribution values
  Future<Map<String, String>> getAttribution() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'utm_source': prefs.getString('utm_source') ?? 'organic',
      'utm_medium': prefs.getString('utm_medium') ?? 'app',
      'utm_campaign': prefs.getString('utm_campaign') ?? '',
      'utm_term': prefs.getString('utm_term') ?? '',
      'utm_content': prefs.getString('utm_content') ?? '',
    };
  }

  // Call this when a push notification is tapped
  Future<void> handlePushNotification(RemoteMessage? message) async {
    if (message == null) return;

    final prefs = await SharedPreferences.getInstance();
    final campaign = message.data['campaign'] ?? 'push_campaign';
    print("🔔 Push Notification Tapped: $campaign");

    await prefs.setString('utm_source', 'push_notification');
    await prefs.setString('utm_medium', 'app');
    await prefs.setString('utm_campaign', campaign);
    await prefs.setString('utm_content', message.data['notification_id'] ?? '');
    await prefs.setString('utm_term', '');
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

  // Track Purchase/Revenue in AppsFlyer
  static void logPurchase(double amount, String orderId) {
    if (_sdk == null) {
      print("⚠️ AppsFlyer logPurchase failed: SDK not initialized");
      return;
    }

    _sdk!.logEvent("af_purchase", {
      "af_revenue": amount,
      "af_currency": "INR",
      "af_order_id": orderId,
      "af_quantity": 1, // Default to 1 if list is not provided
    });
    print("💰 AppsFlyer Revenue Logged: ₹$amount for Order $orderId");
  }

  // Track Add to Cart
  static void logAddToCart(String id, double price) {
    _sdk?.logEvent("af_add_to_cart", {
      "af_content_id": id,
      "af_currency": "INR",
      "af_price": price,
    });
    print("🛒 AppsFlyer AddToCart: $id | ₹$price");
  }

  // Track Initiate Checkout
  static void logInitiateCheckout(double amount) {
    _sdk?.logEvent("af_initiated_checkout", {
      "af_revenue": amount,
      "af_currency": "INR",
    });
    print("💳 AppsFlyer Initiate Checkout: ₹$amount");
  }

  // Track Login
  static void logLogin() {
    _sdk?.logEvent("af_login", {});
    print("🔑 AppsFlyer Login Logged");
  }

  // Track View Content (Product View)
  static void logViewContent(String id, String name, String price) {
    _sdk?.logEvent("af_content_view", {
      "af_content_id": id,
      "af_content_type": "product",
      "af_price": double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0,
      "af_currency": "INR",
      "af_content": name,
    });
    print("👁️ AppsFlyer ViewContent: $name (₹$price)");
  }

  // Track Search
  static void logSearch(String query) {
    _sdk?.logEvent("af_search", {
      "af_search_string": query,
    });
    print("🔍 AppsFlyer Search: $query");
  }

  // Track Remove from Cart
  static void logRemoveFromCart(String id, double price) {
    _sdk?.logEvent("af_remove_from_cart", {
      "af_content_id": id,
      "af_price": price,
      "af_currency": "INR",
    });
    print("🗑️ AppsFlyer RemoveFromCart: $id | ₹$price");
  }
}
