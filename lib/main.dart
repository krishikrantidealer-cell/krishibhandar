import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'package:kisan_sewa_kendra/controller/pref.dart';
import 'package:kisan_sewa_kendra/services/attribution_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';

import 'controller/constants.dart';
import 'firebase_options.dart';
import 'utils/meta_events.dart';
import 'utils/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'controller/language_controller.dart';
import 'view/splash_screen.dart';
import 'view/product_view.dart';
import 'view/collection_view.dart';
import 'view/cart_view.dart';
import 'view/home_view.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

//this is the dev branch
void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 1. Lightweight critical setup ONLY
  PaintingBinding.instance.imageCache.maximumSizeBytes = 8 * 1024 * 1024; // 8 MB
  PaintingBinding.instance.imageCache.maximumSize = 15; // 15 images

  // 7. Always run the app
  runApp(MyApp(languageController: Constants.languageController));
}

void _initDeepLinks() {
  final appLinks = AppLinks();

  // Listen to incoming links while app is open
  appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri);
  }, onError: (err) {
    debugPrint("Deep Link Stream Error: $err");
  });

  // Handle link that opened the app from terminated state
  appLinks.getInitialLink().then((uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }).catchError((err) {
    debugPrint("Deep Link Initial Link Error: $err");
  });
}

void _handleDeepLink(Uri uri) {
  debugPrint("🔗 Received Deep Link: $uri");

  // 1. Parse UTM parameters
  final queryParams = uri.queryParameters;
  if (queryParams.isNotEmpty) {
    AttributionService().saveAttributionFromMap(queryParams);
  }

  // 2. Route Navigation
  // Scheme can be 'krishibhandar' or 'https'/'http'
  final pathSegments = uri.pathSegments;
  final host = uri.host;

  String? route;
  String? parameter;

  if (uri.scheme == 'krishibhandar') {
    route = host;
    if (pathSegments.isNotEmpty) {
      parameter = pathSegments.first;
    }
  } else if (uri.scheme == 'https' || uri.scheme == 'http') {
    if (pathSegments.isNotEmpty) {
      route = pathSegments.first;
      if (pathSegments.length > 1) {
        parameter = pathSegments[1];
      }
    }
  }

  if (route != null) {
    switch (route) {
      case 'product':
        if (parameter != null) {
          navigatorKey.currentState?.pushNamed('/product/$parameter');
        }
        break;
      case 'category':
        if (parameter != null) {
          navigatorKey.currentState?.pushNamed('/category/$parameter');
        }
        break;
      case 'offer':
        navigatorKey.currentState?.pushNamed('/offers');
        break;
      case 'cart':
        navigatorKey.currentState?.pushNamed('/cart');
        break;
      default:
        break;
    }
  }
}

class MyApp extends StatelessWidget {
  final LanguageController languageController;
  const MyApp({super.key, required this.languageController});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: languageController,
      builder: (context, child) {
        return MaterialApp(
          title: Constants.title,
          debugShowCheckedModeBanner: false,
          locale: languageController.locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('hi'),
            Locale('te'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Constants.baseColor),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
            textTheme: GoogleFonts.interTextTheme().copyWith(
              displayLarge: GoogleFonts.outfit(fontWeight: FontWeight.w900),
              displayMedium: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              displaySmall: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              headlineLarge: GoogleFonts.outfit(fontWeight: FontWeight.w800),
              headlineMedium: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              headlineSmall: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.w700),
              titleMedium: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              titleSmall: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: Constants.baseColor,
              unselectedItemColor: Colors.grey,
              showUnselectedLabels: true,
              elevation: 10,
              type: BottomNavigationBarType.fixed,
            ),
            cardTheme: const CardThemeData(
              elevation: 5,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            appBarTheme: AppBarTheme(
              foregroundColor: Constants.baseColor,
              backgroundColor: Colors.white,
            ),
          ),
          navigatorKey: navigatorKey,
          onGenerateRoute: (settings) {
            final name = settings.name ?? '';
            if (name.startsWith('/product/')) {
              final id = name.replaceFirst('/product/', '');
              return MaterialPageRoute(
                builder: (context) => ProductView(id: id),
              );
            }
            if (name.startsWith('/category/')) {
              final id = name.replaceFirst('/category/', '');
              return MaterialPageRoute(
                builder: (context) => CollectionView(collectionId: id),
              );
            }
            if (name == '/cart') {
              return MaterialPageRoute(
                builder: (context) => const CartView(),
              );
            }
            if (name == '/home') {
              return MaterialPageRoute(
                builder: (context) => const MyHomePage(),
              );
            }
            // Add other routes as needed
            return null;
          },
          home: const SplashScreen(),
        );
      },
    );
  }
}
