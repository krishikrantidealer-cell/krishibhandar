import 'package:equatable/equatable.dart';
import '../../model/order_model.dart';

abstract class OrderState extends Equatable {
  const OrderState();

  @override
  List<Object?> get props => [];
}

class OrderInitialState extends OrderState {
  const OrderInitialState();
}

class OrderLoadingState extends OrderState {
  final List<OrderModel> currentOrders;

  const OrderLoadingState({this.currentOrders = const []});

  @override
  List<Object?> get props => [currentOrders];
}

class OrderLoadedState extends OrderState {
  final List<OrderModel> orders;
  final DateTime lastFetched;

  const OrderLoadedState({
    required this.orders,
    required this.lastFetched,
  });

  @override
  List<Object?> get props => [orders, lastFetched];
}

class OrderErrorState extends OrderState {
  final String message;
  final List<OrderModel> currentOrders;

  const OrderErrorState({
    required this.message,
    this.currentOrders = const [],
  });

  @override
  List<Object?> get props => [message, currentOrders];
}

class OrderActionSuccessState extends OrderState {
  final String message;
  final List<OrderModel> orders;

  const OrderActionSuccessState({
    required this.message,
    required this.orders,
  });

  @override
  List<Object?> get props => [message, orders];
}
