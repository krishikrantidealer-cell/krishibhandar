import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'pref.dart';

class CartItem {
  final String id;
  final String? productId;
  final int qty;
  final String title;
  final String price;
  final String image;
  final String variantTitle;

  CartItem({
    required this.id,
    this.productId,
    required this.qty,
    required this.title,
    required this.price,
    required this.image,
    required this.variantTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'variantId': id,
        'productId': productId,
        'qty': qty,
        'quantity': qty,
        'title': title,
        'price': price,
        'image': image,
        'variantTitle': variantTitle,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: (json['id'] ?? json['variantId'] ?? '').toString(),
        productId: (json['productId'] ?? json['product_id'])?.toString(),
        qty: int.tryParse((json['qty'] ?? json['quantity'] ?? 1).toString()) ?? 1,
        title: json['title'] ?? '',
        price: (json['price'] ?? '0').toString(),
        image: json['image'] ?? '',
        variantTitle: json['variantTitle'] ?? json['variant_title'] ?? '',
      );

  CartItem copyWith({
    String? id,
    String? productId,
    int? qty,
    String? title,
    String? price,
    String? image,
    String? variantTitle,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      qty: qty ?? this.qty,
      title: title ?? this.title,
      price: price ?? this.price,
      image: image ?? this.image,
      variantTitle: variantTitle ?? this.variantTitle,
    );
  }
}

class CartController extends ChangeNotifier {
  static final CartController _instance = CartController._internal();
  static CartController get instance => _instance;
  static CartController get notifier => _instance;

  CartController._internal() {
    _loadCart();
  }

  factory CartController() => _instance;

  List<CartItem> _items = [];
  bool _isInitialized = false;

  List<CartItem> get items => List.unmodifiable(_items);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.qty);
  int get uniqueItemCount => _items.length;

  double get totalAmount => _items.fold(0.0, (sum, item) {
        final p = double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        return sum + (p * item.qty);
      });

  List<String> get uniqueImages {
    final images = <String>[];
    for (var item in _items) {
      if (item.image.isNotEmpty) {
        String url = item.image;
        if (url.startsWith('//')) url = 'https:$url';
        if (!images.contains(url)) images.add(url);
      }
    }
    return images;
  }

  Future<void> _loadCart() async {
    try {
      final cartJson = await Pref.getPref(PrefKey.cart);
      if (cartJson != null && cartJson.isNotEmpty && cartJson != '[]') {
        final list = jsonDecode(cartJson);
        if (list is List) {
          _items = list
              .map((e) => CartItem.fromJson(e is Map ? Map<String, dynamic>.from(e) : {}))
              .where((item) => item.id.isNotEmpty && item.qty > 0)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('CartController: Error loading initial cart: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _persistAndSync() async {
    final cartList = _items.map((e) => e.toJson()).toList();
    await Pref.setPref(key: PrefKey.cart, value: jsonEncode(cartList));
    notifyListeners();
  }

  Future<void> addItem({
    required String variantId,
    String? productId,
    required int qty,
    required String title,
    required String price,
    required String? image,
    required String variantTitle,
  }) async {
    final index = _items.indexWhere((item) => item.id == variantId);
    final newItem = CartItem(
      id: variantId,
      productId: productId,
      qty: qty,
      title: title,
      price: price,
      image: image ?? '',
      variantTitle: variantTitle,
    );

    if (index >= 0) {
      _items[index] = newItem;
    } else {
      _items.add(newItem);
    }

    await _persistAndSync();

    // Background sync to backend if authenticated
    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.addToCart(newItem.toJson());
      }
    } catch (e) {
      debugPrint('CartController: backend sync error: $e');
    }
  }

  Future<void> updateItemQty(String variantId, int newQty) async {
    final index = _items.indexWhere((item) => item.id == variantId);
    if (index >= 0) {
      if (newQty > 0) {
        _items[index] = _items[index].copyWith(qty: newQty);
      } else {
        _items.removeAt(index);
      }
      await _persistAndSync();

      try {
        final token = await ApiService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          if (newQty > 0) {
            await ApiService.updateCartItem(variantId, newQty);
          } else {
            await ApiService.removeFromCart(variantId);
          }
        }
      } catch (e) {
        debugPrint('CartController: updateQty backend sync error: $e');
      }
    }
  }

  Future<void> removeItem(String variantId) async {
    _items.removeWhere((item) => item.id == variantId);
    await _persistAndSync();

    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.removeFromCart(variantId);
      }
    } catch (e) {
      debugPrint('CartController: removeFromCart backend sync error: $e');
    }
  }

  Future<void> clear() async {
    _items.clear();
    await Pref.removePrefKey(PrefKey.cart);
    notifyListeners();

    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.clearCart();
      }
    } catch (e) {
      debugPrint('CartController: clearCart backend sync error: $e');
    }
  }

  // ─── Static Facade for Backward Compatibility ─────────────────────────────
  static Future<void> addToCart({
    required String variantId,
    String? productId,
    required int qty,
    required String title,
    required String price,
    required String? image,
    required String variantTitle,
  }) =>
      _instance.addItem(
        variantId: variantId,
        productId: productId,
        qty: qty,
        title: title,
        price: price,
        image: image,
        variantTitle: variantTitle,
      );

  static Future<List<CartItem>> getCart() async {
    if (!_instance._isInitialized) {
      await _instance._loadCart();
    }
    return _instance.items;
  }

  static Future<void> updateQty(String variantId, int newQty) =>
      _instance.updateItemQty(variantId, newQty);

  static Future<void> removeFromCart(String variantId) =>
      _instance.removeItem(variantId);

  static Future<void> clearCart() => _instance.clear();
}
