import 'package:equatable/equatable.dart';
import '../../controller/cart_controller.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class LoadCartEvent extends CartEvent {
  const LoadCartEvent();
}

class AddToCartEvent extends CartEvent {
  final CartItem item;

  const AddToCartEvent({required this.item});

  @override
  List<Object?> get props => [item];
}

class UpdateCartQuantityEvent extends CartEvent {
  final String variantId;
  final int quantity;

  const UpdateCartQuantityEvent({
    required this.variantId,
    required this.quantity,
  });

  @override
  List<Object?> get props => [variantId, quantity];
}

class RemoveFromCartEvent extends CartEvent {
  final String variantId;

  const RemoveFromCartEvent({required this.variantId});

  @override
  List<Object?> get props => [variantId];
}

class ClearCartEvent extends CartEvent {
  const ClearCartEvent();
}
