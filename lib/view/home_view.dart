import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/components/cart_summary_bar.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'package:kisan_sewa_kendra/view/support_view.dart';
import 'package:kisan_sewa_kendra/view/policy_pages.dart';

import '../components/ksk_appbar.dart';
import '../controller/constants.dart';
import '../controller/routers.dart';
import '../generated/assets.dart';
import 'component/home.dart';
import 'component/categories.dart';
import 'order_view.dart';
import 'cart_view.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  bool _isDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    await Constants.fetchRemoteConfig(context);
    if (mounted) {
      setState(() {
        _isDataLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          return false; // Prevent pop, stay in app
        }
        return true; // Allow pop, exit app
      },
      child: Scaffold(
        backgroundColor: const Color(0xffF9FBF9),
        extendBodyBehindAppBar: false,
        appBar: _currentIndex == 0 ? const KskAppbar() : null,
        drawer: _buildModernDrawer(context),
        body: !_isDataLoaded
            ? AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            : Stack(
                children: [
                  IndexedStack(
                    index: _currentIndex,
                    children: [
                      Home(scrollController: _scrollController),
                      const Categories(),
                      const OrderView(),
                      SupportView(
                        onBack: () {
                          setState(() {
                            _currentIndex = 0;
                          });
                        },
                      ),
                    ],
                  ),
                  const Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CartSummaryBar(),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, -2))
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double itemWidth = constraints.maxWidth / 4;
                  return Stack(
                    children: [
                      // Animated Active Pill
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        left: itemWidth * _currentIndex,
                        width: itemWidth,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1E88E5), // Premium Blue
                                Color(0xFF0F9D8A), // Teal Bridge
                                Color(0xFF2E7D32), // Agri Green
                              ],
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Navigation Items
                      Row(
                        children: [
                          _buildNavItem(
                              0,
                              FontAwesomeIcons.house,
                              AppLocalizations.of(context)!.home),
                          _buildNavItem(
                              1,
                              FontAwesomeIcons.list,
                              AppLocalizations.of(context)!.categories),
                          _buildNavItem(
                              2,
                              FontAwesomeIcons.bagShopping,
                              AppLocalizations.of(context)!.myOrders),
                          _buildNavItem(
                              3,
                              FontAwesomeIcons.headset,
                              AppLocalizations.of(context)!.support),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, dynamic icon, String label) {
    bool isSelected = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_currentIndex != index) {
            HapticFeedback.lightImpact();
            setState(() => _currentIndex = index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: FaIcon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.grey[500],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      width: MediaQuery.of(context).size.width * 0.82,
      child: Column(
        children: [
          // Header Section - Responsive
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E88E5), // Premium Blue
                  Color(0xFF2E7D32), // Agri Green
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Subtle Decorative Circle 1
                Positioned(
                  top: -30,
                  right: -30,
                  child: Container(
                    height: 140,
                    width: 140,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Subtle Decorative Circle 2
                Positioned(
                  bottom: -20,
                  left: -10,
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo Glass Card
                        const AnimatedDrawerLogo(),
                        const SizedBox(height: 20),
                        // App Branding
                        Text(
                          "Krishi Bhandar",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "हर किसान की पहचान !",
                          style: GoogleFonts.outfit(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              children: [
                _buildSectionHeader(AppLocalizations.of(context)!.menu),
                _drawerItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    title: AppLocalizations.of(context)!.home,
                    isSelected: _currentIndex == 0,
                    onTap: () => Navigator.pop(context)),
                _drawerItem(
                    icon: Icons.grid_view_outlined,
                    activeIcon: Icons.grid_view_rounded,
                    title: AppLocalizations.of(context)!.categories,
                    isSelected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 1);
                    }),
                _drawerItem(
                    icon: Icons.shopping_bag_outlined,
                    activeIcon: Icons.shopping_bag_rounded,
                    title: AppLocalizations.of(context)!.myOrders,
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 2);
                    }),
                _drawerItem(
                    icon: Icons.shopping_cart_outlined,
                    activeIcon: Icons.shopping_cart_rounded,
                    title: AppLocalizations.of(context)!.myCart,
                    onTap: () {
                      Navigator.pop(context);
                      Routers.goTO(context, toBody: const CartView());
                    }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
                _buildSectionHeader(AppLocalizations.of(context)!.support),
                _drawerItem(
                    icon: Icons.contact_support_outlined,
                    activeIcon: Icons.contact_support_rounded,
                    title: AppLocalizations.of(context)!.contactUs,
                    isSelected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = 3);
                    }),
                _drawerItem(
                    icon: Icons.privacy_tip_outlined,
                    title: AppLocalizations.of(context)!.privacyPolicy,
                    onTap: () {
                      Navigator.pop(context);
                      Routers.goTO(context,
                          toBody: PolicyPage(
                              title:
                                  AppLocalizations.of(context)!.privacyPolicy,
                              content: PolicyContent.privacyPolicy));
                    }),
                _drawerItem(
                    icon: Icons.local_shipping_outlined,
                    title: AppLocalizations.of(context)!.shippingPolicy,
                    onTap: () {
                      Navigator.pop(context);
                      Routers.goTO(context,
                          toBody: PolicyPage(
                              title:
                                  AppLocalizations.of(context)!.shippingPolicy,
                              content: PolicyContent.shippingPolicy));
                    }),
                _drawerItem(
                    icon: Icons.rule_rounded,
                    title: AppLocalizations.of(context)!.termsConditions,
                    onTap: () {
                      Navigator.pop(context);
                      Routers.goTO(context,
                          toBody: PolicyPage(
                              title:
                                  AppLocalizations.of(context)!.termsConditions,
                              content: PolicyContent.termsConditions));
                    }),
              ],
            ),
          ),

          // Footer info
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFF0F0F0)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "KrishiBhandar v3.0.0",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.eco_rounded,
                      color: Constants.baseColor.withOpacity(0.15),
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.madeWithHeartForFarmers,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, top: 10, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    IconData? activeIcon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? Constants.baseColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border(
                    left: BorderSide(color: Constants.baseColor, width: 3.5),
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Constants.baseColor.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? (activeIcon ?? icon) : icon,
                size: 20,
                color: isSelected ? Constants.baseColor : Colors.grey[600],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.2,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Constants.baseColor : Colors.black87,
                  ),
                ),
              ),
              if (!isSelected)
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.grey[300],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedDrawerLogo extends StatefulWidget {
  final double size;
  const AnimatedDrawerLogo({super.key, this.size = 58});

  @override
  State<AnimatedDrawerLogo> createState() => _AnimatedDrawerLogoState();
}

class _AnimatedDrawerLogoState extends State<AnimatedDrawerLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.05)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Image.asset(
          Assets.assetsLogo,
          height: widget.size,
          width: widget.size,
        ),
      ),
    );
  }
}
