import 'package:flutter/foundation.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String createdAt;
  final String totalPrice;
  final String currency;
  final String fulfillmentStatus;
  final String financialStatus;
  final String? cancelledAt;
  final String? closedAt;
  final bool confirmed;
  final List<LineItem> lineItems;
  final List<Fulfillment> fulfillments;
  final String? subtotalPrice;
  final String? totalTax;
  final String? totalShipping;
  final String? shippingAddress;
  final String? firstName;
  final String? lastName;
  final String? customerPhone;
  final String? orderStatusUrl;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.totalPrice,
    required this.currency,
    required this.fulfillmentStatus,
    required this.financialStatus,
    this.cancelledAt,
    this.closedAt,
    required this.confirmed,
    required this.lineItems,
    required this.fulfillments,
    this.subtotalPrice,
    this.totalTax,
    this.totalShipping,
    this.shippingAddress,
    this.firstName,
    this.lastName,
    this.customerPhone,
    this.orderStatusUrl,
  });

  String get customerName {
    if ((firstName == null || firstName!.isEmpty) &&
        (lastName == null || lastName!.isEmpty)) return "Customer";
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  String get trackingStatus {
    if (cancelledAt != null) return 'Cancelled';
    if (fulfillments.isNotEmpty) {
      final lastFulfillment = fulfillments.last;
      switch (lastFulfillment.shipmentStatus?.toLowerCase()) {
        case 'delivered':
          return 'Delivered';
        case 'out_for_delivery':
          return 'Out for Delivery';
        case 'in_transit':
          return 'In Transit';
        case 'failure':
          return 'Delivery Failed';
        case 'attempted_delivery':
          return 'Delivery Attempted';
        case 'ready_for_pickup':
          return 'Ready for Pickup';
        default:
          return 'Shipped';
      }
    }
    if (fulfillmentStatus.toLowerCase() == 'fulfilled') return 'Shipped';
    if (fulfillmentStatus.toLowerCase() == 'partial')
      return 'Partially Shipped';
    if (closedAt != null) return 'Completed';
    if (confirmed) return 'Processing';
    return 'Order Placed';
  }

  bool get hasTrackingNumber {
    for (var f in fulfillments) {
      if (f.trackingNumber != null && f.trackingNumber!.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Fulfillment? get validFulfillment {
    for (var f in fulfillments.reversed) {
      if (f.trackingNumber != null && f.trackingNumber!.trim().isNotEmpty) {
        return f;
      }
    }
    return fulfillments.isNotEmpty ? fulfillments.last : null;
  }

  bool get isCancellable {
    // Also check financialStatus: voided or refunded orders are not cancellable
    final fs = financialStatus.toLowerCase();
    if (fs == 'voided' || fs == 'refunded') return false;
    return cancelledAt == null &&
           fulfillments.isEmpty &&
           !hasTrackingNumber &&
           trackingStatus != 'Cancelled' &&
           trackingStatus != 'Shipped' &&
           trackingStatus != 'Delivered';
  }

  String get formattedDate {
    if (createdAt.isEmpty) return '';
    try {
      DateTime dt = DateTime.parse(createdAt).toLocal();
      const monthNames = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec"
      ];
      String month = monthNames[dt.month - 1];
      int hour = dt.hour;
      String ampm = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      String minute = dt.minute.toString().padLeft(2, '0');
      return "${dt.day} $month ${dt.year}, $hour:$minute $ampm";
    } catch (e) {
      return createdAt.split('T')[0];
    }
  }

  OrderModel copyWith({
    String? cancelledAt,
    String? financialStatus,
    String? fulfillmentStatus,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      createdAt: createdAt,
      totalPrice: totalPrice,
      currency: currency,
      fulfillmentStatus: fulfillmentStatus ?? this.fulfillmentStatus,
      financialStatus: financialStatus ?? this.financialStatus,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      closedAt: closedAt,
      confirmed: confirmed,
      lineItems: lineItems,
      fulfillments: fulfillments,
      subtotalPrice: subtotalPrice,
      totalTax: totalTax,
      totalShipping: totalShipping,
      shippingAddress: shippingAddress,
      firstName: firstName,
      lastName: lastName,
      customerPhone: customerPhone,
      orderStatusUrl: orderStatusUrl,
    );
  }

  int get totalQuantity {
    return lineItems.fold(0, (sum, item) => sum + item.quantity);
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['line_items'] ?? json['lineItems'] ?? json['items'];
    List<LineItem> items = (rawItems as List? ?? [])
        .map((item) => LineItem.fromJson(item is Map ? Map<String, dynamic>.from(item) : {}))
        .toList();

    String? subtotal = (json['subtotal_price'] ?? json['subtotalPrice'] ?? json['subtotal'])?.toString();
    if (subtotal == null ||
        subtotal == '0' ||
        subtotal == '0.0' ||
        subtotal == '0.00') {
      double calculated = 0;
      for (var item in items) {
        calculated += (double.tryParse(item.price) ?? 0) * item.quantity;
      }
      subtotal = calculated.toStringAsFixed(2);
    }

    String orderId = (json['id'] ?? json['_id'] ?? '').toString();
    String orderNum = (json['order_number'] ?? json['orderNumber'] ?? json['name'] ?? orderId).toString();

    // Customer names
    String? fName = json['customer_first_name']?.toString() ?? json['customer']?['first_name']?.toString() ?? json['customer']?['name']?.toString();
    String? lName = json['customer_last_name']?.toString() ?? json['customer']?['last_name']?.toString();
    String? phone = json['customer_phone']?.toString() ?? json['customer']?['phone']?.toString();

    // Shipping address
    String? shippingAddr;
    if (json['shipping_address'] != null) {
      if (json['shipping_address'] is Map) {
        final sa = json['shipping_address'];
        shippingAddr = "${sa['address1'] ?? ''}, ${sa['city'] ?? ''}, ${sa['province'] ?? sa['state'] ?? ''} - ${sa['zip'] ?? sa['pincode'] ?? ''}".trim();
      } else {
        shippingAddr = json['shipping_address'].toString();
      }
    } else if (json['shippingAddress'] != null) {
      if (json['shippingAddress'] is Map) {
        final sa = json['shippingAddress'];
        shippingAddr = "${sa['address1'] ?? ''}, ${sa['city'] ?? ''}, ${sa['province'] ?? sa['state'] ?? ''} - ${sa['zip'] ?? sa['pincode'] ?? ''}".trim();
      } else {
        shippingAddr = json['shippingAddress'].toString();
      }
    }

    return OrderModel(
      id: orderId,
      orderNumber: orderNum,
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      totalPrice: (json['total_price'] ?? json['totalPrice'] ?? json['totalAmount'] ?? '0.00').toString(),
      currency: json['currency'] ?? 'INR',
      fulfillmentStatus: json['fulfillment_status'] ?? json['fulfillmentStatus'] ?? 'pending',
      financialStatus: json['financial_status'] ?? json['financialStatus'] ?? 'pending',
      cancelledAt: json['cancelled_at'] ?? json['cancelledAt'],
      closedAt: json['closed_at'] ?? json['closedAt'],
      confirmed: json['confirmed'] ?? true,
      lineItems: items,
      fulfillments: (json['fulfillments'] as List? ?? [])
          .map((f) => Fulfillment.fromJson(f is Map ? Map<String, dynamic>.from(f) : {}))
          .toList(),
      subtotalPrice: subtotal,
      totalTax: (json['total_tax'] ?? json['totalTax'])?.toString(),
      totalShipping: (json['total_shipping'] ?? json['totalShipping'])?.toString(),
      shippingAddress: shippingAddr,
      firstName: fName,
      lastName: lName,
      customerPhone: phone,
      orderStatusUrl: (json['order_status_url'] ?? json['orderStatusUrl'])?.toString(),
    );
  }
}

class Fulfillment {
  final String id;
  final String? shipmentStatus;
  final String? trackingNumber;
  final String? trackingUrl;
  final String? trackingCompany;

  Fulfillment({
    required this.id,
    this.shipmentStatus,
    this.trackingNumber,
    this.trackingUrl,
    this.trackingCompany,
  });

  factory Fulfillment.fromJson(Map<String, dynamic> json) {
    return Fulfillment(
      id: json['id'].toString(),
      shipmentStatus: json['shipment_status'],
      trackingNumber: json['tracking_number'],
      trackingUrl: json['tracking_url'],
      trackingCompany: json['tracking_company'],
    );
  }
}

class LineItem {
  final String title;
  final int quantity;
  final String price;
  final String? variantTitle;
  final String? image;
  final String? variantId;
  final String? productId;
  final String? totalDiscount;

  LineItem({
    required this.title,
    required this.quantity,
    required this.price,
    this.variantTitle,
    this.image,
    this.variantId,
    this.productId,
    this.totalDiscount,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) {
    // Advanced image detection for multiple API formats (REST, GraphQL mapped, etc.)
    String? img;
    var rawImage = json['image'];

    if (rawImage != null) {
      if (rawImage is String) {
        img = rawImage;
      } else if (rawImage is Map) {
        img = rawImage['src'] ?? rawImage['url'];
      }
    }

    // Fallback search in nested structures
    img ??= json['product']?['image']?['src'] ??
        json['product']?['featuredImage']?['url'] ??
        json['variant']?['image']?['url'] ??
        json['variant']?['product']?['featuredImage']?['url'];

    // Clean the URL
    if (img != null) {
      img = img.trim();
      if (img.isEmpty || !img.startsWith('http')) img = null;
    }

    debugPrint("[Model Parse] Item: ${json['title']} | Image: $img");

    return LineItem(
      title: json['title'] ?? '',
      quantity: json['quantity'] ?? 0,
      price: json['price']?.toString() ?? '0.00',
      variantTitle: json['variant_title'],
      image: img,
      variantId: json['variant_id']?.toString(),
      productId: json['product_id']?.toString(),
      totalDiscount: json['total_discount']?.toString(),
    );
  }
}
