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
import '../search_results_view.dart';
import '../../model/categories_model.dart';
import '../../model/product_model.dart';
import '../../shopify/shopify.dart';

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

  final List<Map<String, String>> _cropData = [
    {
      "name": "Rice",
      "count": "95+ Products",
      "image": "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/paddy.png?v=1783163292"
    },
    {
      "name": "Maize",
      "count": "70+ Products",
      "image": "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/maze.png?v=1783163292"
    },
    {
      "name": "Wheat",
      "count": "120+ Products",
      "image": "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/weat.png?v=1783163292"
    },
    {
      "name": "Sugarcane",
      "count": "80+ Products",
      "image": "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/sugercane.png?v=1783163292"
    },
    {
      "name": "Cotton",
      "count": "85+ Products",
      "image": "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/cotton.png?v=1783163291"
    },
  ];

  // Press state for Phase 2 Button Polish
  bool _isWhatsAppPressed = false;

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
    final banners = await Shopify.getBannerCollections(context);
    if (mounted) {
      setState(() {
        _banners = banners;
        _isLoadingBanners = false;
      });
      // Preload banner images (DISABLED for 3GB RAM stability)
      // for (var banner in _banners) {
      //   if (banner.image.isNotEmpty) {
      //     precacheImage(NetworkImage(banner.image), context);
      //   }
      // }
    }
  }

  Future<void> _fetchBestSellerIds() async {
    final allCats = Constants.homeScreenCatBanners;
    String? bestSellerId;
    for (var cat in allCats) {
      if (cat['image']?.toLowerCase().contains('best') ?? false) {
        bestSellerId = cat['id'];
        break;
      }
    }

    if (bestSellerId != null) {
      final result = await Shopify.getProductsFromCollections(
        context,
        id: bestSellerId,
        limit: 10,
      );
      final List<ProductModel> products =
          (result['product'] as List<dynamic>?)?.cast<ProductModel>() ?? [];
      if (mounted) {
        setState(() {
          _bestSellerIds = products.map((p) => p.id).toList();
        });
      }
    }
  }

  void _handleBannerClick(CategoriesModel banner) async {
    int index = _banners.indexOf(banner);

    // 🟢 Banner 1 → Product: Fertap Gold
    if (index == 0) {
      await _openProductById("8063121522841");
    }

    // 🟢 Banner 2 → Product: Aura Plus
    else if (index == 1) {
      await _openProductById("8243097370777");
    }

    // 🟢 Banner 3 → Product: Swiss Gold
    else if (index == 2) {
      await _openProductById("7935280578713");
    }

    // 🟢 Banner 4 → Nothing
    else if (index == 3) {
      // Do nothing as requested
    }

    // 🟢 Banner 5 → Product: Humiroot
    else if (index == 4) {
      await _openProductById("7955218170009");
    }

    // 🛑 Fallback
    else {
      Routers.goTO(
        context,
        toBody: CollectionView(
          collectionId: "329026142361",
        ),
      );
    }
  }
  Future<void> _openProduct(String handle,
      {String? fallbackCollectionId}) async {
    try {
      // debugPrint("🔍 Fetching product handle: $handle");

      final results = await Shopify.fetchSearchResults(context, query: handle);

      // debugPrint("🔍 Search results count: ${results.length}");
      // debugPrint("   → handle: ${r.handle}  title: ${r.title}");

      if (results.isNotEmpty) {
        // Try exact handle match first, fallback to first result
        final product = results.any((p) => p.handle == handle)
            ? results.firstWhere((p) => p.handle == handle)
            : results.first;

        if (mounted) {
          Routers.goTO(context, toBody: ProductView(product: product));
        }
      } else {
        // debugPrint("⚠️ Product not found: $handle");
        if (mounted) {
          // Fallback → go to a collection if provided
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
      }
    } catch (e) {
      // debugPrint("❌ Product open error: $e");
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
      final product = await Shopify.getProductDetails(context, productId: id);
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

  Widget _buildShopByCropSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
                "Shop by Crop",
                style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 185,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: _cropData.length,
            itemBuilder: (context, index) {
              final crop = _cropData[index];
              return _ShopByCropCard(
                name: crop['name']!,
                count: crop['count']!,
                imageUrl: crop['image']!,
                onTap: () => Routers.goTO(
                  context,
                  toBody: SearchResultsView(
                    query: crop['name']!,
                    title: crop['name']!,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _initCategories() async {
    final allCategories =
        await Shopify.getCategories(context, forcedLang: 'EN');

    final List<String> orderedTitles = [
      'PGRs',
      'Insecticides',
      'Fungicides',
      'Fertilizers',
      'Herbicides',
      'NPK Fertilizers',
      'Bio-Pesticides',
      'Bio-Fungicide',
      'Bio-Fertilizers',
    ];

    final Map<String, List<String>> titleAliases = {
      'PGRs': [
        'PGR',
        'Growth Promoter',
        'Plant Growth Regulator',
        'Growth Promoters',
        'Growth Promotors',
        'Promoter',
        'PGRS'
      ],
      'Insecticides': ['Insecticide', 'Insecticides'],
      'Fungicides': ['Fungicide', 'Fungicides'],
      'Fertilizers': [
        'Fertilizer',
        'Fertilizers',
        'Organic Fertilizer',
        'Organic Fertilizers',
        'Bio-Fertilizer',
        'Bio Fertilizer'
      ],
      'Herbicides': ['Herbicide', 'Herbicides', 'Weedicide'],
      'NPK Fertilizers': ['NPK', 'NPK Fertilizer', 'NPK Fertilizers'],
      'Bio-Pesticides': [
        'Bio-Pesticide',
        'Bio Pesticide',
        'Biological Pesticide',
        'Bio-Insecticide',
        'Bio Insecticide',
        'Bio-Pesticides'
      ],
      'Bio-Fungicide': [
        'Bio-Fungicide',
        'Bio Fungicide',
        'Biological Fungicide',
        'Bio-Fungicides'
      ],
      'Bio-Fertilizers': [
        'Bio-Fertilizer',
        'Bio Fertilizer',
        'Biological Fertilizer',
        'Bio-Fertilizers'
      ],
    };

    List<CategoriesModel> filtered = [];
    for (var title in orderedTitles) {
      CategoriesModel? found;

      List<String> aliases = titleAliases[title] ?? [title];
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

      if (found != null) {
        filtered.add(CategoriesModel(
          id: found.id,
          title: _getLocalizedCategoryTitle(context, title),
          handle: found.handle,
          description: found.description,
          image: found.image,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _categories = filtered;
        _isLoadingCats = false;
      });
      // Pre-cache SVGs (DISABLED for 3GB RAM stability)
      // for (var cat in _categories) {
      //   if (cat.image.isNotEmpty) {
      //     DefaultCacheManager().downloadFile(cat.image);
      //   }
      // }
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
                                height: 180, // Matching 2.1 aspect ratio height
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
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
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  if (bestSeller != null)
                    SliverToBoxAdapter(
                        child: _buildDynamicSection(bestSeller, [])),

                  SliverToBoxAdapter(child: _buildShopByCropSection()),

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

    // Mapping Titles and Subtitles from instructions
    String title = "";
    String subtitle = "";
    String? headerImageUrl;

    switch (id) {
      case "329119367321":
        title = "Best Seller";
        subtitle = "Top performing farming products";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Best_Sellers_New_0141dc78-17a7-4681-a1a8-58ac8248a5c4.png?v=1784628915";
        break;
      case "329026371737":
        title = "Insecticide";
        subtitle = "Protect crops from insects";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Insecticides_New_726a2744-fc90-42a6-a48b-1013a5b26b55.png?v=1784628915";
        break;
      case "329026175129":
        title = "Fungicide";
        subtitle = "Advanced disease control";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Fungicides_New_459199bb-d20d-4983-b741-e031a58d5ae2.png?v=1784628916";
        break;
      case "329026142361":
        title = "Fertilizer";
        subtitle = "Better nutrition for crops";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Fertilizers_New_d711af01-a8a0-493a-b4e4-881b4c29cb52.png?v=1784628915";
        break;
      case "329026240665":
        title = "Herbicide";
        subtitle = "Effective weed management";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Herbicides_New_a310f3d5-9295-4715-8ac6-983ba9c3424c.png?v=1784628915";
        break;
      case "329026470041":
        title = "Top Growth Promoters";
        subtitle = "Faster and healthier growth";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/PGRs_New_fdd490af-ab2e-4f39-9d70-d918c907a7af.png?v=1784628915";
        break;
      case "333391134873":
        title = "Buy 1 Get 1 Free";
        subtitle = "Limited time special offers";
        headerImageUrl = "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Buy_1_get_1_new.png?v=1784628915";
        break;
      default:
        title = "Featured Selection";
        subtitle = "Premium quality farming essentials";
    }

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
          headerImageUrl != null
              ? GestureDetector(
                  onTap: () => Routers.goTO(context,
                      toBody: CollectionView(collectionId: id, title: title)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: KskNetworkImage(
                        headerImageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                )
              : SectionHeader(
                  title: title,
                  subtitle: subtitle,
                ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Constants.stringToColor(color: data['color'] ?? "#fff")
                  .withOpacity(0.04),
            ),
            child: ProductsGrid(
              id: id,
              limit: 4,
              shrinkWrap: true,
              excludeIds: excludeIds,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: _PremiumExploreButton(
              onTap: () => Routers.goTO(context,
                  toBody: CollectionView(collectionId: id!, title: title)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCollectionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
        const SizedBox(height: 16),
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
                title: "Bio Products",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Bio-Products.png?v=1778653230",
                onTap: () => Routers.goTO(context,
                    toBody: CollectionView(
                        collectionId: "329337798809", title: "Bio Products")),
              ),
              _CollectionCard(
                title: "Insecticides",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Insecticides_caa2d9e9-b52e-41e8-ab52-2d7ba95a8da0.png?v=1778653230",
                onTap: () => Routers.goTO(context,
                    toBody: CollectionView(
                        collectionId: "329026371737", title: "Insecticides")),
              ),
              _CollectionCard(
                title: "Fungicides",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Fungicides_b66a7ccd-99d4-40ee-a069-17413504bcf2.png?v=1778653230",
                onTap: () => Routers.goTO(context,
                    toBody: CollectionView(
                        collectionId: "329026175129", title: "Fungicides")),
              ),
              _CollectionCard(
                title: "PGRs",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/PGRs.png?v=1778653230",
                onTap: () => Routers.goTO(context,
                    toBody: CollectionView(
                        collectionId: "329026470041", title: "PGRs")),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _PremiumExploreButton(
            onTap: () => Routers.goTO(context,
                toBody: CollectionView(
                    collectionId: "329119367321", title: "Best Sellers")),
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
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
        const SizedBox(height: 16),
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
                title: "NPK Fertilizers",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/NPK_Fertilizers.png?v=1778656835",
                onTap: () => Routers.goTO(context,
                    toBody: CollectionView(
                        collectionId: "329027715225", title: "NPK Fertilizers")),
              ),
              _CollectionCard(
                title: "Featured Growth",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/ChatGPT_Image_May_13_2026_12_14_51_PM.png?v=1778654730",
                onTap: () => _openProductById("8507485225113"),
              ),
              _CollectionCard(
                title: "Proper Care",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/Proper_404_ff6ed463-0058-4ab1-ae59-53942d0a8acc.png?v=1778654565",
                onTap: () => _openProductById("7926581362841"),
              ),
              _CollectionCard(
                title: "Exclusive Offer",
                imageUrl:
                    "https://cdn.shopify.com/s/files/1/0627/9204/0601/files/ChatGPT_Image_May_16_2026_11_58_03_AM.png?v=1778912897",
                onTap: () => _openProductById("8568815157401"),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _PremiumExploreButton(
            onTap: () => Routers.goTO(context,
                toBody: CollectionView(
                    collectionId: "329119367321", title: "Best Sellers")),
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
                GestureDetector(
                  onTapDown: (_) => setState(() => _isWhatsAppPressed = true),
                  onTapUp: (_) => setState(() => _isWhatsAppPressed = false),
                  onTapCancel: () => setState(() => _isWhatsAppPressed = false),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    launchUrlString("https://wa.me/919399022060");
                  },
                  child: AnimatedScale(
                    scale: _isWhatsAppPressed ? 0.96 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366), // Official WhatsApp Green
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            AppLocalizations.of(context)!.whatsAppSupport,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
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

class _ShopByCropCard extends StatefulWidget {
  final String name;
  final String count;
  final String imageUrl;
  final VoidCallback onTap;

  const _ShopByCropCard({
    required this.name,
    required this.count,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  State<_ShopByCropCard> createState() => _ShopByCropCardState();
}

class _ShopByCropCardState extends State<_ShopByCropCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 130,
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF3F3F3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: KskNetworkImage(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.count,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
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

class _CollectionCard extends StatefulWidget {
  final String imageUrl;
  final String title;
  final VoidCallback onTap;

  const _CollectionCard({
    required this.imageUrl,
    required this.title,
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
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: _scale < 1.0 ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                KskNetworkImage(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                ),
                // Premium Overlay Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.1),
                          Colors.black.withOpacity(0.7),
                        ],
                        stops: const [0.5, 0.7, 1.0],
                      ),
                    ),
                  ),
                ),
                // Collection Title
                Positioned(
                  bottom: 12,
                  left: 10,
                  right: 10,
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
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
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.85),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            CarouselSlider(
              carouselController: _controller,
              options: CarouselOptions(
                aspectRatio: 2.1, // Reverted to original production aspect ratio
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
                    fit: BoxFit.fill, // Ensures image fills the larger hero container
                    width: double.infinity,
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
