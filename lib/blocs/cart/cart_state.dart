import 'package:equatable/equatable.dart';
import '../../controller/cart_controller.dart';

abstract class CartState extends Equatable {
  final List<CartItem> items;

  const CartState({this.items = const []});

  int get itemCount => items.fold(0, (sum, item) => sum + item.qty);
  int get uniqueItemCount => items.length;

  double get totalAmount => items.fold(0.0, (sum, item) {
        final p = double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        return sum + (p * item.qty);
      });

  List<String> get uniqueImages {
    final images = <String>[];
    for (var item in items) {
      if (item.image.isNotEmpty) {
        String url = item.image;
        if (url.startsWith('//')) url = 'https:$url';
        if (!images.contains(url)) images.add(url);
      }
    }
    return images;
  }

  @override
  List<Object?> get props => [items];
}

class CartInitialState extends CartState {
  const CartInitialState() : super(items: const []);
}

class CartLoadingState extends CartState {
  const CartLoadingState({super.items});
}

class CartLoadedState extends CartState {
  const CartLoadedState({required super.items});

  @override
  List<Object?> get props => [items];
}

class CartErrorState extends CartState {
  final String message;

  const CartErrorState({required this.message, super.items});

  @override
  List<Object?> get props => [message, items];
}
