import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../components/order/order_card.dart';
import '../controller/auth_controller.dart';
import '../controller/constants.dart';
import '../controller/routers.dart';
import '../l10n/app_localizations.dart';
import '../model/order_model.dart';
import '../services/bhandar_api_service.dart';
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
  bool _isStartShoppingPressed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Constants.authController.addListener(_onAuthChanged);
    _fetchOrders();
  }

  void _onAuthChanged() {
    if (mounted) {
      _fetchOrders();
    }
  }

  @override
  void dispose() {
    Constants.authController.removeListener(_onAuthChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    var customerId = await AuthController.getCustomerId();
    final phone = await AuthController.getSavedPhone();

    // Auto-heal missing customer ID if phone is saved
    if (customerId == null || customerId.isEmpty || customerId == "null") {
      if (phone != null && phone.isNotEmpty) {
        if (mounted) setState(() => _isLoadingOrders = true);
        await AuthController.syncCustomer(phone);
        customerId = await AuthController.getCustomerId();
      }
    }

    if (customerId == null || customerId.isEmpty || customerId == "null") {
      if (mounted) {
        setState(() {
          _orders = [];
          _isLoadingOrders = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isLoadingOrders = true);
    try {
      final orderData = await BhandarApiService.getCustomerOrders(customerId);
      if (mounted) {
        setState(() {
          _orders = orderData.map((e) {
            if (e is OrderModel) return e;
            return OrderModel.fromJson(Map<String, dynamic>.from(e as Map));
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("OrderView fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }
  }

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
      // Completed / Delivered
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
                _buildHeader(),
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
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E88E5).withValues(alpha: 0.02),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0F9D8A).withValues(alpha: 0.02),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final loc = AppLocalizations.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
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
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
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
              loc != null ? loc.myOrders : "My Orders",
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
                color: Colors.white.withValues(alpha: 0.85),
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(TabController controller) {
    final loc = AppLocalizations.of(context);
    final filters = [
      loc != null ? loc.allOrders : "All",
      loc != null ? loc.ongoing : "Ongoing",
      loc != null ? loc.delivered : "Delivered",
      loc != null ? loc.cancelled : "Cancelled",
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
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) => _buildShimmer(),
      );
    }

    if (filteredOrders.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchOrders,
        color: Constants.baseColor,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildEmptyOrders(),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      color: Constants.baseColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return OrderCard(
            order: order,
            onRefreshRequired: _fetchOrders,
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Constants.shimmer(height: 18, width: 90),
              Constants.shimmer(height: 18, width: 60),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Constants.shimmer(height: 40, width: 40),
              const SizedBox(width: 8),
              Constants.shimmer(height: 40, width: 40),
              const SizedBox(width: 8),
              Constants.shimmer(height: 40, width: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.shopping_bag_outlined,
                    size: 50, color: Constants.baseColor.withValues(alpha: 0.3)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Orders Yet",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You haven't placed any orders yet.\nExplore our catalog and place your first order.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
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
                  height: 44,
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
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Text(
                      "Start Shopping",
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
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
}
