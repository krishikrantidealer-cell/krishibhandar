import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/components/cart_summary_bar.dart';
import 'package:kisan_sewa_kendra/components/products_grid.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'package:kisan_sewa_kendra/view/cart_view.dart';
import 'package:kisan_sewa_kendra/view/collection_view.dart';
import 'package:kisan_sewa_kendra/view/component/categories.dart';
import 'package:kisan_sewa_kendra/view/search_results_view.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import '../components/cart_icon.dart';
import '../components/network_image.dart';
import '../components/widget_button.dart';
import '../controller/constants.dart';
import '../controller/routers.dart';
import '../model/product_model.dart';
import '../services/bhandar_api_service.dart';
import '../controller/cart_controller.dart';
import '../services/attribution_service.dart';
import '../utils/firebase_events.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../controller/auth_controller.dart';
import '../model/review_model.dart';
import '../services/review_service.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ProductView extends StatefulWidget {
  final ProductModel? product;
  final String? id;

  const ProductView({
    super.key,
    this.product,
    this.id,
  }) : assert(product != null || id != null,
            'Either product or id must be provided');

  @override
  State<ProductView> createState() => _ProductViewState();
}

class MyWidgetFactory extends WidgetFactory {
  @override
  void parse(BuildTree meta) {
    if (meta.element.localName == 'iframe') {
      debugPrint("DEBUG: [MyWidgetFactory] Found iframe tag in HTML");
      debugPrint("DEBUG: [MyWidgetFactory] iframe element: ${meta.element.outerHtml}");
    }
    super.parse(meta);
  }

  @override
  Widget? buildWebView(
    BuildTree meta,
    String url, {
    double? height,
    Iterable<String>? sandbox,
    double? width,
  }) {
    return const SizedBox.shrink();
  }
}

class _ProductViewState extends State<ProductView>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  final CarouselSliderController _controller = CarouselSliderController();
  int _carouselIndex = 0, _varientIndex = 0;
  List<ProductModel> _recommend = [];
  bool _enableAutoPlay = false;
  late TabController _tabController;
  ProductModel? _localizedProduct;
  bool _isExpanded = false;

  // Press state for Phase 2 Button Polish
  bool _isBuyNowPressed = false;
  bool _isAddToCartPressed = false;
  bool _isSubmitReviewPressed = false;

  // Review states
  double _userRating = 0.0;
  final TextEditingController _reviewNameController = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _selectedReviewImages = [];
  List<ReviewModel> _reviews = [];
  bool _isLoadingReviews = true;
  bool _isSubmittingReview = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Auto fill user name in review if logged in
    final savedName = AuthController.currentName;
    if (savedName != null && savedName.trim().isNotEmpty && savedName.toLowerCase() != 'customer') {
      _reviewNameController.text = savedName.trim();
    }

    // If we only have an ID, we'll fetch the full product in _init
    if (widget.product != null) {
      // 1. Attribution & Meta tracking (Consolidated via AttributionService)
      AttributionService.logViewContent(
        widget.product!.id,
        widget.product!.title,
        widget.product!.variants.isNotEmpty
            ? widget.product!.variants.first.price
            : '0',
      );

      // 2. Firebase tracking
      FirebaseEvents.viewItem(
        widget.product!.id,
        widget.product!.variants.isNotEmpty
            ? widget.product!.variants.first.price
            : '0',
      );
    }

    Future.delayed(Duration.zero, _init);

    Constants.languageController.addListener(_onLanguageChanged);
    Constants.cartController.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    Constants.languageController.removeListener(_onLanguageChanged);
    Constants.cartController.removeListener(_onCartChanged);
    _tabController.dispose();
    _reviewNameController.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      _init();
    }
  }

  void _onCartChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  int _getCartQuantity() {
    final product = _localizedProduct ?? widget.product;
    if (product == null || product.variants.isEmpty) return 0;
    final variant = product.variants.length > _varientIndex
        ? product.variants[_varientIndex]
        : product.variants.first;
    return CartController.getItemQuantity(variant.id);
  }

  Future<void> _init() async {
    final productId = widget.product?.id.toString() ?? widget.id;
    if (productId == null) return;

    final localized = await BhandarApiService.getProductDetails(
      context,
      productId: productId,
    );
    if (!mounted) return;
    _recommend = await BhandarApiService.getProductsRecommend(
      context,
      id: productId,
    );

    if (widget.product == null && localized != null) {
      // Log events for deep-linked product once loaded
      AttributionService.logViewContent(
        localized.id,
        localized.title,
        localized.variants.isNotEmpty
            ? localized.variants.first.price
            : '0',
      );
      FirebaseEvents.viewItem(
        localized.id,
        localized.variants.isNotEmpty ? localized.variants.first.price : '0',
      );
    }

    if (mounted) {
      setState(() {
        _localizedProduct = localized;
        _enableAutoPlay = true;
      });
    }

    _loadReviews(productId);
  }

  Future<void> _loadReviews(String productId) async {
    try {
      final list = await ReviewService.getProductReviews(productId);
      if (mounted) {
        setState(() {
          _reviews = list;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  String? _extractIframeSrc(String html) {
    if (html.isEmpty) return null;
    final match = RegExp(r'<iframe[^>]+src="([^"]+)"').firstMatch(html);
    return match?.group(1);
  }

  String? _extractYoutubeId(String src) {
    final regExp = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/|youtube\.com\/shorts\/|embed\/)([^"&?\/\s]{11})');
    final match = regExp.firstMatch(src);
    return match?.group(1);
  }

  Widget _buildQuantitySelector(int currentQty) {
    final product = _localizedProduct ?? widget.product;
    if (product == null || product.variants.isEmpty) {
      return const SizedBox.shrink();
    }
    final variant = product.variants.length > _varientIndex
        ? product.variants[_varientIndex]
        : product.variants.first;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Constants.baseColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _cartStyleBtn(
            currentQty == 1
                ? Icons.delete_outline_rounded
                : Icons.remove_rounded,
            () async {
              HapticFeedback.mediumImpact();
              await CartController.decrement(variant.id);
            },
          ),
          Text(
            "$currentQty",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Constants.baseColor,
            ),
          ),
          _cartStyleBtn(
            Icons.add_rounded,
            () async {
              HapticFeedback.lightImpact();
              await CartController.increment(variant.id);
            },
          ),
        ],
      ),
    );
  }

  Widget _cartStyleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10), // Larger padding for ProductView
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Constants.baseColor),
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String line1, String line2) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.green[700], size: 20),
        const SizedBox(height: 4),
        Text(
          line1,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black87),
        ),
        Text(
          line2,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _discount({
    required String? comparePrice,
    required String sellingPrice,
  }) {
    if (comparePrice == null || comparePrice.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      double mrp = double.parse(
              comparePrice.replaceAll(Constants.inr, '').replaceAll(',', '')),
          sp = double.parse(
              sellingPrice.replaceAll(Constants.inr, '').replaceAll(',', ''));

      double per = (100 * (mrp - sp)) / mrp;

      if (per > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(1, 1),
              ),
            ],
          ),
          child: Text(
            AppLocalizations.of(context)!.off(per.toInt().toString()),
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
    } catch (e) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  Widget _buildYouSavePill({
    required String? comparePrice,
    required String sellingPrice,
  }) {
    if (comparePrice == null || comparePrice.isEmpty) {
      return const SizedBox.shrink();
    }

    try {
      double mrp = double.parse(
              comparePrice.replaceAll(Constants.inr, '').replaceAll(',', '')),
          sp = double.parse(
              sellingPrice.replaceAll(Constants.inr, '').replaceAll(',', ''));

      double savingAmount = mrp - sp;
      double per = (100 * savingAmount) / mrp;

      if (savingAmount > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_offer_rounded,
                  color: Color(0xFF2E7D32), size: 14),
              const SizedBox(width: 6),
              Text(
                "You Save ${Constants.inr}${savingAmount.toStringAsFixed(0)} (${per.toInt()}%)",
                style: GoogleFonts.outfit(
                  color: const Color(0xFF2E7D32),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
  }

  Widget _buildDeliveryCommitmentRibbon() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FFF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0F2E9), width: 1),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const Icon(Icons.local_shipping_rounded,
                  color: Color(0xFF2E7D32), size: 22),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: Color(0xFF2E7D32), size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Delivery Across India",
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Guaranteed Delivery in 7–9 Business Days",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF43A047),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStars(double rating, {double size = 16}) {
    int fullStars = rating.floor();
    bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < fullStars
                ? Icons.star_rounded
                : (i == fullStars && hasHalfStar
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded),
            color: Colors.amber,
            size: size,
          ),
        const SizedBox(width: 6),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontSize: size * 0.87,
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final product = _localizedProduct ?? widget.product;

    if (product == null || product.variants.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(product?.title ?? AppLocalizations.of(context)!.loading,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Colors.black87)),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.black87, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
            child: Text(AppLocalizations.of(context)!.productUnavailable)),
      );
    }

    final variant = product.variants.length > _varientIndex
        ? product.variants[_varientIndex]
        : product.variants.first;
    double fakeRating = 4.0 + (product.id.hashCode % 11) / 10.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: Container(
            margin: const EdgeInsets.only(left: 14, top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: Colors.black87, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: KskCartIcon(showBackground: true),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Gallery ---
                Stack(
                  children: [
                    CarouselSlider(
                      carouselController: _controller,
                      options: CarouselOptions(
                        aspectRatio: 1.25,
                        viewportFraction: 1,
                        autoPlay:
                            product.images.length > 1 ? _enableAutoPlay : false,
                        enableInfiniteScroll: product.images.length > 1,
                        onPageChanged: (index, _) {
                          setState(() => _carouselIndex = index);
                        },
                      ),
                      items: product.images.map((img) {
                        return KskNetworkImage(img, fit: BoxFit.contain);
                      }).toList(),
                    ),
                    if (product.images.length > 1)
                      Positioned(
                        bottom: 10,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: product.images.asMap().entries.map((entry) {
                            return Container(
                              width: _carouselIndex == entry.key ? 22 : 7.0,
                              height: 7.0,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Constants.baseColor.withValues(
                                    alpha: _carouselIndex == entry.key ? 1.0 : 0.2),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),

                // --- Delivery Commitment ---
                _buildDeliveryCommitmentRibbon(),

                // --- Product Header ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRatingStars(fakeRating),
                          // Brand Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.appBrandName,
                              style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        child: Column(
                          key: ValueKey<String>("${variant.id}_${variant.price}"),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  "${Constants.inr}${variant.price}",
                                  style: const TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                ),
                                if (variant.compareAtPrice != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    "${Constants.inr}${variant.compareAtPrice}",
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.lineThrough,
                                        decorationThickness: 1.5),
                                  ),
                                ],
                                const SizedBox(width: 12),
                                _discount(
                                    comparePrice: variant.compareAtPrice,
                                    sellingPrice: variant.price),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildYouSavePill(
                                comparePrice: variant.compareAtPrice,
                                sellingPrice: variant.price),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(AppLocalizations.of(context)!.inclusiveTaxes,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF0F0F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildTrustBadge(
                                  Icons.verified_user_outlined,
                                  AppLocalizations.of(context)!.trust1Line1,
                                  AppLocalizations.of(context)!.trust1Line2),
                            ),
                            Container(
                                width: 1, height: 30, color: Colors.grey[300]),
                            Expanded(
                              child: _buildTrustBadge(
                                  Icons.security_outlined,
                                  AppLocalizations.of(context)!.trust2Line1,
                                  AppLocalizations.of(context)!.trust2Line2),
                            ),
                            Container(
                                width: 1, height: 30, color: Colors.grey[300]),
                            Expanded(
                              child: _buildTrustBadge(
                                  Icons.stars_outlined,
                                  AppLocalizations.of(context)!.trust3Line1,
                                  AppLocalizations.of(context)!.trust3Line2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 6, color: const Color(0xFFF4F6F8)),

                // --- Select Variant Section (Premium Grid Style) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.selectVariant,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 100, // Fixed height per requirement
                        ),
                        itemCount: product.variants.length,
                        itemBuilder: (context, i) {
                          final v = product.variants[i];
                          final isSelected = _varientIndex == i;
                          final isOutOfStock = v.inventoryQuantity <= 0;

                          return GestureDetector(
                            onTap: isOutOfStock
                                ? null
                                : () => setState(() => _varientIndex = i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeInOut,
                              transform: isSelected
                                  ? (Matrix4.diagonal3Values(1.02, 1.02, 1.0))
                                  : Matrix4.identity(),
                              transformAlignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFF1F8E9) // Very light green
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isSelected ? 0.12 : 0.05),
                                    blurRadius: isSelected ? 10 : 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Opacity(
                                opacity: isOutOfStock ? 0.4 : 1.0,
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // TOP: Variant Name
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            v.title,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(
                                              color: isSelected
                                                  ? const Color(0xFF1B5E20)
                                                  : (isOutOfStock
                                                      ? Colors.grey
                                                      : const Color(
                                                          0xFF212121)), // Near Black
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.w600, // SemiBold
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // BOTTOM: Price
                                      Text(
                                        "${Constants.inr}${v.price}",
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          color: Colors.green[700],
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                Container(height: 6, color: const Color(0xFFF4F6F8)),

                // --- Tabs Header ---
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.black87,
                    unselectedLabelColor: Colors.grey[400],
                    indicatorColor: Colors.black87,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5),
                    tabs: [
                      Tab(text: AppLocalizations.of(context)!.overview),
                      Tab(
                          text: AppLocalizations.of(context)!
                              .details
                              .toUpperCase()),
                    ],
                  ),
                ),

                // --- Tab Content ---
                Container(
                  color: Colors.white,
                  child: _tabController.index == 0
                      ? _buildOverviewContent()
                      : _buildDescriptionContent(),
                ),

                Container(height: 6, color: const Color(0xFFF4F6F8)),

                // --- How to Use ---
                // Container(color: Colors.white, child: _buildHowToUseSection()),

                Container(height: 6, color: const Color(0xFFF4F6F8)),

                // --- Customer Reviews ---
                Container(
                    color: Colors.white, child: _buildReviewsListSection()),

                // --- Write a Review ---
                Container(
                    color: Colors.white, child: _buildWriteReviewSection()),

                Container(height: 6, color: const Color(0xFFF4F6F8)),

                // --- Similar Products ---
                if (_recommend.isNotEmpty) ...[
                  const Divider(
                      height: 1, thickness: 1, color: Color(0xFFF0F0F0)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                              AppLocalizations.of(context)!.similarProducts,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: Colors.black)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            if (product.productType.isNotEmpty) {
                              Routers.goTO(context,
                                  toBody: SearchResultsView(
                                      query: product.productType,
                                      title: product.productType));
                            } else if (product.collectionId != null &&
                                product.collectionId!.isNotEmpty) {
                              Routers.goTO(context,
                                  toBody: CollectionView(
                                      collectionId: product.collectionId!));
                            } else {
                              Routers.goTO(context, toBody: const Categories());
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.viewAll,
                              style: TextStyle(
                                  color: Constants.baseColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 275,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 20, bottom: 20),
                      itemCount: _recommend.length,
                      itemBuilder: (context, index) => Container(
                        width: 175,
                        margin: const EdgeInsets.only(right: 15),
                        child: ProductCard(product: _recommend[index]),
                      ),
                    ),
                  ),
                ],



                const SizedBox(height: 180), // Increased bottom spacing
              ],
            ),
          ),
          const Positioned(
            bottom: 120, // Position above the bottom sheet
            left: 0,
            right: 0,
            child: Center(
              child: CartSummaryBar(),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(20, 15, 20, 35),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, -5))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: _getCartQuantity() > 0
                    ? _buildQuantitySelector(_getCartQuantity())
                    : GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _isAddToCartPressed = true),
                        onTapUp: (_) =>
                            setState(() => _isAddToCartPressed = false),
                        onTapCancel: () =>
                            setState(() => _isAddToCartPressed = false),
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final p = _localizedProduct ?? widget.product;
                          if (p == null) return;
                          final v = p.variants.length > _varientIndex
                              ? p.variants[_varientIndex]
                              : p.variants.first;

                          // Consolidated Event tracking via AttributionService (Meta + AppsFlyer)
                          // Fixed: Added await for standard event tracking
                          await AttributionService.logAddToCart(
                              p.id,
                              p.title,
                              double.tryParse(v.price
                                      .replaceAll(RegExp(r'[^\d.]'), '')) ??
                                  0.0);

                          // Firebase Event: add_to_cart
                          FirebaseEvents.addToCart(p.id, v.price);

                          await CartController.addToCart(
                            variantId: v.id,
                            productId: p.id,
                            qty: 1,
                            title: p.title,
                            price: v.price,
                            image: p.image,
                            variantTitle: v.title,
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  AppLocalizations.of(context)!.addedToCart,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              backgroundColor: Constants.baseColor,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(milliseconds: 1000),
                              margin: const EdgeInsets.all(20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                        child: AnimatedScale(
                          scale: _isAddToCartPressed ? 0.97 : 1.0,
                          duration: const Duration(milliseconds: 120),
                          child: Container(
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
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0),
                                  child: Text(
                                      AppLocalizations.of(context)!.addToCart,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _isBuyNowPressed = true),
                  onTapUp: (_) => setState(() => _isBuyNowPressed = false),
                  onTapCancel: () => setState(() => _isBuyNowPressed = false),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final p = _localizedProduct ?? widget.product;
                    if (p == null) return;
                    final v = p.variants.length > _varientIndex
                        ? p.variants[_varientIndex]
                        : p.variants.first;

                    final priceVal = double.tryParse(
                            v.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
                        0.0;
                    await AttributionService.logAddToCart(
                        p.id, p.title, priceVal);
                    FirebaseEvents.addToCart(p.id, v.price);

                    await CartController.buyNow(
                      variantId: v.id,
                      productId: p.id,
                      qty: 1,
                      title: p.title,
                      price: v.price,
                      image: p.image,
                      variantTitle: v.title,
                    );
                    if (!context.mounted) return;
                    Routers.goTO(context, toBody: const CartView());
                  },
                  child: AnimatedScale(
                    scale: _isBuyNowPressed ? 0.97 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFAEEA4D),
                            Color(0xFF7BC943),
                            Color(0xFF2E7D32),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(AppLocalizations.of(context)!.buyNow,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewContent() {
    final product = _localizedProduct ?? widget.product;
    if (product == null) return const SizedBox.shrink();

    final Map<String, String> details = {
      AppLocalizations.of(context)!.productName: product.title,
      AppLocalizations.of(context)!.brand: "KrishiKranti Organics",
      AppLocalizations.of(context)!.category: product.productType,
    };

    String techContent = "";
    if (product.title.contains('(') && product.title.contains(')')) {
      techContent = product.title.substring(
          product.title.lastIndexOf('(') + 1, product.title.lastIndexOf(')'));
    }

    if (techContent.isNotEmpty) {
      details[AppLocalizations.of(context)!.technicalContent] = techContent;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: details.entries
            .where((e) => e.value.isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((entry) {
          final isEven = entry.key % 2 == 0;
          return Container(
            color: isEven ? Colors.grey[50] : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: Text(entry.value.key,
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
                Expanded(
                  child: Text(entry.value.value,
                      style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.4)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDescriptionContent() {
    final product = _localizedProduct ?? widget.product;
    if (product == null || product.body.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: Text(AppLocalizations.of(context)!.noDescription,
                style: const TextStyle(color: Colors.grey))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.aboutProduct,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Colors.black)),
          const SizedBox(height: 15),
          Builder(builder: (context) {
            final iframeSrc = _extractIframeSrc(product.body);
            if (iframeSrc == null) return const SizedBox.shrink();
            final videoId = _extractYoutubeId(iframeSrc);
            if (videoId == null) return const SizedBox.shrink();
            final isShorts = iframeSrc.contains('youtube.com/shorts') ||
                iframeSrc.contains('/shorts/');
            return _ProductVideoCard(videoId: videoId, isShorts: isShorts);
          }),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: _isExpanded
                  ? const BoxConstraints()
                  : const BoxConstraints(
                      maxHeight: 250), // Increased default height
              child: ClipRect(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Builder(builder: (context) {
                        debugPrint("DEBUG: Product ID: ${product.id}");
                        debugPrint("DEBUG: Body length: ${product.body.length}");
                        debugPrint("DEBUG: Contains iframe: ${product.body.contains('<iframe')}");
                        if (product.body.contains('<iframe')) {
                          debugPrint("DEBUG: Iframe HTML: ${product.body.substring(product.body.indexOf('<iframe'), product.body.indexOf('</iframe>') + 9)}");
                        }
                        return HtmlWidget(
                          product.body,
                          factoryBuilder: () => MyWidgetFactory(),
                          textStyle: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                              height: 1.7),
                        );
                      }),
                    ),
                    if (!_isExpanded)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.9),
                                Colors.white,
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: WidgetButton(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Constants.baseColor, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isExpanded
                          ? AppLocalizations.of(context)!.viewLess
                          : AppLocalizations.of(context)!.viewMore,
                      style: TextStyle(
                          color: Constants.baseColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Constants.baseColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  // --- Public Review System Helpers ---

  Widget _buildReviewImage(String imageStr,
      {double? size, double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (imageStr.startsWith("data:image") && imageStr.contains(",")) {
      try {
        final base64Data = imageStr.split(",")[1];
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          width: width ?? size,
          height: height ?? size,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            width: width ?? size,
            height: height ?? size,
            color: Colors.grey[200],
            child: const Icon(Icons.image_not_supported_rounded,
                color: Colors.grey, size: 20),
          ),
        );
      } catch (_) {}
    }
    return KskNetworkImage(
      imageStr,
      width: width ?? size,
      height: height ?? size,
      fit: fit,
    );
  }

  void _openImagePreview(String imageStr) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _buildReviewImage(imageStr,
                    size: double.infinity, fit: BoxFit.contain),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickReviewImages() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1024,
      );
      if (pickedFiles.isNotEmpty) {
        for (var file in pickedFiles) {
          final bytes = await file.readAsBytes();
          final base64String =
              "data:image/jpeg;base64,${base64Encode(bytes)}";
          if (_selectedReviewImages.length < 5) {
            setState(() {
              _selectedReviewImages.add(base64String);
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking review image: $e");
    }
  }

  String _formatReviewDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return diff.inMinutes <= 1 ? "Just now" : "${diff.inMinutes} mins ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} hours ago";
    } else if (diff.inDays < 7) {
      return "${diff.inDays} days ago";
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return "$weeks ${weeks == 1 ? 'week' : 'weeks'} ago";
    } else {
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec"
      ];
      final monthName =
          (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : "";
      return "${dt.day} $monthName ${dt.year}";
    }
  }

  Widget _buildWriteReviewSection() {
    final ratingTitles = {
      5.0: "Excellent Quality",
      4.0: "Very Good Product",
      3.0: "Average Experience",
      2.0: "Below Expectations",
      1.0: "Poor Experience",
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Constants.baseColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.rate_review_rounded,
                    color: Constants.baseColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.writeReview,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: const Color(0xFF1E1E1E),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.shareExperience,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Star Rating Input
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _userRating == 0.0
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFFABE3C).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1.0;
                    final isSelected = _userRating > 0 && starVal <= _userRating;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _userRating = starVal);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          isSelected
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isSelected
                              ? const Color(0xFFFABE3C)
                              : const Color(0xFFCBD5E1),
                          size: 38,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(
                  _userRating == 0.0
                      ? "Tap to rate / रेटिंग चुनें (1-5 Stars)"
                      : (ratingTitles[_userRating] ?? "${_userRating.toInt()} Stars"),
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _userRating == 0.0
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Reviewer Name Input
          TextField(
            controller: _reviewNameController,
            decoration: InputDecoration(
              hintText: "Your Name / आपका नाम (e.g. Ramesh Patel)",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Constants.baseColor.withValues(alpha: 0.6)),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Review Text Field
          TextField(
            controller: _reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  "Write your experience (Crop results, packaging, original quality)...",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: Constants.baseColor.withValues(alpha: 0.6)),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Photo Upload Section
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _selectedReviewImages.length >= 5
                    ? null
                    : _pickReviewImages,
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Constants.baseColor, width: 1.2),
                ),
                icon: Icon(Icons.add_photo_alternate_rounded,
                    color: Constants.baseColor, size: 18),
                label: Text(
                  _selectedReviewImages.isEmpty
                      ? "Add Photos"
                      : "Add More (${_selectedReviewImages.length}/5)",
                  style: GoogleFonts.outfit(
                    color: Constants.baseColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Help other farmers with real photos",
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Attached Images Thumbnails
          if (_selectedReviewImages.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedReviewImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final img = _selectedReviewImages[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _buildReviewImage(img,
                            size: 70, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedReviewImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: GestureDetector(
              onTapDown: (_) =>
                  setState(() => _isSubmitReviewPressed = true),
              onTapUp: (_) =>
                  setState(() => _isSubmitReviewPressed = false),
              onTapCancel: () =>
                  setState(() => _isSubmitReviewPressed = false),
              onTap: _isSubmittingReview
                  ? null
                  : () async {
                      if (_userRating < 1.0) {
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                "Please select a star rating (1-5 stars) / कृपया स्टार रेटिंग चुनें"),
                            backgroundColor: const Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        return;
                      }

                      final pId = widget.product?.id.toString() ?? widget.id;
                      if (pId == null) return;

                      setState(() => _isSubmittingReview = true);
                      HapticFeedback.lightImpact();

                      final name = _reviewNameController.text.trim().isNotEmpty
                          ? _reviewNameController.text.trim()
                          : (AuthController.currentName ?? 'Verified Farmer');
                      final comment = _reviewController.text.trim();

                      final newReview = await ReviewService.postReview(
                        productId: pId,
                        userName: name,
                        userPhone: AuthController.currentPhone,
                        rating: _userRating,
                        comment: comment,
                        images: List<String>.from(_selectedReviewImages),
                      );

                      if (mounted) {
                        setState(() {
                          if (newReview != null) {
                            _reviews.insert(0, newReview);
                          }
                          _isSubmittingReview = false;
                          _reviewController.clear();
                          _selectedReviewImages.clear();
                          _userRating = 0.0;
                          FocusScope.of(context).unfocus();
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                "Review posted publicly! Thank you for helping other farmers."),
                            backgroundColor: Constants.baseColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              child: AnimatedScale(
                scale: _isSubmitReviewPressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Container(
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
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isSubmittingReview
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            AppLocalizations.of(context)!.submitReview,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsListSection() {
    double avgRating = 5.0;
    if (_reviews.isNotEmpty) {
      double sum = _reviews.fold(0.0, (prev, r) => prev + r.rating);
      avgRating = sum / _reviews.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.customerReviews,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.black,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFABE3C), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      "${avgRating.toStringAsFixed(1)} / 5.0 (${_reviews.length})",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_isLoadingReviews)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined,
                      size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text(
                    "No reviews yet. Be the first to review this product!",
                    style: GoogleFonts.inter(
                        fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              final initials = review.userName.trim().isNotEmpty
                  ? review.userName.trim()[0].toUpperCase()
                  : 'F';

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              Constants.baseColor.withValues(alpha: 0.12),
                          child: Text(
                            initials,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              color: Constants.baseColor,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      review.userName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: const Color(0xFF1E1E1E),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle_rounded,
                                            size: 10, color: Color(0xFF2E7D32)),
                                        SizedBox(width: 2),
                                        Text(
                                          "Verified",
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatReviewDate(review.createdAt),
                                style: GoogleFonts.inter(
                                    color: Colors.grey[500], fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        _buildRatingStars(review.rating, size: 14),
                      ],
                    ),
                    if (review.comment.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        review.comment,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF333333),
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (review.images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 65,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: review.images.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, imgIdx) {
                            final imgUrl = review.images[imgIdx];
                            return GestureDetector(
                              onTap: () => _openImagePreview(imgUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 65,
                                  height: 65,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _buildReviewImage(imgUrl,
                                      size: 65, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ProductVideoCard extends StatelessWidget {
  final String videoId;
  final bool isShorts;
  const _ProductVideoCard({required this.videoId, this.isShorts = false});

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = "https://img.youtube.com/vi/$videoId/hqdefault.jpg";

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductVideoWebViewScreen(
                videoUrl: "https://www.youtube.com/watch?v=$videoId",
              ),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: isShorts ? 9 / 16 : 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      KskNetworkImage(thumbnailUrl, fit: BoxFit.cover),
                      Container(color: Colors.black.withValues(alpha: 0.25)),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 72,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.video_collection_outlined,
                    color: Constants.baseColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Watch Product Video",
                  style: TextStyle(
                    color: Constants.baseColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProductVideoWebViewScreen extends StatefulWidget {
  final String videoUrl;
  const ProductVideoWebViewScreen({
    super.key,
    required this.videoUrl,
  });

  @override
  State<ProductVideoWebViewScreen> createState() =>
      _ProductVideoWebViewScreenState();
}

class _ProductVideoWebViewScreenState extends State<ProductVideoWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView Error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.videoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: WebViewWidget(controller: _controller),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

