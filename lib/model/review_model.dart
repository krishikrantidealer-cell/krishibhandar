import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String productId;
  final String userName;
  final String? userPhone;
  final double rating;
  final String comment;
  final List<String> images;
  final DateTime createdAt;

  ReviewModel({
    required this.id,
    required this.productId,
    required this.userName,
    this.userPhone,
    required this.rating,
    required this.comment,
    required this.images,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'userName': userName,
        'userPhone': userPhone,
        'rating': rating,
        'comment': comment,
        'images': images,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['createdAt'] is Timestamp) {
      parsedDate = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      parsedDate = DateTime.tryParse(json['createdAt']) ?? DateTime.now();
    } else if (json['created_at'] is String) {
      parsedDate = DateTime.tryParse(json['created_at']) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    List<String> imageList = [];
    if (json['images'] is List) {
      imageList = (json['images'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    double parsedRating = 5.0;
    if (json['rating'] is num) {
      parsedRating = (json['rating'] as num).toDouble();
    } else if (json['rating'] != null) {
      parsedRating = double.tryParse(json['rating'].toString()) ?? 5.0;
    }

    return ReviewModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      productId: (json['productId'] ?? json['product_id'] ?? '').toString(),
      userName: (json['userName'] ?? json['user_name'] ?? json['name'] ?? 'Farmer Customer').toString(),
      userPhone: json['userPhone']?.toString() ?? json['phone']?.toString(),
      rating: parsedRating.clamp(1.0, 5.0),
      comment: (json['comment'] ?? json['description'] ?? json['review'] ?? '').toString(),
      images: imageList,
      createdAt: parsedDate,
    );
  }
}
