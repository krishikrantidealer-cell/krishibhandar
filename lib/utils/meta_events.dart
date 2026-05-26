import 'package:facebook_app_events/facebook_app_events.dart';

class MetaEvents {
  static final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Initialize and disable auto-logging to ensure only manual events are sent.
  static Future<void> init() async {
    // debugPrint("MetaEvents: Initializing...");
    try {
      await _facebookAppEvents.setAutoLogAppEventsEnabled(false);
      // debugPrint("MetaEvents: Initialization successful");
    } catch (e) {
      // debugPrint("MetaEvents: Initialization failed: $e");
    }
  }

  /// Trigger: When product detail page opens
  static void viewContent({
    required String? id,
    required String? name,
    required String? price,
  }) {
    if (id == null || price == null) {
      // debugPrint("MetaEvents: viewContent skipped - missing ID or price");
      return;
    }
    double val =
        double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

    // debugPrint("MetaEvents: Logging viewContent for $name (ID: $id, Value: $val)");
    _facebookAppEvents.logEvent(
      name: 'view_content',
      parameters: {
        'fb_content_type': 'product',
        'fb_content_id': id,
        'fb_description': name ?? '',
        'fb_currency': 'INR',
        'fb_value': val,
      },
      valueToSum: val,
    );
  }

  /// Trigger: When user taps "Add to Cart"
  static void addToCart({
    required String? id,
    required String? name,
    required String? price,
  }) {
    if (id == null || price == null) {
      // debugPrint("MetaEvents: addToCart skipped - missing ID or price");
      return;
    }
    double val =
        double.tryParse(price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

    // debugPrint("MetaEvents: Logging addToCart for $name (ID: $id, Value: $val)");
    _facebookAppEvents.logEvent(
      name: 'add_to_cart',
      parameters: {
        'fb_content_type': 'product',
        'fb_content_id': id,
        'fb_description': name ?? '',
        'fb_currency': 'INR',
        'fb_value': val,
      },
      valueToSum: val,
    );
  }

  /// Trigger: When user taps "Buy Now" or proceeds to checkout
  static void initiateCheckout({
    required double totalValue,
    String? contentIds,
  }) {
    // debugPrint("MetaEvents: Logging initiateCheckout (Value: $totalValue, IDs: $contentIds)");
    _facebookAppEvents.logEvent(
      name: 'initiate_checkout',
      parameters: {
        'fb_content_type': 'product',
        if (contentIds != null) 'fb_content_id': contentIds,
        'fb_currency': 'INR',
        'fb_value': totalValue,
      },
      valueToSum: totalValue,
    );
  }

  /// Trigger: When order is successfully placed
  static void purchase({
    required double totalValue,
    String? contentIds,
  }) {
    // debugPrint("MetaEvents: Logging purchase (Value: $totalValue, IDs: $contentIds)");
    _facebookAppEvents.logEvent(
      name: 'purchase',
      parameters: {
        'fb_content_type': 'product',
        if (contentIds != null) 'fb_content_id': contentIds,
        'fb_currency': 'INR',
        'fb_value': totalValue,
      },
      valueToSum: totalValue,
    );
  }
}
