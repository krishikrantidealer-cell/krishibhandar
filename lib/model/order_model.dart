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
        (lastName == null || lastName!.isEmpty)) {
      return "Customer";
    }
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
    // Fallback: If fulfillment status is fulfilled, it's at least shipped.
    // In many cases for this business, fulfilled == completed/delivered if no tracking is used.
    if (fulfillmentStatus.toLowerCase() == 'fulfilled') return 'Delivered';
    if (fulfillmentStatus.toLowerCase() == 'partial') {
      return 'Partially Shipped';
    }
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
    // Check financialStatus and cancelled status
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
    try {
      final rawItems = json['line_items'] ?? json['lineItems'] ?? json['items'];
      List<LineItem> items = [];
      if (rawItems is List) {
        items = rawItems.map((item) {
          if (item is Map) {
            return LineItem.fromJson(Map<String, dynamic>.from(item));
          }
          return LineItem(title: 'Product Item', quantity: 1, price: '0.00');
        }).toList();
      }

      String subtotal = (json['subtotal_price'] ?? json['subtotalPrice'] ?? json['subtotal'] ?? '').toString();
      if (subtotal.isEmpty || subtotal == '0' || subtotal == '0.0' || subtotal == '0.00') {
        double calculated = 0;
        for (var item in items) {
          calculated += (double.tryParse(item.price) ?? 0) * item.quantity;
        }
        subtotal = calculated.toStringAsFixed(2);
      }

      final ordId = (json['id'] ?? json['_id'] ?? json['order_number'] ?? json['orderNumber'] ?? json['name'] ?? '').toString();
      final ordNumber = (json['order_number'] ?? json['orderNumber'] ?? json['name'] ?? ordId).toString();
      final totPrice = (json['total_price'] ?? json['totalPrice'] ?? json['total'] ?? json['totalAmount'] ?? subtotal).toString();
      final fStatus = (json['fulfillment_status'] ?? json['fulfillmentStatus'] ?? json['status'] ?? 'pending').toString();
      final finStatus = (json['financial_status'] ?? json['financialStatus'] ?? 'pending').toString();

      String? fName = json['customer_first_name']?.toString() ?? json['firstName']?.toString();
      String? lName = json['customer_last_name']?.toString() ?? json['lastName']?.toString();
      String? shipAddr = json['shipping_address']?.toString() ?? json['shippingAddress']?.toString();

      if (json['shippingAddress'] is Map) {
        final sa = json['shippingAddress'] as Map;
        fName ??= sa['name']?.toString();
        final parts = [
          sa['address1'] ?? sa['street'],
          sa['address2'],
          sa['city'],
          sa['province'],
          sa['zip'],
          sa['country'] ?? 'India'
        ].where((p) => p != null && p.toString().trim().isNotEmpty).toList();
        if (parts.isNotEmpty) shipAddr = parts.join(', ');
      }

      String? custPhone = json['customer_phone']?.toString() ?? json['customerPhone']?.toString() ?? json['phone']?.toString();
      if (custPhone == null && json['shippingAddress'] is Map) {
        custPhone = json['shippingAddress']['phone']?.toString();
      }

      return OrderModel(
        id: ordId,
        orderNumber: ordNumber,
        createdAt: (json['created_at'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()).toString(),
        totalPrice: totPrice,
        currency: json['currency'] ?? 'INR',
        fulfillmentStatus: fStatus,
        financialStatus: finStatus,
        cancelledAt: json['cancelled_at']?.toString() ?? json['cancelledAt']?.toString(),
        closedAt: json['closed_at']?.toString() ?? json['closedAt']?.toString(),
        confirmed: json['confirmed'] == true || fStatus.contains('confirm') || fStatus.contains('process') || fStatus.contains('ship') || fStatus.contains('deliver'),
        lineItems: items,
        fulfillments: (json['fulfillments'] as List? ?? [])
            .map((f) => Fulfillment.fromJson(Map<String, dynamic>.from(f as Map)))
            .toList(),
        subtotalPrice: subtotal,
        totalTax: json['total_tax']?.toString() ?? json['taxes']?.toString(),
        totalShipping: json['total_shipping']?.toString() ?? json['shipping']?.toString(),
        shippingAddress: shipAddr,
        firstName: fName,
        lastName: lName,
        customerPhone: custPhone,
        orderStatusUrl: json['order_status_url']?.toString(),
      );
    } catch (e, stack) {
      debugPrint(">>>>>>>> OrderModel.fromJson PARSING ERROR: $e");
      debugPrint("StackTrace: $stack");
      rethrow;
    }
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
      id: (json['id'] ?? '').toString(),
      shipmentStatus: json['shipment_status']?.toString() ?? json['shipmentStatus']?.toString(),
      trackingNumber: json['tracking_number']?.toString() ?? json['trackingNumber']?.toString(),
      trackingUrl: json['tracking_url']?.toString() ?? json['trackingUrl']?.toString(),
      trackingCompany: json['tracking_company']?.toString() ?? json['trackingCompany']?.toString(),
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
    var rawImage = json['image'] ?? json['imageUrl'];

    if (rawImage != null) {
      if (rawImage is String) {
        img = rawImage;
      } else if (rawImage is Map) {
        img = rawImage['src'] ?? rawImage['url'];
      }
    }

    if (img == null && json['images'] is List && (json['images'] as List).isNotEmpty) {
      img = json['images'][0]?.toString();
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

    int qty = 1;
    if (json['quantity'] != null) {
      qty = json['quantity'] is int ? json['quantity'] : (int.tryParse(json['quantity'].toString()) ?? 1);
    }

    return LineItem(
      title: (json['name'] ?? json['title'] ?? 'Product Item').toString(),
      quantity: qty,
      price: (json['price'] ?? json['unitPrice'] ?? '0.00').toString(),
      variantTitle: json['variant_title']?.toString() ?? json['variantTitle']?.toString() ?? json['sku']?.toString(),
      image: img,
      variantId: json['variant_id']?.toString() ?? json['variantId']?.toString(),
      productId: json['product_id']?.toString() ?? json['productId']?.toString(),
      totalDiscount: json['total_discount']?.toString() ?? json['discount']?.toString(),
    );
  }
}
