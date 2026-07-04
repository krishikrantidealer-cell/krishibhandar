import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attribution_service.dart';
import 'constants.dart';
import 'pref.dart';

class AuthController {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool isSyncing = false;

  // Keys for SharedPreferences
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyShopifyId = 'shopify_customer_id';
  static const String _keyEmail = 'user_email';
  static const String _keyState = 'user_state';
  static const String _keyAddressList = 'user_address_list';


  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    String? phone = prefs.getString(_keyPhone);
    if (phone == null || phone.isEmpty) {
      final addresses = await getStoredAddresses();
      if (addresses.isNotEmpty) {
        for (var addr in addresses) {
          final p = addr['phone'];
          if (p != null && p.trim().isNotEmpty) {
            phone = p.trim();
            break;
          }
        }
      }
    }
    return phone;
  }

  static Future<String?> getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<String?> getShopifyCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyShopifyId);
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<void> saveAddress({
    required String pincode,
    required String address1,
    required String address2,
    required String city,
    required String state,
    String? firstName,
    String? lastName,
    String? name,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final address = {
      'pincode': pincode,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'name': name ?? '',
      'first_name': firstName ?? '',
      'last_name': lastName ?? '',
      'phone': phone ?? '',
    };

    List<Map<String, String>> current = await getStoredAddresses();

    current.insert(0, address); // Add new address at the top
    await prefs.setString(_keyAddressList, jsonEncode(current));

    if (name != null) {
      await prefs.setString(_keyName, name);
      // Background sync name to Shopify
      _updateShopifyCustomerName(name);
    }

    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_keyPhone, phone);
    }
  }

  static Future<void> updateAddress({
    required int index,
    required String pincode,
    required String address1,
    required String address2,
    required String city,
    required String state,
    String? firstName,
    String? lastName,
    String? name,
    String? phone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> current = await getStoredAddresses();

    if (index >= 0 && index < current.length) {
      current[index] = {
        'pincode': pincode,
        'address1': address1,
        'address2': address2,
        'city': city,
        'state': state,
        'name': name ?? '',
        'first_name': firstName ?? '',
        'last_name': lastName ?? '',
        'phone': phone ?? '',
      };
      await prefs.setString(_keyAddressList, jsonEncode(current));

      if (phone != null && phone.isNotEmpty) {
        await prefs.setString(_keyPhone, phone);
      }
    }
  }

  static Future<void> _updateShopifyCustomerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? customerId = prefs.getString(_keyShopifyId);
      if (customerId == null) return;

      final names = name.split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      const String baseUrl = "https://3b7f20-3.myshopify.com/admin/api/2024-10";
      await http.put(
        Uri.parse('$baseUrl/customers/$customerId.json'),
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Access-Token': Constants.shopifyAccessToken,
        },
        body: jsonEncode({
          "customer": {
            "id": customerId,
            "first_name": firstName,
            "last_name": lastName,
          }
        }),
      );
      debugPrint('AuthController: Synced name "$name" to Shopify');
    } catch (e) {
      debugPrint('AuthController: Name sync error: $e');
    }
  }

  static Future<List<Map<String, String>>> getStoredAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString(_keyAddressList);
    if (json == null) return [];
    try {
      List<dynamic> list = jsonDecode(json);
      return list.map((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
        }
        return <String, String>{};
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      debugPrint('AuthController: Error loading addresses: $e');
      return [];
    }
  }

  static Future<void> removeAddressFromList(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> current = await getStoredAddresses();
    if (index >= 0 && index < current.length) {
      current.removeAt(index);
      await prefs.setString(_keyAddressList, jsonEncode(current));
    }
  }

  static Future<Map<String, String>> getSavedAddress() async {
    List<Map<String, String>> all = await getStoredAddresses();
    if (all.isNotEmpty) return all.first;
    return {
      'pincode': '',
      'address1': '',
      'address2': '',
      'city': '',
      'state': '',
      'name': '',
    };
  }

  // ─── Send OTP (Bypassed) ──────────────────────────────────────────────────
  static Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required VoidCallback onAutoVerified,
  }) async {
    // Firebase OTP login is commented out completely
    onError('Firebase OTP is disabled');
  }

  // ─── Verify OTP (Bypassed) ────────────────────────────────────────────────
  static Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
    required Function(String error) onError,
  }) async {
    // Firebase OTP login is commented out completely
    return true;
  }

  // ─── Sync with Shopify ────────────────────────────────────────────────────
  static Future<void> syncWithShopify(String phone) async {
    isSyncing = true;
    
    // AppsFlyer Event: Login
    AttributionService.logLogin();

    try {
      const String baseUrl = "https://3b7f20-3.myshopify.com/admin/api/2024-10";
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': Constants.shopifyAccessToken,
      };

      final prefs = await SharedPreferences.getInstance();

      // ── User-switch guard ────────────────────────────────────────────────
      // If a different phone is logging in (e.g. app update, shared device),
      // wipe the previous user's data so their orders/addresses don't leak.
      final savedPhone = prefs.getString(_keyPhone);
      final normalizedIncoming = phone.replaceAll(RegExp(r'[^\d]'), '');
      final normalizedSaved = savedPhone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
      if (normalizedSaved.isNotEmpty && normalizedSaved != normalizedIncoming) {
        debugPrint('AuthController: New user detected ($normalizedSaved → $normalizedIncoming). Clearing old user data.');
        await Future.wait([
          prefs.remove(_keyPhone),
          prefs.remove(_keyName),
          prefs.remove(_keyShopifyId),
          prefs.remove(_keyEmail),
          prefs.remove(_keyAddressList),
          prefs.remove(_keyState),
        ]);
      }
      // ────────────────────────────────────────────────────────────────────

      // 1. Consolidated Search (Faster: 1 request instead of 3)
      // We search for E.164, local format, and raw digits in one go using OR
      final String query = 'phone:"+91$phone" OR phone:"$phone" OR "$phone"';
      var searchRes = await http.get(
        Uri.parse(
            '$baseUrl/customers/search.json?query=${Uri.encodeComponent(query)}&limit=1'),
        headers: headers,
      );

      var searchData =
          searchRes.statusCode == 200 ? jsonDecode(searchRes.body) : {};
      var customers = searchData['customers'] as List?;

      // 2. Process Result or Create
      if (customers != null && customers.isNotEmpty) {
        final customer = customers[0];
        await _saveShopifyCustomerToPrefs(customer, prefs);
      } else {
        // Create new customer
        final createRes = await http.post(
          Uri.parse('$baseUrl/customers.json'),
          headers: headers,
          body: jsonEncode({
            "customer": {
              "phone": "+91$phone",
              "first_name": "Krishi",
              "last_name": "Customer",
              "tags": "mobile-app",
            }
          }),
        );

        if (createRes.statusCode == 201) {
          final createData = jsonDecode(createRes.body);
          await _saveShopifyCustomerToPrefs(createData['customer'], prefs);
        } else if (createRes.statusCode == 422) {
          // If creation fails because phone is "taken" but search didn't find them,
          // it's likely a formatting edge case. Do a final broad digits-only search.
          var finalSearch = await http.get(
            Uri.parse('$baseUrl/customers/search.json?query=$phone&limit=1'),
            headers: headers,
          );
          var finalData =
              finalSearch.statusCode == 200 ? jsonDecode(finalSearch.body) : {};
          var finalCustomers = finalData['customers'] as List?;
          if (finalCustomers != null && finalCustomers.isNotEmpty) {
            await _saveShopifyCustomerToPrefs(finalCustomers[0], prefs);
          }
        }
      }
    } catch (e) {
      debugPrint('AuthController: Shopify sync error: $e');
    } finally {
      isSyncing = false;
    }
  }

  static Future<void> _saveShopifyCustomerToPrefs(
      dynamic customer, SharedPreferences prefs) async {
    if (customer == null || customer['id'] == null) {
      debugPrint('AuthController: ERROR - Cannot save null customer or missing ID');
      return;
    }
    final String customerId = customer['id'].toString();
    await prefs.setString(_keyShopifyId, customerId);
    await prefs.setString(
        _keyName,
        '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'
            .trim());
    await prefs.setString(_keyEmail, customer['email'] ?? '');
    
    // Fix 2: Verify save
    final savedId = prefs.getString(_keyShopifyId);
    debugPrint('AuthController: Customer ID Saved: $savedId');
    if (savedId == null) {
      debugPrint('AuthController: CRITICAL - Failed to save customer ID to SharedPreferences');
      debugPrint('Shopify Customer Data: ${jsonEncode(customer)}');
    }
  }

  static Future<void> syncCustomerFromOrder(String orderIdOrName) async {
    debugPrint('AuthController: Starting syncCustomerFromOrder for: $orderIdOrName');
    try {
      const String baseUrl = "https://3b7f20-3.myshopify.com/admin/api/2024-10";
      Map<String, String> headers = {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': Constants.shopifyAccessToken,
      };

      dynamic order;

      // 1. Try fetching as order ID first (numeric)
      if (RegExp(r'^\d+$').hasMatch(orderIdOrName)) {
        debugPrint('AuthController: Attempting direct order lookup by ID: $orderIdOrName');
        var res = await http.get(
          Uri.parse('$baseUrl/orders/$orderIdOrName.json'),
          headers: headers,
        );
        if (res.statusCode == 200) {
          order = jsonDecode(res.body)['order'];
          debugPrint('AuthController: Found order via direct ID lookup');
        } else {
          debugPrint('AuthController: Direct ID lookup failed (Status: ${res.statusCode}). Proceeding to search.');
        }
      }

      // 2. Search fallback (Always attempt if direct lookup failed or wasn't tried)
      if (order == null) {
        final List<String> placeholders = [
          'success',
          'thank_you',
          'thank-you',
          'order_placed',
          'order-placed',
          'confirm',
          'confirmed'
        ];
        final bool isPlaceholder = placeholders.contains(orderIdOrName.toLowerCase());

        if (isPlaceholder) {
          debugPrint('AuthController: Skipping polling loop for placeholder: $orderIdOrName');
        } else {
          debugPrint('AuthController: Searching for order name/token: $orderIdOrName');
          // A. Search matching order by checking latest orders
          int attempts = 5;
          for (int i = 0; i < attempts; i++) {
            var res = await http.get(
              Uri.parse('$baseUrl/orders.json?limit=30&status=any'),
              headers: headers,
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
                    order = ord;
                    debugPrint("🎯 syncCustomerFromOrder: Found matching order: ${ord['id']} on attempt ${i + 1}");
                    break;
                  }
                }
              }
            } else {
              debugPrint('AuthController: Orders list fetch failed (Status: ${res.statusCode}): ${res.body}');
            }

            if (order != null) break;

            if (i < attempts - 1) {
              debugPrint("⏳ syncCustomerFromOrder: Order $orderIdOrName not found yet (attempt ${i + 1}/$attempts). Retrying in 3 seconds...");
              await Future.delayed(const Duration(seconds: 3));
            }
          }
        }

        // B. Fallback: Search latest order in the system if created in the last 10 minutes
        if (order == null) {
          debugPrint('AuthController: Final fallback - checking latest system order');
          var res = await http.get(
            Uri.parse('$baseUrl/orders.json?limit=1&status=any'),
            headers: headers,
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
                    order = latestOrder;
                    debugPrint("🎯 syncCustomerFromOrder: Matched order based on latest order fallback (created $difference min ago): ${order['id']}");
                  }
                }
              }
            }
          }
        }
      }

      if (order != null) {
        final customer = order['customer'];
        if (customer == null) {
          debugPrint('AuthController: ERROR - Order found but no customer data attached');
          return;
        }
        
        final shipping = order['shipping_address'];
        final billing = order['billing_address'];

        String? phone;
        if (customer['phone'] != null) {
          phone = customer['phone'].toString();
        }
        phone ??= shipping?['phone']?.toString() ?? billing?['phone']?.toString();

        if (phone != null && phone.isNotEmpty) {
          phone = phone.replaceAll(RegExp(r'[^\d]'), '');
          if (phone.startsWith('91') && phone.length > 10) {
            phone = phone.substring(2);
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPhone, phone);
          
          if (customer['id'] != null) {
            await _saveShopifyCustomerToPrefs(customer, prefs);
            debugPrint('AuthController: Synced Customer ID ${customer['id']} from Order successfully.');
          } else {
            debugPrint('AuthController: Customer ID missing in order, syncing by phone: $phone');
            await syncWithShopify(phone);
          }
        } else {
          debugPrint('AuthController: WARNING - No phone number found in order or customer profile');
          // Still try to save customer if ID exists
          if (customer['id'] != null) {
             final prefs = await SharedPreferences.getInstance();
             await _saveShopifyCustomerToPrefs(customer, prefs);
          }
        }
      } else {
        debugPrint('AuthController: FAILED to find order $orderIdOrName after all attempts');
      }
    } catch (e, stack) {
      debugPrint('AuthController: syncCustomerFromOrder CRITICAL ERROR: $e');
      debugPrint('Stacktrace: $stack');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyPhone),
      prefs.remove(_keyName),
      prefs.remove(_keyShopifyId),
      prefs.remove(_keyEmail),
      prefs.remove(_keyAddressList),
      prefs.remove(_keyState),
    ]);
    debugPrint('AuthController: All user data cleared on sign-out');
  }
}
