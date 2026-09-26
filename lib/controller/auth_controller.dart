import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attribution_service.dart';
import 'constants.dart';

class AuthController {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool isSyncing = false;

  // Keys for SharedPreferences
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyCustomerId = 'customer_id';
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

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomerId) ?? prefs.getString('shopify_customer_id') ?? prefs.getString(_keyPhone);
  }

  static Future<String?> getShopifyCustomerId() async => getCustomerId();

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
      _updateCustomerName(name);
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

  static Future<void> _updateCustomerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyName, name);
      final String? customerId = prefs.getString(_keyCustomerId) ?? prefs.getString(_keyPhone);
      if (customerId == null) return;

      final names = name.split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      final String baseUrl = Constants.apiBaseUrl;
      await http.put(
        Uri.parse('$baseUrl/api/customers/$customerId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name,
          "first_name": firstName,
          "last_name": lastName,
        }),
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('AuthController: Name sync notice: $e');
    }
  }

  static Future<void> updateCustomerName(String name) async => _updateCustomerName(name);

  static Future<List<Map<String, String>>> getStoredAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    String? json = prefs.getString(_keyAddressList);
    if (json == null) return [];
    try {
      List<dynamic> list = jsonDecode(json);
      return list
          .map((e) {
            if (e is Map) {
              return e
                  .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
            }
            return <String, String>{};
          })
          .where((m) => m.isNotEmpty)
          .toList();
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

  // ─── Sync Customer Profile ────────────────────────────────────────────────
  static Future<void> syncCustomer(String phone) async {
    isSyncing = true;
    AttributionService.logLogin();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = cleanPhone.length > 10 && cleanPhone.startsWith('91')
          ? cleanPhone.substring(2)
          : cleanPhone;

      final savedPhone = prefs.getString(_keyPhone);
      if (savedPhone != null && savedPhone.isNotEmpty && savedPhone != formattedPhone) {
        debugPrint('AuthController: New user detected ($savedPhone → $formattedPhone). Clearing old user data.');
        await Future.wait([
          prefs.remove(_keyPhone),
          prefs.remove(_keyName),
          prefs.remove(_keyCustomerId),
          prefs.remove('shopify_customer_id'),
          prefs.remove(_keyEmail),
          prefs.remove(_keyAddressList),
          prefs.remove(_keyState),
        ]);
      }

      await prefs.setString(_keyPhone, formattedPhone);
      if (prefs.getString(_keyCustomerId) == null || prefs.getString(_keyCustomerId)!.isEmpty) {
        await prefs.setString(_keyCustomerId, formattedPhone);
      }

      // Sync with Bhandar backend if reachable
      try {
        final res = await http.post(
          Uri.parse('${Constants.apiBaseUrl}/api/auth/customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "phone": formattedPhone,
            "name": prefs.getString(_keyName) ?? "Krishi Customer",
            "source": "mobile_app",
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final cust = data['customer'] ?? data['user'] ?? data['data'];
          if (cust is Map && (cust['id'] != null || cust['_id'] != null)) {
            final custId = (cust['id'] ?? cust['_id']).toString();
            await prefs.setString(_keyCustomerId, custId);
            if (cust['name'] != null && (cust['name'] as String).isNotEmpty) {
              await prefs.setString(_keyName, cust['name']);
            }
          }
        }
      } catch (apiErr) {
        debugPrint('AuthController: Backend customer sync notice: $apiErr');
      }
    } catch (e) {
      debugPrint('AuthController: Customer sync error: $e');
    } finally {
      isSyncing = false;
    }
  }

  static Future<void> syncWithShopify(String phone) async => syncCustomer(phone);

  static Future<void> syncCustomerFromOrder(String orderIdOrName) async {
    debugPrint('AuthController: Starting syncCustomerFromOrder for: $orderIdOrName');
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = Constants.apiBaseUrl;

      final res = await http.get(
        Uri.parse('$baseUrl/api/orders/$orderIdOrName'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final order = data['order'] ?? data['data'] ?? data;
        if (order is Map) {
          final phone = order['customer_phone'] ?? order['phone'] ?? order['customer']?['phone'];
          final name = order['customer_first_name'] ?? order['customer_name'] ?? order['customer']?['name'];
          if (phone != null && phone.toString().isNotEmpty) {
            final cleanPhone = phone.toString().replaceAll(RegExp(r'[^\d]'), '');
            await prefs.setString(_keyPhone, cleanPhone);
          }
          if (name != null && name.toString().isNotEmpty) {
            await prefs.setString(_keyName, name.toString());
          }
        }
      }
    } catch (e) {
      debugPrint('AuthController: syncCustomerFromOrder notice: $e');
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
      prefs.remove(_keyCustomerId),
      prefs.remove('shopify_customer_id'),
      prefs.remove(_keyEmail),
      prefs.remove(_keyAddressList),
      prefs.remove(_keyState),
    ]);
    debugPrint('AuthController: All user data cleared on sign-out');
  }
}
