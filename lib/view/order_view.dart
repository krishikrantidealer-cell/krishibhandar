import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controller/constants.dart';
import '../controller/auth_controller.dart';
import '../shopify/shopify.dart';
import '../model/order_model.dart';
import 'order_detail_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kisan_sewa_kendra/components/network_image.dart';
import '../controller/cart_controller.dart';
import '../controller/routers.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'cart_view.dart';
import 'home_view.dart';

class OrderView extends StatefulWidget {
  const OrderView({super.key});

  @override
  State<OrderView> createState() => _OrderViewState();
}

class _OrderViewState extends State<OrderView>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<OrderModel> _orders = [];
  bool _isLoadingOrders = false;
  Timer? _autoRefreshTimer;

  // Press state for Phase 2 Button Polish
  bool _isStartShoppingPressed = false;

  /// Tracks the last successful fetch time to avoid redundant rapid calls.
  DateTime? _lastFetchTime;

  /// Minimum interval between auto-refreshes (30 seconds).
  static const _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchOrders();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Restart polling when app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchOrders(); // immediate refresh on resume
      _startAutoRefresh();
    } else if (state == AppLifecycleState.paused) {
      _autoRefreshTimer?.cancel(); // save battery while backgrounded
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_refreshInterval, (_) {
      _fetchOrdersSilently();
    });
  }

  /// Silent fetch — no loading indicator, just update data in-place.
  Future<void> _fetchOrdersSilently() async {
    // Debounce: skip if last fetch was very recent
    if (_lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) <
            const Duration(seconds: 10)) {
      return;
    }
    final customerId = await AuthController.getShopifyCustomerId();
    if (customerId == null) return;
    try {
      final orderData = await ShopifyAPI.getCustomerOrders(customerId);
      if (mounted) {
        setState(() {
          _orders = orderData.map((e) => OrderModel.fromJson(e)).toList();
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (_) {}
  }

  /// Fetch orders using the Shopify customer ID saved after checkout.
  /// No login required — customer ID is set automatically via syncCustomerFromOrder.
  Future<void> _fetchOrders() async {
    var customerId = await AuthController.getShopifyCustomerId();

    // Auto-heal missing customer ID if phone is saved when loading the screen
    if (customerId == null || customerId.isEmpty || customerId == "null") {
      final phone = await AuthController.getSavedPhone();
      if (phone != null && phone.isNotEmpty) {
        if (mounted) setState(() => _isLoadingOrders = true);
        await AuthController.syncWithShopify(phone);
        customerId = await AuthController.getShopifyCustomerId();
      }
    }

    // No customer ID means user hasn't placed an order yet — show empty state.
    if (customerId == null || customerId.isEmpty || customerId == "null") {
      if (mounted) setState(() => _isLoadingOrders = false);
      return;
    }

    if (mounted) setState(() => _isLoadingOrders = true);
    try {
      final orderData = await ShopifyAPI.getCustomerOrders(customerId);
      if (mounted) {
        setState(() {
          _orders = orderData.map((e) => OrderModel.fromJson(e)).toList();
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint("Fetch Orders Error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

  @override
  bool get wantKeepAlive => true;

  List<OrderModel> _filterOrders(int index) {
    if (index == 0) return _orders; // All
    if (index == 1) {
      // Ongoing
      return _orders
          .where((o) =>
              o.trackingStatus != 'Completed' &&
              o.trackingStatus != 'Delivered' &&
              o.trackingStatus != 'Cancelled')
          .toList();
    }
    if (index == 2) {
      // Completed
      return _orders
          .where((o) =>
              o.trackingStatus == 'Completed' ||
              o.trackingStatus == 'Delivered')
          .toList();
    }
    if (index == 3) {
      // Cancelled
      return _orders.where((o) => o.trackingStatus == 'Cancelled').toList();
    }
    return _orders;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
            Column(
              children: [
                _buildAdvancedHeader(),
                Expanded(
                  child: DefaultTabController(
                    length: 4,
                    child: Builder(builder: (context) {
                      final tabController = DefaultTabController.of(context);
                      return Column(
                        children: [
                          _buildFilterChips(tabController),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildOrderList(0),
                                _buildOrderList(1),
                                _buildOrderList(2),
                                _buildOrderList(3),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
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
            child: _blurCircle(250, const Color(0xFF0F9D8A).withOpacity(0.02)),
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

  Widget _buildAdvancedHeader() {
    return Container(
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
              AppLocalizations.of(context)!.myOrders,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              "Track and manage your purchases",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.85),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(TabController controller) {
    final filters = [
      AppLocalizations.of(context)!.allOrders,
      AppLocalizations.of(context)!.ongoing,
      AppLocalizations.of(context)!.delivered,
      AppLocalizations.of(context)!.cancelled
    ];
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: Colors.transparent,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filters.length,
            itemBuilder: (context, index) {
              final isSelected = controller.index == index;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.animateTo(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF1E88E5),
                                Color(0xFF0F9D8A),
                                Color(0xFF2E7D32),
                              ],
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: const Color(0xFF2E7D32),
                              width: 1.2,
                            ),
                    ),
                    child: Center(
                      child: Text(
                        filters[index],
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderList(int filterIndex) {
    final filteredOrders = _filterOrders(filterIndex);

    if (_isLoadingOrders && filteredOrders.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => _buildAdvancedShimmer(),
      );
    }

    if (filteredOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchOrders,
        color: Constants.baseColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: _buildEmptyOrders(),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Constants.baseColor,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) =>
            _buildAdvancedCard(filteredOrders[index]),
      ),
    );
  }

  Widget _buildAdvancedShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Constants.shimmer(height: 20, width: 100),
                Constants.shimmer(height: 20, width: 60),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                Constants.shimmer(height: 50, width: 50),
                const SizedBox(width: 12),
                Constants.shimmer(height: 50, width: 50),
                const SizedBox(width: 12),
                Constants.shimmer(height: 50, width: 50),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetail(OrderModel order) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) =>
            OrderDetailView(order: order),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    ).then((_) => _fetchOrdersSilently());
  }

  Widget _buildAdvancedCard(OrderModel order) {
    String status = order.trackingStatus;
    Color statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToDetail(order),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusIndicator(status, statusColor),
                      Text(
                        "${Constants.inr}${order.totalPrice}",
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.items(order.totalQuantity),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            order.formattedDate,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDynamicProductList(order),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          label: AppLocalizations.of(context)!.details,
                          icon: Icons.info_outline,
                          color: Colors.grey.withOpacity(0.1),
                          textColor: Colors.grey[500]!,
                          onPressed: () => _navigateToDetail(order),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildGradientActionButton(
                          label: AppLocalizations.of(context)!.reorder,
                          icon: Icons.refresh_rounded,
                          onPressed: () async {
                            final scaffoldMessenger =
                                ScaffoldMessenger.of(context);
                            for (var item in order.lineItems) {
                              if (item.variantId != null) {
                                await CartController.addToCart(
                                  variantId: item.variantId!,
                                  productId: item.productId,
                                  qty: item.quantity,
                                  title: item.title,
                                  price: item.price,
                                  image: item.image,
                                  variantTitle: item.variantTitle ?? '',
                                );
                              }
                            }
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                  content: Text(AppLocalizations.of(context)!.itemsAddedToBag)),
                            );
                            if (mounted) {
                              Routers.goTO(context, toBody: const CartView());
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, Color color) {
    IconData icon;
    String statusLower = status.toLowerCase();
    
    if (statusLower.contains('delivered') || statusLower.contains('completed')) {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF43A047);
    } else if (statusLower.contains('cancelled')) {
      icon = Icons.cancel_rounded;
      color = const Color(0xFFE53935);
    } else if (statusLower.contains('shipped')) {
      icon = Icons.local_shipping_rounded;
      color = const Color(0xFF1E88E5);
    } else if (statusLower.contains('pending') || statusLower.contains('processing')) {
      icon = Icons.schedule_rounded;
      color = const Color(0xFFFB8C00);
    } else {
      icon = Icons.info_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicProductList(OrderModel order) {
    final items = order.lineItems;
    const double itemWidth = 36.0;
    const double spacing = 4.0;
    const double totalItemMetric = itemWidth + spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        int maxPossible = (maxWidth / totalItemMetric).floor();
        if (maxPossible < 1) return const SizedBox.shrink();

        int displayCount;
        bool showCounter = items.length > maxPossible;

        if (showCounter) {
          displayCount = maxPossible; // last one will be the counter
        } else {
          displayCount = items.length;
        }

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(displayCount, (index) {
            final bool isLast = showCounter && index == displayCount - 1;
            // If we are showing a counter in the last spot,
            // the number of hidden items is total - (displayCount - 1)
            final int hiddenCount = items.length - (displayCount - 1);

            return Container(
              width: itemWidth,
              height: itemWidth,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isLast
                    ? Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Text(
                            "+$hiddenCount",
                            style: GoogleFonts.inter(
                              color: Colors.grey[600],
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      )
                    : (items[index].image == null || items[index].image!.isEmpty
                        ? Container(
                            color: Colors.grey[50],
                            child: Icon(Icons.shopping_bag_outlined,
                                color: Colors.grey[200], size: 16))
                        : KskNetworkImage(items[index].image!,
                            fit: BoxFit.cover)),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    Color textColor = Colors.white,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        elevation: 0,
        minimumSize: const Size(double.infinity, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: Icon(icon, size: 14),
      label: Text(label,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildGradientActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    bool isPressed = false;
    return StatefulBuilder(
      builder: (context, setBtnState) {
        return GestureDetector(
          onTapDown: (_) => setBtnState(() => isPressed = true),
          onTapUp: (_) => setBtnState(() => isPressed = false),
          onTapCancel: () => setBtnState(() => isPressed = false),
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: AnimatedScale(
            scale: isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 40,
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
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(label,
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('delivered') || status.contains('completed'))
      return const Color(0xFF43A047);
    if (status.contains('cancelled')) return const Color(0xFFE53935);
    if (status.contains('shipped')) return const Color(0xFF1E88E5);
    if (status.contains('pending') || status.contains('processing'))
      return const Color(0xFFFB8C00);
    return Constants.baseColor;
  }



  Widget _buildEmptyOrders() {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.95 + (0.05 * value),
            child: child,
          ),
        );
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(Icons.shopping_bag_outlined,
                      size: 60, color: Constants.baseColor.withOpacity(0.2)),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "No Orders Yet",
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E1E1E)),
              ),
              const SizedBox(height: 12),
              Text(
                "You haven't placed any orders yet.\nStart exploring products and place your first order.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTapDown: (_) => setState(() => _isStartShoppingPressed = true),
                onTapUp: (_) => setState(() => _isStartShoppingPressed = false),
                onTapCancel: () => setState(() => _isStartShoppingPressed = false),
                onTap: () {
                  HapticFeedback.lightImpact();
                  Routers.goNoBack(context, toBody: const MyHomePage());
                },
                child: AnimatedScale(
                  scale: _isStartShoppingPressed ? 0.97 : 1.0,
                  duration: const Duration(milliseconds: 120),
                  child: Container(
                    height: 46,
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
                          color: const Color(0xFF2E7D32).withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Text(
                        "Start Shopping",
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
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
