import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:kisan_sewa_kendra/controller/auth_controller.dart';
import 'package:kisan_sewa_kendra/controller/pref.dart';
import 'package:kisan_sewa_kendra/firebase_options.dart';
import 'package:kisan_sewa_kendra/services/attribution_service.dart';
import 'package:kisan_sewa_kendra/utils/meta_events.dart';
import 'package:kisan_sewa_kendra/utils/notification_service.dart';
import 'package:kisan_sewa_kendra/view/home_view.dart';
import '../controller/constants.dart';
import '../controller/update_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _dotsController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _glowScale;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<Offset> _taglineSlide;

  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // 1. Logo Continuity - Start at 1.0 opacity
    _logoOpacity = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.linear),
      ),
    );

    _logoScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    _glowScale = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Title Sequence
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeIn),
      ),
    );

    _titleSlide =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Tagline Sequence
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeIn),
      ),
    );

    _taglineSlide =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _initApp();

    // Remove native splash as soon as first frame of Premium Splash is ready
    // and ONLY THEN start the animation for a perfect synchronized transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _controller.forward();
    });
  }

  _initApp() async {
    try {
      // Step 1: Initialize Core I/O and Firebase Core in parallel
      await Future.wait([
        dotenv.load(fileName: ".env"),
        Pref.ensureInitialized(),
        Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ),
      ]);

      // Step 2: Deferred and Parallelized Initialization
      await Future.wait([
        UpdateService.init(),
        Constants.fetchRemoteConfig(context),
        _initNonCriticalServices(),
      ]);

      final phone = await AuthController.getSavedPhone();
      final shopifyId = await AuthController.getShopifyCustomerId();
      if (phone != null &&
          phone.isNotEmpty &&
          (shopifyId == null || shopifyId.isEmpty || shopifyId == "null")) {
        AuthController.syncWithShopify(phone).catchError((e) {
          debugPrint("Splash: Auto-heal error: $e");
        });
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    }

    final updateType = await UpdateService.checkUpdateStatus();

    if (updateType == UpdateType.force && mounted) {
      UpdateService.showUpdateDialog(context, UpdateType.force);
      return;
    }

    // Phase 4: Optimized Duration (Total ~1.1s including animation)
    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() => _isExiting = true);
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MyHomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        ).then((_) {
          if (updateType == UpdateType.optional && mounted) {
            UpdateService.showUpdateDialog(context, UpdateType.optional);
          }
        });
      }
    }
  }

  Future<void> _initNonCriticalServices() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      );
      await NotificationService.init();
      await MetaEvents.init();
      await AttributionService().init();
    } catch (e) {
      debugPrint("Non-critical init error: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: _isExiting ? 0.0 : 1.0,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E88E5), // Premium Blue
                Color(0xFF0F9D8A), // Teal Bridge
                Color(0xFF2E7D32), // Agri Green
              ],
            ),
          ),
          child: Stack(
            children: [
              // --- BACKGROUND DECORATION ---
              Positioned(
                top: -size.width * 0.2,
                right: -size.width * 0.1,
                child: Container(
                  width: size.width * 0.8,
                  height: size.width * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -size.width * 0.3,
                left: -size.width * 0.2,
                child: Container(
                  width: size.width * 0.9,
                  height: size.width * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
              ),
              // Extra blurred gradient orb behind logo
              Center(
                child: Opacity(
                  opacity: 0.04,
                  child: Container(
                    width: size.width * 0.7,
                    height: size.width * 0.7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0)],
                      ),
                    ),
                  ),
                ),
              ),

              // --- MAIN CONTENT ---
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LOGO SECTION
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft expanded radial glow
                            Transform.scale(
                              scale: _glowScale.value,
                              child: Opacity(
                                opacity: _logoOpacity.value * 0.12,
                                child: Container(
                                  width: size.width * 0.5,
                                  height: size.width * 0.5,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            // The Hero Logo
                            Transform.scale(
                              scale: _logoScale.value,
                              child: Opacity(
                                opacity: _logoOpacity.value,
                                child: Image.asset(
                                  'assets/logo_splash.png',
                                  width: size.width * 0.45, // HERO size (+18%)
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32), // Reduced spacing
                        // BRAND TITLE
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: const Text(
                              "Krishi Bhandar",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40, // Increased size
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8, // Tighter
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // TAGLINE
                        FadeTransition(
                          opacity: _taglineOpacity,
                          child: SlideTransition(
                            position: _taglineSlide,
                            child: Text(
                              "हर किसान की पहचान !",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 18, // Increased size
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // --- BOTTOM LOADING INDICATOR ---
              Positioned(
                bottom: size.height * 0.08,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedBuilder(
                    animation: _dotsController,
                    builder: (context, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          double delay = index * 0.2;
                          double dotValue =
                              ((_dotsController.value + delay) % 1.0);
                          double opacity = dotValue < 0.5
                              ? (dotValue * 2)
                              : (1.0 - (dotValue - 0.5) * 2);

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(opacity * 0.75),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
