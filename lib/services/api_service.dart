import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../controller/pref.dart';
import '../model/categories_model.dart';
import '../model/product_model.dart';

class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    required this.statusCode,
  });
}

class ApiService {
  static String get baseUrl {
    String url = dotenv.get('BACKEND_URL', fallback: 'http://localhost:5000').trim();
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  static Future<String?> getAuthToken() async {
    return await Pref.getPref(PrefKey.authToken);
  }

  static Future<void> saveAuthToken(String token) async {
    await Pref.setPref(key: PrefKey.authToken, value: token);
  }

  static Future<void> clearAuthToken() async {
    await Pref.removePrefKey(PrefKey.authToken);
    await Pref.removePrefKey(PrefKey.customerId);
    await Pref.removePrefKey(PrefKey.customerRole);
  }

  static Future<Map<String, String>> _headers({bool isAuthRequired = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (isAuthRequired) {
      final token = await getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🔐 AUTHENTICATION
  // ──────────────────────────────────────────────────────────────────────────

  /// Send OTP to user phone
  static Future<ApiResponse<Map<String, dynamic>>> sendOtp(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/send-otp'),
        headers: await _headers(),
        body: jsonEncode({'phone': phone.replaceAll(RegExp(r'[^\d]'), '')}),
      );

      final data = jsonDecode(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && (data['success'] == true || data['status'] == true),
        message: data['message'] ?? 'OTP sent',
        data: data is Map<String, dynamic> ? data : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      debugPrint('ApiService.sendOtp error: $e');
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Verify OTP and obtain JWT Auth Token
  static Future<ApiResponse<Map<String, dynamic>>> verifyOtp(String phone, String otp) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final res = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-otp'),
        headers: await _headers(),
        body: jsonEncode({'phone': cleanPhone, 'otp': otp.trim()}),
      );

      final data = jsonDecode(res.body);
      final bool ok = res.statusCode == 200 && (data['success'] == true || data['token'] != null);

      if (ok && data['token'] != null) {
        await saveAuthToken(data['token'].toString());
        if (data['customer'] != null && data['customer']['_id'] != null) {
          await Pref.setPref(key: PrefKey.customerId, value: data['customer']['_id'].toString());
        }
      }

      return ApiResponse(
        success: ok,
        message: data['message'] ?? (ok ? 'Verified successfully' : 'Verification failed'),
        data: data is Map<String, dynamic> ? data : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      debugPrint('ApiService.verifyOtp error: $e');
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Logout from current device
  static Future<bool> logout() async {
    try {
      final headers = await _headers(isAuthRequired: true);
      await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: headers);
    } catch (e) {
      debugPrint('ApiService.logout error: $e');
    } finally {
      await clearAuthToken();
    }
    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🎨 BANNERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get banners (type: 'home' | 'category' | null)
  static Future<List<Map<String, dynamic>>> getBanners({String? type}) async {
    try {
      String path = '$baseUrl/api/banners';
      if (type != null && type.isNotEmpty) {
        path += '?type=$type';
      }

      final res = await http.get(Uri.parse(path), headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['banners'] is List) {
          return List<Map<String, dynamic>>.from(data['banners']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ApiService.getBanners error: $e');
    }
    return [];
  }

  static Future<List<CategoriesModel>> getBannerCollections() async {
    try {
      final list = await getBanners(type: 'category');
      return list.map((e) => CategoriesModel.fromJson({
        'id': e['_id'] ?? e['id'] ?? 0,
        'title': e['title'] ?? '',
        'handle': e['linkUrl'] ?? e['handle'] ?? '',
        'description': '',
        'image': e['imageUrl'] ?? e['image'] ?? '',
      })).toList();
    } catch (e) {
      debugPrint('ApiService.getBannerCollections error: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 📂 CATEGORIES
  // ──────────────────────────────────────────────────────────────────────────

  /// Get all categories
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/categories'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['categories'] is List) {
          return List<Map<String, dynamic>>.from(data['categories']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ApiService.getCategories error: $e');
    }
    return [];
  }

  static Future<List<CategoriesModel>> getCategoriesList() async {
    try {
      final list = await getCategories();
      return list.map((e) => CategoriesModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('ApiService.getCategoriesList error: $e');
      return [];
    }
  }

  /// Get category by ID or handle
  static Future<Map<String, dynamic>?> getCategoryById(String id) async {
    try {
      final cleanId = id.trim();
      final res = await http.get(
        Uri.parse('$baseUrl/api/categories/$cleanId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? (data['data'] ?? data['category'] ?? data) : null;
      }
    } catch (e) {
      debugPrint('ApiService.getCategoryById error: $e');
    }
    return null;
  }

  static Future<Map<String, String>> getCollection({required String id}) async {
    try {
      final cat = await getCategoryById(id);
      if (cat != null) {
        return {
          "title": cat['title']?.toString() ?? cat['name']?.toString() ?? '',
          "handle": cat['handle']?.toString() ?? cat['slug']?.toString() ?? id,
          "pro": (cat['products_count'] ?? cat['productCount'] ?? '0').toString(),
          "image": (cat['image'] is Map ? (cat['image']['src'] ?? cat['image']['url']) : cat['image'] ?? cat['imageUrl'] ?? '').toString(),
        };
      }
    } catch (e) {
      debugPrint('ApiService.getCollection error: $e');
    }
    return {};
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🛍️ PRODUCTS
  // ──────────────────────────────────────────────────────────────────────────

  /// List products with pagination, category filter, and search
  static Future<Map<String, dynamic>> getProducts({
    int page = 1,
    int limit = 50,
    String? categoryId,
    String? search,
    String? sort,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (categoryId != null && categoryId.isNotEmpty) {
        queryParams['category'] = categoryId.trim();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (sort != null && sort.isNotEmpty) {
        queryParams['sort'] = sort;
      }

      final uri = Uri.parse('$baseUrl/api/products').replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: await _headers());
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic>) {
          return data;
        } else if (data is List) {
          return {'data': data, 'total': data.length};
        }
      }
    } catch (e) {
      debugPrint('ApiService.getProducts error: $e');
    }
    return {'data': [], 'total': 0};
  }

  static Future<List<ProductModel>> getProductsList({int? limit, String? search, String? categoryId}) async {
    try {
      final data = await getProducts(limit: limit ?? 50, search: search, categoryId: categoryId);
      final list = (data['data'] as List? ?? data['products'] as List? ?? []);
      return list.map((e) => ProductModel.fromJson(e is Map ? Map<String, dynamic>.from(e) : {})).toList();
    } catch (e) {
      debugPrint('ApiService.getProductsList error: $e');
      return [];
    }
  }

  /// Get products by category
  static Future<List<Map<String, dynamic>>> getProductsByCategory(String categoryId) async {
    try {
      final cleanId = categoryId.trim();
      final res = await http.get(
        Uri.parse('$baseUrl/api/products/category/$cleanId'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['products'] is List) {
          return List<Map<String, dynamic>>.from(data['products']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ApiService.getProductsByCategory error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> getProductsFromCollections({
    required String id,
    int? limit,
    String? cursor,
  }) async {
    try {
      final rawList = await getProductsByCategory(id);
      final products = rawList.map((e) => ProductModel.fromJson(e)).toList();
      return {
        'products': products,
        'pageInfo': {'hasNextPage': false},
      };
    } catch (e) {
      debugPrint('ApiService.getProductsFromCollections error: $e');
      return {'products': <ProductModel>[], 'pageInfo': {'hasNextPage': false}};
    }
  }

  /// Get single product by handle / slug / ID
  static Future<Map<String, dynamic>?> getProductByHandle(String handle) async {
    try {
      final cleanHandle = handle.trim();
      final res = await http.get(
        Uri.parse('$baseUrl/api/products/$cleanHandle'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        } else if (data is Map && data['product'] != null) {
          return Map<String, dynamic>.from(data['product']);
        } else if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('ApiService.getProductByHandle error: $e');
    }
    return null;
  }

  static Future<ProductModel?> getProductDetails({required String productId}) async {
    try {
      final p = await getProductByHandle(productId);
      if (p != null) {
        return ProductModel.fromJson(p);
      }
    } catch (e) {
      debugPrint('ApiService.getProductDetails error: $e');
    }
    return null;
  }

  static Future<List<ProductModel>> getProductsRecommend({required String productId}) async {
    return await getProductsList(limit: 6);
  }

  static Future<List<ProductModel>> fetchSearchResults({required String query, int? limit}) async {
    return await getProductsList(search: query, limit: limit ?? 20);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🛒 CART
  // ──────────────────────────────────────────────────────────────────────────

  /// Get customer's cart
  static Future<Map<String, dynamic>?> getCart() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/cart'),
        headers: await _headers(isAuthRequired: true),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? (data['cart'] ?? data) : null;
      }
    } catch (e) {
      debugPrint('ApiService.getCart error: $e');
    }
    return null;
  }

  /// Add item to cart
  static Future<bool> addToCart(Map<String, dynamic> item) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/cart/items'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode(item),
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('ApiService.addToCart error: $e');
      return false;
    }
  }

  /// Update item quantity in cart
  static Future<bool> updateCartItem(String variantIdOrSku, int quantity) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/cart/items/$variantIdOrSku'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode({'quantity': quantity}),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.updateCartItem error: $e');
      return false;
    }
  }

  /// Remove item from cart
  static Future<bool> removeFromCart(String variantIdOrSku) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/cart/items/$variantIdOrSku'),
        headers: await _headers(isAuthRequired: true),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.removeFromCart error: $e');
      return false;
    }
  }

  /// Apply coupon to cart
  static Future<ApiResponse<Map<String, dynamic>>> applyCoupon(String code) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/cart/apply-coupon'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode({'code': code.trim().toUpperCase()}),
      );
      final data = jsonDecode(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && data['success'] == true,
        message: data['message'],
        data: data is Map<String, dynamic> ? data : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      debugPrint('ApiService.applyCoupon error: $e');
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Remove coupon from cart
  static Future<bool> removeCoupon() async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/cart/coupon'),
        headers: await _headers(isAuthRequired: true),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.removeCoupon error: $e');
      return false;
    }
  }

  /// Clear entire cart
  static Future<bool> clearCart() async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/cart'),
        headers: await _headers(isAuthRequired: true),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.clearCart error: $e');
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 📦 ORDERS & PAYMENTS
  // ──────────────────────────────────────────────────────────────────────────

  /// Create Razorpay order ID
  static Future<Map<String, dynamic>?> createRazorpayOrder({
    required double amount,
    String? receipt,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/orders/razorpay'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode({
          'amount': amount,
          'receipt': receipt ?? 'rcpt_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? (data['order'] ?? data['data'] ?? data) : null;
      }
    } catch (e) {
      debugPrint('ApiService.createRazorpayOrder error: $e');
    }
    return null;
  }

  /// Create a new order (COD or Online)
  static Future<ApiResponse<Map<String, dynamic>>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/orders'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode(orderData),
      );
      final data = jsonDecode(res.body);
      return ApiResponse(
        success: res.statusCode == 200 || res.statusCode == 201,
        message: data['message'],
        data: data is Map<String, dynamic> ? (data['data'] ?? data['order'] ?? data) : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      debugPrint('ApiService.createOrder error: $e');
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  /// Get orders for a specific customer by phone or email
  static Future<List<Map<String, dynamic>>> getOrdersByCustomer(String emailOrPhone) async {
    try {
      final encoded = Uri.encodeComponent(emailOrPhone.trim());
      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/customer/$encoded'),
        headers: await _headers(isAuthRequired: true),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['orders'] is List) {
          return List<Map<String, dynamic>>.from(data['orders']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ApiService.getOrdersByCustomer error: $e');
    }
    return [];
  }

  /// Get single order details
  static Future<Map<String, dynamic>?> getOrderById(String orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderId'),
        headers: await _headers(isAuthRequired: true),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? (data['data'] ?? data['order'] ?? data) : null;
      }
    } catch (e) {
      debugPrint('ApiService.getOrderById error: $e');
    }
    return null;
  }

  /// Cancel an order
  static Future<ApiResponse<Map<String, dynamic>>> cancelOrder(String orderId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/orders/$orderId/cancel'),
        headers: await _headers(isAuthRequired: true),
      );
      final data = jsonDecode(res.body);
      return ApiResponse(
        success: res.statusCode == 200 && (data['success'] == true || data['status'] == true),
        message: data['message'] ?? 'Order cancelled',
        data: data is Map<String, dynamic> ? data : null,
        statusCode: res.statusCode,
      );
    } catch (e) {
      debugPrint('ApiService.cancelOrder error: $e');
      return ApiResponse(success: false, message: e.toString(), statusCode: 500);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 🏷️ COUPONS
  // ──────────────────────────────────────────────────────────────────────────

  /// Get list of active promo coupons
  static Future<List<Map<String, dynamic>>> getCoupons() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/coupons'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        } else if (data is Map && data['coupons'] is List) {
          return List<Map<String, dynamic>>.from(data['coupons']);
        } else if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        }
      }
    } catch (e) {
      debugPrint('ApiService.getCoupons error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getAvailableDiscounts() async {
    try {
      final coupons = await getCoupons();
      return coupons.map((c) => {
        'code': c['code'] ?? '',
        'summary': c['description'] ?? '${c['value'] ?? ''} OFF',
        'type': (c['valueType'] == 'percentage' || c['discountType'] == 'percentage') ? 'percentage' : 'fixed_amount',
        'value': c['value'] ?? c['discountValue'] ?? 0,
        'min_subtotal': c['minimumPurchase'] ?? c['minOrderAmount'] ?? 0,
        'minAmount': c['minimumPurchase'] ?? c['minOrderAmount'] ?? 0,
        'appliesOncePerCustomer': c['appliesOncePerCustomer'] ?? false,
        'startsAt': c['startDate'] ?? c['startsAt'],
      }).toList();
    } catch (e) {
      debugPrint('ApiService.getAvailableDiscounts error: $e');
      return [];
    }
  }

  /// Validate coupon by code
  static Future<Map<String, dynamic>?> validateDiscountCode(String code) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/coupons/${code.trim().toUpperCase()}'),
        headers: await _headers(),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coupon = data is Map && data['data'] != null ? data['data'] : (data is Map && data['coupon'] != null ? data['coupon'] : data);
        if (coupon is Map<String, dynamic>) {
          return {
            'code': coupon['code'] ?? code,
            'type': (coupon['valueType'] == 'percentage' || coupon['discountType'] == 'percentage') ? 'percentage' : 'fixed_amount',
            'value': (coupon['value'] ?? coupon['discountValue'] ?? 0).toDouble(),
            'min_subtotal': (coupon['minimumPurchase'] ?? coupon['minOrderAmount'] ?? 0).toDouble(),
            'minAmount': (coupon['minimumPurchase'] ?? coupon['minOrderAmount'] ?? 0).toDouble(),
          };
        }
      }
    } catch (e) {
      debugPrint('ApiService.validateDiscountCode error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> validateCoupon(String code) async {
    return await validateDiscountCode(code);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 👤 CUSTOMERS & PROFILE
  // ──────────────────────────────────────────────────────────────────────────

  /// Get logged-in customer profile
  static Future<Map<String, dynamic>?> getCurrentCustomer() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/customers/me'),
        headers: await _headers(isAuthRequired: true),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? (data['customer'] ?? data) : null;
      }
    } catch (e) {
      debugPrint('ApiService.getCurrentCustomer error: $e');
    }
    return null;
  }

  /// Update customer details
  static Future<bool> updateCustomer(String customerId, Map<String, dynamic> updateData) async {
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/api/customers/$customerId'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode(updateData),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.updateCustomer error: $e');
      return false;
    }
  }

  /// Add address to customer address book
  static Future<Map<String, dynamic>?> addAddress(String customerId, Map<String, dynamic> address) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/customers/$customerId/addresses'),
        headers: await _headers(isAuthRequired: true),
        body: jsonEncode(address),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('ApiService.addAddress error: $e');
    }
    return null;
  }

  /// Delete address from customer address book
  static Future<bool> deleteAddress(String customerId, String addressId) async {
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/api/customers/$customerId/addresses/$addressId'),
        headers: await _headers(isAuthRequired: true),
      );
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('ApiService.deleteAddress error: $e');
      return false;
    }
  }
}
