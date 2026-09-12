import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../components/network_image.dart';
import '../../components/widget_button.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';
import '../collection_view.dart';
import '../product_view.dart';
import '../../model/categories_model.dart';
import '../../services/api_service.dart';
import '../../components/products_grid.dart';

class Home extends StatefulWidget {
  final ScrollController scrollController;

  const Home({
    super.key,
    required this.scrollController,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Static in-memory cache for instant navigation without reloading
  static List<CategoriesModel>? _cachedCategories;
  static List<CategoriesModel>? _cachedBanners;
  static List<CategoriesModel>? _cachedCategoryStripBanners;

  List<CategoriesModel> _categories = _cachedCategories ?? [];
  List<CategoriesModel> _banners = _cachedBanners ?? [];
  List<CategoriesModel> _categoryStripBanners = _cachedCategoryStripBanners ?? [];
  bool _isLoadingCats = _cachedCategories == null || _cachedCategoryStripBanners == null;
  bool _isLoadingBanners = _cachedBanners == null;

  @override
  void initState() {
    super.initState();
    _initData();
    Constants.languageController.addListener(_onLanguageChanged);
  }

  Future<void> _initData() async {
    await Future.wait([
      _fetchBanners(),
      _initCategories(),
    ]);
  }

  @override
  void dispose() {
    Constants.languageController.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      _refresh();
    }
  }

  /// Refreshes all home data simultaneously (called on pull-to-refresh)
  Future<void> _refresh() async {
    await Future.wait([
      _fetchBanners(),
      _initCategories(),
    ]);
  }

  Future<void> _fetchBanners() async {
    final homeBanners = await ApiService.getBanners(type: 'home');
    List<CategoriesModel> bannerList = [];
    if (homeBanners.isNotEmpty) {
      bannerList = homeBanners.map((e) => CategoriesModel.fromJson({
        'id': e['_id'] ?? e['id'] ?? '',
        'title': e['title'] ?? '',
        'handle': e['linkValue'] ?? e['handle'] ?? '',
        'image': e['imageUrl'] ?? e['image'] ?? '',
      })).toList();
    } else {
      bannerList = await ApiService.getBannerCollections();
    }
    _cachedBanners = bannerList;
    if (mounted) {
      setState(() {
        _banners = bannerList;
        _isLoadingBanners = false;
      });
    }
  }

  void _handleBannerClick(CategoriesModel banner) async {
    if (banner.handle.isNotEmpty) {
      if (banner.handle.startsWith('http')) {
        await launchUrlString(banner.handle, mode: LaunchMode.externalApplication);
        return;
      } else if (banner.handle.length == 24) {
        // Category ObjectId
        Routers.goTO(context, toBody: CollectionView(collectionId: banner.handle, title: banner.title));
        return;
      } else {
        await _openProduct(banner.handle);
        return;
      }
    }

    int index = _banners.indexOf(banner);
    if (index == 0) {
      await _openProduct("rakshak-novaluron-indoxacarb-sc");
    } else if (index == 1) {
      await launchUrlString(
          "https://play.google.com/store/apps/details?id=com.snss.ebs.kisan_sewa_kendra",
          mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openProduct(String handle,
      {String? fallbackCollectionId}) async {
    try {
      final product = await ApiService.getProductDetails(productId: handle);
      if (product != null && mounted) {
        Routers.goTO(context, toBody: ProductView(product: product));
        return;
      }

      final results = await ApiService.fetchSearchResults(query: handle);
      if (results.isNotEmpty && mounted) {
        final found = results.any((p) => p.handle == handle)
            ? results.firstWhere((p) => p.handle == handle)
            : results.first;
        Routers.goTO(context, toBody: ProductView(product: found));
      } else if (mounted) {
        if (fallbackCollectionId != null) {
          Routers.goTO(context,
              toBody: CollectionView(collectionId: fallbackCollectionId));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Product not available right now."),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Something went wrong. Please try again."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _initCategories() async {
    // 1. Fetch categories directly from database
    final allCategories = await ApiService.getCategoriesList();

    // 2. Fetch category strip banners directly from database
    final rawCategoryBanners = await ApiService.getBanners(type: 'category');

    List<CategoriesModel> stripBanners = [];
    if (rawCategoryBanners.isNotEmpty) {
      stripBanners = rawCategoryBanners.map((b) {
        final handle = (b['linkValue'] ?? b['handle'] ?? b['_id'] ?? b['id'] ?? '').toString();
        final id = handle;
        final title = (b['title'] ?? '').toString();
        final img = (b['imageUrl'] ?? b['image'] ?? '').toString();
        return CategoriesModel(
          id: id,
          title: _getLocalizedCategoryTitle(context, title),
          handle: handle,
          description: '',
          image: img,
        );
      }).toList();
    } else {
      // Fallback: use database categories' images
      stripBanners = allCategories.where((c) => c.image.isNotEmpty).map((c) {
        return CategoriesModel(
          id: c.id,
          title: _getLocalizedCategoryTitle(context, c.title),
          handle: c.handle,
          description: c.description,
          image: c.image,
        );
      }).toList();
    }

    // Exactly 9 distinct primary categories for the 3x3 Home grid
    const targetCategories = [
      'insecticides',
      'fungicides',
      'herbicides',
      'fertilizers',
      'pgrs',
      'bio-products',
      'micronutrients',
      'organic-fertilizers',
      'antibiotics',
    ];

    List<CategoriesModel> home9Categories = [];
    for (final target in targetCategories) {
      final match = allCategories.where((c) {
        final h = c.handle.toLowerCase().trim();
        final t = c.title.toLowerCase().trim();
        if (target == 'pgrs') {
          return h == 'pgrs' || h == 'pgr' || t == 'pgrs' || t == 'pgr';
        }
        if (target == 'bio-products') {
          return h == 'bio-products' || t == 'bio products';
        }
        if (target == 'organic-fertilizers') {
          return h == 'organic-fertilizers' ||
              h == 'organic-fertilizer' ||
              t == 'organic fertilizers';
        }
        return h == target || t == target;
      }).firstOrNull;

      if (match != null &&
          !home9Categories.any((item) => item.id == match.id)) {
        home9Categories.add(match);
      }
    }

    // Fallback: backfill with any missing categories to ensure exactly 9
    if (home9Categories.length < 9) {
      for (final cat in allCategories) {
        if (home9Categories.length >= 9) break;
        if (!home9Categories.any((c) => c.id == cat.id)) {
          home9Categories.add(cat);
        }
      }
    }

    _cachedCategories = home9Categories;
    _cachedCategoryStripBanners = stripBanners;
    if (mounted) {
      setState(() {
        _categories = home9Categories;
        _categoryStripBanners = stripBanners;
        _isLoadingCats = false;
      });
    }
  }

  String _getLocalizedCategoryTitle(BuildContext context, String title) {
    if (!mounted) return title;
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return title;
    switch (title.toLowerCase().trim()) {
      case 'pgrs':
      case 'pgr':
        return l10n.pgr;
      case 'insecticides':
      case 'insecticide':
        return l10n.insecticides;
      case 'fungicides':
      case 'fungicide':
        return l10n.fungicides;
      case 'fertilizers':
      case 'fertilizer':
        return l10n.fertilizers;
      case 'herbicides':
      case 'herbicide':
        return l10n.herbicides;
      case 'npk fertilizers':
      case 'npk fertilizer':
        return l10n.npkFertilizer;
      case 'bio-pesticides':
      case 'bio-pesticide':
        return l10n.bioPesticide;
      case 'bio-fungicide':
      case 'bio-fungicides':
        return l10n.bioFungicide;
      case 'bio-fertilizers':
      case 'bio-fertilizer':
        return l10n.bioFertilizer;
      default:
        return title;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Black icons
        statusBarBrightness: Brightness.light, // For iOS
      ),
      child: Container(
        color: const Color(0xffF9FBF9),
        child: Stack(
          children: [
            // Header Shapes (For consistency with Categories & Orders)
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Constants.baseColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 70,
              left: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Constants.baseColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            RefreshIndicator(
              color: const Color(0xFF26842c),
              onRefresh: _refresh,
              child: CustomScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 15)),

                  // --- BANNERS ---
                  SliverToBoxAdapter(
                    child: _isLoadingBanners
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Shimmer.fromColors(
                              baseColor: Colors.grey.shade100,
                              highlightColor: Colors.white,
                              child: Container(
                                height: 140,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          )
                        : _banners.isNotEmpty
                            ? Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: HomeCarousel(
                                  banners: _banners,
                                  onBannerClick: _handleBannerClick,
                                ),
                              )
                            : const SizedBox.shrink(),
                  ),

                  // --- CATEGORIES HEADER ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFF26842c),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.of(context)!.categories,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- CATEGORIES GRID ---
                  if (_isLoadingCats)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade100,
                            highlightColor: Colors.white,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          childCount: 6,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.88,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cat = _categories[index];
                            final localizedTitle =
                                _getLocalizedCategoryTitle(context, cat.title);
                            return WidgetButton(
                              onTap: () => Routers.goTO(context,
                                  toBody: CollectionView(
                                      collectionId: cat.id.toString(),
                                      title: localizedTitle)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Constants.baseColor
                                          .withValues(alpha: 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: Constants.baseColor
                                        .withValues(alpha: 0.05),
                                    width: 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: KskNetworkImage(
                                    cat.image,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: _categories.length,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // --- CATEGORY STRIP BANNERS & 4-PRODUCT GRIDS ---
                  if (_categoryStripBanners.isNotEmpty)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final banner = _categoryStripBanners[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Strip Banner
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: WidgetButton(
                                    onTap: () => Routers.goTO(
                                      context,
                                      toBody: CollectionView(
                                        collectionId: banner.id.toString(),
                                        title: banner.title,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.04),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: AspectRatio(
                                          aspectRatio: 4.8,
                                          child: KskNetworkImage(
                                            banner.image,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // 2. 4 Products Grid for this category
                                ProductsGrid(
                                  key: ValueKey('category_grid_${banner.id}'),
                                  id: banner.id.toString(),
                                  limit: 4,
                                  shrinkWrap: true,
                                ),

                                const SizedBox(height: 10),

                                // 3. View All Button
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: InkWell(
                                    onTap: () => Routers.goTO(
                                      context,
                                      toBody: CollectionView(
                                        collectionId: banner.id.toString(),
                                        title: banner.title,
                                      ),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Constants.baseColor.withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "${AppLocalizations.of(context)?.viewAll ?? 'View All'} ${banner.title}",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Constants.baseColor,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                            color: Constants.baseColor,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: _categoryStripBanners.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 10)),

                  // --- PREMIUM FOOTER ---
                  SliverToBoxAdapter(child: _buildPremiumFooter()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFooter() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _trustItem(Icons.local_shipping_outlined,
                    AppLocalizations.of(context)!.freeShipping),
                _trustItem(Icons.verified_outlined,
                    AppLocalizations.of(context)!.securePay),
                _trustItem(Icons.support_agent_rounded,
                    AppLocalizations.of(context)!.agriSupport),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              children: [
                Image.asset('assets/logo.png',
                    height: 60, opacity: const AlwaysStoppedAnimation(0.6)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () =>
                      launchUrlString("https://wa.me/919399022060"),
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: Text(AppLocalizations.of(context)!.whatsAppSupport),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    elevation: 0,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 25),
                Text(
                  "© ${DateTime.now().year} Krishi Bhandar",
                  style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Constants.baseColor),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black54)),
      ],
    );
  }
}


class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onViewAll;

  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 76, // Compact height
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFAEEA4D),
            Color(0xFF7BC943),
            Color(0xFF2E7D32),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Subtle Leaf Artwork (Bottom Right)
            Positioned(
              right: -10,
              bottom: -15,
              child: Opacity(
                opacity: 0.08,
                child: Transform.rotate(
                  angle: -0.2,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 70,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Subtle Leaf Artwork (Top Left)
            Positioned(
              left: 8,
              top: -8,
              child: Opacity(
                opacity: 0.06,
                child: Transform.rotate(
                  angle: 0.5,
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (onViewAll != null)
                    WidgetButton(
                      onTap: onViewAll!,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context)!.viewAll,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 9,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class HomeCarousel extends StatefulWidget {
  final List<CategoriesModel> banners;
  final Function(CategoriesModel) onBannerClick;

  const HomeCarousel({
    super.key,
    required this.banners,
    required this.onBannerClick,
  });

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final CarouselSliderController _controller = CarouselSliderController();
  int _carouselIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CarouselSlider(
              carouselController: _controller,
              options: CarouselOptions(
                aspectRatio: 2.6,
                viewportFraction: 1.0, // Full width slider
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 5),
                autoPlayAnimationDuration: const Duration(milliseconds: 1000),
                autoPlayCurve: Curves.easeInOutQuart,
                onPageChanged: (index, _) {
                  setState(() {
                    _carouselIndex = index;
                  });
                },
              ),
              items: widget.banners.map((banner) {
                return WidgetButton(
                  onTap: () => widget.onBannerClick(banner),
                  child: KskNetworkImage(
                    banner.image,
                    fit: BoxFit.fill,
                    width: 600,
                    height: 230,
                  ),
                );
              }).toList(),
            ),
            // Floating Indicator Dots
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.banners.asMap().entries.map((entry) {
                  bool isActive = _carouselIndex == entry.key;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isActive ? 18.0 : 6.0,
                    height: 4.0,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: isActive
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              )
                            ]
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
