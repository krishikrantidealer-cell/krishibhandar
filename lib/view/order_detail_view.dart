import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../model/order_model.dart';
import '../controller/constants.dart';
import '../shopify/shopify.dart';
import '../components/network_image.dart';
import '../controller/cart_controller.dart';
import '../controller/routers.dart';
import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import 'cart_view.dart';
import 'support_view.dart';

class OrderDetailView extends StatefulWidget {
  final OrderModel order;
  const OrderDetailView({super.key, required this.order});

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  late OrderModel _currentOrder;
  bool _isLoading = false;

  // Press state for Phase 2 Button Polish
  bool _isReorderPressed = false;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _refreshOrder();
  }

  Future<void> _refreshOrder() async {
    setState(() => _isLoading = true);
    try {
      final data = await ShopifyAPI.getOrderFullDetails(widget.order.id);
      if (data.isNotEmpty && mounted) {
        OrderModel freshOrder = OrderModel.fromJson(data);

        // Preserve images from initial order if fresh data is missing them
        for (var i = 0; i < freshOrder.lineItems.length; i++) {
          if (freshOrder.lineItems[i].image == null ||
              freshOrder.lineItems[i].image!.isEmpty) {
            // Find same item in initial order
            final initialItem = widget.order.lineItems
                .where((li) =>
                    li.title == freshOrder.lineItems[i].title &&
                    li.variantTitle == freshOrder.lineItems[i].variantTitle)
                .firstOrNull;

            if (initialItem != null && initialItem.image != null) {
              freshOrder.lineItems[i] = LineItem(
                title: freshOrder.lineItems[i].title,
                quantity: freshOrder.lineItems[i].quantity,
                price: freshOrder.lineItems[i].price,
                variantTitle: freshOrder.lineItems[i].variantTitle,
                image: initialItem.image,
                variantId: freshOrder.lineItems[i].variantId,
                productId: freshOrder.lineItems[i].productId,
                totalDiscount: freshOrder.lineItems[i].totalDiscount,
              );
            }
          }
        }

        setState(() {
          _currentOrder = freshOrder;
        });
      }
    } catch (e) {
      debugPrint("Refresh detail error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: Constants.baseColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)!.orderSummary,
          style: GoogleFonts.outfit(
              color: Constants.baseColor,
              fontWeight: FontWeight.w800,
              fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading && _currentOrder.shippingAddress == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  _buildOrderInfoSection(),
                  const SizedBox(height: 16),
                  _buildTrackingTimeline(),
                  const SizedBox(height: 16),
                  _buildItemList(),
                  const SizedBox(height: 16),
                  _buildBillSummary(),
                  const SizedBox(height: 16),
                  _buildHelpAction(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildTrackingTimeline() {
    String status = _currentOrder.trackingStatus;
    bool isCancelled = status == 'Cancelled';

    List<Map<String, dynamic>> stages = [
      {
        'title': AppLocalizations.of(context)!.orderPlaced,
        'key': 'placed',
        'active': true,
        'icon': Icons.check_circle_outline,
      },
      {
        'title': AppLocalizations.of(context)!.processing,
        'key': 'processing',
        'active': _currentOrder.confirmed ||
            ['Shipped', 'Out for Delivery', 'Delivered', 'Completed']
                .contains(status),
        'icon': Icons.inventory_2_outlined,
      },
      {
        'title': AppLocalizations.of(context)!.shipped,
        'key': 'shipped',
        'active': ['Shipped', 'Out for Delivery', 'Delivered', 'Completed']
            .contains(status),
        'icon': Icons.local_shipping_outlined,
      },
      {
        'title': AppLocalizations.of(context)!.delivered,
        'key': 'delivered',
        'active': ['Delivered', 'Completed'].contains(status),
        'icon': Icons.task_alt,
      },
    ];

    if (isCancelled) {
      stages = [
        {
          'title': AppLocalizations.of(context)!.orderPlaced,
          'active': true,
          'icon': Icons.check_circle_outline
        },
        {
          'title': AppLocalizations.of(context)!.cancelled,
          'active': true,
          'isError': true,
          'icon': Icons.cancel_outlined
        },
      ];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.trackOrder,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Constants.baseColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),
          Column(
            children: List.generate(stages.length, (index) {
              final stage = stages[index];
              bool isActive = stage['active'];
              bool isError = stage['isError'] ?? false;
              bool isLast = index == stages.length - 1;
              Color activeColor = isError ? Colors.red : const Color(0xFF2E7D32);

              return IntrinsicHeight(
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? activeColor.withOpacity(0.1)
                                : Colors.grey[50],
                          ),
                          child: Icon(
                            stage['icon'],
                            size: 16,
                            color: isActive ? activeColor : Colors.grey[300],
                          ),
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? activeColor.withOpacity(0.2)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stage['title'],
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isActive
                                        ? (isError
                                            ? Colors.red
                                            : const Color(0xFF1E1E1E))
                                        : Colors.grey[400])),
                            if (isActive && !isLast && !isError)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                    AppLocalizations.of(context)!
                                        .statusUpdatedRecently,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          if (_currentOrder.orderStatusUrl != null &&
              _currentOrder.orderStatusUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final url = Uri.parse(_currentOrder.orderStatusUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(AppLocalizations.of(context)!.trackOnShopify),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.baseColor.withOpacity(0.05),
                  foregroundColor: Constants.baseColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.orderInfo,
                  style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Constants.baseColor,
                      letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Constants.baseColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("#${_currentOrder.orderNumber}",
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Constants.baseColor)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _infoRow(
              Icons.calendar_today_rounded,
              AppLocalizations.of(context)!.placedOn,
              _currentOrder.formattedDate),
          const SizedBox(height: 16),
          _infoRow(
              Icons.payment_rounded,
              AppLocalizations.of(context)!.payment,
              _currentOrder.financialStatus.toUpperCase() == 'PENDING'
                  ? 'COD'
                  : _currentOrder.financialStatus),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(AppLocalizations.of(context)!.yourOrderItems,
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Constants.baseColor,
                    letterSpacing: 0.5)),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _currentOrder.lineItems.length,
            separatorBuilder: (_, __) => Divider(
                height: 1, indent: 20, endIndent: 20, color: Colors.grey[50]),
            itemBuilder: (context, index) {
              final item = _currentOrder.lineItems[index];
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[100]!)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item.image != null
                            ? KskNetworkImage(item.image!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey[50],
                                child: Icon(Icons.shopping_bag_outlined,
                                    color: Colors.grey[200])),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E1E1E))),
                          const SizedBox(height: 6),
                          Text(
                              "Qty: ${item.quantity} • ${item.variantTitle ?? 'Standard'}",
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text("${Constants.inr}${item.price}",
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1E1E))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.billSummary,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Constants.baseColor,
                  letterSpacing: 0.5)),
          const SizedBox(height: 24),
          _billRow(AppLocalizations.of(context)!.itemTotal,
              _currentOrder.subtotalPrice ?? '0.00'),
          const SizedBox(height: 14),
          _billRow(AppLocalizations.of(context)!.deliveryCharge,
              _currentOrder.totalShipping ?? 'FREE',
              isFree: _currentOrder.totalShipping == '0.00' ||
                  _currentOrder.totalShipping == null),
          const SizedBox(height: 14),
          _billRow(AppLocalizations.of(context)!.handlingFee, "0.00"),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.grandTotal,
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E1E1E))),
              Text("${Constants.inr}${_currentOrder.totalPrice}",
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Constants.baseColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHelpAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Routers.goTO(context, toBody: const SupportView());
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Color(0xFFEEEEEE)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(Icons.headset_mic_rounded,
                size: 18, color: Constants.baseColor),
            label: Text(AppLocalizations.of(context)!.needHelp,
                style: GoogleFonts.outfit(
                    color: const Color(0xFF1E1E1E),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
          const SizedBox(height: 20),
          Text(
            AppLocalizations.of(context)!.paidVia(
                _currentOrder.financialStatus.toUpperCase() == 'PENDING'
                    ? 'COD'
                    : _currentOrder.financialStatus.toUpperCase()),
            style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[300],
                letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCancelOrder() async {
    String? selectedReason;
    final reasons = [
      AppLocalizations.of(context)!.reasonChangedMind,
      AppLocalizations.of(context)!.reasonMistake,
      AppLocalizations.of(context)!.reasonBetterPrice,
      AppLocalizations.of(context)!.reasonLongTime,
      AppLocalizations.of(context)!.reasonCoupon,
      AppLocalizations.of(context)!.reasonOther,
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context)!.cancelOrder,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E1E1E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.cancellationReason,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              ...reasons.map((reason) => InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => selectedReason = reason);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selectedReason == reason
                              ? Colors.red
                              : const Color(0xFFF0F0F0),
                        ),
                        color: selectedReason == reason
                            ? Colors.red.withOpacity(0.05)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              reason,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: selectedReason == reason
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selectedReason == reason
                                    ? Colors.red
                                    : const Color(0xFF1E1E1E),
                              ),
                            ),
                          ),
                          if (selectedReason == reason)
                            const Icon(Icons.check_circle_rounded,
                                size: 20, color: Colors.red),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.goBack,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedReason == null
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context, true);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor: Colors.grey[100],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.cancelOrder,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        setState(() => _isLoading = true);
        final success = await ShopifyAPI.cancelOrder(widget.order.id);
        if (success) {
          if (mounted) {
            // Immediately update local state so the Cancel button hides at once,
            // without waiting for _refreshOrder() to get the updated API response.
            setState(() {
              _currentOrder = _currentOrder.copyWith(
                cancelledAt: DateTime.now().toIso8601String(),
                financialStatus: 'voided',
              );
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.cancelSuccess),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Also refresh from API in background to get true server state
            _refreshOrder();
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.cancelFail),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() => _isLoading = false);
          }
        }
      }
    });
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, -5))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentOrder.isCancellable) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _handleCancelOrder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: BorderSide(
                        color: Colors.red.withOpacity(0.2), width: 1.5),
                    backgroundColor: Colors.red.withOpacity(0.02),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.red),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cancel_outlined, size: 16),
                            const SizedBox(width: 8),
                            Text(AppLocalizations.of(context)!.cancelOrder,
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isReorderPressed = true),
                onTapUp: (_) => setState(() => _isReorderPressed = false),
                onTapCancel: () => setState(() => _isReorderPressed = false),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  final messenger = ScaffoldMessenger.of(context);
                  for (var item in _currentOrder.lineItems) {
                    if (item.variantId != null) {
                      await CartController.addToCart(
                        variantId: item.variantId!,
                        qty: item.quantity,
                        title: item.title,
                        price: item.price,
                        image: item.image,
                        variantTitle: item.variantTitle ?? '',
                      );
                    }
                  }
                  messenger.showSnackBar(const SnackBar(
                      content: Text("Order items added to bag")));
                  Routers.goTO(context, toBody: const CartView());
                },
                child: AnimatedScale(
                  scale: _isReorderPressed ? 0.97 : 1.0,
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
                          color: const Color(0xFF2E7D32).withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.reorder,
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ],
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

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.grey[400]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1E1E))),
      ],
    );
  }

  Widget _billRow(String label, String value, {bool isFree = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600])),
        Text(isFree ? "FREE" : "${Constants.inr}$value",
            style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isFree ? const Color(0xFF2E7D32) : const Color(0xFF1E1E1E))),
      ],
    );
  }
}
