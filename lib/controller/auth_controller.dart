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
  static const String _keyShopifyId = 'shopify_customer_id';
  static const String _keyEmail = 'user_email';
  static const String _keyState = 'user_state';
  static const String _keyAddressList = 'user_address_list';

  // ─── Check if user is logged in ──────────────────────────────────────────
  static bool isLoggedIn() {
    return _auth.currentUser != null;
  }

  static Future<String?> getSavedPhone() async {
    final prefs = await SharedPreferences.getInstance();
    String? phone = prefs.getString(_keyPhone);
    if (phone == null && _auth.currentUser?.phoneNumber != null) {
      String fbPhone = _auth.currentUser!.phoneNumber!;
      if (fbPhone.startsWith('+91')) {
        fbPhone = fbPhone.substring(3);
      }
      return fbPhone;
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

  // ─── Send OTP ─────────────────────────────────────────────────────────────
  static Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required VoidCallback onAutoVerified,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification on Android (SMS auto-read)
          try {
            await _auth.signInWithCredential(credential);

            // Save phone and initial Shopify sync
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyPhone, phone);

            // Critical to sync shopify even in auto-verification
            await syncWithShopify(phone);

            onAutoVerified();
          } catch (e) {
            debugPrint('AuthController: Auto-verification error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          // If we are already signed in (auto-verification completed), ignore late failure events
          if (_auth.currentUser != null) return;

          String message = 'Verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            message = 'Invalid phone number. Please check and try again.';
          } else if (e.code == 'too-many-requests') {
            message =
                'Too many attempts. You have been temporarily blocked for security reasons. Please try again in 4-24 hours.';
          } else if (e.code == 'network-request-failed') {
            message = 'Network error. Please check your internet connection.';
          } else if (e.code == 'session-expired') {
            message = 'The SMS code has expired. Please request a new code.';
          } else {
            message = 'Error (${e.code}): ${e.message}';
          }
          onError(message);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError('Failed to send OTP. Please try again.');
    }
  }

  // ─── Verify OTP ──────────────────────────────────────────────────────────
  static Future<bool> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String phone,
    required Function(String error) onError,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);

      // Save phone to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPhone, phone);

      return true;
    } on FirebaseAuthException catch (e) {
      String message = 'Invalid OTP. Please try again.';
      if (e.code == 'invalid-verification-code') {
        message = 'Wrong OTP entered. Please check and try again.';
      } else if (e.code == 'session-expired') {
        message = 'OTP expired. Please request a new one.';
      }
      onError(message);
      return false;
    } catch (e) {
      onError('Verification failed. Please try again.');
      return false;
    }
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
    await prefs.setString(_keyShopifyId, customer['id'].toString());
    await prefs.setString(
        _keyName,
        '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'
            .trim());
    await prefs.setString(_keyEmail, customer['email'] ?? '');
    debugPrint('AuthController: Synced Shopify Customer ID: ${customer['id']}');
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    await _auth.signOut();
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
