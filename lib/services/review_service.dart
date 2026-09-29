import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../controller/constants.dart';
import '../model/review_model.dart';

class ReviewService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String get _baseUrl => Constants.apiBaseUrl;

  static Map<String, String> get _header => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Uploads a review image directly to the Google Cloud Storage bucket (folder: reviews)
  static Future<String?> uploadReviewImageBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['folder'] = 'reviews';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final url = decoded['url'] ??
              decoded['imageUrl'] ??
              decoded['fileUrl'] ??
              decoded['location'] ??
              (decoded['data'] is Map ? decoded['data']['url'] : null);
          if (url != null && url.toString().isNotEmpty) {
            return url.toString();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Review image GCS upload error: $e");
    }
    return null;
  }

  /// Fetch public reviews for a product (MongoDB Backend REST API first, Firestore fallback)
  static Future<List<ReviewModel>> getProductReviews(String productId) async {
    final cleanId = productId.replaceAll(RegExp(r'[^\w-]'), '').trim();
    final List<ReviewModel> reviews = [];

    // 1. Primary: Fetch from MongoDB Backend REST API
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/api/reviews?productId=$cleanId'),
        headers: _header,
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        final list = decoded is List
            ? decoded
            : (decoded['reviews'] ?? decoded['data'] ?? []);

        if (list is List) {
          for (var item in list) {
            if (item is Map<String, dynamic>) {
              reviews.add(ReviewModel.fromJson(item));
            } else if (item is Map) {
              reviews.add(ReviewModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("MongoDB reviews fetch error: $e");
    }

    // 2. Fallback: Check Firestore if MongoDB had no reviews or was unreachable
    if (reviews.isEmpty) {
      try {
        final querySnapshot = await _firestore
            .collection('reviews')
            .where('productId', isEqualTo: cleanId)
            .get()
            .timeout(const Duration(seconds: 4));

        for (var doc in querySnapshot.docs) {
          final data = doc.data();
          data['id'] = doc.id;
          reviews.add(ReviewModel.fromJson(data));
        }
      } catch (e) {
        if (kDebugMode) debugPrint("Firestore reviews fetch fallback error: $e");
      }
    }

    // Sort newest first (only real reviews, zero dummy/seed data)
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  /// Post a new public review (Saved to MongoDB and Firestore)
  static Future<ReviewModel?> postReview({
    required String productId,
    required String userName,
    String? userPhone,
    required double rating,
    required String comment,
    required List<String> images,
  }) async {
    final cleanId = productId.replaceAll(RegExp(r'[^\w-]'), '').trim();
    final now = DateTime.now();

    final payload = {
      'productId': cleanId,
      'userName': userName.trim().isNotEmpty ? userName.trim() : 'Verified Buyer',
      'userPhone': userPhone ?? '',
      'rating': rating,
      'comment': comment.trim(),
      'images': images,
      'createdAt': now.toIso8601String(),
    };

    String docId = 'rev_${now.millisecondsSinceEpoch}';

    // 1. Primary: Save directly to MongoDB Database via Backend REST API
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/reviews'),
        headers: _header,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map && decoded['review'] is Map) {
          final revMap = decoded['review'];
          if (revMap['id'] != null) {
            docId = revMap['id'].toString();
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint("MongoDB review POST error: $e");
    }

    // 2. Secondary: Sync to Firestore for real-time listener fallback
    try {
      final docRef = await _firestore.collection('reviews').add({
        ...payload,
        'mongoId': docId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (docId.startsWith('rev_')) {
        docId = docRef.id;
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Firestore review write error: $e");
    }

    return ReviewModel(
      id: docId,
      productId: cleanId,
      userName: payload['userName'].toString(),
      userPhone: userPhone,
      rating: rating,
      comment: comment.trim(),
      images: images,
      createdAt: now,
    );
  }
}
