import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../controller/auth_controller.dart';
import '../../model/order_model.dart';
import '../../services/api_service.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  OrderBloc() : super(const OrderInitialState()) {
    on<FetchOrdersEvent>(_onFetchOrders);
    on<CancelOrderEvent>(_onCancelOrder);
  }

  List<OrderModel> _currentOrders = [];

  List<OrderModel> get currentOrders => _currentOrders;

  Future<void> _onFetchOrders(
      FetchOrdersEvent event, Emitter<OrderState> emit) async {
    // 1. Silent fetch debounce: if recent and silent, skip
    if (event.isSilent && state is OrderLoadedState) {
      final loaded = state as OrderLoadedState;
      if (DateTime.now().difference(loaded.lastFetched) <
          const Duration(seconds: 10)) {
        return;
      }
    }

    // 2. Emit loading if not silent
    if (!event.isSilent) {
      emit(OrderLoadingState(currentOrders: _currentOrders));
    }

    try {
      final phone = await AuthController.getSavedPhone();
      final customerId = await AuthController.getCustomerId();
      final identifier =
          (phone != null && phone.isNotEmpty) ? phone : customerId;

      if (identifier == null || identifier.isEmpty || identifier == "null") {
        _currentOrders = [];
        emit(OrderLoadedState(
          orders: const [],
          lastFetched: DateTime.now(),
        ));
        return;
      }

      final orderData = await ApiService.getOrdersByCustomer(identifier);
      final List<OrderModel> orders =
          orderData.map((e) => OrderModel.fromJson(e)).toList();

      _currentOrders = orders;
      emit(OrderLoadedState(
        orders: orders,
        lastFetched: DateTime.now(),
      ));
    } catch (e) {
      debugPrint('OrderBloc._onFetchOrders error: $e');
      emit(OrderErrorState(
        message: e.toString(),
        currentOrders: _currentOrders,
      ));
    }
  }

  Future<void> _onCancelOrder(
      CancelOrderEvent event, Emitter<OrderState> emit) async {
    try {
      final res = await ApiService.cancelOrder(event.orderId);
      if (res.success) {
        // Refresh orders
        add(const FetchOrdersEvent(isRefresh: true));
        emit(OrderActionSuccessState(
          message: res.message ?? 'Order cancelled successfully',
          orders: _currentOrders,
        ));
      } else {
        emit(OrderErrorState(
          message: res.message ?? 'Failed to cancel order. Please contact support.',
          currentOrders: _currentOrders,
        ));
      }
    } catch (e) {
      debugPrint('OrderBloc._onCancelOrder error: $e');
      emit(OrderErrorState(
        message: e.toString(),
        currentOrders: _currentOrders,
      ));
    }
  }
}
