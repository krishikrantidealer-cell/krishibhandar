import 'package:flutter/material.dart';
import '../view/splash_screen.dart';
import '../view/product_view.dart';
import '../view/collection_view.dart';
import '../view/admin/admin_login_view.dart';
import '../view/admin/admin_dashboard_view.dart';
import '../view/admin/notification_form_view.dart';
import '../view/admin/schedule_list_view.dart';
import '../view/home_view.dart';
import '../view/cart_view.dart';

class Routers {
  static const String root = '/';
  static const String home = '/home';
  static const String cart = '/cart';
  static const String adminLogin = '/admin/login';
  static const String adminDashboard = '/admin/dashboard';
  static const String adminNotificationForm = '/admin/notification/form';
  static const String adminSchedules = '/admin/schedules';

  static goTO(BuildContext context, {required Widget toBody}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => toBody,
        ),
      );

  static goNoBack(BuildContext context, {required Widget toBody}) =>
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => toBody,
        ),
      );

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case root:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case home:
        return MaterialPageRoute(builder: (_) => const MyHomePage());
      case cart:
        return MaterialPageRoute(builder: (_) => const CartView());
      case adminLogin:
        return MaterialPageRoute(builder: (_) => const AdminLoginView());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const AdminDashboardView());
      case adminNotificationForm:
        final Map<String, dynamic>? data = args as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => NotificationFormView(scheduleData: data),
        );
      case adminSchedules:
        return MaterialPageRoute(builder: (_) => const ScheduleListView());
      
      // Dynamic Product Route
      case String name when name.startsWith('/product/'):
        final productId = name.split('/').last;
        return MaterialPageRoute(
          builder: (_) => ProductView(id: productId),
        );

      // Dynamic Category Route
      case String name when name.startsWith('/category/'):
        final categoryId = name.split('/').last;
        return MaterialPageRoute(
          builder: (_) => CollectionView(collectionId: categoryId),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  static goBack(BuildContext context) => Navigator.pop(
        context,
      );
}
