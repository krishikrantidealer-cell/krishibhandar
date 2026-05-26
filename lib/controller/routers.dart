import 'package:flutter/material.dart';
import '../view/splash_screen.dart';
import '../view/product_view.dart';
import '../view/collection_view.dart';

class Routers {
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
      case '/':
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
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
