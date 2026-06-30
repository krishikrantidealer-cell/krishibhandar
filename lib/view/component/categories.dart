import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/network_image.dart';
import '../../controller/constants.dart';
import '../../model/categories_model.dart';
import '../../shopify/shopify.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import '../collection_view.dart';

class Categories extends StatefulWidget {
  const Categories({super.key});

  @override
  State<Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories>
    with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _init);
    Constants.languageController.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    Constants.languageController.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      _init();
    }
  }

  List<CategoriesModel> _categories = [];
  bool _isLoading = true;

  Future<void> _init({bool isRefresh = false}) async {
    if (!mounted) return;
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    final all = await Shopify.getCategories(context);

    final filtered = all.where((cat) {
      final handle = cat.handle.toLowerCase().trim();
      final hasImage = cat.image.isNotEmpty;

      final isNotHomePage = handle != "home-page" && handle != "frontpage";
      final isNotHydroponics = !handle.contains('hydroponics');
      final isNotSale =
          !handle.contains('sale') && !handle.contains('republic-day');
      final isNotBanner =
          !handle.contains('banner') && !handle.contains('best-seller');

      return hasImage &&
          isNotHomePage &&
          isNotHydroponics &&
          isNotSale &&
          isNotBanner;
    }).toList();

    if (mounted) {
      setState(() {
        _categories = filtered;
        _isLoading = false;
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    Widget innerContent;
    if (_isLoading) {
      innerContent = _buildShimmerGrid();
    } else if (_categories.isEmpty) {
      innerContent = const Center(
        child: Text("No categories found."),
      );
    } else {
      innerContent = Column(
        children: [
          // --- MODERN REFINED HEADER ---
          Container(
            height: 100,
            width: double.infinity,
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)!.categories,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "Explore Agricultural Products",
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- REFRESHABLE GRID ---
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF26842c),
              backgroundColor: Colors.white,
              onRefresh: () => _init(isRefresh: true),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final category = _categories[index];
                          return TweenAnimationBuilder<double>(
                            duration:
                                Duration(milliseconds: 250 + (index * 20)),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOutCubic,
                            child: _buildCategoryCard(category),
                            builder: (context, value, child) {
                              return Transform.translate(
                                offset: Offset(0, 15 * (1 - value)),
                                child: Opacity(
                                  opacity: value,
                                  child: child,
                                ),
                              );
                            },
                          );
                        },
                        childCount: _categories.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xffF9FBF9),
        body: Stack(
          children: [
            _buildBackgroundDecor(),
            innerContent,
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundDecor() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: 150,
            right: -100,
            child: _blurCircle(300, const Color(0xFF1E88E5).withOpacity(0.02)),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _blurCircle(250, const Color(0xFF2E7D32).withOpacity(0.02)),
          ),
          Positioned(
            top: 450,
            left: -50,
            child: _blurCircle(200, const Color(0xFF0F9D8A).withOpacity(0.02)),
          ),
        ],
      ),
    );
  }

  Widget _blurCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildCategoryCard(CategoriesModel category) {
    return _PremiumCategoryCard(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 250),
            pageBuilder: (context, animation, secondaryAnimation) =>
                CollectionView(
              collectionId: category.id.toString(),
              title: category.title,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      image: category.image,
      title: category.title,
    );
  }

  Widget _buildShimmerGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Refined Shimmer Header
        Container(
          height: 100,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Constants.shimmer(height: 20, width: 140),
                const SizedBox(height: 6),
                Constants.shimmer(height: 10, width: 100),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
              childAspectRatio: 0.82,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white,
                  boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 82,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9FAFB),
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        child: Constants.shimmer(),
                      ),
                    ),
                    Expanded(
                      flex: 18,
                      child: Center(
                        child: Constants.shimmer(height: 10, width: 60),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PremiumCategoryCard extends StatefulWidget {
  final VoidCallback onTap;
  final String image;
  final String title;

  const _PremiumCategoryCard({
    required this.onTap,
    required this.image,
    required this.title,
  });

  @override
  State<_PremiumCategoryCard> createState() => _PremiumCategoryCardState();
}

class _PremiumCategoryCardState extends State<_PremiumCategoryCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IMAGE SECTION (82%)
              Expanded(
                flex: 82,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF9FAFB),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(0.0), // Micro-adjustment for 2-3% larger visual image
                      child: KskNetworkImage(
                        widget.image,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              // EXPLORE SECTION (18%)
              Expanded(
                flex: 18,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Explore",
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: Color(0xFF2E7D32),
                        ),
                      ],
                    ),
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
