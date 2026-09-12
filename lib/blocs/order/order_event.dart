import 'package:equatable/equatable.dart';

abstract class OrderEvent extends Equatable {
  const OrderEvent();

  @override
  List<Object?> get props => [];
}

class FetchOrdersEvent extends OrderEvent {
  final bool isRefresh;
  final bool isSilent;

  const FetchOrdersEvent({
    this.isRefresh = false,
    this.isSilent = false,
  });

  @override
  List<Object?> get props => [isRefresh, isSilent];
}

class CancelOrderEvent extends OrderEvent {
  final String orderId;
  final String? reason;

  const CancelOrderEvent({
    required this.orderId,
    this.reason,
  });

  @override
  List<Object?> get props => [orderId, reason];
}
