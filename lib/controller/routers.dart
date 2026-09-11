import 'package:flutter/material.dart';
import '../view/splash_screen.dart';
import '../view/auth/login_view.dart';
import '../view/auth/complete_profile_view.dart';
import '../view/home_view.dart';
import '../view/cart_view.dart';
import '../view/product_view.dart';
import '../view/collection_view.dart';
import '../view/checkout/checkout_view.dart';
import '../view/checkout/address_view.dart';
import '../view/checkout/coupons_view.dart';
import '../view/order_detail_view.dart';
import '../view/policy_pages.dart';
import '../model/order_model.dart';

import 'cart_controller.dart';

class Routers {
  static Future<dynamic> goTO(BuildContext context, {required Widget toBody}) =>
      Navigator.push(
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

  static Future<dynamic> goToLogin(BuildContext context) =>
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );

  static Future<dynamic> goToCompleteProfile(
    BuildContext context, {
    required String phone,
    String? customerId,
    String? name,
  }) =>
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => CompleteProfileView(
            phone: phone,
            customerId: customerId,
            name: name,
          ),
        ),
        (route) => false,
      );

  static Future<dynamic> goToHome(BuildContext context) =>
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
        (route) => false,
      );

  // ─── Typed Destination Helpers ───────────────────────────────────────────
  static Future<dynamic> toProduct(BuildContext context, String productId) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductView(id: productId),
        ),
      );

  static Future<dynamic> toCategory(BuildContext context, String categoryId) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CollectionView(collectionId: categoryId),
        ),
      );

  static Future<dynamic> toCart(BuildContext context) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CartView(),
        ),
      );

  static Future<dynamic> toCheckout(
    BuildContext context, {
    List<CartItem>? cartItems,
    double? totalAmount,
    Map<String, dynamic>? selectedAddress,
    String? couponCode,
    double discountAmount = 0.0,
  }) {
    final items = cartItems ?? CartController.instance.items;
    final total = totalAmount ?? CartController.instance.totalAmount;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutView(
          cartItems: items,
          totalAmount: total,
          shippingAddress: selectedAddress,
          couponCode: couponCode,
          discountAmount: discountAmount,
        ),
      ),
    );
  }

  static Future<dynamic> toCoupons(
    BuildContext context, {
    double? subtotal,
    int? totalItems,
  }) {
    final amount = subtotal ?? CartController.instance.totalAmount;
    final count = totalItems ?? CartController.instance.itemCount;
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CouponsView(
          subtotal: amount,
          totalItems: count,
        ),
      ),
    );
  }

  static Future<dynamic> toAddress(BuildContext context) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AddressView(),
        ),
      );

  static Future<dynamic> toOrderDetail(
    BuildContext context,
    OrderModel order,
  ) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailView(order: order),
        ),
      );

  static Future<dynamic> toPolicy(
    BuildContext context, {
    required String title,
    required String content,
  }) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PolicyPage(title: title, content: content),
        ),
      );

  // ─── Named Route Generator ───────────────────────────────────────────────
  static Route<dynamic> generateRoute(RouteSettings settings) {
    final name = settings.name ?? '';

    switch (name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginView());

      case '/home':
        return MaterialPageRoute(builder: (_) => const MyHomePage());

      case '/cart':
        return MaterialPageRoute(builder: (_) => const CartView());

      // Dynamic Product Route
      case String n when n.startsWith('/product/'):
        final productId = n.split('/').last;
        return MaterialPageRoute(
          builder: (_) => ProductView(id: productId),
        );

      // Dynamic Category Route
      case String n when n.startsWith('/category/'):
        final categoryId = n.split('/').last;
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

  static void goBack(BuildContext context, [dynamic result]) => Navigator.pop(
        context,
        result,
      );
}
