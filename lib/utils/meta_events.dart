import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import '../services/attribution_service.dart';

class MetaEvents {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Initialize and disable auto-logging to ensure only manual events are sent.
  static Future<void> init() async {
    try {
      if (kDebugMode) print("[Meta][INIT] Starting...");
      // Official configuration for manual logging only
      await _facebookAppEvents.setAutoLogAppEventsEnabled(false);
      if (kDebugMode) {
        print("[Meta][INIT] Completed successfully (Auto-log disabled)");
      }
    } catch (e) {
      if (kDebugMode) {
        print("[Meta][INIT] Failed: $e");
      }
    }
  }

  /// Helper to fetch attribution parameters for Meta events
  static Future<Map<String, dynamic>> _getAttributionParams() async {
    try {
      final attr = await AttributionService().getAttribution();
      final Map<String, dynamic> params = {};
      
      // Map UTMs if they exist
      if (attr['utm_source'] != null && attr['utm_source'] != 'None') {
        params['utm_source'] = attr['utm_source'];
      }
      if (attr['utm_medium'] != null && attr['utm_medium'] != 'None') {
        params['utm_medium'] = attr['utm_medium'];
      }
      if (attr['utm_campaign'] != null && attr['utm_campaign'] != 'None') {
        params['utm_campaign'] = attr['utm_campaign'];
      }
      if (attr['utm_term'] != null && attr['utm_term'] != 'None') {
        params['utm_term'] = attr['utm_term'];
      }
      if (attr['utm_content'] != null && attr['utm_content'] != 'None') {
        params['utm_content'] = attr['utm_content'];
      }
      
      // IMPORTANT: Map Facebook Click ID (fbclid) if available
      if (attr['fbclid'] != null && attr['fbclid']!.isNotEmpty) {
        params['fbclid'] = attr['fbclid'];
      }

      return params;
    } catch (e) {
      debugPrint("[Meta][ATTRIBUTION] Load failed: $e");
    }
    return {};
  }

  /// Trigger: When product detail page opens
  static Future<void> viewContent({
    required String? id,
    required String? name,
    required String? price,
  }) async {
    try {
      if (id == null || price == null) return;
      double val = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

      final attribution = await _getAttributionParams();
      
      if (kDebugMode) {
        print("[Meta][ViewContent] ID: $id | Price: $val | Attr: $attribution");
      }

      // Use standard event helper for better Meta mapping
      await _facebookAppEvents.logViewContent(
        id: id,
        type: 'product',
        currency: 'INR',
        price: val,
        parameters: attribution,
      );
    } catch (e) {
      debugPrint("[Meta][ViewContent][ERROR] Failed: $e");
    }
  }

  /// Trigger: When user taps "Add to Cart"
  static Future<void> addToCart({
    required String? id,
    required String? name,
    required String? price,
  }) async {
    try {
      if (id == null || price == null) return;
      double val = double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

      final attribution = await _getAttributionParams();
      
      if (kDebugMode) {
        print("[Meta][AddToCart] ID: $id | Price: $val | Attr: $attribution");
      }

      await _facebookAppEvents.logAddToCart(
        id: id,
        type: 'product',
        currency: 'INR',
        price: val,
        parameters: attribution,
      );
    } catch (e) {
      debugPrint("[Meta][AddToCart][ERROR] Failed: $e");
    }
  }

  /// Trigger: When user proceeds to checkout
  static Future<void> initiateCheckout({
    required double totalValue,
    List<String>? contentIds,
  }) async {
    try {
      final attribution = await _getAttributionParams();
      
      if (kDebugMode) {
        print("[Meta][InitiateCheckout] Value: $totalValue | Items: ${contentIds?.length} | Attr: $attribution");
      }

      await _facebookAppEvents.logInitiatedCheckout(
        totalPrice: totalValue,
        currency: 'INR',
        contentId: contentIds?.join(','),
        contentType: 'product',
        numItems: contentIds?.length,
        parameters: attribution,
      );
    } catch (e) {
      debugPrint("[Meta][InitiateCheckout][ERROR] Failed: $e");
    }
  }

  /// Trigger: When order is successfully placed
  static Future<void> purchase({
    required double totalValue,
    required List<String> contentIds,
    String? orderId,
  }) async {
    try {
      final attribution = await _getAttributionParams();
      
      final parameters = {
        'fb_content_id': contentIds.join(','),
        'fb_content_type': 'product',
        if (orderId != null) 'fb_order_id': orderId,
        ...attribution,
      };

      if (kDebugMode) {
        print("[Meta][Purchase] Value: $totalValue | OrderID: $orderId | Attr: $attribution");
      }

      // Official logPurchase supports parameters enrichment natively
      await _facebookAppEvents.logPurchase(
        amount: totalValue,
        currency: 'INR',
        parameters: parameters,
      );
    } catch (e) {
      debugPrint("[Meta][Purchase][ERROR] Failed: $e");
    }
  }

  /// Trigger: When user logs in
  static Future<void> login() async {
    try {
      final attribution = await _getAttributionParams();

      if (kDebugMode) {
        print("📊 Meta Event: Login");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $attribution");
      }

      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_login_complete',
        parameters: attribution,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logLogin failed: $e");
    }
  }

  /// Trigger: When user searches
  static Future<void> search({required String query}) async {
    try {
      final attribution = await _getAttributionParams();
      final parameters = {
        'fb_search_string': query,
        'fb_success': true,
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: Search");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_search',
        parameters: parameters,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logSearch failed: $e");
    }
  }

  /// Trigger: When user removes product from cart
  static Future<void> removeFromCart({
    required String id,
    required double price,
  }) async {
    try {
      final attribution = await _getAttributionParams();
      final parameters = {
        'fb_content_type': 'product',
        'fb_content_id': id,
        'fb_currency': 'INR',
        'fb_value': price,
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: RemoveFromCart");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      await _facebookAppEvents.logEvent(
        name: 'remove_from_cart',
        parameters: parameters,
        valueToSum: price,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logRemoveFromCart failed: $e");
    }
  }
}
