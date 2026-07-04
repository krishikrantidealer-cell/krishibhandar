import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:flutter/foundation.dart';
import '../services/attribution_service.dart';

class MetaEvents {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Initialize and disable auto-logging to ensure only manual events are sent.
  static Future<void> init() async {
    try {
      // Official configuration for manual logging only
      await _facebookAppEvents.setAutoLogAppEventsEnabled(false);
      if (kDebugMode) {
        print("🚀 MetaEvents: Initialization successful (Auto-log disabled)");
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ MetaEvents: Initialization failed: $e");
      }
    }
  }

  /// Helper to fetch attribution parameters for Meta events
  static Future<Map<String, dynamic>> _getAttributionParams() async {
    try {
      final attr = await AttributionService().getAttribution();
      // Only include if utm_source is valid and not generic
      if (attr['utm_source'] != null && 
          attr['utm_source'] != 'organic' && 
          attr['utm_source']!.isNotEmpty &&
          attr['utm_source'] != 'None') {
        return {
          'utm_source': attr['utm_source'],
          'utm_medium': attr['utm_medium'],
          'utm_campaign': attr['utm_campaign'],
          'utm_term': attr['utm_term'],
          'utm_content': attr['utm_content'],
        };
      }
    } catch (e) {
      debugPrint("MetaEvents: Attribution load failed: $e");
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
      final parameters = {
        'fb_content_id': id,
        'fb_content_type': 'product',
        'fb_currency': 'INR',
        'fb_value': val,
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: ViewContent");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      // Enrichment: Standard ViewContent using logEvent to support custom attribution parameters
      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_content_view',
        parameters: parameters,
        valueToSum: val,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logViewContent failed: $e");
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
      final parameters = {
        'fb_content_id': id,
        'fb_content_type': 'product',
        'fb_currency': 'INR',
        'fb_value': val,
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: AddToCart");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_add_to_cart',
        parameters: parameters,
        valueToSum: val,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logAddToCart failed: $e");
    }
  }

  /// Trigger: When user proceeds to checkout
  static Future<void> initiateCheckout({
    required double totalValue,
    List<String>? contentIds,
  }) async {
    try {
      final attribution = await _getAttributionParams();
      final parameters = {
        'fb_content_type': 'product',
        'fb_content_id': contentIds?.join(','),
        'fb_num_items': contentIds?.length,
        'fb_currency': 'INR',
        'fb_value': totalValue,
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: InitiateCheckout");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      await _facebookAppEvents.logEvent(
        name: 'fb_mobile_initiated_checkout',
        parameters: parameters,
        valueToSum: totalValue,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logInitiatedCheckout failed: $e");
    }
  }

  /// Trigger: When order is successfully placed
  static Future<void> purchase({
    required double totalValue,
    required List<String> contentIds,
  }) async {
    try {
      final attribution = await _getAttributionParams();
      
      final parameters = {
        'fb_content_id': contentIds.join(','),
        'fb_content_type': 'product',
        ...attribution,
      };

      if (kDebugMode) {
        print("📊 Meta Event: Purchase");
        print("   ↓ Current Attribution: $attribution");
        print("   ↓ Final Parameter Map: $parameters");
      }

      // Official logPurchase supports parameters enrichment natively
      await _facebookAppEvents.logPurchase(
        amount: totalValue,
        currency: 'INR',
        parameters: parameters,
      );
    } catch (e) {
      debugPrint("❌ MetaEvents: logPurchase failed: $e");
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
