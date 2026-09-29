import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../controller/constants.dart';
import '../model/categories_model.dart';
import '../model/localization_model.dart';
import '../model/product_model.dart';
import '../model/order_model.dart';
import '../services/attribution_service.dart';

/// Krishi Bhandar Backend REST API Service
class BhandarApiService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String get _baseUrl => Constants.apiBaseUrl;

  static Map<String, String> get _header => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ==========================================
  // Categories & Banners
  // ==========================================
  static Future<List<CategoriesModel>> getCategories(
    BuildContext? context, {
    String? cursor,
    String? forcedLang,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/categories'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['categories'] ?? decoded['data'] ?? []);

        if (list is List) {
          final List<CategoriesModel> categories = [];
          for (var item in list) {
            if (item is Map) {
              final rawId = item['id'] ?? item['_id'] ?? item['shopifyId'] ?? '';
              final parsedId = int.tryParse(rawId.toString().replaceAll(RegExp(r'[^\d]'), '')) ??
                  rawId.toString().hashCode.abs() % 1000000;

              String imgUrl = '';
              if (item['imageUrl'] != null && item['imageUrl'].toString().trim().isNotEmpty) {
                imgUrl = item['imageUrl'].toString().trim();
              } else if (item['bannerImage'] != null && item['bannerImage'].toString().trim().isNotEmpty) {
                imgUrl = item['bannerImage'].toString().trim();
              } else if (item['image'] is Map && item['image']['src'] != null) {
                imgUrl = item['image']['src'].toString().trim();
              } else if (item['image'] is String && item['image'].toString().trim().isNotEmpty) {
                imgUrl = item['image'].toString().trim();
              } else if (item['icon'] != null) {
                imgUrl = item['icon'].toString().trim();
              }

              final name = (item['name'] ?? item['title'] ?? '').toString();
              final handle = (item['slug'] ?? item['handle'] ?? name).toString();

              categories.add(
                CategoriesModel(
                  id: parsedId,
                  title: name,
                  handle: handle,
                  description: (item['description'] ?? '').toString(),
                  image: imgUrl,
                ),
              );
            }
          }
          return categories;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getCategories Error: $e");
    }
    return [];
  }

  static Future<List<CategoriesModel>> getBannerCollections(
    BuildContext? context, {
    String? forcedLang,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/banners?type=home'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['banners'] ?? decoded['data'] ?? []);

        if (list is List) {
          final List<CategoriesModel> banners = [];
          for (var item in list) {
            if (item is Map) {
              final rawId = item['id'] ?? item['_id'] ?? '';
              final parsedId = int.tryParse(rawId.toString().replaceAll(RegExp(r'[^\d]'), '')) ??
                  rawId.toString().hashCode.abs() % 1000000;

              String imgUrl = '';
              if (item['imageUrl'] != null && item['imageUrl'].toString().trim().isNotEmpty) {
                imgUrl = item['imageUrl'].toString().trim();
              } else if (item['imageUrlMedium'] != null && item['imageUrlMedium'].toString().trim().isNotEmpty) {
                imgUrl = item['imageUrlMedium'].toString().trim();
              } else if (item['image'] is Map && item['image']['src'] != null) {
                imgUrl = item['image']['src'].toString().trim();
              } else if (item['image'] != null && item['image'].toString().trim().isNotEmpty) {
                imgUrl = item['image'].toString().trim();
              }

              banners.add(
                CategoriesModel(
                  id: parsedId,
                  title: (item['title'] ?? item['name'] ?? '').toString(),
                  handle: (item['linkValue'] ?? item['link'] ?? item['target'] ?? item['slug'] ?? '').toString(),
                  description: (item['subtitle'] ?? item['description'] ?? '').toString(),
                  image: imgUrl,
                ),
              );
            }
          }
          return banners;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getBannerCollections Error: $e");
    }
    return [];
  }

  static Future<Map<String, String>> getCollection({required String id}) async {
    try {
      final endpoint = id.startsWith('/') ? id : '/api/collections/$id';
      final res = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final col = decoded['collection'] ?? decoded['data'] ?? decoded;
        if (col is Map) {
          String imgUrl = '';
          if (col['bannerImage'] != null && col['bannerImage'].toString().isNotEmpty) {
            imgUrl = col['bannerImage'].toString();
          } else if (col['image'] is String) {
            imgUrl = col['image'].toString();
          }

          return {
            'id': (col['id'] ?? col['_id'] ?? id).toString(),
            'title': (col['title'] ?? col['name'] ?? col['bannerTitle'] ?? '').toString(),
            'image': imgUrl,
            'description': (col['description'] ?? '').toString(),
          };
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getCollection Error: $e");
    }
    return {};
  }

  static Future<Map<String, String>> getCollectionDetails(
    BuildContext? context, {
    required String id,
  }) async {
    return getCollection(id: id);
  }

  static Future<List<Map<String, String>>> getHomeScreenSections() async {
    final List<Map<String, String>> sections = [];
    final Set<String> seenIds = {};

    try {
      // 1. Fetch Collections with strip banners from API
      final resCols = await http.get(
        Uri.parse('$_baseUrl/api/collections'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (resCols.statusCode >= 200 && resCols.statusCode < 300) {
        final decoded = jsonDecode(resCols.body);
        final list = decoded is List
            ? decoded
            : (decoded['collections'] ?? decoded['data'] ?? []);

        if (list is List) {
          for (var col in list) {
            if (col is Map) {
              final name = (col['name'] ?? col['title'] ?? '').toString().trim();
              final slug = (col['slug'] ?? '').toString().trim();
              final id = (col['id'] ?? col['_id'] ?? slug).toString().trim();
              final bannerImg = (col['bannerImage'] ?? col['imageUrl'] ?? '').toString().trim();
              final stripImg = (col['stripBanner'] ?? col['stripBannerImage'] ?? col['strip'] ?? '').toString().trim();
              final subtitle = (col['description'] ?? col['subtitle'] ?? '').toString().trim();

              // Skip crop collections in general sections list
              if (name.toLowerCase().contains('crop') || name.toLowerCase().contains('fasal')) {
                continue;
              }

              // STRICT: Only show on home screen if it has an actual strip banner
              if (name.isNotEmpty && id.isNotEmpty && stripImg.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                sections.add({
                  'id': slug.isNotEmpty ? slug : (name.isNotEmpty ? name : id),
                  'collectionId': id,
                  'name': name,
                  'title': name,
                  'slug': slug,
                  'subtitle': subtitle,
                  'image': bannerImg,
                  'stripBanner': stripImg,
                });
              }
            }
          }
        }
      }

      // 2. Fetch Categories with strip banners from API
      final resCats = await http.get(
        Uri.parse('$_baseUrl/api/categories'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (resCats.statusCode >= 200 && resCats.statusCode < 300) {
        final decoded = jsonDecode(resCats.body);
        final list = decoded is List
            ? decoded
            : (decoded['categories'] ?? decoded['data'] ?? []);

        if (list is List) {
          for (var cat in list) {
            if (cat is Map) {
              final name = (cat['name'] ?? cat['title'] ?? '').toString().trim();
              final slug = (cat['slug'] ?? cat['handle'] ?? name).toString().trim();
              final id = (cat['id'] ?? cat['_id'] ?? slug).toString().trim();
              final stripImg = (cat['stripBanner'] ?? cat['stripBannerImage'] ?? cat['strip'] ?? '').toString().trim();
              final bannerImg = (cat['bannerImage'] ?? cat['imageUrl'] ?? '').toString().trim();
              final subtitle = (cat['description'] ?? '').toString().trim();

              // STRICT: Only show on home screen if it has an actual strip banner
              if (name.isNotEmpty && id.isNotEmpty && stripImg.isNotEmpty && !seenIds.contains(id)) {
                seenIds.add(id);
                sections.add({
                  'id': slug.isNotEmpty ? slug : (name.isNotEmpty ? name : id),
                  'collectionId': id,
                  'name': name,
                  'title': name,
                  'slug': slug,
                  'subtitle': subtitle,
                  'image': bannerImg,
                  'stripBanner': stripImg,
                });
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getHomeScreenSections Error: $e");
    }

    return sections;
  }

  // ==========================================
  // Crops & Sub-collections (Shop by Crop)
  // ==========================================
  static Future<List<Map<String, String>>> getCrops(BuildContext? context) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/collections'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['collections'] ?? decoded['data'] ?? []);

        if (list is List) {
          for (var col in list) {
            if (col is Map) {
              final name = (col['name'] ?? col['title'] ?? '').toString().toLowerCase();
              final slug = (col['slug'] ?? '').toString().toLowerCase();
              if (name.contains('crop') || name.contains('fasal') || slug.contains('crop') || slug.contains('fasal')) {
                final subs = col['subCollections'] ?? col['subcollections'] ?? col['crops'] ?? col['children'];
                if (subs is List && subs.isNotEmpty) {
                  final List<Map<String, String>> crops = [];
                  for (var sub in subs) {
                    if (sub is Map) {
                      final subName = (sub['name'] ?? sub['title'] ?? '').toString();
                      final rawCount = sub['productsCount'] ?? sub['count'];
                      String subCount;
                      if (rawCount is int) {
                        subCount = '$rawCount ${rawCount == 1 ? "Product" : "Products"}';
                      } else if (rawCount != null && rawCount.toString().isNotEmpty) {
                        final str = rawCount.toString().trim();
                        final parsed = int.tryParse(str);
                        if (parsed != null) {
                          subCount = '$parsed ${parsed == 1 ? "Product" : "Products"}';
                        } else if (str.toLowerCase().contains('product')) {
                          subCount = str;
                        } else {
                          subCount = '$str Products';
                        }
                      } else {
                        subCount = '0 Products';
                      }

                      String img = '';
                      if (sub['image'] is Map && sub['image']['src'] != null) {
                        img = sub['image']['src'].toString();
                      } else if (sub['image'] != null && sub['image'].toString().isNotEmpty) {
                        img = sub['image'].toString();
                      } else if (sub['imageUrl'] != null) {
                        img = sub['imageUrl'].toString();
                      }

                      if (subName.isNotEmpty) {
                        crops.add({
                          'name': subName,
                          'count': subCount,
                          'image': img,
                        });
                      }
                    } else if (sub is String && sub.isNotEmpty) {
                      crops.add({
                        'name': sub,
                        'count': '0 Products',
                        'image': '',
                      });
                    }
                  }
                  if (crops.isNotEmpty) return crops;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getCrops Error: $e");
    }
    return [];
  }

  // ==========================================
  // Products
  // ==========================================
  static Future<Map<String, dynamic>> getProductsFromCollections(
    BuildContext? context, {
    String? id,
    String? collectionId,
    String? cursor,
    int? count,
    int? limit,
    String? forcedLang,
    String? sortKey,
    bool reverse = false,
  }) async {
    try {
      final targetId = (id ?? collectionId ?? '').trim();
      final targetLimit = limit ?? count ?? 20;

      // Legacy ID and collection mapping
      const legacyMap = {
        '329026371737': 'Insecticides',
        '329026175129': 'Fungicides',
        '329026142361': 'Fertilizers',
        '329026240665': 'Herbicides',
        '329026470041': 'PGRs',
        '333391134873': 'Buy 1 Get 1',
        '329119367321': 'Best Sellers',
        '6aa52c90f643d16337f7f7ec': 'Best Sellers',
        '6aa3f8b7f643d16337f7f7bd': 'Buy 1 Get 1',
      };

      final resolved = legacyMap[targetId] ?? targetId;
      String endpoint;

      if (resolved.isEmpty ||
          resolved == '0' ||
          resolved.toLowerCase() == 'all') {
        endpoint = '/api/products?limit=$targetLimit';
      } else {
        String queryName = resolved;
        if (resolved.toLowerCase().contains('buy 1 get 1') ||
            resolved.toLowerCase() == 'bogo' ||
            resolved.toLowerCase() == 'buy-1-get-1') {
          queryName = 'Buy 1 Get 1';
        } else if (resolved.toLowerCase().contains('best') ||
            resolved.toLowerCase() == 'best-sellers' ||
            resolved.toLowerCase() == 'best seller') {
          queryName = 'Best Sellers';
        } else if (resolved.toLowerCase().contains('crop') ||
            resolved.toLowerCase().contains('fasal')) {
          queryName = 'Shop By Crop';
        }
        endpoint =
            '/api/products?category=${Uri.encodeComponent(queryName)}&limit=$targetLimit';
      }

      final res = await http.get(
        Uri.parse('$_baseUrl$endpoint'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['products'] ?? decoded['data'] ?? []);

        if (list is List) {
          final List<ProductModel> products = list.map((item) {
            if (item is Map<String, dynamic>) {
              return ProductModel.fromJson(item);
            }
            return ProductModel.fromJson(Map<String, dynamic>.from(item));
          }).toList();

          return {
            'product': products,
            'products': products,
            'hasNextPage': false,
            'cursor': null,
          };
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getProductsFromCollections Error: $e");
    }
    return {
      'product': <ProductModel>[],
      'products': <ProductModel>[],
      'hasNextPage': false,
      'cursor': null,
    };
  }

  static Future<ProductModel?> getProductDetails(
    BuildContext? context, {
    String? id,
    String? productId,
    String? forcedLang,
  }) async {
    try {
      final rawId = (id ?? productId ?? '').trim();
      final cleanId = rawId.replaceAll(RegExp(r'[^\w-]'), '');

      // Try fetching direct product by ID
      final res = await http.get(
        Uri.parse('$_baseUrl/api/products/$cleanId'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final item = decoded['product'] ?? decoded['data'] ?? decoded;
        if (item is Map) {
          return ProductModel.fromJson(Map<String, dynamic>.from(item));
        }
      }

      // Fallback search if ID format differs
      final searchRes = await fetchSearchResults(null, query: rawId, limit: 1);
      if (searchRes.isNotEmpty) {
        return searchRes.first;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getProductDetails Error: $e");
    }
    return null;
  }

  static Future<ProductModel?> getProductVariantDetails(
    BuildContext? context, {
    required String variantId,
    String? forcedLang,
  }) async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/products?variantId=$variantId'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['products'] ?? decoded['data'] ?? []);

        if (list is List && list.isNotEmpty) {
          return ProductModel.fromJson(Map<String, dynamic>.from(list.first));
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getProductVariantDetails Error: $e");
    }
    return null;
  }

  static Future<List<ProductModel>> fetchSearchResults(
    BuildContext? context, {
    required String query,
    String? cursor,
    int limit = 20,
    String? forcedLang,
  }) async {
    try {
      final cleanQuery = query.trim();
      final res = await http.get(
        Uri.parse('$_baseUrl/api/products?search=${Uri.encodeComponent(cleanQuery)}&limit=$limit'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['products'] ?? decoded['data'] ?? []);

        if (list is List) {
          return list.map((item) {
            if (item is Map<String, dynamic>) {
              return ProductModel.fromJson(item);
            }
            return ProductModel.fromJson(Map<String, dynamic>.from(item));
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService fetchSearchResults Error: $e");
    }
    return [];
  }

  static Future<List<ProductModel>> getProductsRecommend(
    BuildContext? context, {
    String? id,
    String? productId,
    String? forcedLang,
  }) async {
    try {
      final targetId = id ?? productId ?? '';
      final res = await http.get(
        Uri.parse('$_baseUrl/api/products?limit=8'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['products'] ?? decoded['data'] ?? []);

        if (list is List) {
          return list
              .where((item) => (item['id'] ?? item['_id']).toString() != targetId)
              .take(6)
              .map((item) => ProductModel.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getProductsRecommend Error: $e");
    }
    return [];
  }

  static Future<ProductModel?> getProductsByVariant({
    required String variantId,
    String? forcedLang,
  }) async {
    return getProductVariantDetails(null, variantId: variantId);
  }

  // ==========================================
  // Localization & Share
  // ==========================================
  static Future<List<LocalizationModel>> getLocalization(
    BuildContext? context,
  ) async {
    return [
      LocalizationModel(name: 'हिंदी', iso: 'HI'),
      LocalizationModel(name: 'English', iso: 'EN'),
      LocalizationModel(name: 'తెలుగు', iso: 'TE'),
      LocalizationModel(name: 'मराठी', iso: 'MR'),
      LocalizationModel(name: 'தமிழ்', iso: 'TA'),
    ];
  }

  static Future<void> share({required String url}) async {
    // ignore: deprecated_member_use
    await Share.share(url);
  }

  // ==========================================
  // Coupons & Discounts
  // ==========================================
  static Future<List<Map<String, dynamic>>> getAvailableDiscounts() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/coupons'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['coupons'] ?? decoded['data'] ?? []);

        if (list is List) {
          return list.whereType<Map>().map((c) {
            final code = (c['code'] ?? c['title'] ?? '').toString();
            final discountType = (c['type'] ?? c['discountType'] ?? 'fixed_amount').toString();
            final value = (c['discount'] ?? c['value'] ?? c['amount'] ?? 0) is num
                ? (c['discount'] ?? c['value'] ?? c['amount'] ?? 0) as num
                : num.tryParse((c['discount'] ?? c['value'] ?? c['amount'] ?? '0').toString()) ?? 0;

            return {
              'code': code,
              'title': (c['title'] ?? code).toString(),
              'summary': (c['description'] ?? 'Save on your order').toString(),
              'type': discountType.contains('percent') ? 'percentage' : 'fixed_amount',
              'value': value,
              'minSubtotal': (c['minOrderAmount'] ?? c['min_subtotal'] ?? 0) is num
                  ? (c['minOrderAmount'] ?? c['min_subtotal'] ?? 0) as num
                  : 0,
              'status': (c['status'] ?? 'ACTIVE').toString().toUpperCase(),
            };
          }).toList();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getAvailableDiscounts Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> validateDiscountCode({
    required String code,
  }) async {
    try {
      final discounts = await getAvailableDiscounts();
      final cleanCode = code.trim().toUpperCase();

      for (var d in discounts) {
        if (d['code'].toString().toUpperCase() == cleanCode) {
          return d;
        }
      }

      if (cleanCode == "PAYONLINE60") {
        return {
          'code': 'PAYONLINE60',
          'title': 'Pay Online & Save ₹60',
          'summary': 'Flat ₹60 off on Online Payment',
          'type': 'fixed_amount',
          'value': 60.0,
          'status': 'ACTIVE',
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService validateDiscountCode Error: $e");
    }
    return null;
  }

  // ==========================================
  // Orders
  // ==========================================
  static Future<List<dynamic>> getCustomerOrders(String customerId) async {
    final cleanId = customerId.replaceAll(RegExp(r'[^\d]'), '');
    final List<dynamic> orders = [];
    final Set<String> seenOrderIds = {};

    // 1. Fetch from Backend REST API
    if (cleanId.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse('$_baseUrl/api/orders/customer/$cleanId'),
          headers: _header,
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          final decoded = jsonDecode(res.body);
          final list = decoded is List
              ? decoded
              : (decoded['orders'] ?? decoded['data'] ?? []);

          if (list is List) {
            for (var item in list) {
              try {
                OrderModel ord;
                if (item is Map<String, dynamic>) {
                  ord = OrderModel.fromJson(item);
                } else if (item is Map) {
                  ord = OrderModel.fromJson(Map<String, dynamic>.from(item));
                } else {
                  continue;
                }
                if (!seenOrderIds.contains(ord.orderNumber)) {
                  seenOrderIds.add(ord.orderNumber);
                  orders.add(ord);
                }
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint("BhandarApiService getCustomerOrders REST Error: $e");
      }
    }

    // 2. Fetch from Firestore for realtime orders fallback
    if (cleanId.isNotEmpty) {
      try {
        final snapshots = await Future.wait([
          _firestore
              .collection('orders')
              .where('customer_phone', isEqualTo: cleanId)
              .get()
              .timeout(const Duration(seconds: 5)),
          _firestore
              .collection('orders')
              .where('phone', isEqualTo: cleanId)
              .get()
              .timeout(const Duration(seconds: 5)),
          _firestore
              .collection('orders')
              .where('customer_id', isEqualTo: cleanId)
              .get()
              .timeout(const Duration(seconds: 5)),
        ]);

        for (var querySnap in snapshots) {
          for (var doc in querySnap.docs) {
            final data = doc.data();
            data['id'] ??= doc.id;
            data['order_number'] ??= doc.id;
            final ordNum = (data['order_number'] ?? doc.id).toString();
            if (!seenOrderIds.contains(ordNum)) {
              try {
                seenOrderIds.add(ordNum);
                orders.add(OrderModel.fromJson(data));
              } catch (_) {}
            }
          }
        }
      } catch (fsErr) {
        if (kDebugMode) debugPrint("Firestore getCustomerOrders Error: $fsErr");
      }
    }

    return orders;
  }

  static Future<Map<String, dynamic>> getOrderFullDetails(dynamic orderId) async {
    try {
      final cleanId = orderId.toString().replaceAll(RegExp(r'[^\w-]'), '');
      final res = await http.get(
        Uri.parse('$_baseUrl/api/orders/$cleanId'),
        headers: _header,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        return decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService getOrderFullDetails Error: $e");
    }
    return {};
  }

  static Future<Map<String, dynamic>> createOrder({
    required Map<String, dynamic> body,
    required bool isCod,
    required String? discountCode,
  }) async {
    final now = DateTime.now();
    final generatedOrderNum = 'ORD-${now.millisecondsSinceEpoch.toString().substring(5)}';

    final orderPayload = Map<String, dynamic>.from(body);
    final String cleanPhone = (orderPayload['phone'] ??
            orderPayload['customer_phone'] ??
            (orderPayload['shippingAddress'] is Map ? orderPayload['shippingAddress']['phone'] : null) ??
            '')
        .toString()
        .replaceAll(RegExp(r'[^\d]'), '');

    orderPayload['phone'] = cleanPhone;
    orderPayload['customer_phone'] = cleanPhone;
    orderPayload['customerPhone'] = cleanPhone;
    orderPayload['order_number'] ??= generatedOrderNum;
    orderPayload['orderNumber'] ??= generatedOrderNum;
    orderPayload['name'] ??= generatedOrderNum;
    orderPayload['id'] ??= generatedOrderNum;
    orderPayload['isCod'] = isCod;
    orderPayload['paymentMethod'] = isCod ? 'COD' : 'ONLINE';
    orderPayload['payment_method'] = isCod ? 'COD' : 'ONLINE';
    orderPayload['financial_status'] = isCod ? 'pending' : 'paid';
    orderPayload['financialStatus'] = isCod ? 'pending' : 'paid';
    orderPayload['created_at'] ??= now.toIso8601String();
    orderPayload['createdAt'] ??= now.toIso8601String();

    if (discountCode != null && discountCode.isNotEmpty) {
      orderPayload['discountCode'] = discountCode;
      orderPayload['discount_code'] = discountCode;
    }

    try {
      final attribution = await AttributionService().getAttribution();
      if (attribution.isNotEmpty) {
        orderPayload['attribution'] = attribution;
        orderPayload['note_attributes'] = attribution.entries.map((e) => {'name': e.key, 'value': e.value}).toList();
      }
    } catch (_) {}

    // 1. Post to Backend REST API first
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/orders'),
        headers: _header,
        body: jsonEncode(orderPayload),
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint("📦 [createOrder API Response] status=${res.statusCode} body=${res.body}");
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        Map<String, dynamic> result = {};
        if (decoded is Map<String, dynamic>) {
          result = decoded;
        } else if (decoded is Map) {
          result = Map<String, dynamic>.from(decoded);
        }

        final serverOrder = (result['order'] is Map ? result['order'] : result['data']) ?? orderPayload;
        final actualOrderNum = (result['orderNumber'] ?? serverOrder['name'] ?? serverOrder['orderNumber'] ?? generatedOrderNum).toString();

        // Dual-Write: Save the confirmed order to Firestore
        try {
          await _firestore
              .collection('orders')
              .doc(actualOrderNum)
              .set(Map<String, dynamic>.from(serverOrder), SetOptions(merge: true))
              .timeout(const Duration(seconds: 4));
        } catch (_) {}

        return {
          "success": true,
          "orderNumber": actualOrderNum,
          "order_number": actualOrderNum,
          "order": serverOrder,
          "data": serverOrder,
        };
      } else {
        final decoded = jsonDecode(res.body);
        final errMsg = (decoded is Map ? (decoded['message'] ?? decoded['error']) : null) ?? 'Server error ${res.statusCode}';
        return {
          "success": false,
          "error": errMsg,
          "message": errMsg,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService createOrder REST Error: $e");
      
      // Fallback: Save to Firestore if network timeout / offline
      try {
        await _firestore
            .collection('orders')
            .doc(generatedOrderNum)
            .set(orderPayload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
      } catch (_) {}

      return {
        "success": true,
        "orderNumber": generatedOrderNum,
        "order_number": generatedOrderNum,
        "id": generatedOrderNum,
        "order": orderPayload,
      };
    }
  }

  static Future<bool> cancelOrder(String orderId) async {
    try {
      final cleanId = orderId.replaceAll(RegExp(r'[^\w-]'), '');
      final res = await http.put(
        Uri.parse('$_baseUrl/api/orders/$cleanId'),
        headers: _header,
        body: jsonEncode({'orderStatus': 'cancelled', 'cancelled_at': DateTime.now().toIso8601String()}),
      ).timeout(const Duration(seconds: 15));

      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService cancelOrder Error: $e");
      return false;
    }
  }

  static Future<String?> updateOrderAttribution(String orderIdOrName) async {
    try {
      final attribution = await AttributionService().getAttribution();
      if (attribution.isEmpty) return null;

      final cleanId = orderIdOrName.replaceAll(RegExp(r'[^\w-]'), '');
      final res = await http.put(
        Uri.parse('$_baseUrl/api/orders/$cleanId'),
        headers: _header,
        body: jsonEncode({'attribution': attribution}),
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return 'Updated attribution successfully';
      }
    } catch (e) {
      if (kDebugMode) debugPrint("BhandarApiService updateOrderAttribution Error: $e");
    }
    return null;
  }
}

// Alias for convenient access
typedef BhandarApi = BhandarApiService;
