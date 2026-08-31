import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AdminController {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1'); // Adjust if needed

  /// Logs in the admin and refreshes the ID token to ensure custom claims are loaded.
  static Future<User?> login(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Force refresh the token to get the 'admin' claim immediately
      await credential.user?.getIdToken(true);
      
      return credential.user;
    } catch (e) {
      debugPrint("Admin Login Error: $e");
      rethrow;
    }
  }

  /// Checks if the current Firebase user has the 'admin' claim.
  static Future<bool> isUserAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Force refresh once more to be absolutely sure
      final tokenResult = await user.getIdTokenResult(true);
      return tokenResult.claims?['admin'] == true;
    } catch (e) {
      debugPrint("Error checking admin status: $e");
      return false;
    }
  }

  /// Wraps the 'admin_createQueuedNotification' Callable Function.
  static Future<void> sendNow({
    required String title,
    required String body,
    String? imageUrl,
  }) async {
    try {
      final result = await _functions.httpsCallable('admin_createQueuedNotification').call({
        'title': title,
        'body': body,
        'image': imageUrl,
      });
      debugPrint("Manual Send Result: ${result.data}");
    } catch (e) {
      debugPrint("Error in sendNow: $e");
      rethrow;
    }
  }

  /// Wraps the 'admin_saveScheduledNotification' Callable Function.
  static Future<void> saveSchedule({
    String? id,
    required String title,
    required String body,
    String? imageUrl,
    required List<String> times,
    required bool active,
  }) async {
    try {
      await _functions.httpsCallable('admin_saveScheduledNotification').call({
        'id': id,
        'title': title,
        'body': body,
        'image': imageUrl,
        'times': times,
        'active': active,
      });
    } catch (e) {
      debugPrint("Error in saveSchedule: $e");
      rethrow;
    }
  }

  /// Fetches all schedules via the 'admin_getScheduledNotifications' Callable.
  static Future<List<Map<String, dynamic>>> getScheduledNotifications() async {
    try {
      final result = await _functions.httpsCallable('admin_getScheduledNotifications').call();
      return List<Map<String, dynamic>>.from(result.data);
    } catch (e) {
      debugPrint("Error in getScheduledNotifications: $e");
      rethrow;
    }
  }

  /// Soft deletes a schedule via the 'admin_deleteScheduledNotification' Callable.
  static Future<void> deleteSchedule(String id) async {
    try {
      await _functions.httpsCallable('admin_deleteScheduledNotification').call({
        'id': id,
      });
    } catch (e) {
      debugPrint("Error in deleteSchedule: $e");
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }
}
