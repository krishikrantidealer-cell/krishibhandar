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
      homeScreenCatBanners = [],
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
