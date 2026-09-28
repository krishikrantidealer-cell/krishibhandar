import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'qty': qty,
        'title': title,
        'price': price,
        'image': image,
        'variantTitle': variantTitle,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        id: json['id'].toString(),
        productId: json['productId']?.toString(),
        qty: int.tryParse(json['qty'].toString()) ?? 1,
        title: json['title'] ?? '',
        price: json['price'] ?? '0',
        image: json['image'] ?? '',
        variantTitle: json['variantTitle'] ?? '',
      );
}

class CartController extends ChangeNotifier {
  static final CartController _instance = CartController._internal();
  factory CartController() => _instance;
  CartController._internal() {
    _loadFromStorage();
  }

  static List<CartItem> _items = [];
  static bool _isLoaded = false;

  static List<CartItem> get currentItems => List.unmodifiable(_items);

  static Future<void> ensureInitialized() async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }
  }

  static Future<void> _loadFromStorage() async {
    try {
      final cartJson = await Pref.getPref(PrefKey.cart);
      if (cartJson != null && cartJson.isNotEmpty && cartJson != '[]') {
        final List<dynamic> list = jsonDecode(cartJson);
        _items = list.map((e) => CartItem.fromJson(e)).toList();
      } else {
        _items = [];
      }
    } catch (_) {
      _items = [];
    }
    _isLoaded = true;
    _instance.notifyListeners();
  }

  static void _saveToStorage() {
    try {
      final jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
      Pref.setPref(key: PrefKey.cart, value: jsonStr);
    } catch (e) {
      debugPrint("CartController save error: $e");
    }
  }

  static Future<void> flushSave() async {
    final jsonStr = jsonEncode(_items.map((e) => e.toJson()).toList());
    await Pref.setPref(key: PrefKey.cart, value: jsonStr);
  }

  static int getItemQuantity(String variantId) {
    final idx = _items.indexWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());
    return idx >= 0 ? _items[idx].qty : 0;
  }

  static Future<List<CartItem>> getCart() async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }
    return List.from(_items);
  }

  static Future<void> addToCart({
    required String variantId,
    String? productId,
    required int qty,
    required String title,
    required String price,
    required String? image,
    required String variantTitle,
  }) async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }

    final addQty = qty > 0 ? qty : 1;
    final index = _items.indexWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());

    if (index >= 0) {
      _items[index] = _items[index].copyWith(
        qty: _items[index].qty + addQty,
        title: title,
        price: price,
        image: (image != null && image.isNotEmpty)
            ? image
            : _items[index].image,
        variantTitle: variantTitle,
      );
    } else {
      _items.add(CartItem(
        id: variantId,
        productId: productId,
        qty: addQty,
        title: title,
        price: price,
        image: image ?? '',
        variantTitle: variantTitle,
      ));
    }

    _instance.notifyListeners();
    _saveToStorage();
  }

  static Future<void> increment(String variantId) async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }
    final index = _items.indexWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());
    if (index >= 0) {
      final current = _items[index];
      _items[index] = current.copyWith(qty: current.qty + 1);
      _instance.notifyListeners();
      _saveToStorage();
    }
  }

  static Future<void> decrement(String variantId) async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }
    final index = _items.indexWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());
    if (index >= 0) {
      final current = _items[index];
      if (current.qty > 1) {
        _items[index] = current.copyWith(qty: current.qty - 1);
      } else {
        _items.removeAt(index);
      }
      _instance.notifyListeners();
      _saveToStorage();
    }
  }

  static Future<void> updateQty(String variantId, int newQty) async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }

    final index = _items.indexWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());
    if (index >= 0) {
      if (newQty > 0) {
        _items[index] = _items[index].copyWith(qty: newQty);
      } else {
        _items.removeAt(index);
      }
      _instance.notifyListeners();
      _saveToStorage();
    }
  }

  static Future<void> removeFromCart(String variantId) async {
    if (!_isLoaded) {
      await _loadFromStorage();
    }

    _items.removeWhere(
        (it) => it.id.toString().trim() == variantId.toString().trim());
    _instance.notifyListeners();
    _saveToStorage();
  }

  static Future<void> clearCart() async {
    _items.clear();
    _instance.notifyListeners();
    await Pref.removePrefKey(PrefKey.cart);
  }

  void notifyCartChanged() {
    notifyListeners();
  }
}
