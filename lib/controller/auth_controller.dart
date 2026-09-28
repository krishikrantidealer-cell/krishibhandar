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
  static bool _isProfileCompleted = false;

  // Keys for SharedPreferences
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyCustomerId = 'customer_id';
  static const String _keyEmail = 'user_email';
  static const String _keyState = 'user_state';
  static const String _keyAddressList = 'user_address_list';
  static const String _keyProfileCompleted = 'is_profile_completed';

  // Synchronous Getters
  static String? get currentPhone => _phone;
  static String? get currentName => _name;
  static String? get currentCustomerId => _customerId;
  static String? get currentEmail => _email;
  static bool get isLoggedIn => _phone != null && _phone!.trim().isNotEmpty;
  static bool get isProfileCompleted {
    if (!isLoggedIn) return false;
    if (_isProfileCompleted) return true;
    final n = _name?.trim().toLowerCase();
    if (n != null &&
        n.isNotEmpty &&
        n != "krishi customer" &&
        n != "krishi farmer") {
      return true;
    }
    return false;
  }

  static Future<void> setProfileCompleted(bool value) async {
    _isProfileCompleted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProfileCompleted, value);
    instance.notifyListeners();
  }

  /// Ensure SharedPreferences and in-memory auth state are loaded before any widget builds
  static Future<void> ensureInitialized() async {
    final prefs = await SharedPreferences.getInstance();
    _phone = prefs.getString(_keyPhone) ??
        prefs.getString('phone') ??
        prefs.getString('customer_phone') ??
        prefs.getString('userPhone') ??
        prefs.getString('mobile');

    _name = prefs.getString(_keyName) ??
        prefs.getString('name') ??
        prefs.getString('customer_name') ??
        prefs.getString('userName');

    _customerId = prefs.getString(_keyCustomerId) ??
        prefs.getString('customerId') ??
        prefs.getString('id') ??
        _phone;

    _email = prefs.getString(_keyEmail) ??
        prefs.getString('email') ??
        prefs.getString('customer_email');

    _isProfileCompleted = prefs.getBool(_keyProfileCompleted) ?? false;

    // Fallback: If phone is missing from direct key, check saved addresses
    if (_phone == null || _phone!.isEmpty) {
      final addresses = await getStoredAddresses();
      if (addresses.isNotEmpty) {
        for (var addr in addresses) {
          final p = addr['phone'];
          final n = addr['name'] ?? addr['first_name'];
          if (p != null && p.trim().isNotEmpty) {
            _phone = p.trim();
            _customerId ??= _phone;
            if (n != null && n.trim().isNotEmpty && (_name == null || _name!.isEmpty)) {
              _name = n.trim();
              await prefs.setString(_keyName, _name!);
            }
            await prefs.setString(_keyPhone, _phone!);
            break;
          }
        }
      }
    }

    if (_phone != null && _phone!.isNotEmpty) {
      await prefs.setString(_keyPhone, _phone!);
    }

    // Auto-detect profile completion status from existing credentials
    if (!_isProfileCompleted && isLoggedIn) {
      final n = _name?.trim().toLowerCase();
      final bool hasValidName = n != null &&
          n.isNotEmpty &&
          n != "krishi customer" &&
          n != "krishi farmer";
      final addresses = await getStoredAddresses();
      if (hasValidName || addresses.isNotEmpty) {
        _isProfileCompleted = true;
        await prefs.setBool(_keyProfileCompleted, true);
      }
    }

    instance.notifyListeners();
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

    _isProfileCompleted = true;
    await prefs.setBool(_keyProfileCompleted, true);

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
      _isProfileCompleted = true;
      await prefs.setBool(_keyProfileCompleted, true);
      instance.notifyListeners();
    }
  }

  static Future<void> _updateCustomerName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _name = name;
      await prefs.setString(_keyName, name);
      final String? customerId = _customerId ?? prefs.getString(_keyCustomerId) ?? _phone;

      if (name.trim().isNotEmpty &&
          name.trim().toLowerCase() != "krishi customer" &&
          name.trim().toLowerCase() != "krishi farmer") {
        _isProfileCompleted = true;
        await prefs.setBool(_keyProfileCompleted, true);
      }

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
        _isProfileCompleted = false;
        await Future.wait([
          prefs.remove(_keyPhone),
          prefs.remove(_keyName),
          prefs.remove(_keyCustomerId),
          prefs.remove(_keyEmail),
          prefs.remove(_keyAddressList),
          prefs.remove(_keyState),
          prefs.remove(_keyProfileCompleted),
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
        final Map<String, dynamic> reqBody = {
          "phone": formattedPhone,
          "source": "mobile_app",
        };
        if (name != null && name.trim().isNotEmpty) {
          reqBody["name"] = name.trim();
        } else if (_name != null &&
            _name!.trim().isNotEmpty &&
            _name!.trim().toLowerCase() != "krishi customer" &&
            _name!.trim().toLowerCase() != "krishi farmer") {
          reqBody["name"] = _name!.trim();
        }

        final res = await http.post(
          Uri.parse('${Constants.apiBaseUrl}/api/auth/customer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(reqBody),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body);
          final cust = data['customer'] ?? data['user'] ?? data['data'];
          if (cust is Map) {
            if (cust['id'] != null || cust['_id'] != null) {
              _customerId = (cust['id'] ?? cust['_id']).toString();
              await prefs.setString(_keyCustomerId, _customerId!);
            }
            if (cust['name'] != null && (cust['name'] as String).trim().isNotEmpty) {
              final backendName = (cust['name'] as String).trim();
              if (backendName.toLowerCase() != "krishi customer" &&
                  backendName.toLowerCase() != "krishi farmer") {
                _name = backendName;
                await prefs.setString(_keyName, _name!);
                _isProfileCompleted = true;
                await prefs.setBool(_keyProfileCompleted, true);
              }
            }

            // Sync addresses from backend if local list is empty
            if (cust['addresses'] is List && (cust['addresses'] as List).isNotEmpty) {
              final currentAddrs = await getStoredAddresses();
              if (currentAddrs.isEmpty) {
                final List<Map<String, String>> parsedAddrs = [];
                for (var a in (cust['addresses'] as List)) {
                  if (a is Map) {
                    parsedAddrs.add({
                      'pincode': (a['zip'] ?? a['pincode'] ?? '').toString(),
                      'address1': (a['address1'] ?? a['street'] ?? '').toString(),
                      'address2': (a['address2'] ?? '').toString(),
                      'city': (a['city'] ?? '').toString(),
                      'state': (a['province'] ?? a['state'] ?? '').toString(),
                      'name': (a['name'] ?? _name ?? '').toString(),
                      'phone': (a['phone'] ?? formattedPhone).toString(),
                    });
                  }
                }
                if (parsedAddrs.isNotEmpty) {
                  await prefs.setString(_keyAddressList, jsonEncode(parsedAddrs));
                  _isProfileCompleted = true;
                  await prefs.setBool(_keyProfileCompleted, true);
                }
              }
            } else if (cust['default_address'] is Map) {
              final currentAddrs = await getStoredAddresses();
              if (currentAddrs.isEmpty) {
                final a = cust['default_address'];
                final defaultAddr = [{
                  'pincode': (a['zip'] ?? a['pincode'] ?? '').toString(),
                  'address1': (a['address1'] ?? a['street'] ?? '').toString(),
                  'address2': (a['address2'] ?? '').toString(),
                  'city': (a['city'] ?? '').toString(),
                  'state': (a['province'] ?? a['state'] ?? '').toString(),
                  'name': (a['name'] ?? _name ?? '').toString(),
                  'phone': (a['phone'] ?? formattedPhone).toString(),
                }];
                await prefs.setString(_keyAddressList, jsonEncode(defaultAddr));
                _isProfileCompleted = true;
                await prefs.setBool(_keyProfileCompleted, true);
              }
            }
          }
        }
      } catch (apiErr) {
        debugPrint('AuthController: Backend customer sync notice: $apiErr');
      }

      // Check final profile completion status
      final currentAddrs = await getStoredAddresses();
      final n = _name?.trim().toLowerCase();
      final bool hasValidName = n != null &&
          n.isNotEmpty &&
          n != "krishi customer" &&
          n != "krishi farmer";

      if (_isProfileCompleted || hasValidName || currentAddrs.isNotEmpty) {
        _isProfileCompleted = true;
        await prefs.setBool(_keyProfileCompleted, true);
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
            _isProfileCompleted = true;
            await prefs.setBool(_keyProfileCompleted, true);
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
      prefs.remove(_keyProfileCompleted),
      Pref.removePrefKey(PrefKey.userAccessToken),
      Pref.removePrefKey(PrefKey.userAccessTokenExp),
      Pref.removePrefKey(PrefKey.checkoutId),
    ]);

    _phone = null;
    _name = null;
    _customerId = null;
    _email = null;
    _isProfileCompleted = false;

    // Reset in-memory cart
    CartController.clearCart();

    instance.notifyListeners();
    debugPrint('AuthController: User successfully signed out, state reset.');
  }
}
