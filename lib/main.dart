import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:kisan_sewa_kendra/services/attribution_service.dart';
import 'package:kisan_sewa_kendra/controller/pref.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';

import 'controller/constants.dart';
import 'controller/routers.dart';
import 'firebase_options.dart';
import 'utils/notification_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'controller/language_controller.dart';
import 'view/splash_screen.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global persistent instance and state for deep link lifecycle & duplicate protection
final _appLinks = AppLinks();
Uri? _lastProcessedUri;
DateTime? _lastProcessedTime;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.firebaseMessagingBackgroundHandler(message);
}

//this is the dev branch
void main() {
  // Disable runtime fetching only in release mode for stability.
  // This allows debugging with auto-downloaded fonts while ensuring 
  // the App Store version only uses bundled assets.
  if (kReleaseMode) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  runZonedGuarded(() async {
    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // 0. Pre-Flight Configuration (Must be before ANY widget builds)
    try {
      await Future.wait([
        dotenv.load(fileName: ".env"),
        Pref.ensureInitialized(),
      ]).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("CRITICAL: Pre-flight initialization failed: $e");
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 1. Lightweight critical setup ONLY
    PaintingBinding.instance.imageCache.maximumSizeBytes = 8 * 1024 * 1024; // 8 MB
    PaintingBinding.instance.imageCache.maximumSize = 15; // 15 images

    // 7. Always run the app
    _initDeepLinks();
    runApp(MyApp(languageController: Constants.languageController));
  }, (error, stack) {
    debugPrint("CRITICAL MAIN ERROR: $error");
    debugPrint(stack.toString());
  });
}

void _initDeepLinks() {
  // 1. Warm Start Listener (App already running in background/foreground)
  _appLinks.uriLinkStream.listen((uri) {
    _handleDeepLink(uri, isColdStart: false);
  }, onError: (err) {
    debugPrint("❌ Deep Link Stream Error: $err");
  });

  // 2. Cold Start (App launched via deep link from terminated state)
  // A 500ms delay ensures the Flutter Engine and Platform Channels are fully 
  // connected before we query the platform for the initial intent.
  Future.delayed(const Duration(milliseconds: 500), () async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri, isColdStart: true);
      }
    } catch (err) {
      debugPrint("❌ Deep Link Initial Link Error: $err");
    }
  });
}

void _handleDeepLink(Uri uri, {bool isColdStart = false}) {
  final now = DateTime.now();
  
  // Duplicate Protection: Prevent processing the same URI within a 2-second window
  // (e.g. if platform delivers intent through both getInitialLink and uriLinkStream)
  if (_lastProcessedUri == uri && 
      _lastProcessedTime != null && 
      now.difference(_lastProcessedTime!).inSeconds < 2) {
    return;
  }
  
  _lastProcessedUri = uri;
  _lastProcessedTime = now;

  if (kDebugMode) {
    debugPrint("🔗 [DeepLink] ${isColdStart ? 'Cold' : 'Warm'} Start Detected");
    debugPrint("🧪 [Forensic] Scheme: ${uri.scheme}, Host: ${uri.host}, Path: ${uri.path}");
    debugPrint("🧪 [Forensic] Query Keys: ${uri.queryParameters.keys.toList()}");
  }

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
            platform: TargetPlatform.iOS, // Force iOS style behaviors
            // Fallback font to prevent crashes if GoogleFonts fails to load
            fontFamily: 'Roboto', 
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
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
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
          onGenerateRoute: Routers.generateRoute,
          home: const SplashScreen(),
        );
      },
    );
  }
}
