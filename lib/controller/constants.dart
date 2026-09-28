import 'package:cached_network_image_plus/widgets/shimmer_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shimmer/shimmer.dart';

import '../controller/language_controller.dart';
import '../controller/cart_controller.dart';
import '../controller/auth_controller.dart';
import '../model/localization_model.dart';
import '../services/bhandar_api_service.dart';
import 'pref.dart';

class Constants {
  static final LanguageController languageController = LanguageController();
  static final CartController cartController = CartController();
  static final AuthController authController = AuthController.instance;
  static String cdnUrl = "";
  static String inr = "₹", title = "Krishi Bhandar";
  static Color baseColor = const Color(0xff26842c);
  static String get apiBaseUrl {
    try {
      if (dotenv.isInitialized) {
        return dotenv.get(
          'API_BASE_URL',
          fallback: "https://backend-bhandar-205278744741.asia-south1.run.app",
        );
      }
    } catch (_) {}
    return "https://backend-bhandar-205278744741.asia-south1.run.app";
  }

  static String get razorpayKey {
    try {
      if (dotenv.isInitialized) {
        return dotenv.get('RAZORPAY_KEY', fallback: "");
      }
    } catch (_) {}
    return "";
  }

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

  static Future<void> fetchRemoteConfig([
    BuildContext? context,
  ]) async {
    try {
      languageList = [
        LocalizationModel(name: 'हिंदी', iso: 'HI'),
        LocalizationModel(name: 'English', iso: 'EN'),
        LocalizationModel(name: 'తెలుగు', iso: 'TE'),
        LocalizationModel(name: 'मराठी', iso: 'MR'),
        LocalizationModel(name: 'தமிழ்', iso: 'TA'),
      ];

      lang = (await Pref.getPref(PrefKey.lang).timeout(const Duration(seconds: 2))) ?? "EN";

      final disc =
          await BhandarApiService.validateDiscountCode(code: payOnlineDiscountCode).timeout(const Duration(seconds: 5));
      if (disc != null && disc['value'] != null) {
        payOnlineDiscountAmount = (disc['value'] as num).toDouble();
      }
    } catch (e) {
      debugPrint("Failed to fetch remote config: $e");
    }
  }
}
