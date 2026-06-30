import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/components/widget_button.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'package:kisan_sewa_kendra/view/cart_view.dart';

import '../controller/constants.dart';
import '../controller/routers.dart';
import '../model/product_model.dart';
import '../shopify/shopify.dart';
import '../view/product_view.dart';
import '../controller/cart_controller.dart';
import '../utils/firebase_events.dart';
import '../utils/meta_events.dart';
import 'network_image.dart';
import '../services/attribution_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../controller/pref.dart';
import 'cart_summary_bar.dart';

class ProductsGrid extends StatefulWidget {
  final String? id;
  final String? query;
  final int? limit;
  final bool isFilter;
  final bool shrinkWrap;
  final List<String>? excludeIds; // To prevent duplicates
  final Widget? header; // Optional scrollable header widget

  const ProductsGrid({
    super.key,
    this.id,
    this.query,
    this.limit,
    this.isFilter = false,
    this.shrinkWrap = true,
    this.excludeIds,
    this.header,
  });

  @override
  State<ProductsGrid> createState() => ProductsGridState();
}

class ProductsGridState extends State<ProductsGrid>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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

  List<ProductModel> _products = [], _fullProducts = [];
  bool _isLoading = true;

  /// Public method to sort products from outside (e.g. CollectionView header)
  void sortProducts(String sortType) {
    setState(() {
      if (sortType == "a-z") {
        _products.sort((a, b) => a.title.compareTo(b.title));
      } else if (sortType == "z-a") {
        _products.sort((a, b) => b.title.compareTo(a.title));
      } else {
        _products = List.from(_fullProducts);
      }
    });
  }

  Future<void> _init() async {
    if (!mounted) return;
    if ((widget.id == null || widget.id!.isEmpty || widget.id == "0") &&
        (widget.query == null || widget.query!.isEmpty)) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<ProductModel> list = [];

      if (widget.id != null && widget.id!.isNotEmpty && widget.id != "0") {
        final result = await Shopify.getProductsFromCollections(
          context,
          id: widget.id!,
          limit: widget.limit != null
              ? (widget.limit! + (widget.excludeIds?.length ?? 0))
              : null,
        );
        list = (result['product'] as List<dynamic>?)?.cast<ProductModel>() ??
            <ProductModel>[];
      } else if (widget.query != null && widget.query!.isNotEmpty) {
        list = await Shopify.fetchSearchResults(
          context,
          query: widget.query!,
        );
      }

      if (mounted) {
        setState(() {
          // Filter out excluded IDs
          if (widget.excludeIds != null) {
            list =
                list.where((p) => !widget.excludeIds!.contains(p.id)).toList();
          }

          // Apply limit after exclusion
          if (widget.limit != null && list.length > widget.limit!) {
            list = list.sublist(0, widget.limit);
          }

          _products = list;
          _fullProducts = List.from(_products);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("ProductsGrid Error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;

    // Industry Standard: Dynamic Aspect Ratio for feature-rich cards
    // Taller ratio (0.54) to fit ratings, titles, and steppers comfortably without overflow
    double aspectRatio = 0.54;
    if (width < 360) {
      aspectRatio = 0.51;
    } else if (width > 420) {
      aspectRatio = 0.59;
    }

    // Main Grid/List content
    Widget content;
    if (_isLoading) {
      content = GridView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
        ),
        itemCount: widget.limit ?? 4,
        itemBuilder: (context, index) => _buildShimmerCard(),
      );
    } else if (_products.isEmpty) {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                  )
                ],
              ),
              child:
                  Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey[200]),
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context)!.noProductsFound,
              style: GoogleFonts.outfit(
                color: Colors.grey[800],
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Try searching with different keywords",
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      content = GridView.builder(
        shrinkWrap: widget.shrinkWrap,
        physics: widget.shrinkWrap
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: aspectRatio,
        ),
        itemCount: _products.length,
        itemBuilder: (context, index) => ProductCard(product: _products[index]),
      );
    }

    // Wrap with header/filter if needed
    if (widget.header != null || widget.isFilter) {
      if (!widget.shrinkWrap && widget.header != null) {
        // Scrollable header with grid
        content = CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: widget.header!),
            if (widget.isFilter) SliverToBoxAdapter(child: _buildSortHeader()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              sliver: _isLoading
                  ? SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: aspectRatio,
                      ),
                      delegate: SliverChildBuilderDelegate(
                          (_, __) => _buildShimmerCard(),
                          childCount: widget.limit ?? 4),
                    )
                  : (_products.isEmpty
                      ? SliverToBoxAdapter(
                          child: SizedBox(height: 200, child: content))
                      : SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: aspectRatio,
                          ),
                          delegate: SliverChildBuilderDelegate(
                              (_, index) =>
                                  ProductCard(product: _products[index]),
                              childCount: _products.length),
                        )),
            ),
          ],
        );
      } else {
        // Vertical column layout
        content = Column(
          mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.header != null) widget.header!,
            if (widget.isFilter) _buildSortHeader(),
            widget.shrinkWrap ? content : Expanded(child: content),
          ],
        );
      }
    }

    // Final layout with cart summary if not shrinking
    if (widget.shrinkWrap) return content;

    return Stack(
      children: [
        Positioned.fill(child: content),
        const Positioned(
          bottom: 25,
          left: 0,
          right: 0,
          child: Center(
            child: CartSummaryBar(),
          ),
        ),
      ],
    );
  }

  Widget _buildSortHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(AppLocalizations.of(context)!.sortBy,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            icon: Icon(Icons.swap_vert_rounded,
                color: Constants.baseColor, size: 22),
            onSelected: (value) {
              setState(() {
                if (value == "a-z") {
                  _products.sort((a, b) => a.title.compareTo(b.title));
                } else if (value == "z-a") {
                  _products.sort((a, b) => b.title.compareTo(a.title));
                } else {
                  _products = List.from(_fullProducts);
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: "a-z",
                  child: Text(AppLocalizations.of(context)!.aToZ)),
              PopupMenuItem(
                  value: "z-a",
                  child: Text(AppLocalizations.of(context)!.zToA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              child: Constants.shimmer(),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Constants.shimmer(height: 12, width: 40), // For rating pill
                  const SizedBox(height: 8),
                  Constants.shimmer(
                      height: 14, width: double.infinity), // Title line 1
                  const SizedBox(height: 4),
                  Constants.shimmer(height: 14, width: 100), // Title line 2
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Constants.shimmer(height: 10, width: 40),
                          const SizedBox(height: 4),
                          Constants.shimmer(height: 18, width: 60),
                        ],
                      ),
                      Constants.shimmer(height: 32, width: 60), // Add button
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final ProductModel product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _qty = 0;
  Timer? _timer;
  VariantModel? _activeVariant;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _activeVariant = _minPriceVariant();
    _updateQty();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateQty();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _updateQty() async {
    String? cart = await Pref.getPref(PrefKey.cart);
    if (cart != null) {
      List<dynamic> cartList = jsonDecode(cart);

      int totalQty = 0;
      VariantModel? firstFoundVariant;

      for (var v in widget.product.variants) {
        int index = cartList
            .indexWhere((item) => item['id'].toString() == v.id.toString());
        if (index >= 0) {
          int q = int.tryParse(cartList[index]['qty'].toString()) ?? 0;
          totalQty += q;
          firstFoundVariant ??= v;
        }
      }

      if (mounted) {
        setState(() {
          _qty = totalQty;
          if (firstFoundVariant != null) {
            _activeVariant = firstFoundVariant;
          }
        });
      }
    } else {
      if (mounted && _qty != 0) setState(() => _qty = 0);
    }
  }

  VariantModel? _minPriceVariant() {
    if (widget.product.variants.isEmpty) return null;
    final available =
        widget.product.variants.where((v) => v.inventoryQuantity > 0).toList();
    if (available.isEmpty) return widget.product.variants.first;
    available.sort((a, b) {
      final aPrice =
          double.tryParse(a.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final bPrice =
          double.tryParse(b.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      return aPrice.compareTo(bPrice);
    });
    return available.first;
  }

  int _getPackCount(String title) {
    // Searches for patterns like x2, x 2, (500gx2), Pack of 2
    final regex = RegExp(r'[xX]\s*(\d+)|Pack\s*of\s*(\d+)|(\d+)\s*[xX]');
    final match = regex.firstMatch(title);
    if (match != null) {
      for (int i = 1; i <= match.groupCount; i++) {
        if (match.group(i) != null) {
          return int.tryParse(match.group(i)!) ?? 1;
        }
      }
    }
    return 1;
  }

  Widget _buildRatingPill(double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.star_rounded, color: Color(0xFFFABE3C), size: 12),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = _activeVariant ?? _minPriceVariant();
    if (variant == null) return const SizedBox.shrink();

    double fakeRating = 4.0 + (widget.product.id.hashCode % 11) / 10.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        Routers.goTO(context, toBody: ProductView(product: widget.product));
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 58,
                child: Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      width: double.infinity,
                      height: double.infinity,
                      padding: const EdgeInsets.all(4),
                      child: KskNetworkImage(
                        widget.product.image ?? '',
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    _buildDiscountBadge(variant),
                  ],
                ),
              ),
              Expanded(
                flex: 42,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRatingPill(fakeRating),
                      const SizedBox(height: 2),
                      Flexible(
                        child: Text(
                          widget.product.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (variant.compareAtPrice != null &&
                                    variant.compareAtPrice!.isNotEmpty)
                                  Text(
                                    "${Constants.inr}${variant.compareAtPrice}",
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                Text(
                                  "${Constants.inr}${variant.price}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _qty > 0
                              ? (widget.product.variants.length > 1
                                  ? GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        _showVariantBottomSheet(context);
                                      },
                                      child: _buildStepper(variant),
                                    )
                                  : _buildStepper(variant))
                              : _buildAddButton(variant),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(VariantModel variant) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        if (widget.product.variants.length > 1) {
          _showVariantBottomSheet(context);
        } else {
          _addToCart(variant);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF1E88E5),
              Color(0xFF0F9D8A),
              Color(0xFF2E7D32),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppLocalizations.of(context)!.add.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
            if (widget.product.variants.length > 1)
              Text(
                AppLocalizations.of(context)!.options,
                style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }

  void _showVariantBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        List<dynamic> localCart = [];
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Helper to get qty from local sheet state
            int getVQty(String vId) {
              int idx =
                  localCart.indexWhere((item) => item['id'].toString() == vId);
              return idx >= 0
                  ? (int.tryParse(localCart[idx]['qty'].toString()) ?? 0)
                  : 0;
            }

            return FutureBuilder<String?>(
              future: Pref.getPref(PrefKey.cart),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.data != null) {
                    localCart = jsonDecode(snapshot.data!);
                  } else {
                    localCart = [];
                  }
                }

                return Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.selectOption,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: widget.product.variants.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final v = widget.product.variants[index];
                            int vQty = getVQty(v.id);

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 4),
                              decoration: BoxDecoration(
                                color: vQty > 0
                                    ? Constants.baseColor.withOpacity(0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      Container(
                                        width: 45,
                                        height: 45,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey[100]!),
                                          color: Colors.white,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: KskNetworkImage(
                                            widget.product.image ?? '',
                                            fit: BoxFit.contain),
                                      ),
                                      if (_getPackCount(v.title) > 1)
                                        Positioned(
                                          top: -2,
                                          right: -2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Constants.baseColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: Colors.white,
                                                  width: 1),
                                            ),
                                            child: Text(
                                              "x${_getPackCount(v.title)}",
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 7,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.title,
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: vQty > 0
                                                  ? FontWeight.w900
                                                  : FontWeight.w700),
                                        ),
                                        Text(
                                          "${Constants.inr}${v.price}",
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                              color: vQty > 0
                                                  ? Constants.baseColor
                                                  : Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  vQty > 0
                                      ? _buildMiniStepper(
                                          v, vQty, setSheetState)
                                      : GestureDetector(
                                          onTap: () async {
                                            HapticFeedback.lightImpact();
                                            await _addToCart(v);
                                            setSheetState(() {});
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 18, vertical: 8),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF1E88E5),
                                                  Color(0xFF0F9D8A),
                                                  Color(0xFF2E7D32),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.10),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              AppLocalizations.of(context)!.add,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addToCart(VariantModel variant) async {
    MetaEvents.addToCart(
      id: widget.product.id,
      name: widget.product.title,
      price: variant.price,
    );
    // AppsFlyer Event: Add to Cart
    AttributionService.logAddToCart(widget.product.id, double.tryParse(variant.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0);

    FirebaseEvents.addToCart(widget.product.id, variant.price);

    await CartController.addToCart(
      variantId: variant.id,
      productId: widget.product.id,
      qty: 1,
      title: widget.product.title,
      price: variant.price,
      image: widget.product.image,
      variantTitle: variant.title,
    );
    if (mounted) {
      setState(() {
        _activeVariant = variant;
      });
    }
    _updateQty();
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Added to cart",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Constants.baseColor,
        duration: const Duration(milliseconds: 1000),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildMiniStepper(
      VariantModel variant, int qty, StateSetter setSheetState) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF0F9D8A),
            Color(0xFF2E7D32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cartStyleBtn(
              qty == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
              () async {
            HapticFeedback.mediumImpact();
            await CartController.updateQty(variant.id, qty - 1);
            setSheetState(() {});
            _updateQty();
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "$qty",
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14),
            ),
          ),
          _cartStyleBtn(Icons.add_rounded, () async {
            HapticFeedback.lightImpact();
            await CartController.updateQty(variant.id, qty + 1);
            setSheetState(() {});
            _updateQty();
          }),
        ],
      ),
    );
  }

  Widget _buildStepper(VariantModel variant) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E88E5),
            Color(0xFF0F9D8A),
            Color(0xFF2E7D32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cartStyleBtn(
              widget.product.variants.length > 1
                  ? Icons.remove_rounded
                  : (_qty == 1
                      ? Icons.delete_outline_rounded
                      : Icons.remove_rounded), () async {
            HapticFeedback.mediumImpact();
            if (widget.product.variants.length > 1) {
              _showVariantBottomSheet(context);
            } else {
              await CartController.updateQty(variant.id, _qty - 1);
              _updateQty();
            }
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "$_qty",
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
          _cartStyleBtn(Icons.add_rounded, () async {
            HapticFeedback.lightImpact();
            if (widget.product.variants.length > 1) {
              _showVariantBottomSheet(context);
            } else {
              await CartController.updateQty(variant.id, _qty + 1);
              _updateQty();
            }
          }),
        ],
      ),
    );
  }

  Widget _cartStyleBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildDiscountBadge(VariantModel variant) {
    if (variant.compareAtPrice == null || variant.compareAtPrice!.isEmpty)
      return const SizedBox.shrink();
    try {
      double mrp = double.parse(variant.compareAtPrice!
          .replaceAll(Constants.inr, '')
          .replaceAll(',', ''));
      double sp = double.parse(
          variant.price.replaceAll(Constants.inr, '').replaceAll(',', ''));
      double per = (100 * (mrp - sp)) / mrp;
      if (per > 1) {
        return Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              AppLocalizations.of(context)!.off(per.toInt().toString()),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800),
            ),
          ),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }
}
