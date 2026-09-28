import 'package:flutter/material.dart';
import '../view/splash_screen.dart';
import '../view/product_view.dart';
import '../view/collection_view.dart';
import '../view/admin/admin_login_view.dart';
import '../view/admin/admin_dashboard_view.dart';
import '../view/admin/notification_form_view.dart';
import '../view/admin/schedule_list_view.dart';
import '../view/auth/phone_login_view.dart';
import '../view/auth/complete_profile_view.dart';
import '../view/home_view.dart';
import '../view/cart_view.dart';
import '../view/order_view.dart';
import '../view/support_view.dart';

class Routers {
  static const String root = '/';
  static const String home = '/home';
  static const String phoneLogin = '/auth/login';
  static const String completeProfile = '/auth/complete-profile';
  static const String cart = '/cart';
  static const String orders = '/orders';
  static const String support = '/support';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminNotificationForm = '/admin/notification/form';
  static const String adminSchedules = '/admin/schedules';

  static Future<dynamic> goTO(BuildContext context, {required Widget toBody}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => toBody,
        ),
      );

  static Future<dynamic> goNoBack(BuildContext context, {required Widget toBody}) =>
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => toBody,
        ),
      );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;
    final uri = Uri.parse(settings.name ?? '/');
    final segments = uri.pathSegments;

    // 1. Static Root Routes
    switch (uri.path) {
      case root:
        return MaterialPageRoute(builder: (_) => const SplashScreen(), settings: settings);
      case phoneLogin:
        return MaterialPageRoute(builder: (_) => const PhoneLoginView(), settings: settings);
      case completeProfile:
        return MaterialPageRoute(
          builder: (_) => CompleteProfileView(
            phone: args is String ? args : null,
            isEditing: args is Map && (args['isEditing'] == true),
            canSkip: args is Map ? (args['canSkip'] ?? false) : false,
          ),
          settings: settings,
        );
      case home:
        return MaterialPageRoute(builder: (_) => const MyHomePage(), settings: settings);
      case cart:
        return MaterialPageRoute(builder: (_) => const CartView(), settings: settings);
      case orders:
        return MaterialPageRoute(builder: (_) => const OrderView(), settings: settings);
      case support:
        return MaterialPageRoute(builder: (_) => const SupportView(), settings: settings);
      case adminLogin:
        return MaterialPageRoute(builder: (_) => const AdminLoginView(), settings: settings);
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardView(), settings: settings);
      case adminNotificationForm:
        final Map<String, dynamic>? data = args as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => NotificationFormView(scheduleData: data),
          settings: settings,
        );
      case adminSchedules:
        return MaterialPageRoute(builder: (_) => const ScheduleListView(), settings: settings);
    }

    // 2. Dynamic Segment-based Routes
    if (segments.isNotEmpty) {
      final firstSegment = segments.first.toLowerCase();

      // /product/:id (e.g., /product/6aa15000860da9561e509447 or /product/ebs-bio-pesticide)
      if (firstSegment == 'product' && segments.length >= 2) {
        final productId = segments[1];
        return MaterialPageRoute(
          builder: (_) => ProductView(id: productId),
          settings: settings,
        );
      }

      // /category/:id or /collection/:id
      if ((firstSegment == 'category' || firstSegment == 'collection') && segments.length >= 2) {
        final collectionId = segments[1];
        return MaterialPageRoute(
          builder: (_) => CollectionView(collectionId: collectionId),
          settings: settings,
        );
      }
    }

    // 3. Fallback Route
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text('No route defined for ${settings.name}'),
            ],
          ),
        ),
      ),
      settings: settings,
    );
  }

  static void goBack(BuildContext context) => Navigator.pop(context);
}
