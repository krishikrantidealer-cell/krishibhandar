import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../components/network_image.dart';
import '../../components/products_grid.dart';
import '../../components/widget_button.dart';
import '../../controller/constants.dart';
import '../../controller/routers.dart';
import '../collection_view.dart';
import '../product_view.dart';
import '../../model/categories_model.dart';
import '../../model/product_model.dart';
import '../../services/api_service.dart';

class Home extends StatefulWidget {
  final ScrollController scrollController;

  const Home({
    super.key,
    required this.scrollController,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<CategoriesModel> _categories = [];
  List<CategoriesModel> _banners = [];
  bool _isLoadingCats = true;
  bool _isLoadingBanners = true;
  List<String> _bestSellerIds = [];

  @override
  void initState() {
    super.initState();
    _staggeredInit();
    Constants.languageController.addListener(_onLanguageChanged);
  }

  Future<void> _staggeredInit() async {
    await _fetchBanners();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _initCategories();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _fetchBestSellerIds();
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
      _fetchBestSellerIds(),
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
    if (mounted) {
      setState(() {
        _banners = bannerList;
        _isLoadingBanners = false;
      });
    }
  }

  Future<void> _fetchBestSellerIds() async {
    final allCats = Constants.homeScreenCatBanners;
    String? bestSellerId = allCats.isNotEmpty ? allCats.first['id'] : null;

    if (bestSellerId != null) {
      final result = await ApiService.getProductsFromCollections(
        id: bestSellerId,
        limit: 10,
      );
      final List<ProductModel> products =
          (result['products'] as List<dynamic>?)?.cast<ProductModel>() ?? [];
      if (mounted) {
        setState(() {
          _bestSellerIds = products.map((p) => p.id).toList();
        });
      }
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

  Future<void> _openProductById(String id) async {
    try {
      final product = await ApiService.getProductDetails(productId: id);
      if (product != null && mounted) {
        Routers.goTO(context, toBody: ProductView(product: product));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Product not found."),
            duration: Duration(seconds: 2),
          ),
        );
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
    final allCategories = await ApiService.getCategoriesList();

    final List<Map<String, dynamic>> target9Categories = [
      {
        'title': 'PGRs',
        'aliases': ['pgrs', 'pgr', 'growth promoter', 'plant growth regulator'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp',
      },
      {
        'title': 'Insecticides',
        'aliases': ['insecticides', 'insecticide', 'organic insecticides'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Insecticides_1782219848442_full.webp',
      },
      {
        'title': 'Fungicides',
        'aliases': ['fungicides', 'fungicide', 'organic fungicdes'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fungicides_1782219847975_full.webp',
      },
      {
        'title': 'Fertilizers',
        'aliases': ['fertilizer', 'fertilizers', 'organic fertilizers'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp',
      },
      {
        'title': 'Herbicides',
        'aliases': ['herbicides', 'herbicide', 'weedicide', 'weedicides'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio_Nematicide_1782219846072_full.webp',
      },
      {
        'title': 'NPK Fertilizers',
        'aliases': ['npk fertilizers', 'npk', 'npk fertilizer'],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Micronutrients_1782219847036_full.webp',
      },
      {
        'title': 'Bio-Pesticides',
        'aliases': [
          'bio-pesticides',
          'bio-pesticide',
          'bio pesticide',
          'bio pesticides',
          'biological pesticide'
        ],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp',
      },
      {
        'title': 'Bio-Fungicide',
        'aliases': [
          'bio-fungicide',
          'bio-fungicides',
          'bio fungicide',
          'bio fungicides'
        ],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fungicides_1782219847975_full.webp',
      },
      {
        'title': 'Bio-Fertilizers',
        'aliases': [
          'bio_fertilizers',
          'bio-fertilizer',
          'bio-fertilizers',
          'bio fertilizer',
          'bio fertilizers'
        ],
        'defaultImage':
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp',
      },
    ];

    List<CategoriesModel> filtered = [];
    for (var target in target9Categories) {
      final title = target['title'] as String;
      final aliases = target['aliases'] as List<String>;
      final defaultImage = target['defaultImage'] as String;

      CategoriesModel? found;
      for (var alias in aliases) {
        for (var cat in allCategories) {
          final catTitle = cat.title.toLowerCase().trim();
          final aliasLower = alias.toLowerCase().trim();

          if (catTitle == aliasLower || catTitle.contains(aliasLower)) {
            found = cat;
            break;
          }
        }
        if (found != null) break;
      }

      final categoryId = found?.id ?? title.toLowerCase().replaceAll(' ', '-');
      final categoryHandle = found?.handle.isNotEmpty == true
          ? found!.handle
          : title.toLowerCase().replaceAll(' ', '-');
      final categoryImage = (found != null && found.image.isNotEmpty)
          ? found.image
          : defaultImage;

      filtered.add(CategoriesModel(
        id: categoryId,
        title: _getLocalizedCategoryTitle(context, title),
        handle: categoryHandle,
        description: found?.description ?? '',
        image: categoryImage,
      ));
    }

    if (mounted) {
      setState(() {
        _categories = filtered;
        _isLoadingCats = false;
      });
    }
  }

  String _getLocalizedCategoryTitle(BuildContext context, String title) {
    if (!mounted) return title;
    final l10n = AppLocalizations.of(context)!;
    switch (title) {
      case 'PGRs':
        return l10n.pgr;
      case 'Insecticides':
        return l10n.insecticides;
      case 'Fungicides':
        return l10n.fungicides;
      case 'Fertilizers':
        return l10n.fertilizers;
      case 'Herbicides':
        return l10n.herbicides;
      case 'NPK Fertilizers':
        return l10n.npkFertilizer;
      case 'Bio-Pesticides':
        return l10n.bioPesticide;
      case 'Bio-Fungicide':
        return l10n.bioFungicide;
      case 'Bio-Fertilizers':
        return l10n.bioFertilizer;
      default:
        return title;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCats = Constants.homeScreenCatBanners;

    Map<String, String>? bestSeller;
    for (var cat in allCats) {
      if (cat['image']?.toLowerCase().contains('best') ?? false) {
        bestSeller = cat;
        break;
      }
    }

    Map<String, String>? badiBachat;
    for (var cat in allCats) {
      if (cat['image']?.toLowerCase().contains('bachat') ?? false) {
        badiBachat = cat;
        break;
      }
    }

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
                          crossAxisSpacing: 0,
                          mainAxisSpacing: 0,
                          childAspectRatio: 1.0,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final cat = _categories[index];
                            return WidgetButton(
                              onTap: () => Routers.goTO(context,
                                  toBody: CollectionView(
                                      collectionId: cat.id.toString(),
                                      title: cat.title)),
                              child: KskNetworkImage(
                                cat.image,
                                fit: BoxFit.contain,
                              ),
                            );
                          },
                          childCount: _categories.length,
                        ),
                      ),
                    ),

                  // --- DYNAMIC SECTIONS ---
                  if (bestSeller != null)
                    SliverToBoxAdapter(
                        child: _buildDynamicSection(bestSeller, [])),

                  // --- NEW COLLECTIONS SECTION ---
                  SliverToBoxAdapter(child: _buildCollectionsSection()),

                  if (badiBachat != null)
                    SliverToBoxAdapter(
                        child:
                            _buildDynamicSection(badiBachat, _bestSellerIds)),

                  for (var section in allCats)
                    if (section != bestSeller && section != badiBachat) ...[
                      SliverToBoxAdapter(
                          child: _buildDynamicSection(section, [])),
                      if (section['id'] == "329026240665")
                        SliverToBoxAdapter(child: _buildExclusiveSection()),
                    ],

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

  Widget _buildDynamicSection(
      Map<String, String> data, List<String> excludeIds) {
    final id = data['id'];
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }

    String title = data['title'] ?? "Featured Selection";
    String subtitle = data['subtitle'] ?? "Premium quality farming essentials";

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 250),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          SectionHeader(
            title: title,
            subtitle: subtitle,
            onViewAll: () => Routers.goTO(context,
                toBody: CollectionView(collectionId: id, title: title)),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Constants.stringToColor(color: data['color'] ?? "#fff")
                  .withOpacity(0.04),
            ),
            child: Column(
              children: [
                ProductsGrid(
                  id: id,
                  limit: 4,
                  shrinkWrap: true,
                  excludeIds: excludeIds,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4.5,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF26842c),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Collections",
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a6a", title: "Bio Products")),
              ),
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Insecticides_1782219848442_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a5f", title: "Insecticides")),
              ),
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fungicides_1782219847975_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a5d", title: "Fungicides")),
              ),
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a60", title: "PGRs")),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _PremiumExploreButton(
            onTap: () => Routers.goTO(context,
                toBody: const CollectionView(
                    collectionId: "6a3935cebd6e0cfbef015a5f", title: "Best Sellers")),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildExclusiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4.5,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF26842c),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Exclusive",
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
            children: [
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a69", title: "NPK Fertilizers")),
              ),
              _CollectionCard(
                imageUrl:
                    "https://storage.googleapis.com/bhandar-product-images/banners/category/Micronutrients_1782219847036_full.webp",
                onTap: () => Routers.goTO(context,
                    toBody: const CollectionView(
                        collectionId: "6a3935cebd6e0cfbef015a65", title: "Micronutrients")),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
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

class _CollectionCard extends StatefulWidget {
  final String imageUrl;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_CollectionCard> createState() => _CollectionCardState();
}

class _CollectionCardState extends State<_CollectionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.93),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: _scale < 1.0 ? 12 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: WidgetButton(
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: KskNetworkImage(
                widget.imageUrl,
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
      ),
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

class _PremiumExploreButton extends StatefulWidget {
  final VoidCallback onTap;
  const _PremiumExploreButton({super.key, required this.onTap});

  @override
  State<_PremiumExploreButton> createState() => _PremiumExploreButtonState();
}

class _PremiumExploreButtonState extends State<_PremiumExploreButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _arrowController;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _arrowAnimation = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.viewAll,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Constants.baseColor,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _arrowAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_arrowAnimation.value, 0),
                    child: child,
                  );
                },
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Constants.baseColor,
                ),
              ),
            ],
          ),
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
