import 'package:cached_network_image_plus/widgets/shimmer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';

import '../controller/language_controller.dart';
import '../controller/cart_controller.dart';
import '../model/localization_model.dart';
import '../services/api_service.dart';
import 'pref.dart';

class Constants {
  static final LanguageController languageController = LanguageController();
  static final CartController cartController = CartController();
  static String cdnUrl =
      "https://storage.googleapis.com/bhandar-product-images/";
  static String inr = "₹", title = "Krishi Bhandar";
  static Color baseColor = const Color(0xff26842c);
  static String razorpayKey = dotenv.get('RAZORPAY_KEY', fallback: "");

  static String lang = 'EN';
  static String payOnlineDiscountCode = "PAYONLINE60";
  static double payOnlineDiscountAmount = 60.0;
  static List<Map<String, String>> circles = [],
      homeScreenCatBanners = [
        {
          "id": "6a3935cebd6e0cfbef015a5f",
          "title": "Insecticides",
          "subtitle": "Protect crops from insects",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Insecticides_1782219848442_full.webp",
          "color": "#f0f4ff",
        },
        {
          "id": "6a3935cebd6e0cfbef015a5d",
          "title": "Fungicides",
          "subtitle": "Advanced disease control",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fungicides_1782219847975_full.webp",
          "color": "#f9f0ff",
        },
        {
          "id": "6a3935cebd6e0cfbef015a60",
          "title": "PGRs & Growth Promoters",
          "subtitle": "Faster and healthier growth",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp",
          "color": "#f0fcff",
        },
        {
          "id": "6a3935cebd6e0cfbef015a63",
          "title": "Bio Fertilizers",
          "subtitle": "Better nutrition for crops",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp",
          "color": "#f0fff4",
        },
        {
          "id": "6a3935cebd6e0cfbef015a5e",
          "title": "Herbicides",
          "subtitle": "Effective weed management",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Bio_Nematicide_1782219846072_full.webp",
          "color": "#fff0f0",
        },
        {
          "id": "6a3935cebd6e0cfbef015a69",
          "title": "NPK Fertilizers",
          "subtitle": "Water soluble plant nutrition",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp",
          "color": "#eef9f2",
        },
        {
          "id": "6a3935cebd6e0cfbef015a65",
          "title": "Micronutrients",
          "subtitle": "Essential trace elements for yield",
          "image":
              "https://storage.googleapis.com/bhandar-product-images/banners/category/Micronutrients_1782219847036_full.webp",
          "color": "#fff9f0",
        },
      ],
      cropsList = [];
  static List<LocalizationModel> languageList = [];

  static Widget shimmer({double? height, double? width}) => ShimmerWidget(
        shimmerDirection: ShimmerDirection.ltr,
        shimmerDuration: const Duration(milliseconds: 1500),
        baseColor: const Color.fromRGBO(64, 64, 64, 0.5),
        highlightColor: const Color.fromRGBO(166, 166, 166, 1.0),
        backColor: const Color.fromRGBO(217, 217, 217, 0.5),
        height: height,
        width: width,
      );

  static Widget shimmerText({int lines = 1}) => Column(
        children: [
          for (int i = 0; i < lines; i++) ...[
            shimmer(height: 15),
            if (i - 1 < lines) ...[
              const SizedBox(
                height: 5,
              ),
            ],
          ],
        ],
      );

  static Color stringToColor({required String color}) =>
      Color(int.parse(color.replaceFirst('#', '0XFF')));

  static Future<void> fetchRemoteConfig(
    BuildContext? context,
  ) async {
    try {
      languageList = [
        LocalizationModel(name: 'English', iso: 'EN'),
        LocalizationModel(name: 'हिंदी', iso: 'HI'),
        LocalizationModel(name: 'తెలుగు', iso: 'TE'),
      ];

      lang = (await Pref.getPref(PrefKey.lang)) ?? "EN";

      // Fetch dynamic banners from backend if available
      try {
        final catBanners = await ApiService.getBanners(type: 'category');
        if (catBanners.isNotEmpty) {
          homeScreenCatBanners = catBanners.map((b) => {
            "id": (b['_id'] ?? b['id'] ?? '').toString(),
            "image": (b['imageUrl'] ?? b['image'] ?? '').toString(),
            "color": (b['color'] ?? '#f0f4ff').toString(),
          }).toList();
        }
      } catch (_) {}

      // Validate default online discount from backend
      try {
        final disc = await ApiService.validateCoupon(payOnlineDiscountCode);
        if (disc != null) {
          payOnlineDiscountAmount = (disc['value'] ?? disc['discountValue'] ?? 60.0).toDouble();
        }
      } catch (_) {}
    } catch (e) {
      debugPrint("Failed to fetch remote config: $e");
    }
  }
}
