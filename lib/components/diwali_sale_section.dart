import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../model/product_model.dart';
import '../shopify/shopify.dart';
import 'network_image.dart';
import '../view/product_view.dart';
import '../view/collection_view.dart';
import '../controller/routers.dart';
import 'diwali_countdown.dart';

class DiwaliSaleSection extends StatefulWidget {
  const DiwaliSaleSection({Key? key}) : super(key: key);

  @override
  State<DiwaliSaleSection> createState() => _DiwaliSaleSectionState();
}

class _DiwaliSaleSectionState extends State<DiwaliSaleSection>
    with SingleTickerProviderStateMixin {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  late AnimationController _pulseController;
  late PageController _pageController;
  Timer? _carouselTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _fetchDiwaliProducts();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchDiwaliProducts() async {
    final products = await Shopify.getProductsByCollectionHandle(
      context,
      handle: 'diwali-dhamaka-sale',
      limit: 12,
    );

    if (mounted) {
      setState(() {
        _products = products;
        _isLoading = false;
      });
      _startAutoCarousel();
    }
  }

  void _startAutoCarousel() {
    _carouselTimer?.cancel();
    final pageCount = (_products.length / 4).ceil();
    if (pageCount <= 1) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || !_pageController.hasClients) return;
      final pageCount = (_products.length / 4).ceil();
      if (pageCount <= 1) return;
      final nextPage = (_currentPage + 1) % pageCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseAutoCarousel() {
    _carouselTimer?.cancel();
  }

  void _resumeAutoCarousel() {
    _startAutoCarousel();
  }

  void _openCollectionView() {
    if (_products.isNotEmpty && _products.first.collectionId != null) {
      Routers.goTO(
        context,
        toBody: CollectionView(
          collectionId: _products.first.collectionId!,
          title: "Diwali Dhamaka Sale",
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DiwaliSaleController.instance.isSaleActive) {
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFA51F57))),
      );
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    final int pageCount = (_products.length / 4).ceil();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4A0E3C), // Deep Plum / Burgundy
            Color(0xFF6B1242), // Rich Festive Wine
            Color(0xFF4A0E3C), // Deep Plum
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF5C15D).withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B0B35).withOpacity(0.4),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Painter for Festive Fireworks & Kandil Line Art
          Positioned.fill(
            child: CustomPaint(
              painter: _FestiveBackgroundPainter(animation: _pulseController),
            ),
          ),

          Column(
            children: [
              // 1. CENTERED FESTIVE HEADER
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  children: [
                    // Top Row: Diya (left), FESTIVE OFFERS Pill (center), View All (right)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Diya with glowing flame animation
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF5C15D).withOpacity(
                                      0.3 + 0.4 * _pulseController.value,
                                    ),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text('🪔', style: TextStyle(fontSize: 18)),
                            );
                          },
                        ),

                        // Center: FESTIVE OFFERS Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B0524).withOpacity(0.7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFF5C15D).withOpacity(0.7),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                "✦ ",
                                style: TextStyle(
                                  color: Color(0xFFF5C15D),
                                  fontSize: 9,
                                ),
                              ),
                              Text(
                                "FESTIVE OFFERS",
                                style: TextStyle(
                                  color: Color(0xFFF5C15D),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                " ✦",
                                style: TextStyle(
                                  color: Color(0xFFF5C15D),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: View All Button
                        InkWell(
                          onTap: _openCollectionView,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "View All",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Main Heading: Diwali Dhamaka Sale (Centered)
                    const Text(
                      "Diwali Dhamaka Sale",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        fontFamily: 'serif',
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Color(0xFFF5C15D),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Gold flourish line under heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                const Color(0xFFF5C15D).withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "✦ 🪔 ✦",
                            style: TextStyle(
                              color: Color(0xFFF5C15D),
                              fontSize: 9,
                            ),
                          ),
                        ),
                        Container(
                          width: 40,
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF5C15D).withOpacity(0.8),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Centered Countdown Timer Pill
                    AnimatedBuilder(
                      animation: DiwaliSaleController.instance,
                      builder: (context, child) {
                        return _DiwaliHeaderCountdownRow(
                          time: DiwaliSaleController.instance.remainingTime,
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    // Centered Subtitle Ribbon
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFEFA6),
                            Color(0xFFF5C15D),
                            Color(0xFFFFEFA6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF5C15D).withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text("✨ ", style: TextStyle(fontSize: 10)),
                          Text(
                            "Special festive offers just for you",
                            style: TextStyle(
                              color: Color(0xFF3B0B35),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(" ✨", style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. 2x2 HORIZONTAL PRODUCT CARDS GRID PAGEVIEW
              SizedBox(
                height: 272,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is ScrollStartNotification) {
                      _pauseAutoCarousel();
                    } else if (notification is ScrollEndNotification) {
                      _resumeAutoCarousel();
                    }
                    return false;
                  },
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: pageCount,
                    itemBuilder: (context, pageIndex) {
                      final startIndex = pageIndex * 4;
                      final pageProducts =
                          _products.skip(startIndex).take(4).toList();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            if (pageProducts.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: _PremiumDiwaliProductCard(
                                      product: pageProducts[0],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (pageProducts.length > 1)
                                    Expanded(
                                      child: _PremiumDiwaliProductCard(
                                        product: pageProducts[1],
                                      ),
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                            const SizedBox(height: 8),
                            if (pageProducts.length > 2)
                              Row(
                                children: [
                                  Expanded(
                                    child: _PremiumDiwaliProductCard(
                                      product: pageProducts[2],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (pageProducts.length > 3)
                                    Expanded(
                                      child: _PremiumDiwaliProductCard(
                                        product: pageProducts[3],
                                      ),
                                    )
                                  else
                                    const Expanded(child: SizedBox()),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 3. PAGE INDICATORS
              if (pageCount > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFFF5C15D)
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),

              // 4. BOTTOM PREMIUM GOLD CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                child: InkWell(
                  onTap: _openCollectionView,
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFEFA6),
                              Color(0xFFF5C15D),
                              Color(0xFFE5A83B),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF5C15D).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.shopping_cart_rounded,
                              color: Color(0xFF3B0B35),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "SHOP ALL DIWALI OFFERS",
                              style: TextStyle(
                                color: Color(0xFF3B0B35),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Color(0xFF3B0B35),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (bounds) {
                                  return LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.0),
                                      Colors.white.withOpacity(0.35),
                                      Colors.white.withOpacity(0.0),
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                  ).createShader(Rect.fromLTWH(
                                    -bounds.width +
                                        (_pulseController.value *
                                            bounds.width *
                                            2),
                                    0,
                                    bounds.width,
                                    bounds.height,
                                  ));
                                },
                                child: Container(color: Colors.transparent),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumDiwaliProductCard extends StatefulWidget {
  final ProductModel product;
  const _PremiumDiwaliProductCard({Key? key, required this.product})
      : super(key: key);

  @override
  State<_PremiumDiwaliProductCard> createState() =>
      _PremiumDiwaliProductCardState();
}

class _PremiumDiwaliProductCardState extends State<_PremiumDiwaliProductCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    double sellingPrice = 0.0;
    double compareAtPrice = 0.0;
    int discount = 0;
    double savingsAmount = 0.0;

    if (widget.product.variants.isNotEmpty) {
      final v = widget.product.variants.first;
      sellingPrice = double.tryParse(v.price) ?? 0.0;
      compareAtPrice = double.tryParse(v.compareAtPrice ?? '0') ?? 0.0;

      if (compareAtPrice > sellingPrice && sellingPrice > 0) {
        savingsAmount = compareAtPrice - sellingPrice;
        discount = ((savingsAmount / compareAtPrice) * 100).round();
      }
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        Routers.goTO(context, toBody: ProductView(product: widget.product));
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: 130,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFF5C15D).withOpacity(0.5),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Row(
                children: [
                  // Left section: Image Area (~38% width)
                  SizedBox(
                    width: 65,
                    child: Container(
                      height: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                      child: KskNetworkImage(
                        widget.product.images.isNotEmpty
                            ? widget.product.images.first
                            : '',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Subtle divider
                  Container(
                    width: 0.5,
                    height: double.infinity,
                    color: Colors.grey.shade200,
                  ),

                  // Right section: Details Area
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(7.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Title
                          Text(
                            widget.product.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E1E1E),
                              height: 1.15,
                            ),
                          ),

                          // Price Row
                          if (sellingPrice > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    "₹${sellingPrice.toStringAsFixed(0)}",
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF3B0B35),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (discount > 0)
                                    Text(
                                      "₹${compareAtPrice.toStringAsFixed(0)}",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          // Savings Tag
                          if (savingsAmount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFA5D6A7),
                                  width: 0.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "🌱 You Save ₹${savingsAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                            ),

                          // VIEW DEAL Button
                          Container(
                            width: double.infinity,
                            height: 23,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6B1242), Color(0xFF4A0E3C)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A0E3C).withOpacity(0.25),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text(
                                  "VIEW DEAL",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Discount Badge (Top-left of left section)
              if (discount > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2.5,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9E0B42), // Deep festive magenta/red
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      "$discount% OFF",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
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

class _DiwaliHeaderCountdownRow extends StatelessWidget {
  final Duration time;
  const _DiwaliHeaderCountdownRow({Key? key, required this.time})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final days = time.inDays;
    final hours = time.inHours.remainder(24);
    final mins = time.inMinutes.remainder(60);
    final secs = time.inSeconds.remainder(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2B0524).withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFFF5C15D).withOpacity(0.7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: const [
                Icon(Icons.timer_outlined, color: Color(0xFFF5C15D), size: 14),
                SizedBox(width: 4),
                Text(
                  "SALE ENDS IN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            _DiwaliHeaderTimeBox(value: days, label: 'DAYS'),
            const SizedBox(width: 4),
            _DiwaliHeaderTimeBox(value: hours, label: 'HOURS'),
            const SizedBox(width: 4),
            _DiwaliHeaderTimeBox(value: mins, label: 'MINS'),
            const SizedBox(width: 4),
            _DiwaliHeaderTimeBox(value: secs, label: 'SECS'),
          ],
        ),
      ),
    );
  }
}

class _DiwaliHeaderTimeBox extends StatelessWidget {
  final int value;
  final String label;
  const _DiwaliHeaderTimeBox({Key? key, required this.value, required this.label})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF3B0B35).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFF5C15D).withOpacity(0.6),
          width: 0.8,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Text(
              value.toString().padLeft(2, '0'),
              key: ValueKey<int>(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFFFD987),
              fontSize: 7.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _FestiveBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  _FestiveBackgroundPainter({required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final goldStroke = Paint()
      ..color = const Color(0xFFF5C15D).withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final goldFill = Paint()
      ..color = const Color(0xFFF5C15D).withOpacity(0.3);

    // 1. Top-Left Fireworks
    _drawFirework(canvas, const Offset(35, 45), 18, animation.value, goldStroke);

    // 2. Top-Right Fireworks & Hanging Lantern (Kandil)
    _drawFirework(canvas, Offset(size.width - 35, 45), 18, 1.0 - animation.value, goldStroke);
    _drawLantern(canvas, Offset(size.width - 25, 0), 28, goldStroke, goldFill);

    // 3. Bottom Fireworks
    _drawFirework(canvas, Offset(25, size.height - 35), 14, animation.value, goldStroke);
    _drawFirework(canvas, Offset(size.width - 25, size.height - 35), 14, 1.0 - animation.value, goldStroke);

    // 4. Subtle Shimmer Line Sweep across container
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.06),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(
        -size.width + (animation.value * size.width * 2),
        0,
        size.width,
        size.height,
      ));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);
  }

  void _drawFirework(
    Canvas canvas,
    Offset center,
    double radius,
    double anim,
    Paint stroke,
  ) {
    for (int i = 0; i < 8; i++) {
      double angle = i * math.pi / 4;
      double r1 = 4 + anim * 3;
      double r2 = radius + anim * 4;
      canvas.drawLine(
        Offset(
          center.dx + math.cos(angle) * r1,
          center.dy + math.sin(angle) * r1,
        ),
        Offset(
          center.dx + math.cos(angle) * r2,
          center.dy + math.sin(angle) * r2,
        ),
        stroke,
      );
    }
  }

  void _drawLantern(
    Canvas canvas,
    Offset start,
    double length,
    Paint stroke,
    Paint fill,
  ) {
    canvas.drawLine(start, Offset(start.dx, start.dy + length), stroke);
    Path path = Path();
    Offset c = Offset(start.dx, start.dy + length + 6);
    path.moveTo(c.dx, c.dy - 6);
    path.lineTo(c.dx + 5, c.dy);
    path.lineTo(c.dx, c.dy + 6);
    path.lineTo(c.dx - 5, c.dy);
    path.close();
    canvas.drawPath(path, stroke);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(covariant _FestiveBackgroundPainter oldDelegate) => true;
}
