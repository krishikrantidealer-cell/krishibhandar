import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../controller/cart_controller.dart';

class ShiprocketService {
  /// Primary registered Shopify store domain required by Shiprocket / Fastrr
  static const String defaultDomain = 'krishibhandar.com';

  /// Shiprocket Boost / Fastrr mobile app script URL
  static const String scriptUrl =
      'https://fastrr-boost-ui.pickrr.com/assets/js/channels/mobileApp.js';

  /// Extracts numeric ID from Shopify GID or returns cleaned ID string.
  /// Example: "gid://shopify/ProductVariant/123456" -> "123456"
  static String cleanGid(String? rawId) {
    if (rawId == null || rawId.trim().isEmpty) return '';
    final trimmed = rawId.trim();
    if (trimmed.contains('/')) {
      return trimmed.split('/').last;
    }
    return trimmed;
  }

  /// Safely parses price string into a positive double value.
  /// Handles formatted strings like "₹500.00", "500", "1,200.50".
  static double parsePrice(String priceStr) {
    final clean = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    final parsed = double.tryParse(clean);
    if (parsed == null || parsed <= 0) {
      throw FormatException('Invalid or non-positive price value: "$priceStr"');
    }
    return parsed;
  }

  /// Builds the items array required by Fastrr window.getOneClickCheckoutUrl()
  ///
  /// Contract expected by mobileApp.js:
  /// - `id`: numeric or string Shopify product ID
  /// - `variant_id`: numeric or string Shopify variant ID
  /// - `quantity`: integer
  /// - `title`: string
  /// - `price`: double
  /// - `image`: string
  static List<Map<String, dynamic>> buildItemsPayload(List<CartItem> cartItems) {
    if (cartItems.isEmpty) {
      throw ArgumentError('Cart is empty. Cannot generate checkout payload.');
    }

    final List<Map<String, dynamic>> items = [];

    for (int i = 0; i < cartItems.length; i++) {
      final item = cartItems[i];

      final variantIdClean = cleanGid(item.id);
      if (variantIdClean.isEmpty) {
        throw FormatException('Cart item at index $i is missing a valid variant ID.');
      }

      final productIdClean = cleanGid(item.productId);
      final rawProductId = productIdClean.isNotEmpty ? productIdClean : variantIdClean;

      final dynamic productIdVal = int.tryParse(rawProductId) ?? rawProductId;
      final dynamic variantIdVal = int.tryParse(variantIdClean) ?? variantIdClean;

      final double priceVal = parsePrice(item.price);
      final productName = item.title.trim().isNotEmpty ? item.title.trim() : 'Product';

      items.add({
        'id': productIdVal,
        'variant_id': variantIdVal,
        'quantity': item.qty > 0 ? item.qty : 1,
        'title': productName,
        'price': priceVal,
        'image': item.image.trim(),
      });
    }

    return items;
  }

  /// Formats attribution parameters into URL-encoded query string as required by Shiprocket utmParams
  /// Example: "utm_source=meta&utm_medium=cpc&fbclid=12345"
  static String buildUtmParamsString(Map<String, String>? attribution) {
    if (attribution == null || attribution.isEmpty) return '';

    final List<String> pairs = [];
    attribution.forEach((key, value) {
      final trimmedKey = key.trim();
      final trimmedValue = value.trim();
      if (trimmedKey.isNotEmpty &&
          trimmedValue.isNotEmpty &&
          trimmedValue.toLowerCase() != 'none' &&
          trimmedValue.toLowerCase() != 'null') {
        pairs.add('${Uri.encodeComponent(trimmedKey)}=${Uri.encodeComponent(trimmedValue)}');
      }
    });

    return pairs.join('&');
  }

  /// Builds optional checkout attributes Map from available customer and address state
  static Map<String, dynamic>? buildCartAttributes({
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? shippingAddress,
  }) {
    final Map<String, dynamic> attributes = {};

    if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      attributes['customer_phone'] = customerPhone.trim();
    }
    if (customerEmail != null && customerEmail.trim().isNotEmpty) {
      attributes['customer_email'] = customerEmail.trim();
    }
    if (shippingAddress != null && shippingAddress.isNotEmpty) {
      if (shippingAddress['pincode'] != null) {
        attributes['shipping_pincode'] = shippingAddress['pincode'].toString();
      }
      if (shippingAddress['city'] != null) {
        attributes['shipping_city'] = shippingAddress['city'].toString();
      }
      if (shippingAddress['state'] != null) {
        attributes['shipping_state'] = shippingAddress['state'].toString();
      }
    }

    return attributes.isNotEmpty ? attributes : null;
  }

  /// Generates full bootstrap JSON payload object for window.getOneClickCheckoutUrl()
  static Map<String, dynamic> buildCheckoutPayload({
    required List<CartItem> cartItems,
    String domain = defaultDomain,
    String? couponCode,
    Map<String, String>? attributionParams,
    String? customerPhone,
    String? customerEmail,
    Map<String, dynamic>? shippingAddress,
  }) {
    final itemsPayload = buildItemsPayload(cartItems);
    final utmString = buildUtmParamsString(attributionParams);
    final cartAttributes = buildCartAttributes(
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      shippingAddress: shippingAddress,
    );

    final Map<String, dynamic> payload = {
      'items': itemsPayload,
      'domain': domain,
      'webUrl': domain,
    };

    if (couponCode != null && couponCode.trim().isNotEmpty) {
      payload['couponCode'] = couponCode.trim();
    }

    if (utmString.isNotEmpty) {
      payload['utmParams'] = utmString;
    }

    if (cartAttributes != null) {
      payload['cartAttributes'] = cartAttributes;
      payload['encodingRequired'] = true;
    }

    if (kDebugMode) {
      debugPrint('🚀 [SHIPROCKET] Checkout Payload Prepared:');
      debugPrint('   - Domain: $domain');
      debugPrint('   - WebUrl: ${payload['webUrl']}');
      debugPrint('   - Items Count: ${itemsPayload.length}');
      debugPrint('   - Coupon: ${payload['couponCode'] ?? "None"}');
      debugPrint('   - UTM Params: ${payload['utmParams'] ?? "None"}');
    }

    return payload;
  }

  /// Validates generated Fastrr checkout URL parameters before navigation
  static Map<String, String> validateCheckoutUrl(String url) {
    if (url.trim().isEmpty) {
      return {'error': 'Checkout URL is empty.'};
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.scheme.toLowerCase().contains('http')) {
      return {'error': 'Invalid checkout URL scheme: ${uri?.scheme}'};
    }

    final host = uri.host.toLowerCase();
    if (!host.contains('fastrr') &&
        !host.contains('pickrr') &&
        !host.contains('shiprocket')) {
      return {'error': 'Unexpected checkout host domain: $host'};
    }

    final params = uri.queryParameters;

    if (!params.containsKey('platform') || params['platform']?.isEmpty == true) {
      return {'error': 'Missing required "platform" parameter in checkout URL.'};
    }

    final sellerDomain = params['sellerDomain'];
    if (sellerDomain == null ||
        sellerDomain == 'undefined' ||
        sellerDomain.trim().isEmpty) {
      return {'error': 'Invalid "sellerDomain" parameter in checkout URL: "$sellerDomain"'};
    }

    final domain = params['domain'];
    if (domain == null ||
        domain == 'undefined' ||
        domain.trim().isEmpty) {
      return {'error': 'Invalid "domain" parameter in checkout URL: "$domain"'};
    }

    final cart = params['cart'];
    if (cart == null ||
        cart == 'undefined' ||
        cart == 'null' ||
        cart.trim().isEmpty) {
      return {'error': 'Invalid or missing "cart" parameter in checkout URL.'};
    }

    return {'success': 'true'};
  }

  /// Generates complete HTML string for the local bootstrap page in WebView
  static String buildBootstrapHtml(Map<String, dynamic> checkoutPayload) {
    final payloadJsonStr = jsonEncode(checkoutPayload);
    final domainStr = checkoutPayload['domain']?.toString() ?? defaultDomain;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    body {
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100vh;
      margin: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background-color: #ffffff;
      color: #333333;
    }
    .spinner {
      border: 3px solid #f3f3f3;
      border-top: 3px solid #26842c;
      border-radius: 50%;
      width: 40px;
      height: 40px;
      animation: spin 0.8s linear infinite;
    }
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    .text {
      margin-top: 18px;
      font-size: 15px;
      color: #555555;
      font-weight: 500;
      letter-spacing: 0.3px;
    }
  </style>
</head>
<body>
  <div class="spinner"></div>
  <div class="text">Securing checkout session...</div>

  <script>
    (function() {
      // 1. Establish Shopify global context before loading mobileApp.js
      window.Shopify = window.Shopify || {};
      window.Shopify.shop = "$domainStr";
      window.Shopify.theme = { name: "MobileApp" };
      window.Shopify.currency = { active: "INR", rate: "1.0" };

      var executed = false;

      function sendBridgeMessage(msgObj) {
        try {
          if (window.ShiprocketBridge) {
            window.ShiprocketBridge.postMessage(JSON.stringify(msgObj));
          }
        } catch(e) {}
      }

      function startCheckout() {
        if (executed) return;
        executed = true;

        try {
          if (typeof window.getOneClickCheckoutUrl !== 'function') {
            sendBridgeMessage({
              type: 'error',
              message: 'mobileApp.js script loaded but window.getOneClickCheckoutUrl function is missing.'
            });
            return;
          }

          var payload = $payloadJsonStr;
          var url = window.getOneClickCheckoutUrl(payload);

          if (!url || typeof url !== 'string' || url.trim().length === 0) {
            sendBridgeMessage({
              type: 'error',
              message: 'getOneClickCheckoutUrl returned an empty URL response.'
            });
            return;
          }

          var trimmedUrl = url.trim();

          sendBridgeMessage({
            type: 'checkout_url',
            url: trimmedUrl
          });

          window.location.href = trimmedUrl;
        } catch(err) {
          sendBridgeMessage({
            type: 'error',
            message: 'Failed to initialize checkout URL: ' + (err.message || err)
          });
        }
      }

      // Explicit script loading with onload / onerror
      var script = document.createElement("script");
      script.src = "$scriptUrl";
      script.onload = function() {
        startCheckout();
      };
      script.onerror = function() {
        sendBridgeMessage({
          type: 'error',
          message: 'Failed to load Fastrr mobileApp.js script from server.'
        });
      };
      document.head.appendChild(script);
    })();
  </script>
</body>
</html>
''';
  }
}
