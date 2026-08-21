import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../controller/cart_controller.dart';
import '../controller/constants.dart';

class ShopfloService {
  static const String _tokenEndpoint =
      'https://api.shopflo.co/kratos/api/v2/token';
  static const String defaultBackUrl =
      'https://krishibhandar.com/cart?action=backToCart';
  static const String defaultSuccessUrl =
      'https://krishibhandar.com/checkout/success';

  /// Generates a unique Shopflo session ID
  static String generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(900000) + 100000;
    return 'sf_${timestamp}_$random';
  }

  /// Creates a checkout token and returns the checkout URL using Shopflo V2 Token API.
  static Future<ShopfloTokenResult> createCheckoutToken({
    required List<CartItem> cartItems,
    String? couponCode,
    String? customerPhone,
    String? customerEmail,
    String? customerToken,
    Map<String, dynamic>? shippingAddress,
    Map<String, String>? attributionParams,
    String backUrl = defaultBackUrl,
    String successUrl = defaultSuccessUrl,
  }) async {
    try {
      final hasApiKey = Constants.shopfloApiKey.isNotEmpty;
      final hasMerchantId = Constants.shopfloMerchantId.isNotEmpty;

      debugPrint('🛍️ [ShopfloConfig] API key configured: $hasApiKey');
      debugPrint('🛍️ [ShopfloConfig] Merchant ID configured: $hasMerchantId');

      if (!hasApiKey || !hasMerchantId) {
        String errorMsg = 'Shopflo configuration missing.';
        if (!hasApiKey && !hasMerchantId) {
          errorMsg = 'Both SHOPFLO_API_KEY and SHOPFLO_MERCHANT_ID are missing.';
        } else if (!hasApiKey) {
          errorMsg = 'SHOPFLO_API_KEY is missing.';
        } else {
          errorMsg = 'SHOPFLO_MERCHANT_ID is missing.';
        }
        
        debugPrint('🛍️ [ShopfloService] Error: $errorMsg Please check app environment settings (.env).');
        return ShopfloTokenResult.failure(
          errorMessage: 'Shopflo configuration missing. Please check app environment settings.',
        );
      }

      debugPrint('🛍️ [Shopflo] Creating checkout...');
      final sessionId = generateSessionId();

      // Map cart items according to Shopflo V2 specification for Shopify
      final items = cartItems.map((item) {
        // Strip GID prefixes if present (e.g. gid://shopify/ProductVariant/123456 -> 123456)
        final variantIdStr = item.id.toString().split('/').last;
        final productIdStr = (item.productId?.toString() ?? '').split('/').last;

        final rawPriceStr = item.price.replaceAll(RegExp(r'[^\d.]'), '');
        final unitPrice = double.tryParse(rawPriceStr) ?? 0.0;
        final totalPrice = unitPrice * item.qty;

        final productName = item.title.isNotEmpty ? item.title : 'Product';
        final variantName = item.variantTitle.isNotEmpty ? item.variantTitle : '';
        final fullName = variantName.isNotEmpty
            ? '$productName - $variantName'
            : productName;

        return {
          'id': variantIdStr,
          'quantity': item.qty,
          'name': fullName,
          'product_name': productName,
          'variant_name': variantName,
          'price': unitPrice,
          'sku': variantIdStr,
          'product_id': productIdStr,
          'image': item.image,
          'line_price': {
            'sub_total': totalPrice,
            'total': totalPrice,
            'discounts': <Map<String, dynamic>>[],
          },
        };
      }).toList();

      // Customer authentication object for Shopify Storefront
      final customerAuth = {
        'authentication': {
          'shop_storefront_token': Constants.storefrontAccessToken,
          'platform': 'SHOPIFY_STOREFRONT',
          'user_token': customerToken ?? '',
        },
      };

      final payload = <String, dynamic>{
        'sf_session_id': sessionId,
        'items': items,
        'customer': customerAuth,
        'back_url': backUrl,
        'success_url': successUrl,
      };

      // Add coupon/discount code if applied
      if (couponCode != null && couponCode.trim().isNotEmpty) {
        payload['discount_code'] = couponCode.trim();
        payload['discount_codes'] = [couponCode.trim()];
      }

      // Add customer contact info if available
      if (customerPhone != null && customerPhone.isNotEmpty) {
        payload['phone'] = customerPhone;
      }
      if (customerEmail != null && customerEmail.isNotEmpty) {
        payload['email'] = customerEmail;
      }

      // Add UTM attribution metadata in Shopflo's required List<NameValue> format
      if (attributionParams != null && attributionParams.isNotEmpty) {
        payload['note_attributes'] = attributionParams.entries
            .where((e) => e.value.isNotEmpty && e.value != 'None')
            .map((e) => {'name': e.key, 'value': e.value})
            .toList();
        payload['attributes'] = attributionParams;
      }

      // Add shipping address if available
      if (shippingAddress != null && shippingAddress.isNotEmpty) {
        payload['shipping_address'] = shippingAddress;
      }

      final headers = {
        'Authorization': Constants.shopfloApiKey,
        'Content-Type': 'application/json',
        'Merchant': Constants.shopfloMerchantId,
        'x-merchant-id': Constants.shopfloMerchantId,
      };

      if (kDebugMode) {
        debugPrint('🛍️ [ShopfloService] Request Endpoint: $_tokenEndpoint');
        debugPrint('🛍️ [ShopfloService] Request Headers: {Authorization: [REDACTED], Merchant: ${Constants.shopfloMerchantId}}');
        debugPrint('🛍️ [ShopfloService] Request Payload: {sf_session_id: $sessionId, items_count: ${items.length}}');
      }

      final response = await http.post(
        Uri.parse(_tokenEndpoint),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        debugPrint('🛍️ [ShopfloService] Response Code: ${response.statusCode}');
        debugPrint('🛍️ [ShopfloService] Response Body: ${response.body}');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Extract checkout URL from standard response structures
        String? checkoutUrl;
        String? token;

        if (data.containsKey('checkout_url') && data['checkout_url'] != null) {
          checkoutUrl = data['checkout_url'].toString();
        } else if (data['data'] is Map &&
            data['data']['checkout_url'] != null) {
          checkoutUrl = data['data']['checkout_url'].toString();
        } else if (data.containsKey('url') && data['url'] != null) {
          checkoutUrl = data['url'].toString();
        } else if (data['data'] is Map && data['data']['url'] != null) {
          checkoutUrl = data['data']['url'].toString();
        }

        if (data.containsKey('token') && data['token'] != null) {
          token = data['token'].toString();
        } else if (data['data'] is Map && data['data']['token'] != null) {
          token = data['data']['token'].toString();
        }

        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          debugPrint('🛍️ [Shopflo] Checkout token/url received');
          debugPrint('🛍️ [Shopflo] Opening checkout');
          return ShopfloTokenResult.success(
            checkoutUrl: checkoutUrl,
            token: token,
            rawResponse: data,
          );
        } else {
          return ShopfloTokenResult.failure(
            errorMessage:
                'Checkout URL was missing from the Shopflo response.',
            statusCode: response.statusCode,
          );
        }
      } else {
        String errorMsg = 'Failed to generate checkout token (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['message'] != null) {
            errorMsg = errorData['message'].toString();
          } else if (errorData['error'] != null) {
            errorMsg = errorData['error'].toString();
          }
        } catch (_) {}

        return ShopfloTokenResult.failure(
          errorMessage: errorMsg,
          statusCode: response.statusCode,
        );
      }
    } catch (e, stack) {
      debugPrint('🛍️ [ShopfloService] Exception: $e\n$stack');
      return ShopfloTokenResult.failure(
        errorMessage: 'Network or communication error: $e',
      );
    }
  }
}

class ShopfloTokenResult {
  final bool isSuccess;
  final String? checkoutUrl;
  final String? token;
  final String? errorMessage;
  final int? statusCode;
  final Map<String, dynamic>? rawResponse;

  ShopfloTokenResult._({
    required this.isSuccess,
    this.checkoutUrl,
    this.token,
    this.errorMessage,
    this.statusCode,
    this.rawResponse,
  });

  factory ShopfloTokenResult.success({
    required String checkoutUrl,
    String? token,
    Map<String, dynamic>? rawResponse,
  }) {
    return ShopfloTokenResult._(
      isSuccess: true,
      checkoutUrl: checkoutUrl,
      token: token,
      rawResponse: rawResponse,
    );
  }

  factory ShopfloTokenResult.failure({
    required String errorMessage,
    int? statusCode,
  }) {
    return ShopfloTokenResult._(
      isSuccess: false,
      errorMessage: errorMessage,
      statusCode: statusCode,
    );
  }
}
