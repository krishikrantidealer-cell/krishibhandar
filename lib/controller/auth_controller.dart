import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/attribution_service.dart';
import 'cart_controller.dart';
import 'constants.dart';
import 'pref.dart';

class AuthController extends ChangeNotifier {
  static final AuthController instance = AuthController._internal();
  factory AuthController() => instance;
  AuthController._internal();

  static bool isSyncing = false;

  // In-memory cache for synchronous, zero-lag UI access
  static String? _phone;
  static String? _name;
  static String? _customerId;
  static String? _email;

  // Keys for SharedPreferences
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyCustomerId = 'customer_id';
  static const String _keyEmail = 'user_email';
  static const String _keyState = 'user_state';
  static const String _keyAddressList = 'user_address_list';

  // Synchronous Getters
  static String? get currentPhone => _phone;
  static String? get currentName => _name;
  static String? get currentCustomerId => _customerId;
  static String? get currentEmail => _email;
  static bool get isLoggedIn => _phone != null && _phone!.trim().isNotEmpty;

  /// Ensure SharedPreferences and in-memory auth state are loaded before any widget builds
  static Future<void> ensureInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    _phone = prefs.getString(_keyPhone);
    _name = prefs.getString(_keyName);
    _customerId = prefs.getString(_keyCustomerId) ?? _phone;
    _email = prefs.getString(_keyEmail);

    // Fallback: If phone is missing from direct key, check saved addresses
    if (_phone == null || _phone!.isEmpty) {
      final addresses = await getStoredAddresses();
      if (addresses.isNotEmpty) {
        for (var addr in addresses) {
          final p = addr['phone'];
          if (p != null && p.trim().isNotEmpty) {
            _phone = p.trim();
            _customerId ??= _phone;
            await prefs.setString(_keyPhone, _phone!);
            break;
          }
        }
      }
    }
  }

  static Future<String?> getSavedPhone() async {
    if (_phone != null && _phone!.isNotEmpty) return _phone;
    await ensureInitialized();
    return _phone;
  }

  static Future<String?> getSavedName() async {
    if (_name != null && _name!.isNotEmpty) return _name;
    await ensureInitialized();
    return _name;
  }

  static Future<String?> getCustomerId() async {
    if (_customerId != null && _customerId!.isNotEmpty) return _customerId;
    await ensureInitialized();
    return _customerId ?? _phone;
  }

  static Future<String?> getSavedEmail() async {
    if (_email != null && _email!.isNotEmpty) return _email;
    await ensureInitialized();
    return _email;
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

    if (name != null && name.isNotEmpty) {
      _name = name;
      await prefs.setString(_keyName, name);
      _updateCustomerName(name);
    }

    if (phone != null && phone.isNotEmpty) {
      _phone = phone;
      await prefs.setString(_keyPhone, phone);
    }

    instance.notifyListeners();
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
        _phone = phone;
        await prefs.setString(_keyPhone, phone);
      }
      instance.notifyListeners();
    }
  }

  static Future<void> _updateCustomerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = name;
      await prefs.setString(_keyName, name);
      final String? customerId = _customerId ?? prefs.getString(_keyCustomerId) ?? _phone;
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
              return e.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
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
      instance.notifyListeners();
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

  // ─── Sync Customer Profile ────────────────────────────────────────────────
  static Future<void> syncCustomer(String phone, [String? name]) async {
    isSyncing = true;
    AttributionService.logLogin();

    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
      final formattedPhone = cleanPhone.length > 10 && cleanPhone.startsWith('91')
          ? cleanPhone.substring(2)
          : cleanPhone;

      if (_phone != null && _phone!.isNotEmpty && _phone != formattedPhone) {
        debugPrint('AuthController: New user detected ($_phone → $formattedPhone). Clearing old user data.');
        await Future.wait([
          prefs.remove(_keyPhone),
          prefs.remove(_keyName),
          prefs.remove(_keyCustomerId),
          prefs.remove(_keyEmail),
          prefs.remove(_keyAddressList),
          prefs.remove(_keyState),
        ]);
      }

      _phone = formattedPhone;
      await prefs.setString(_keyPhone, formattedPhone);

      if (name != null && name.trim().isNotEmpty) {
        _name = name.trim();
        await prefs.setString(_keyName, _name!);
      }

      if (_customerId == null || _customerId!.isEmpty) {
        _customerId = formattedPhone;
        await prefs.setString(_keyCustomerId, formattedPhone);
      }

      // Sync with Bhandar backend
      try {
        final res = await http.post(
          Uri.parse('${Constants.apiBaseUrl}/api/auth/customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "phone": formattedPhone,
            "name": _name ?? "Krishi Customer",
            "source": "mobile_app",
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final cust = data['customer'] ?? data['user'] ?? data['data'];
          if (cust is Map && (cust['id'] != null || cust['_id'] != null)) {
            _customerId = (cust['id'] ?? cust['_id']).toString();
            await prefs.setString(_keyCustomerId, _customerId!);
            if (cust['name'] != null && (cust['name'] as String).isNotEmpty) {
              _name = cust['name'];
              await prefs.setString(_keyName, _name!);
            }
          }
        }
      } catch (apiErr) {
        debugPrint('AuthController: Backend customer sync notice: $apiErr');
      }

      instance.notifyListeners();
    } catch (e) {
      debugPrint('AuthController: Customer sync error: $e');
    } finally {
      isSyncing = false;
    }
  }

  static Future<void> syncCustomerFromOrder(String orderIdOrName) async {
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
            _phone = cleanPhone;
            _customerId = cleanPhone;
            await prefs.setString(_keyPhone, cleanPhone);
            await prefs.setString(_keyCustomerId, cleanPhone);
          }
          if (name != null && name.toString().isNotEmpty) {
            _name = name.toString();
            await prefs.setString(_keyName, _name!);
          }
          instance.notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('AuthController: syncCustomerFromOrder notice: $e');
    }
  }

  // ─── OTP Helpers ────────────────────────────────────────────────────────
  static Future<void> sendOtp({
    required String phone,
    void Function(String verificationId)? onCodeSent,
    void Function(String error)? onError,
    void Function()? onAutoVerified,
  }) async {
    try {
      await syncCustomer(phone);
      if (onCodeSent != null) {
        onCodeSent('dummy_verification_id_$phone');
      }
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      }
    }
  }

  static Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
    void Function(String error)? onError,
  }) async {
    try {
      await syncCustomer(phone);
      return true;
    } catch (e) {
      if (onError != null) {
        onError(e.toString());
      }
      return false;
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyPhone),
      prefs.remove(_keyName),
      prefs.remove(_keyCustomerId),
      prefs.remove(_keyEmail),
      prefs.remove(_keyAddressList),
      prefs.remove(_keyState),
      Pref.removePrefKey(PrefKey.userAccessToken),
      Pref.removePrefKey(PrefKey.userAccessTokenExp),
      Pref.removePrefKey(PrefKey.checkoutId),
    ]);

    _phone = null;
    _name = null;
    _customerId = null;
    _email = null;

    // Reset in-memory cart
    CartController.clearCart();

    instance.notifyListeners();
    debugPrint('AuthController: User successfully signed out, state reset.');
  }
}
