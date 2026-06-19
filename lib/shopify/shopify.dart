import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../controller/constants.dart';
import '../controller/pref.dart';
import '../model/categories_model.dart';
import '../model/localization_model.dart';
import '../model/product_model.dart';
import '../services/attribution_service.dart';

class ShopifyAPI {
  static const String _baseUrl =
      "https://3b7f20-3.myshopify.com/admin/api/2024-10";
  static Map<String, String> _header = {
    'content-type': 'application/json',
    'X-Shopify-Access-Token': Constants.shopifyAccessToken,
  };

  static Future<Map<String, dynamic>> _getData({
    required String link,
  }) async {
    try {
      String path =
          link.contains('?') ? link.replaceFirst('?', '.json?') : '$link.json';

      var res = await http.get(
        Uri.parse("$_baseUrl/$path"),
        headers: _header,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      // debugPrint("ShopifyAPI Error: $e");
    }
    return {};
  }

  static Future<Map<String, String>> getCollection({required String id}) async {
    var res = await _getData(
      link: "collections/$id",
    );
    if (res.isNotEmpty && res['collection'] != null) {
      return {
        "title": res['collection']['title']?.toString() ?? '',
        "handle": res['collection']['handle']?.toString() ?? '',
        "pro": res['collection']['products_count']?.toString() ?? '0',
        "image": res['collection']['image']?['src']?.toString() ?? '',
      };
    }
    return {};
  }

  static Future<List<dynamic>> getCustomerOrders(String customerId) async {
    try {
      final String cleanId = customerId.split('/').last;
      final String query = '''
        query {
          orders(first: 50, reverse: true, query: "customer_id:$cleanId") {
            nodes {
              id
              name
              createdAt
              totalPriceSet {
                presentmentMoney {
                   amount
                   currencyCode
                }
              }
              subtotalPriceSet {
                presentmentMoney {
                   amount
                }
              }
              displayFulfillmentStatus
              displayFinancialStatus
              cancelledAt
              closedAt
              confirmed
              discountApplications(first: 10) {
                nodes {
                  ... on DiscountCodeApplication {
                    code
                  }
                }
              }
              lineItems(first: 50) {
                nodes {
                  title
                  quantity
                  variantTitle
                  originalUnitPriceSet {
                    presentmentMoney {
                       amount
                    }
                  }
                  image {
                    url
                  }
                  variant {
                    id
                    product {
                      id
                      featuredImage {
                        url
                      }
                    }
                  }
                }
              }
            }
          }
        }
      ''';

      var res = await http.post(
        Uri.parse("$_baseUrl/graphql.json"),
        body: json.encode({'query': query}),
        headers: {
          'content-type': 'application/json',
          'X-Shopify-Access-Token': Constants.shopifyAccessToken,
        },
      );

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null && decoded['data']['orders'] != null) {
          final List orders = [];
          for (var node in decoded['data']['orders']['nodes']) {
            try {
              String totalPrice = '0.00';
              String currency = 'INR';
              if (node['totalPriceSet'] != null &&
                  node['totalPriceSet']['presentmentMoney'] != null) {
                totalPrice = node['totalPriceSet']['presentmentMoney']['amount']
                        ?.toString() ??
                    '0.00';
                currency = node['totalPriceSet']['presentmentMoney']
                            ['currencyCode']
                        ?.toString() ??
                    'INR';
              }

              final usedCodes =
                  (node['discountApplications']?['nodes'] as List? ?? [])
                      .map((d) => d['code']?.toString().toUpperCase())
                      .where((c) => c != null)
                      .toList();

              orders.add({
                'id': node['id'].toString(),
                'order_number': node['name'].toString().replaceAll('#', ''),
                'created_at': node['createdAt'],
                'total_price': totalPrice,
                'subtotal_price': node['subtotalPriceSet']?['presentmentMoney']
                        ?['amount']
                    ?.toString(),
                'currency': currency,
                'discount_codes': usedCodes,
                'fulfillment_status':
                    node['displayFulfillmentStatus']?.toLowerCase() ??
                        'pending',
                'financial_status':
                    node['displayFinancialStatus']?.toLowerCase() ?? 'pending',
                'cancelled_at': node['cancelledAt'],
                'closed_at': node['closedAt'],
                'confirmed': node['confirmed'] ?? false,
                'line_items':
                    (node['lineItems']?['nodes'] as List? ?? []).map((li) {
                  String? img = li['image']?['url'] ??
                      li['variant']?['product']?['featuredImage']?['url'];
                  return {
                    'title': li['title'] ?? '',
                    'quantity': li['quantity'] ?? 0,
                    'price': li['originalUnitPriceSet']?['presentmentMoney']
                                ?['amount']
                            ?.toString() ??
                        '0.00',
                    'variant_title': li['variantTitle'] ?? '',
                    'variant_id':
                        li['variant']?['id']?.toString().split('/').last,
                    'product_id': li['variant']?['product']?['id']
                        ?.toString()
                        .split('/')
                        .last,
                    'image': img,
                  };
                }).toList(),
              });

              var lastOrder = orders.last;
              if (lastOrder['subtotal_price'] == null ||
                  lastOrder['subtotal_price'] == '0.00' ||
                  lastOrder['subtotal_price'] == '0') {
                double sub = 0;
                for (var item in lastOrder['line_items']) {
                  sub +=
                      (double.tryParse(item['price']?.toString() ?? '0') ?? 0) *
                          (item['quantity'] ?? 0);
                }
                lastOrder['subtotal_price'] = sub.toStringAsFixed(2);
              }
            } catch (e) {
              // debugPrint("Mapper Error: $e");
            }
          }
          return orders;
        }
      }
    } catch (e) {
      // debugPrint("getCustomerOrders Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>> _getAdminData({
    required String body,
    Map<String, dynamic>? variables,
  }) async {
    try {
      final res = await http.post(
        Uri.parse("$_baseUrl/graphql.json"),
        headers: _header,
        body: jsonEncode({
          'query': body,
          'variables': variables ?? {},
        }),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      // debugPrint("ShopifyAdmin GraphQL Error: $e");
    }
    return {};
  }

  static Future<Map<String, dynamic>> getOrderFullDetails(
      String orderId) async {
    try {
      final String gid =
          orderId.contains('gid://') ? orderId : "gid://shopify/Order/$orderId";

      final String query = r'''
        query getOrder($id: ID!) {
          order(id: $id) {
            id
            name
            createdAt
            totalPriceSet { presentmentMoney { amount } }
            subtotalPriceSet { presentmentMoney { amount } }
            totalTaxSet { presentmentMoney { amount } }
            totalShippingPriceSet { presentmentMoney { amount } }
            displayFulfillmentStatus
            displayFinancialStatus
            confirmed
            cancelledAt
            statusPageUrl
            
            fulfillments(first: 10) {
              nodes {
                id
                shipmentStatus
                trackingNumbers
                trackingUrls
                trackingInfo {
                  number
                  url
                  company
                }
              }
            }
            
            shippingAddress {
              name
              phone
              company
              firstName
              lastName
              address1
              address2
              city
              province
              zip
              country
            }
            billingAddress {
              name
              phone
              company
              firstName
              lastName
              address1
              address2
              city
              province
              zip
              country
            }
            customer {
              firstName
              lastName
              phone
              email
              defaultAddress {
                firstName
                lastName
                company
                address1
                address2
                city
                province
                zip
                country
                phone
              }
            }
            lineItems(first: 20) {
              nodes {
                title
                quantity
                variantTitle
                originalUnitPriceSet {
                  presentmentMoney {
                    amount
                  }
                }
                image {
                  url
                }
                variant {
                  id
                  image {
                    url
                  }
                  product {
                    featuredImage {
                      url
                    }
                  }
                }
              }
            }
          }
        }
      ''';

      final res = await _getAdminData(body: query, variables: {"id": gid});

      Map<String, dynamic> finalData = {};
      var o = res['data']?['order'];

      // REST DATA MERGE: Merge with REST data as it's more reliable for fulfillments/tracking
      try {
        final numericId = gid.split('/').last;
        final restRes = await _getData(link: "orders/$numericId");
        if (restRes['order'] != null) {
          var ro = restRes['order'];

          // If GraphQL failed entirely, start with REST data
          if (o == null) {
            o = ro;
            // Map basic fields
            o['displayFulfillmentStatus'] = ro['fulfillment_status'];
            o['displayFinancialStatus'] = ro['financial_status'];
            o['statusPageUrl'] = ro['order_status_url'];
            o['createdAt'] = ro['created_at'];
            // ← Cancellation fields — critical for isCancellable to work
            o['cancelledAt'] = ro['cancelled_at'];
            o['closedAt'] = ro['closed_at'];
            o['totalPriceSet'] = {
              'presentmentMoney': {'amount': ro['total_price']}
            };
            o['subtotalPriceSet'] = {
              'presentmentMoney': {'amount': ro['subtotal_price']}
            };
            o['totalTaxSet'] = {
              'presentmentMoney': {'amount': ro['total_tax']}
            };
            o['totalShippingPriceSet'] = {
              'presentmentMoney': {'amount': ro['total_shipping']}
            };

            // Map line items from REST
            o['lineItems'] = {
              'nodes': (ro['line_items'] as List? ?? [])
                  .map((li) => {
                        'id': "gid://shopify/LineItem/${li['id']}",
                        'title': li['title'],
                        'quantity': li['quantity'],
                        'originalUnitPriceSet': {
                          'presentmentMoney': {'amount': li['price']}
                        },
                        'variantTitle': li['variant_title'],
                        // REST items rarely have images directly; will need fallback if possible
                      })
                  .toList()
            };
          } else {
            // MERGE REST data into existing GraphQL object
            // Prefer REST for address parts and fulfillments
            var rsa = ro['shipping_address'] ?? ro['billing_address'] ?? {};
            o['shippingAddress'] = {
              ...(o['shippingAddress'] ?? {}),
              'address1': o['shippingAddress']?['address1'] ?? rsa['address1'],
              'address2': o['shippingAddress']?['address2'] ?? rsa['address2'],
              'city': o['shippingAddress']?['city'] ?? rsa['city'],
              'province': o['shippingAddress']?['province'] ?? rsa['province'],
              'zip': o['shippingAddress']?['zip'] ?? rsa['zip'],
              'country': o['shippingAddress']?['country'] ?? rsa['country'],
              'firstName':
                  o['shippingAddress']?['firstName'] ?? rsa['first_name'],
              'lastName': o['shippingAddress']?['lastName'] ?? rsa['last_name'],
              'phone': o['shippingAddress']?['phone'] ?? rsa['phone'],
            };

            if (o['statusPageUrl'] == null)
              o['statusPageUrl'] = ro['order_status_url'];

            // Fallback: GraphQL may miss cancelledAt/closedAt — fill from REST
            o['cancelledAt'] ??= ro['cancelled_at'];
            o['closedAt'] ??= ro['closed_at'];
          }

          // Merge Fulfillments - REST is superior for tracking numbers
          if (ro['fulfillments'] != null &&
              (ro['fulfillments'] as List).isNotEmpty) {
            o['fulfillments'] = {
              'nodes': (ro['fulfillments'] as List)
                  .map((rf) => {
                        'id': rf['id'],
                        'shipmentStatus': rf['shipment_status'],
                        'name': rf['name'],
                        'trackingInfo': [
                          {
                            'number': rf['tracking_number'],
                            'url': rf['tracking_url'],
                            'company': rf['tracking_company'],
                          }
                        ],
                        'trackingNumbers': rf['tracking_numbers'] ?? [],
                        'trackingUrls': rf['tracking_urls'] ?? [],
                      })
                  .toList()
            };
          }
        }
      } catch (e) {
        // debugPrint("REST Merge Error: $e");
      }

      if (o != null) {
        var sa = o['shippingAddress'] ?? o['shipping_address'] ?? {};
        var ba = o['billingAddress'] ?? o['billing_address'] ?? {};
        var c = o['customer'] ?? {};
        var da = c['defaultAddress'] ?? c['default_address'] ?? {};

        // 1. Resolve Identity
        String firstName = (sa['firstName'] ??
                ba['firstName'] ??
                da['firstName'] ??
                c['firstName'] ??
                "")
            .toString()
            .trim();
        String lastName = (sa['lastName'] ??
                ba['lastName'] ??
                da['lastName'] ??
                c['lastName'] ??
                "")
            .toString()
            .trim();
        String fullName = (sa['name'] ??
                ba['name'] ??
                (firstName.isNotEmpty ? "$firstName $lastName" : ""))
            .toString()
            .trim();
        String phone =
            (sa['phone'] ?? ba['phone'] ?? da['phone'] ?? c['phone'] ?? "")
                .toString()
                .trim();
        String zip =
            (sa['zip'] ?? ba['zip'] ?? da['zip'] ?? "").toString().trim();
        String company = (sa['company'] ?? ba['company'] ?? da['company'] ?? "")
            .toString()
            .trim();

        if (fullName.isEmpty) fullName = "Customer";

        // 3. Resolve Location
        String a1 = (sa['address1'] ?? ba['address1'] ?? da['address1'] ?? "")
            .toString()
            .trim();
        String a2 = (sa['address2'] ?? ba['address2'] ?? da['address2'] ?? "")
            .toString()
            .trim();
        String city =
            (sa['city'] ?? ba['city'] ?? da['city'] ?? "").toString().trim();
        String prov = (sa['province'] ?? ba['province'] ?? da['province'] ?? "")
            .toString()
            .trim();
        String country = (sa['country'] ?? ba['country'] ?? da['country'] ?? "")
            .toString()
            .trim();

        // Build COMPLETE composite address string
        String addr = [
          fullName,
          phone.isNotEmpty ? phone : null,
          company.isNotEmpty ? company : null,
          a1.isNotEmpty ? a1 : null,
          a2.isNotEmpty ? a2 : null,
          city.isNotEmpty ? city : null,
          prov.isNotEmpty ? prov : null,
          zip.isNotEmpty ? zip : null,
          country.isNotEmpty ? country : null,
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(", ");

        if (addr.length < 15 && zip.isEmpty) {
          addr = "No shipping address provided";
        }

        final lineItemsMapped = (o['lineItems']?['nodes'] as List? ?? [])
            .map((li) => {
                  'title': li['title'],
                  'quantity': li['quantity'],
                  'price': li['originalUnitPriceSet']?['presentmentMoney']
                          ?['amount']
                      ?.toString(),
                  'variant_title': li['variantTitle'],
                  'image': li['image']?['url'] ??
                      li['variant']?['image']?['url'] ??
                      li['variant']?['product']?['featuredImage']?['url'] ??
                      '',
                })
            .toList();

        finalData = {
          'id': o['id'],
          'order_number': o['name']?.toString().replaceAll('#', '') ?? 'N/A',
          'created_at': o['createdAt'],
          'total_price':
              o['totalPriceSet']?['presentmentMoney']?['amount']?.toString(),
          'subtotal_price':
              o['subtotalPriceSet']?['presentmentMoney']?['amount']?.toString(),
          'total_tax':
              o['totalTaxSet']?['presentmentMoney']?['amount']?.toString(),
          'total_shipping': o['totalShippingPriceSet']?['presentmentMoney']
                  ?['amount']
              ?.toString(),
          'shipping_address': addr,
          'order_status_url': o['statusPageUrl']?.toString(),
          'customer_first_name': firstName,
          'customer_last_name': lastName,
          'customer_phone': phone,
          'fulfillment_status': o['displayFulfillmentStatus']?.toLowerCase(),
          'financial_status': o['displayFinancialStatus']?.toLowerCase(),
          'cancelled_at': o['cancelledAt'],
          'confirmed': o['confirmed'] ?? true,
          'fulfillments': (() {
            var fData = o['fulfillments'];
            List rawList = [];
            if (fData is List) {
              rawList = fData;
            } else if (fData is Map) {
              rawList = fData['nodes'] as List? ??
                  fData['edges']?.map((e) => e['node']).toList() as List? ??
                  [];
            }

            return rawList
                .map((f) {
                  if (f == null) return null;
                  var tiList = f['trackingInfo'] as List? ?? [];
                  var ti = tiList.isNotEmpty ? tiList.first : {};

                  String? trackNum = ti['number']?.toString();
                  String? trackUrl = ti['url']?.toString();
                  String? trackCompany = ti['company']?.toString();

                  // Deep fallback for tracking number
                  if (trackNum == null || trackNum.isEmpty) {
                    trackNum = (f['trackingNumbers'] as List? ?? [])
                            .firstOrNull
                            ?.toString() ??
                        f['tracking_number']?.toString();
                  }

                  // Deepest search: Extract from name or other fields if still missing
                  if (trackNum == null || trackNum.isEmpty) {
                    final searchStr =
                        "${f['name'] ?? ''} ${f['shipment_status'] ?? ''}";
                    final reg = RegExp(r'\d{10,18}');
                    trackNum = reg.firstMatch(searchStr)?.group(0);
                  }

                  // Deep fallback for tracking URL
                  if (trackUrl == null || trackUrl.isEmpty) {
                    trackUrl = (f['trackingUrls'] as List? ?? [])
                            .firstOrNull
                            ?.toString() ??
                        f['tracking_url']?.toString();
                  }

                  // Deep fallback for company
                  if (trackCompany == null || trackCompany.isEmpty) {
                    trackCompany = f['trackingCompany']?.toString() ??
                        f['tracking_company']?.toString();

                    // Extraction fallback for company
                    if ((trackCompany == null || trackCompany.isEmpty) &&
                        (f['name']?.toString().contains("Delhivery") ??
                            false)) {
                      trackCompany = "Delhivery";
                    }
                  }

                  return {
                    'id': f['id']?.toString(),
                    'shipment_status': f['shipmentStatus']?.toString() ??
                        f['shipment_status']?.toString(),
                    'tracking_number': trackNum,
                    'tracking_url': trackUrl,
                    'tracking_company': trackCompany,
                  };
                })
                .where((e) => e != null)
                .toList();
          })(),
          'line_items': lineItemsMapped,
        };

        // Fallback: If subtotal_price is missing or 0, calculate from line items
        if (finalData['subtotal_price'] == null ||
            finalData['subtotal_price'] == '0' ||
            finalData['subtotal_price'] == '0.0' ||
            finalData['subtotal_price'] == '0.00') {
          double calculatedSubtotal = 0;
          for (var item in lineItemsMapped) {
            double price =
                double.tryParse(item['price']?.toString() ?? '0') ?? 0;
            int qty = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
            calculatedSubtotal += (price * qty);
          }
          finalData['subtotal_price'] = calculatedSubtotal.toStringAsFixed(2);
        }
      }
      return finalData;
    } catch (e) {
      debugPrint("getOrderFullDetails Overall Error: $e");
    }
    return {};
  }

  static Future<Map<String, dynamic>> createOrder({
    String? customerId,
    String? email,
    required List<Map<String, dynamic>> lineItems,
    required Map<String, dynamic> shippingAddress,
    required double totalAmount,
    String? discountCode,
    double? discountAmount,
    String? paymentId,
    bool isCod = false,
  }) async {
    try {
      final List<Map<String, dynamic>> cleanLineItems = lineItems.map((item) {
        String vid = item['variant_id']?.toString() ?? '';
        return {
          "variant_id": int.parse(vid.split('/').last),
          "quantity": item['quantity'],
          "price": item['price'],
        };
      }).toList();

      String? cleanPhone = shippingAddress['phone']
              ?.toString()
              .replaceAll(RegExp(r'[^\d]'), '') ??
          '';
      if (cleanPhone.length == 10) {
        cleanPhone = "+91$cleanPhone";
      } else if (cleanPhone.length > 10 && !cleanPhone.startsWith('+')) {
        cleanPhone = "+$cleanPhone";
      } else if (cleanPhone.isEmpty) {
        cleanPhone = null;
      }

      final Map<String, dynamic> addressBlock = {
        "first_name":
            shippingAddress['name']?.toString().split(' ').first ?? '',
        "last_name":
            shippingAddress['name']?.toString().split(' ').skip(1).join(' ') ??
                '',
        "address1": shippingAddress['address1'] ?? '',
        "address2": shippingAddress['address2'] ?? '',
        "city": shippingAddress['city'] ?? '',
        "province": shippingAddress['state'] ?? '',
        "zip": shippingAddress['pincode'] ?? '',
        if (cleanPhone != null && cleanPhone.isNotEmpty) "phone": cleanPhone,
        "country": "India"
      };

      final Map<String, dynamic> orderPayload = {
        "line_items": cleanLineItems,
        "financial_status": isCod ? "pending" : "paid",
        "total_price": totalAmount.toStringAsFixed(2),
        "currency": "INR",
        if (cleanPhone != null && cleanPhone.isNotEmpty) "phone": cleanPhone,
        "note_attributes": [
          {
            "name": "payment_id",
            "value": paymentId ?? (isCod ? "COD" : "Online")
          },
          {"name": "payment_method", "value": isCod ? "COD" : "Online"},
          {"name": "channel", "value": "Mobile App"},
          ...(await AttributionService().getAttribution())
              .entries
              .map((e) => {"name": e.key, "value": e.value})
              .toList(),
        ],
        "shipping_address": addressBlock,
        "billing_address": addressBlock,
        "inventory_behavior": "decrement_ignoring_policy",
        "send_receipt": true,
        "source_name": "mobile_app",
      };

      if (isCod) {
        orderPayload["payment_gateway_names"] = ["Cash on Delivery (COD)"];
        orderPayload["tags"] = "COD, Mobile App";
      }

      if (email != null && email.isNotEmpty) {
        orderPayload["email"] = email;
      }

      if (discountCode != null && discountCode.isNotEmpty) {
        orderPayload["discount_codes"] = [
          {
            "code": discountCode,
            "amount": discountAmount?.toStringAsFixed(2) ?? "0.00",
            "type": "fixed_amount"
          }
        ];
      }

      if (discountAmount != null && discountAmount > 0) {
        orderPayload["total_discounts"] = discountAmount.toStringAsFixed(2);
      }

      debugPrint(
          "DEBUG: Shopify Order Payload --> ${jsonEncode(orderPayload)}");

      if (customerId != null && customerId.isNotEmpty && customerId != "null") {
        try {
          final int cleanId = int.parse(customerId.split('/').last);
          orderPayload["customer"] = {
            "id": cleanId,
          };
        } catch (_) {}
      }

      final res = await http.post(
        Uri.parse("$_baseUrl/orders.json"),
        headers: _header,
        body: jsonEncode({"order": orderPayload}),
      );

      debugPrint(
          "Shopify Create Order Status: ${res.statusCode} Body: ${res.body}");

      if (res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        // Clear attribution after success so next order is organic
        await AttributionService().clearAttribution();
        return decoded;
      } else {
        debugPrint("Create Order Error ${res.statusCode}: ${res.body}");
        return {
          "error": "Shopify Status ${res.statusCode}: ${res.body}",
        };
      }
    } catch (e) {
      debugPrint("createOrder Overall Error: $e");
      return {
        "error": "Exception: $e",
      };
    }
  }

  static Future<bool> cancelOrder(String orderId) async {
    try {
      final numericId =
          orderId.contains('gid://') ? orderId.split('/').last : orderId;
      var res = await http.post(
        Uri.parse("$_baseUrl/orders/$numericId/cancel.json"),
        headers: _header,
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      }
      // debugPrint("Cancel Order Error ${res.statusCode}: ${res.body}");
    } catch (e) {
      // debugPrint("cancelOrder Error: $e");
    }
    return false;
  }

  static Future<void> updateOrderAttribution(String orderIdOrName) async {
    try {
      final attribution = await AttributionService().getAttribution();
      debugPrint("📢 ShopifyAPI: Sending UTM attributes to Shopify for order $orderIdOrName: $attribution");
      String? numericId;

      // 1. Resolve numeric ID
      if (RegExp(r'^\d+$').hasMatch(orderIdOrName)) {
        numericId = orderIdOrName;
      } else {
        // A. Search matching order by checking latest orders (to handle checkout_token / cart_token / name)
        // We poll up to 5 times (total 15 seconds) because external checkout systems (Fastrr) 
        // create orders asynchronously via webhook/API which might take a few seconds to appear in Shopify.
        int attempts = 5;
        for (int i = 0; i < attempts; i++) {
          var res = await http.get(
            Uri.parse('$_baseUrl/orders.json?limit=30&status=any'),
            headers: _header,
          );
          if (res.statusCode == 200) {
            final orders = jsonDecode(res.body)['orders'] as List?;
            if (orders != null && orders.isNotEmpty) {
              for (var ord in orders) {
                final ordToken = ord['checkout_token']?.toString() ?? '';
                final ordCartToken = ord['cart_token']?.toString() ?? '';
                final ordName = ord['name']?.toString() ?? '';

                if (ordToken.toLowerCase() == orderIdOrName.toLowerCase() ||
                    ordCartToken.toLowerCase() == orderIdOrName.toLowerCase() ||
                    ordName.toLowerCase() == orderIdOrName.toLowerCase()) {
                  numericId = ord['id']?.toString();
                  debugPrint("🎯 Found matching order: $numericId on attempt ${i + 1}");
                  break;
                }
              }
            }
          }

          if (numericId != null) break;

          if (i < attempts - 1) {
            debugPrint("⏳ Order $orderIdOrName not found in Shopify yet (attempt ${i + 1}/$attempts). Retrying in 3 seconds...");
            await Future.delayed(const Duration(seconds: 3));
          }
        }

        // B. Fallback: Search latest order in the system if created in the last 10 minutes
        if (numericId == null) {
          var res = await http.get(
            Uri.parse('$_baseUrl/orders.json?limit=1&status=any'),
            headers: _header,
          );
          if (res.statusCode == 200) {
            final orders = jsonDecode(res.body)['orders'] as List?;
            if (orders != null && orders.isNotEmpty) {
              final latestOrder = orders.first;
              final createdAtStr = latestOrder['created_at']?.toString();
              if (createdAtStr != null) {
                final createdAt = DateTime.tryParse(createdAtStr);
                if (createdAt != null) {
                  final difference = DateTime.now().toUtc().difference(createdAt.toUtc()).inMinutes;
                  if (difference.abs() <= 10) {
                    numericId = latestOrder['id']?.toString();
                    debugPrint("🎯 Matched order based on latest order fallback (created $difference min ago): $numericId");
                  }
                }
              }
            }
          }
        }
      }

      if (numericId != null) {
        // 2. Fetch existing order note_attributes first to preserve other metadata
        var res = await http.get(
          Uri.parse('$_baseUrl/orders/$numericId.json'),
          headers: _header,
        );
        List<Map<String, dynamic>> existingAttributes = [];
        if (res.statusCode == 200) {
          final order = jsonDecode(res.body)['order'];
          final rawAttributes = order['note_attributes'] as List? ?? [];
          existingAttributes = rawAttributes.map((attr) {
            return {
              "name": attr['name']?.toString() ?? '',
              "value": attr['value']?.toString() ?? ''
            };
          }).toList();
        }

        // 3. Remove any existing UTM attributes to avoid duplicates
        existingAttributes.removeWhere((attr) =>
            attr['name'] == 'utm_source' ||
            attr['name'] == 'utm_medium' ||
            attr['name'] == 'utm_campaign' ||
            attr['name'] == 'utm_term' ||
            attr['name'] == 'utm_content');

        // 4. Add the new UTM attributes
        existingAttributes.addAll(
          attribution.entries.map((e) => {"name": e.key, "value": e.value}).toList()
        );

        // 5. Send PUT request to update the order
        final payload = {
          "order": {
            "id": int.parse(numericId),
            "note_attributes": existingAttributes
          }
        };

        var updateRes = await http.put(
          Uri.parse('$_baseUrl/orders/$numericId.json'),
          headers: _header,
          body: jsonEncode(payload),
        );

        if (updateRes.statusCode == 200 || updateRes.statusCode == 201) {
          debugPrint("✅ Shopify Order Attribution Updated Successfully for Order: $numericId");
          // Clear attribution after success
          await AttributionService().clearAttribution();
        } else {
          debugPrint("❌ Failed to update Shopify Order Attribution: Status ${updateRes.statusCode} Body: ${updateRes.body}");
        }
      } else {
        debugPrint("⚠️ Could not resolve numeric Order ID for updating attribution: $orderIdOrName");
      }
    } catch (e) {
      debugPrint("Error in updateOrderAttribution: $e");
    }
  }
}

class Shopify {
  static const String _defaultVersion = "2024-10";
  static const String _baseUrl =
      "https://3b7f20-3.myshopify.com/api/$_defaultVersion/graphql.json";

  static const String _colIdPre = "gid://shopify/Collection/";
  static const String _proIdPre = "gid://shopify/Product/";
  static const String _proVarIdPre = "gid://shopify/ProductVariant/";

  static Map<String, String> _header = {
    'content-type': 'application/json',
    'X-Shopify-Storefront-Access-Token': Constants.storefrontAccessToken,
  };

  static Future<Map<String, dynamic>> getGraphQLData(BuildContext? context,
      {required String body,
      String? version,
      String? forcedLang,
      Map<String, dynamic>? variable}) async {
    try {
      String query;
      Map<String, dynamic> variables = {};

      if (version != null) {
        query = body;
        if (variable != null) {
          variables.addAll(variable);
        }
      } else {
        query = '''
          query(\$lang: LanguageCode!) @inContext(language: \$lang) {
            $body
          }
        ''';
        variables = {'lang': (forcedLang ?? Constants.lang).toUpperCase()};
        if (variable != null) {
          variables.addAll(variable);
        }
      }

      // debugPrint("Shopify Request [Lang: ${variables['lang']}]: $body");

      Map<String, dynamic> data = {
        'query': query,
        'variables': variables,
      };

      var res = await http.post(
        Uri.parse(
          version == null
              ? _baseUrl
              : _baseUrl.replaceAll(
                  _defaultVersion,
                  version,
                ),
        ),
        body: json.encode(data),
        headers: _header,
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['errors'] != null) {
          // debugPrint("Shopify GraphQL Errors: ${decoded['errors']}");
        }
        if (decoded['data'] != null) {
          // debugPrint("Shopify Response Data: ${jsonEncode(decoded['data'])}");
        } else {
          debugPrint(
              "Shopify Response: No data returned for lang ${variables['lang']}");
        }
        return decoded;
      } else {
        // debugPrint("Shopify Error ${res.statusCode}: ${res.reasonPhrase}");
        return {};
      }
    } catch (e) {
      // debugPrint("Shopify Network/Parsing Error: $e");
      return {};
    }
  }

  static Future<ProductModel?> getProductDetails(BuildContext context,
      {required String productId}) async {
    // debugPrint("Fetching localized product details for: $productId");
    try {
      final fullId =
          productId.contains(_proIdPre) ? productId : "$_proIdPre$productId";
      var res = await getGraphQLData(
        context,
        body: '''
          node(id: "$fullId") {
            ... on Product {
              id
              title
              descriptionHtml
              vendor
              productType
              handle
              featuredImage {
                url
              }
              images(first: 10) {
                nodes {
                  url
                }
              }
              collections(first: 1) {
                nodes {
                  id
                }
              }
              variants(first: 20) {
                nodes {
                  id
                  title
                  price {
                    amount
                  }
                  compareAtPrice {
                    amount
                  }
                  quantityAvailable
                }
              }
            }
          }
        ''',
      );

      if (res['data'] != null && res['data']['node'] != null) {
        var p = res['data']['node'];

        String? collectionId;
        if (p['collections'] != null &&
            p['collections']['nodes'] != null &&
            (p['collections']['nodes'] as List).isNotEmpty) {
          collectionId = p['collections']['nodes'][0]['id']
              .toString()
              .replaceAll(_colIdPre, '');
        }

        List<Map<String, dynamic>> variants = [];
        if (p['variants'] != null && p['variants']['nodes'] != null) {
          for (var v in p['variants']['nodes']) {
            variants.add({
              "id": v['id'].toString().replaceAll(_proVarIdPre, ''),
              "title": v['title'] ?? '',
              "price": v['price']?['amount']?.toString() ?? '0',
              "compare_at_price": v['compareAtPrice']?['amount']?.toString(),
              "inventory_quantity": v['quantityAvailable'] ?? 0,
            });
          }
        }

        Map<String, dynamic> li = {
          "id": p['id'].toString().replaceAll(_proIdPre, ''),
          "title": p["title"] ?? '',
          "body_html": p["descriptionHtml"] ?? '',
          "vendor": p["vendor"] ?? '',
          "product_type": p["productType"] ?? '',
          "handle": p["handle"] ?? '',
          "images": p["images"] != null && p["images"]['nodes'] != null
              ? (p["images"]['nodes'] as List)
                  .map((e) => {"url": e['url']})
                  .toList()
              : [],
          "variants": variants,
          "image": p["featuredImage"],
          "collectionId": collectionId,
        };

        return ProductModel.fromJson(li);
      }
    } catch (e) {
      // debugPrint("Error fetching product details: $e");
    }
    return null;
  }

  static Future<Map<String, dynamic>> getProductsFromCollections(
    BuildContext context, {
    required String id,
    int? limit,
    String? cursor,
  }) async {
    try {
      var res = await getGraphQLData(
        context,
        body: '''
          collection(id: "$_colIdPre$id") {
          products(first: ${limit ?? 100}, after: ${cursor != null ? "\"$cursor\"" : "null"}) {
              nodes {
                  id
                  title
                  vendor
                  productType
                  handle
                  featuredImage {
                      url
                  }
                  variants(first: 20) {
                      nodes {
                          id
                          title
                          price {
                              amount
                          }
                          compareAtPrice {
                              amount
                          }                   
                          quantityAvailable
                      }
                  }
              }
              pageInfo {
                  hasNextPage
                  endCursor
                  hasPreviousPage
                  startCursor
              }
          }
        }
        ''',
      );

      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['collection'] != null &&
          res['data']['collection']['products'] != null) {
        List<ProductModel> list = [];
        for (var lis in res['data']['collection']['products']['nodes']) {
          List<Map<String, dynamic>> variants = [];

          if (lis['variants'] != null && lis['variants']['nodes'] != null) {
            for (var variant in lis['variants']['nodes']) {
              Map<String, dynamic> vari = {
                "id": variant['id'].toString().replaceAll(_proVarIdPre, ''),
                "title": variant['title'] ?? '',
                "price": variant['price']?['amount']?.toString() ?? '0',
                "compare_at_price":
                    variant['compareAtPrice']?['amount']?.toString(),
                "inventory_quantity": variant['quantityAvailable'] ?? 0,
              };
              variants.add(vari);
            }
          }

          Map<String, dynamic> li = {
            "id": lis['id'].toString().replaceAll(_proIdPre, ''),
            "title": lis["title"] ?? '',
            "body_html": lis["descriptionHtml"] ?? '',
            "vendor": lis["vendor"] ?? '',
            "product_type": lis["productType"] ?? '',
            "handle": lis["handle"] ?? '',
            "images": lis["images"] != null && lis["images"]['nodes'] != null
                ? (lis["images"]['nodes'] as List)
                    .map((e) => {"url": e['url']})
                    .toList()
                : [],
            "variants": variants,
            "image": lis["featuredImage"],
          };
          list.add(ProductModel.fromJson(li));
        }

        var pageInfo = res['data']['collection']['products']['pageInfo'];
        return {
          "product": list,
          "end": (pageInfo != null && pageInfo['hasNextPage'] == true)
              ? pageInfo["endCursor"]
              : null,
        };
      }
    } catch (e) {
      // debugPrint("Error in getProductsFromCollections: $e");
    }
    return {"product": <ProductModel>[], "end": null};
  }

  static Future<ProductModel?> getProductVariantDetails(BuildContext context,
      {required String variantId}) async {
    try {
      final fullId = variantId.contains(_proVarIdPre)
          ? variantId
          : "$_proVarIdPre$variantId";
      var res = await getGraphQLData(
        context,
        body: '''
          node(id: "$fullId") {
            ... on ProductVariant {
              id
              title
              price {
                amount
              }
              compareAtPrice {
                amount
              }
              quantityAvailable
              product {
                id
                title
                descriptionHtml
                vendor
                productType
                handle
                featuredImage {
                  url
                }
                images(first: 10) {
                  nodes {
                    url
                  }
                }
              }
            }
          }
        ''',
      );

      if (res['data'] != null && res['data']['node'] != null) {
        var v = res['data']['node'];
        var p = v['product'];

        List<Map<String, dynamic>> variants = [
          {
            "id": v['id'].toString().replaceAll(_proVarIdPre, ''),
            "title": v['title'] ?? '',
            "price": v['price']?['amount']?.toString() ?? '0',
            "compare_at_price": v['compareAtPrice']?['amount']?.toString(),
            "inventory_quantity": v['quantityAvailable'] ?? 0,
          }
        ];

        Map<String, dynamic> li = {
          "id": p['id'].toString().replaceAll(_proIdPre, ''),
          "title": p["title"] ?? '',
          "body_html": p["descriptionHtml"] ?? '',
          "vendor": p["vendor"] ?? '',
          "product_type": p["productType"] ?? '',
          "handle": p["handle"] ?? '',
          "images": p["images"] != null && p["images"]['nodes'] != null
              ? (p["images"]['nodes'] as List)
                  .map((e) => {"url": e['url']})
                  .toList()
              : [],
          "variants": variants,
          "image": p["featuredImage"],
        };
        return ProductModel.fromJson(li);
      }
    } catch (e) {
      // debugPrint("Error in getProductVariantDetails: $e");
    }
    return null;
  }

  static Future<List<LocalizationModel>> getLocalization(
    BuildContext context,
  ) async {
    try {
      var res = await getGraphQLData(
        context,
        body: '''
          localization {
            availableLanguages {
                isoCode
                endonymName
            }
          }
        ''',
      );
      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['localization'] != null) {
        List<LocalizationModel> list = [];
        for (var lis in res['data']['localization']['availableLanguages']) {
          list.add(LocalizationModel(
            iso: lis['isoCode'] ?? '',
            name: lis['endonymName'] ?? '',
          ));
        }
        return list;
      }
    } catch (e) {
      // debugPrint("Error in getLocalization: $e");
    }
    return [];
  }

  static Future<List<ProductModel>> getProductsRecommend(BuildContext context,
      {required String id}) async {
    try {
      var res = await getGraphQLData(
        context,
        body: '''
            productRecommendations(productId: "$_proIdPre$id") {
            id
            title
            vendor
            productType
            handle
            featuredImage {
                url
            }
            images(first: 10) {
                nodes {
                    url
                }
            }
            variants(first: 100) {
                nodes {
                    id
                    title
                    price {
                        amount
                    }
                    compareAtPrice {
                        amount
                    }                   
                    quantityAvailable
                }
            }
        }
          ''',
      );
      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['productRecommendations'] != null) {
        List<ProductModel> list = [];
        for (var lis in res['data']['productRecommendations']) {
          List<Map<String, dynamic>> variants = [];

          if (lis['variants'] != null && lis['variants']['nodes'] != null) {
            for (var variant in lis['variants']['nodes']) {
              variants.add({
                "id": variant['id'].toString().replaceAll(_proVarIdPre, ''),
                "title": variant['title'] ?? '',
                "price": variant['price']?['amount']?.toString() ?? '0',
                "compare_at_price":
                    variant['compareAtPrice']?['amount']?.toString(),
                "inventory_quantity": variant['quantityAvailable'] ?? 0,
              });
            }
          }

          Map<String, dynamic> li = {
            "id": lis['id'].toString().replaceAll(_proIdPre, ''),
            "title": lis["title"] ?? '',
            "body_html": lis["descriptionHtml"] ?? '',
            "vendor": lis["vendor"] ?? '',
            "product_type": lis["productType"] ?? '',
            "handle": lis["handle"] ?? '',
            "images": lis["images"] != null && lis["images"]['nodes'] != null
                ? (lis["images"]['nodes'] as List)
                    .map((e) => {"url": e['url']})
                    .toList()
                : [],
            "variants": variants,
            "image": lis["featuredImage"],
          };
          list.add(ProductModel.fromJson(li));
        }
        list.shuffle(Random());
        return list;
      }
    } catch (e) {
      // debugPrint("Error in getProductsRecommend: $e");
    }
    return [];
  }

  static Future<Map<String, String>> getCollectionDetails(
    BuildContext context, {
    required String id,
    String? forcedLang,
  }) async {
    try {
      var res = await getGraphQLData(
        context,
        forcedLang: forcedLang,
        body: '''
          collection(id: "$_colIdPre$id") {
            id
            title
            handle
            description
            image { url }
          }
        ''',
      );

      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['collection'] != null) {
        var node = res['data']['collection'];
        return {
          "title": node['title'] ?? '',
          "handle": node['handle'] ?? '',
          "description": node['description'] ?? '',
          "image": node['image']?['url'] ?? '',
        };
      }
    } catch (e) {
      // debugPrint("Error in getCollectionDetails: $e");
    }
    return {};
  }

  static Future<List<CategoriesModel>> getCategories(
    BuildContext context, {
    String? forcedLang,
  }) async {
    try {
      var res = await getGraphQLData(
        context,
        forcedLang: forcedLang,
        body: '''
            collections(first: 100) {
                edges {
                    node {
                        id
                        title
                        handle
                        description
                        image {  
                            url
                            altText
                        }
                    }
                }
            }
          ''',
      );
      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['collections'] != null) {
        List<CategoriesModel> list = [];
        for (var edge in res['data']['collections']['edges']) {
          var node = edge['node'];
          String image = "";
          if (node["image"] != null && node["image"]["url"] != null) {
            image = node["image"]["url"];
          }
          list.add(
            CategoriesModel(
              id: int.tryParse(
                      node['id'].toString().replaceAll(_colIdPre, '')) ??
                  0,
              title: node['title'] ?? '',
              handle: node['handle'] ?? '',
              description: node['description'] ?? '',
              image: image,
            ),
          );
        }
        return list;
      }
    } catch (e) {
      // debugPrint("Error in getCategories: $e");
    }
    return [];
  }

  static Future<List<CategoriesModel>> getBannerCollections(
      BuildContext context) async {
    try {
      var res = await getGraphQLData(
        context,
        body: '''
            b1: collection(handle: "homepage-banner-1") { id title handle description image { url altText } }
            b2: collection(handle: "homepage-banner-2") { id title handle description image { url altText } }
            b3: collection(handle: "homepage-banner-3") { id title handle description image { url altText } }
            b4: collection(handle: "homepage-banner-4") { id title handle description image { url altText } }
            b5: collection(handle: "homepage-banner-5") { id title handle description image { url altText } }
          ''',
      );
      if (res.isNotEmpty && res['data'] != null) {
        List<CategoriesModel> list = [];
        for (int i = 1; i <= 5; i++) {
          var node = res['data']['b$i'];
          if (node != null) {
            String image = "";
            if (node["image"] != null && node["image"]["url"] != null) {
              image = node["image"]["url"];
            }
            list.add(
              CategoriesModel(
                id: int.tryParse(
                        node['id'].toString().replaceAll(_colIdPre, '')) ??
                    0,
                title: node['title'] ?? '',
                handle: node['handle'] ?? '',
                description: node['description'] ?? '',
                image: image,
              ),
            );
          }
        }
        return list;
      }
    } catch (e) {
      // debugPrint("Error in getBannerCollections: $e");
    }
    return [];
  }

  static Future<String> checkout(BuildContext context,
      {required List<dynamic> cartList}) async {
    try {
      List<Map<String, dynamic>> list = [];
      for (var cart in cartList) {
        list.add({
          "merchandiseId": "$_proVarIdPre${cart["id"]}",
          "quantity": cart["qty"],
        });
      }
      String query = '''
        mutation cartCreate(\$input: CartInput!) {
          cartCreate(input: \$input) {
            cart {
              id
              checkoutUrl
            }
            userErrors {
              field
              message
            }
          }
        }
      ''';

      final attribution = await AttributionService().getAttribution();
      // debugPrint("🛒 SENDING ATTRIBUTION TO SHOPIFY: $attribution");

      var res = await getGraphQLData(
        context,
        body: query,
        version: "2024-01",
        variable: {
          "input": {
            "lines": list,
            "attributes": attribution.entries
                .map((e) => {"key": e.key, "value": e.value})
                .toList(),
          },
        },
      );
      if (res['data'] != null &&
          res['data']['cartCreate'] != null &&
          res['data']['cartCreate']['cart'] != null) {
        await Pref.setPref(
          key: PrefKey.checkoutId,
          value: res['data']['cartCreate']['cart']['id'],
        );
        return res['data']['cartCreate']['cart']['checkoutUrl'] ?? '';
      }
    } catch (e) {
      // debugPrint("Error in checkout: $e");
    }
    return '';
  }

  static Future<List<ProductModel>> fetchSearchResults(
    BuildContext context, {
    required String query,
    bool isSugg = false,
  }) async {
    try {
      var res = await getGraphQLData(
        context,
        body: '''
            search(first:${isSugg ? 10 : 50}, query: "$query", types: [PRODUCT]) {
              nodes {
                  ... on Product {
                      id
                      title
                      vendor
                      productType
                      handle
                      featuredImage {
                          url
                      }
                      images(first: 10) {
                          nodes {
                              url
                          }
                      }
                      variants(first: 100) {
                          nodes {
                              id
                              title
                              price {
                                  amount
                              }
                              compareAtPrice {
                                  amount
                              }                   
                              quantityAvailable
                          }
                      }
                  }
              }
          }
          ''',
      );
      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['search'] != null) {
        List<ProductModel> list = [];
        for (var lis in res['data']['search']['nodes']) {
          if (lis == null || lis.isEmpty || lis['id'] == null) {
            continue;
          }
          List<Map<String, dynamic>> variants = [];

          if (lis['variants'] != null && lis['variants']['nodes'] != null) {
            for (var variant in lis['variants']['nodes']) {
              variants.add({
                "id": variant['id'].toString().replaceAll(_proVarIdPre, ''),
                "title": variant['title'] ?? '',
                "price": variant['price']?['amount']?.toString() ?? '0',
                "compare_at_price":
                    variant['compareAtPrice']?['amount']?.toString(),
                "inventory_quantity": variant['quantityAvailable'] ?? 0,
              });
            }
          }

          Map<String, dynamic> li = {
            "id": lis['id'].toString().replaceAll(_proIdPre, ''),
            "title": lis["title"] ?? '',
            "body_html": lis["descriptionHtml"] ?? '',
            "vendor": lis["vendor"] ?? '',
            "product_type": lis["productType"] ?? '',
            "handle": lis["handle"] ?? '',
            "images": lis["images"] != null && lis["images"]['nodes'] != null
                ? (lis["images"]['nodes'] as List)
                    .map((e) => {"url": e['url']})
                    .toList()
                : [],
            "variants": variants,
            "image": lis["featuredImage"],
          };
          list.add(ProductModel.fromJson(li));
        }
        return list;
      }
    } catch (e) {
      // debugPrint("Error in fetchSearchResults: $e");
    }
    return [];
  }

  static Future<void> getCheckoutStatus(
    BuildContext context,
  ) async {
    try {
      String? id = await Pref.getPref(PrefKey.checkoutId);
      if (id != null) {
        String query = '''
        query GetCheckoutDetails {
          node(id: "$id") {
            ... on Checkout {
              id
              orderStatusUrl
            }
          }
        }
      ''';
        var res = await getGraphQLData(
          context,
          body: query,
          version: "2024-01",
        );

        if (res['data'] != null && res['data']['node'] != null) {
          bool status = res['data']['node']['orderStatusUrl'] != null;
          if (status) {
            await Pref.removePrefKey(PrefKey.cart);
            await Pref.removePrefKey(PrefKey.checkoutId);
          }
        }
      }
    } catch (e) {
      // debugPrint("Error in getCheckoutStatus: $e");
    }
  }

  // Auth functions removed
  static Future<Map<String, dynamic>?> getUserInfo(
          BuildContext context) async =>
      null;
  static Future<bool> login(context,
          {required String email, required String password}) async =>
      false;
  static Future<String> signUp(context,
          {required String fName,
          required String lName,
          required String mobile,
          required String email,
          required String password}) async =>
      "";
  static Future<String> updateDetails(context,
          {required String fName,
          required String lName,
          required String mobile,
          required String email}) async =>
      "";

  static Future<void> share({required String url}) async {
    await Share.share(url);
  }
}

class ShopifyAdmin {
  static const String _baseUrl =
      "https://3b7f20-3.myshopify.com/admin/api/2024-10/graphql.json";

  static const String _proIdPre = "gid://shopify/Product/";
  static const String _proVarIdPre = "gid://shopify/ProductVariant/";

  static Map<String, String> _header = {
    'content-type': 'application/json',
    'X-Shopify-Access-Token': Constants.shopifyAccessToken,
  };

  static Future<Map<String, dynamic>> _getData({
    required String body,
  }) async {
    try {
      String query = '''
        query {
          $body
        }
        ''';
      var res = await http.post(
        Uri.parse(_baseUrl),
        body: json.encode({'query': query}),
        headers: _header,
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (e) {
      // debugPrint("ShopifyAdmin Error: $e");
    }
    return {};
  }

  static Future<ProductModel?> getProductsByVariant(
      {required String id}) async {
    try {
      var res = await _getData(
        body: '''
            productVariant(id: "$_proVarIdPre$id") {
                id
                title
                price
                compareAtPrice
                sellableOnlineQuantity
                product {
                  id
                  title
                  descriptionHtml
                  vendor
                  productType
                  handle
                  featuredImage {
                    url
                  }
                  images(first: 10) {
                    nodes {
                      url
                    }
                  }
                }
              }
          ''',
      );
      if (res.isNotEmpty &&
          res['data'] != null &&
          res['data']['productVariant'] != null) {
        var proVer = res['data']['productVariant'];
        var proud = proVer['product'];
        List<String> imgList = [];
        if (proud['images'] != null && proud['images']['nodes'] != null) {
          for (var img in proud['images']['nodes']) {
            imgList.add(img['url']?.toString() ?? '');
          }
        }

        return ProductModel(
          id: proud["id"].toString().replaceAll(_proIdPre, ''),
          title: proud["title"] ?? '',
          body: proud["descriptionHtml"] ?? '',
          vendor: proud["vendor"] ?? '',
          productType: proud["productType"] ?? '',
          handle: proud["handle"] ?? '',
          variants: [
            VariantModel(
              id: proVer['id'].toString().replaceAll(_proVarIdPre, ''),
              title: proVer['title'] ?? '',
              price: proVer['price']?.toString() ?? '0',
              compareAtPrice: proVer['compareAtPrice']?.toString(),
              inventoryQuantity: proVer['sellableOnlineQuantity'] ?? 0,
            ),
          ],
          images: imgList,
          image: proud["featuredImage"]?['url'],
        );
      }
    } catch (e) {
      // debugPrint("Error in getProductsByVariant: $e");
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getAvailableDiscounts() async {
    try {
      const String query = '''
        query {
          codeDiscountNodes(first: 20, query: "status:active") {
            edges {
              node {
                codeDiscount {
                  ... on DiscountCodeBasic {
                    title
                    summary
                    status
                    startsAt
                    appliesOncePerCustomer
                    customerSelection {
                      ... on DiscountCustomerAll { allCustomers }
                    }
                    codes(first: 1) { edges { node { code } } }
                    customerGets {
                      value {
                        ... on DiscountAmount { amount { amount } }
                        ... on DiscountPercentage { percentage }
                      }
                    }
                  }
                  ... on DiscountCodeBxgy {
                    title
                    summary
                    status
                    startsAt
                    appliesOncePerCustomer
                    customerSelection {
                      ... on DiscountCustomerAll { allCustomers }
                    }
                    codes(first: 1) { edges { node { code } } }
                    customerGets {
                      value {
                        ... on DiscountAmount { amount { amount } }
                        ... on DiscountPercentage { percentage }
                      }
                      items {
                        ... on DiscountProducts {
                          products(first: 10) {
                            nodes {
                              id
                              title
                              featuredImage { url }
                              variants(first: 1) {
                                nodes { id title price }
                              }
                            }
                          }
                        }
                        ... on DiscountCollections {
                          collections(first: 2) {
                            nodes {
                              products(first: 5) {
                                nodes {
                                  id
                                  title
                                  featuredImage { url }
                                  variants(first: 1) {
                                    nodes { id title price }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                  ... on DiscountCodeFreeShipping {
                    title
                    summary
                    status
                    startsAt
                    appliesOncePerCustomer
                    customerSelection {
                      ... on DiscountCustomerAll { allCustomers }
                    }
                    codes(first: 1) { edges { node { code } } }
                  }
                }
              }
            }
          }
        }
      ''';

      var res = await http.post(
        Uri.parse(_baseUrl),
        body: json.encode({'query': query}),
        headers: _header,
      );

      if (res.statusCode == 200) {
        // debugPrint("Get Discounts Response: ${res.body}");
        final data = jsonDecode(res.body);
        List<Map<String, dynamic>> discounts = [];

        if (data['data'] != null && data['data']['codeDiscountNodes'] != null) {
          final nodes = data['data']['codeDiscountNodes']['edges'] as List;

          for (var edge in nodes) {
            final node = edge['node']['codeDiscount'];
            if (node == null || node.isEmpty) continue;

            final codesList =
                (node['codes'] != null && node['codes']['edges'] != null)
                    ? node['codes']['edges'] as List
                    : [];
            if (codesList.isEmpty) continue;

            final firstCodeNode = codesList[0]['node'];

            final valObj = node['customerGets'] != null
                ? node['customerGets']['value']
                : null;
            double value = 0;
            String type = 'fixed_amount';

            if (valObj != null) {
              if (valObj['amount'] != null) {
                value =
                    double.tryParse(valObj['amount']['amount'].toString()) ?? 0;
                type = 'fixed_amount';
              } else if (valObj['percentage'] != null) {
                value =
                    (double.tryParse(valObj['percentage'].toString()) ?? 0) *
                        100;
                type = 'percentage';
              }
            } else {
              type = 'special';
              value = 0;
            }

            final customerGets = node['customerGets'];
            List<Map<String, dynamic>> entitledProducts = [];
            if (customerGets != null && customerGets['items'] != null) {
              final items = customerGets['items'];

              // Handle Product Entitlements
              if (items['products'] != null &&
                  items['products']['nodes'] != null) {
                for (var pro in items['products']['nodes']) {
                  final variants = (pro['variants'] != null &&
                          pro['variants']['nodes'] != null)
                      ? pro['variants']['nodes'] as List
                      : [];
                  final variant = variants.isNotEmpty ? variants[0] : null;

                  entitledProducts.add({
                    'id': pro['id']?.toString().split('/').last ?? '',
                    'title': pro['title'] ?? '',
                    'image': pro['featuredImage']?['url'] ?? '',
                    'variantId': variant != null
                        ? variant['id']?.toString().split('/').last ?? ''
                        : '',
                    'variantTitle':
                        variant != null ? variant['title'] ?? '' : '',
                    'price': variant != null
                        ? variant['price']?.toString() ?? '0'
                        : '0',
                  });
                }
              }

              // Handle Collection Entitlements
              if (items['collections'] != null &&
                  items['collections']['nodes'] != null) {
                for (var coll in items['collections']['nodes']) {
                  if (coll['products'] != null &&
                      coll['products']['nodes'] != null) {
                    for (var pro in coll['products']['nodes']) {
                      final variants = (pro['variants'] != null &&
                              pro['variants']['nodes'] != null)
                          ? pro['variants']['nodes'] as List
                          : [];
                      final variant = variants.isNotEmpty ? variants[0] : null;

                      entitledProducts.add({
                        'id': pro['id']?.toString().split('/').last ?? '',
                        'title': pro['title'] ?? '',
                        'image': pro['featuredImage']?['url'] ?? '',
                        'variantId': variant != null
                            ? variant['id']?.toString().split('/').last ?? ''
                            : '',
                        'variantTitle':
                            variant != null ? variant['title'] ?? '' : '',
                        'price': variant != null
                            ? variant['price']?.toString() ?? '0'
                            : '0',
                      });
                    }
                  }
                }
              }
            }

            if (entitledProducts.isNotEmpty) {
              type = 'special';
              value = 0;
            }

            final minReq = node['minimumRequirement'];
            double minAmount = 0;
            int minQty = 0;
            if (minReq != null) {
              if (minReq['amount'] != null) {
                minAmount =
                    double.tryParse(minReq['amount']['amount'].toString()) ?? 0;
              } else if (minReq['greaterThanOrEqualToQuantity'] != null) {
                minQty = int.tryParse(
                        minReq['greaterThanOrEqualToQuantity'].toString()) ??
                    0;
              }
            }

            // Fallback to parsing summary if minAmount is 0
            if (minAmount == 0) {
              final summary = (node['summary'] ?? '').toString().toLowerCase();
              // Handle various Shopify summary formats:
              // "Minimum purchase of ₹1,000.00"
              // "Orders over ₹1,000.00"
              // "Orders of ₹1,000.00 or more"
              // "Spend ₹2,500.00"
              final regex = RegExp(
                  r'(?:over|above|minimum|minimum purchase of|orders of|spend)\s*[^\d]*([\d,]+(?:\.\d+)?)');
              final match = regex.firstMatch(summary);
              if (match != null) {
                minAmount =
                    double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
              }
            }

            discounts.add({
              'code': firstCodeNode['code'],
              'title': node['title'] ?? '',
              'summary': node['summary'] ?? '',
              'value': value,
              'type': type,
              'description': node['summary'] ?? node['title'] ?? '',
              'entitledProducts': entitledProducts,
              'minAmount': minAmount,
              'minQty': minQty,
              'startsAt': node['startsAt'],
              'appliesOncePerCustomer': node['appliesOncePerCustomer'] ?? false,
              'customerSelection': node['customerSelection'],
              'combinesWith': node['combinesWith'],
            });
          }
        }
        return discounts;
      }
    } catch (e) {
      // debugPrint("Get Discounts Error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> validateDiscountCode(
      {required String code}) async {
    try {
      String query = '''
        query {
          codeDiscountNodeByCode(code: "$code") {
            id
            codeDiscount {
              ... on DiscountCodeBasic {
                title
                status
                startsAt
                summary
                appliesOncePerCustomer
                customerSelection {
                  ... on DiscountCustomerAll { allCustomers }
                }
                customerGets {
                  value {
                    ... on DiscountAmount { amount { amount } }
                    ... on DiscountPercentage { percentage }
                  }
                }
              }
              ... on DiscountCodeBxgy {
                title
                status
                startsAt
                summary
                appliesOncePerCustomer
                customerSelection {
                  ... on DiscountCustomerAll { allCustomers }
                }
                customerGets {
                  value {
                    ... on DiscountAmount { amount { amount } }
                    ... on DiscountPercentage { percentage }
                  }
                  items {
                    ... on DiscountProducts {
                      products(first: 10) {
                        nodes {
                          id
                          title
                          featuredImage { url }
                          variants(first: 1) {
                            nodes { id title price }
                          }
                        }
                      }
                    }
                    ... on DiscountCollections {
                      collections(first: 2) {
                        nodes {
                          products(first: 5) {
                            nodes {
                              id
                              title
                              featuredImage { url }
                              variants(first: 1) {
                                nodes { id title price }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
              ... on DiscountCodeFreeShipping {
                title
                status
                startsAt
                summary
                appliesOncePerCustomer
                customerSelection {
                  ... on DiscountCustomerAll { allCustomers }
                }
              }
            }
          }
        }
      ''';

      var res = await http.post(
        Uri.parse(_baseUrl),
        body: json.encode({'query': query}),
        headers: _header,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        // debugPrint("Validate Discount Response: ${res.body}");
        if (data['errors'] != null) {
          debugPrint("Shopify GraphQL Errors: ${data['errors']}");
        }

        if (data['data'] != null &&
            data['data']['codeDiscountNodeByCode'] != null) {
          final discountNode = data['data']['codeDiscountNodeByCode'];
          final discount = discountNode['codeDiscount'];
          if (discount == null) return null;

          final String status =
              (discount['status'] ?? '').toString().toUpperCase();
          if (status != 'ACTIVE') return null;

          String type = 'fixed_amount';
          dynamic value = 0;

          final customerGets = discount['customerGets'];
          if (customerGets != null) {
            final valObj = customerGets['value'];
            if (valObj != null) {
              if (valObj['amount'] != null) {
                value =
                    double.tryParse(valObj['amount']['amount'].toString()) ?? 0;
              } else if (valObj['percentage'] != null) {
                type = 'percentage';
                value =
                    (double.tryParse(valObj['percentage'].toString()) ?? 0) *
                        100;
              }
            }
          }

          List<Map<String, dynamic>> entitledProducts = [];
          if (customerGets != null && customerGets['items'] != null) {
            final items = customerGets['items'];

            // Handle Product Entitlements
            if (items['products'] != null &&
                items['products']['nodes'] != null) {
              for (var pro in items['products']['nodes']) {
                final variants = (pro['variants'] != null &&
                        pro['variants']['nodes'] != null)
                    ? pro['variants']['nodes'] as List
                    : [];
                final variant = variants.isNotEmpty ? variants[0] : null;

                entitledProducts.add({
                  'id': pro['id']?.toString().split('/').last ?? '',
                  'title': pro['title'] ?? '',
                  'image': pro['featuredImage']?['url'] ?? '',
                  'variantId': variant != null
                      ? variant['id']?.toString().split('/').last ?? ''
                      : '',
                  'variantTitle': variant != null ? variant['title'] ?? '' : '',
                  'price': variant != null
                      ? variant['price']?.toString() ?? '0'
                      : '0',
                });
              }
            }
          }

          if (entitledProducts.isNotEmpty) {
            type = 'special';
            value = 0;
          }

          final minReq = discount['minimumRequirement'];
          double minAmount = 0;
          int minQty = 0;
          if (minReq != null) {
            if (minReq['amount'] != null) {
              minAmount =
                  double.tryParse(minReq['amount']['amount'].toString()) ?? 0;
            } else if (minReq['greaterThanOrEqualToQuantity'] != null) {
              minQty = int.tryParse(
                      minReq['greaterThanOrEqualToQuantity'].toString()) ??
                  0;
            }
          }

          // Fallback to parsing summary if minAmount is 0
          if (minAmount == 0) {
            final summary =
                (discount['summary'] ?? '').toString().toLowerCase();
            final regex = RegExp(
                r'(?:over|above|minimum|minimum purchase of|orders of|spend)\s*[^\d]*([\d,]+(?:\.\d+)?)');
            final match = regex.firstMatch(summary);
            if (match != null) {
              minAmount =
                  double.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
            }
          }

          return {
            'code': code,
            'title': discount['title'] ?? '',
            'value': value,
            'type': type,
            'description': discount['summary'] ?? discount['title'] ?? '',
            'entitledProducts': entitledProducts,
            'minAmount': minAmount,
            'minQty': minQty,
            'startsAt': discount['startsAt'],
            'appliesOncePerCustomer':
                discount['appliesOncePerCustomer'] ?? false,
            'customerSelection': discount['customerSelection'],
            'combinesWith': discount['combinesWith'],
          };
        }
      }
    } catch (e) {
      // debugPrint("Validate Discount Error: $e");
    }
    return null;
  }
}
