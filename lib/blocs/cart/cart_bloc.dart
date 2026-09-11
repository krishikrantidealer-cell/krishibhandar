import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controller/cart_controller.dart';
import '../../controller/pref.dart';
import '../../services/api_service.dart';
import 'cart_event.dart';
import 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartInitialState()) {
    on<LoadCartEvent>(_onLoadCart);
    on<AddToCartEvent>(_onAddToCart);
    on<UpdateCartQuantityEvent>(_onUpdateQuantity);
    on<RemoveFromCartEvent>(_onRemoveFromCart);
    on<ClearCartEvent>(_onClearCart);

    add(const LoadCartEvent());
  }

  Future<void> _onLoadCart(LoadCartEvent event, Emitter<CartState> emit) async {
    emit(CartLoadingState(items: state.items));
    try {
      final cartJson = await Pref.getPref(PrefKey.cart);
      if (cartJson != null && cartJson.isNotEmpty && cartJson != '[]') {
        final list = jsonDecode(cartJson);
        if (list is List) {
          final items = list
              .map((e) => CartItem.fromJson(e is Map ? Map<String, dynamic>.from(e) : {}))
              .where((item) => item.id.isNotEmpty && item.qty > 0)
              .toList();
          emit(CartLoadedState(items: items));
          return;
        }
      }
      emit(const CartLoadedState(items: []));
    } catch (e) {
      debugPrint('CartBloc: LoadCart error: $e');
      emit(CartErrorState(message: e.toString(), items: state.items));
    }
  }

  Future<void> _onAddToCart(AddToCartEvent event, Emitter<CartState> emit) async {
    final currentList = List<CartItem>.from(state.items);
    final index = currentList.indexWhere((item) => item.id == event.item.id);

    if (index >= 0) {
      currentList[index] = event.item;
    } else {
      currentList.add(event.item);
    }

    emit(CartLoadedState(items: currentList));
    await _persistAndSync(currentList);

    // Sync to backend
    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.addToCart(event.item.toJson());
      }
    } catch (e) {
      debugPrint('CartBloc: backend sync add error: $e');
    }
  }

  Future<void> _onUpdateQuantity(
      UpdateCartQuantityEvent event, Emitter<CartState> emit) async {
    final currentList = List<CartItem>.from(state.items);
    final index = currentList.indexWhere((item) => item.id == event.variantId);

    if (index >= 0) {
      if (event.quantity > 0) {
        currentList[index] = currentList[index].copyWith(qty: event.quantity);
      } else {
        currentList.removeAt(index);
      }

      emit(CartLoadedState(items: currentList));
      await _persistAndSync(currentList);

      try {
        final token = await ApiService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          if (event.quantity > 0) {
            await ApiService.updateCartItem(event.variantId, event.quantity);
          } else {
            await ApiService.removeFromCart(event.variantId);
          }
        }
      } catch (e) {
        debugPrint('CartBloc: backend sync update error: $e');
      }
    }
  }

  Future<void> _onRemoveFromCart(
      RemoveFromCartEvent event, Emitter<CartState> emit) async {
    final currentList = List<CartItem>.from(state.items);
    currentList.removeWhere((item) => item.id == event.variantId);

    emit(CartLoadedState(items: currentList));
    await _persistAndSync(currentList);

    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.removeFromCart(event.variantId);
      }
    } catch (e) {
      debugPrint('CartBloc: backend sync remove error: $e');
    }
  }

  Future<void> _onClearCart(ClearCartEvent event, Emitter<CartState> emit) async {
    emit(const CartLoadedState(items: []));
    await Pref.removePrefKey(PrefKey.cart);

    try {
      final token = await ApiService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        await ApiService.clearCart();
      }
    } catch (e) {
      debugPrint('CartBloc: backend sync clear error: $e');
    }
  }

  Future<void> _persistAndSync(List<CartItem> items) async {
    final cartList = items.map((e) => e.toJson()).toList();
    await Pref.setPref(key: PrefKey.cart, value: jsonEncode(cartList));
  }
}
