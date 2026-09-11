import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/attribution_service.dart';
import 'pref.dart';

class AuthController {
  static bool isSyncing = false;

  // Keys for SharedPreferences
  static const String _keyPhone = 'user_phone';
  static const String _keyName = 'user_name';
  static const String _keyCustomerId = 'customer_id';
  static const String _keyEmail = 'user_email';
  static const String _keyState = 'user_state';
  static const String _keyAddressList = 'user_address_list';
  static const String _keyIsProfileCompleted = 'is_profile_completed';

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPhone);
  }

  static Future<String?> getSavedName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyName);
  }

  static Future<String?> getCustomerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCustomerId);
  }

  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyEmail);
  }

  static Future<bool> isProfileCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsProfileCompleted) ?? false;
  }

  static Future<void> setProfileCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsProfileCompleted, value);
  }

  static Future<bool> isLoggedIn() async {
    final token = await ApiService.getAuthToken();
    return token != null && token.trim().isNotEmpty;
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
      await prefs.setString(_keyName, name);
      _updateCustomerName(name);
    }

    if (phone != null && phone.isNotEmpty) {
      await prefs.setString(_keyPhone, phone);
    }

    // Sync address to backend if authenticated
    try {
      final custId = await getCustomerId();
      if (custId != null && custId.isNotEmpty) {
        await ApiService.addAddress(custId, address);
      }
    } catch (e) {
      debugPrint('AuthController: saveAddress remote sync error: $e');
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
      final custId = await getCustomerId();
      if (custId == null || custId.isEmpty) return;

      final names = name.split(' ');
      final firstName = names.first;
      final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';

      await ApiService.updateCustomer(custId, {
        "name": name,
        "first_name": firstName,
        "last_name": lastName,
      });
      debugPrint('AuthController: Synced name "$name" to backend');
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

  // ─── Send OTP via Backend ──────────────────────────────────────────────────
  static Future<ApiResponse<Map<String, dynamic>>> sendOtp({
    required String phone,
  }) async {
    return await ApiService.sendOtp(phone);
  }

  // ─── Verify OTP via Backend ────────────────────────────────────────────────
  static Future<ApiResponse<Map<String, dynamic>>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    final response = await ApiService.verifyOtp(cleanPhone, otp);

    if (response.success && response.data != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPhone, cleanPhone);

      final customer = response.data!['customer'];
      if (customer != null) {
        await _saveCustomerToPrefs(customer, prefs);
      } else {
        await prefs.setBool(_keyIsProfileCompleted, false);
      }

      // Attribution
      AttributionService.logLogin();
    }

    return response;
  }

  // ─── Sync with Backend ────────────────────────────────────────────────────
  static Future<void> syncWithBackend(String phone) async {
    isSyncing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString(_keyPhone);
      final normalizedIncoming = phone.replaceAll(RegExp(r'[^\d]'), '');
      final normalizedSaved = savedPhone?.replaceAll(RegExp(r'[^\d]'), '') ?? '';

      if (normalizedSaved.isNotEmpty && normalizedSaved != normalizedIncoming) {
        debugPrint('AuthController: New user detected. Clearing old user data.');
        await Future.wait([
          prefs.remove(_keyPhone),
          prefs.remove(_keyName),
          prefs.remove(_keyCustomerId),
          prefs.remove(_keyEmail),
          prefs.remove(_keyAddressList),
          prefs.remove(_keyState),
        ]);
        await ApiService.clearAuthToken();
      }

      await prefs.setString(_keyPhone, normalizedIncoming);

      // Fetch profile if token exists
      final profile = await ApiService.getCurrentCustomer();
      if (profile != null) {
        await _saveCustomerToPrefs(profile, prefs);
      }
    } catch (e) {
      debugPrint('AuthController: syncWithBackend error: $e');
    } finally {
      isSyncing = false;
    }
  }

  static Future<void> _saveCustomerToPrefs(
      dynamic customer, SharedPreferences prefs) async {
    final id = (customer['_id'] ?? customer['id'])?.toString() ?? '';
    if (id.isNotEmpty) {
      await prefs.setString(_keyCustomerId, id);
    }

    final name = (customer['name'] ?? '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}').toString().trim();
    if (name.isNotEmpty) {
      await prefs.setString(_keyName, name);
    }

    if (customer['email'] != null) {
      await prefs.setString(_keyEmail, customer['email'].toString());
    }

    // Determine isProfileCompleted status
    final hasAddresses = (customer['addresses'] is List && (customer['addresses'] as List).isNotEmpty) ||
        (customer['defaultAddress'] != null &&
            ((customer['defaultAddress']['address1']?.toString().isNotEmpty == true) ||
                (customer['defaultAddress']['city']?.toString().isNotEmpty == true) ||
                (customer['defaultAddress']['zip']?.toString().isNotEmpty == true)));

    final isCompleted = customer['isprofilecompleted'] == true ||
        customer['isProfileCompleted'] == true ||
        (name.isNotEmpty && hasAddresses);

    await prefs.setBool(_keyIsProfileCompleted, isCompleted);

    // Load addresses from customer object if available
    if (customer['addresses'] is List && (customer['addresses'] as List).isNotEmpty) {
      final addrList = (customer['addresses'] as List).map((a) {
        if (a is Map) {
          return {
            'pincode': (a['zip'] ?? a['pincode'] ?? '').toString(),
            'address1': (a['address1'] ?? '').toString(),
            'address2': (a['address2'] ?? '').toString(),
            'city': (a['city'] ?? '').toString(),
            'state': (a['province'] ?? a['state'] ?? '').toString(),
            'name': (a['name'] ?? name).toString(),
            'phone': (a['phone'] ?? customer['phone'] ?? '').toString(),
          };
        }
        return <String, String>{};
      }).where((m) => m.isNotEmpty).toList();

      if (addrList.isNotEmpty) {
        await prefs.setString(_keyAddressList, jsonEncode(addrList));
      }
    }

    debugPrint('AuthController: Synced Customer ID: $id, isProfileCompleted: $isCompleted');
  }

  static Future<void> syncCustomerFromOrder(String orderIdOrName) async {
    try {
      final order = await ApiService.getOrderById(orderIdOrName);
      if (order != null) {
        final customer = order['customer'];
        if (customer != null) {
          final prefs = await SharedPreferences.getInstance();
          await _saveCustomerToPrefs(customer, prefs);
        }
      }
    } catch (e) {
      debugPrint('AuthController: syncCustomerFromOrder error: $e');
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    try {
      await ApiService.logout();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyPhone),
      prefs.remove(_keyName),
      prefs.remove(_keyCustomerId),
      prefs.remove(_keyEmail),
      prefs.remove(_keyAddressList),
      prefs.remove(_keyState),
      prefs.remove(_keyIsProfileCompleted),
    ]);
    await Pref.removePrefKey(PrefKey.authToken);
    debugPrint('AuthController: All user data cleared on sign-out');
  }
}
