import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../components/network_image.dart';
import '../../controller/auth_controller.dart';
import '../../controller/cart_controller.dart';
import '../../controller/constants.dart';
import '../../services/api_service.dart';
import 'address_view.dart';
import 'order_success_view.dart';

class CheckoutView extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? couponCode;
  final Map<String, dynamic>? shippingAddress;
  final double discountAmount;

  const CheckoutView({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    this.couponCode,
    this.shippingAddress,
    this.discountAmount = 0.0,
  });

  @override
  State<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends State<CheckoutView> {
  late Razorpay _razorpay;
  bool _isLoading = false;
  String _selectedPaymentMethod = 'Razorpay'; // 'Razorpay' or 'COD'
  Map<String, dynamic>? _address;

  @override
  void initState() {
    super.initState();
    _address = widget.shippingAddress;
    _initRazorpay();
    _loadAddressIfEmpty();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> _loadAddressIfEmpty() async {
    if (_address == null || _address!.isEmpty) {
      final saved = await AuthController.getSavedAddress();
      if (mounted) {
        setState(() {
          _address = saved;
        });
      }
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    debugPrint("Razorpay Payment Success: ${response.paymentId} | OrderId: ${response.orderId}");
    await _createOrder(
      paymentMethod: 'Razorpay',
      financialStatus: 'paid',
      razorpayPaymentId: response.paymentId,
      razorpayOrderId: response.orderId,
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Razorpay Payment Error: ${response.code} - ${response.message}");
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Payment failed: ${response.message ?? 'Transaction cancelled'}"),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("Razorpay External Wallet: ${response.walletName}");
  }

  Future<void> _startRazorpayPayment() async {
    setState(() => _isLoading = true);

    try {
      final phone = _address?['phone'] ?? await AuthController.getSavedPhone() ?? '';
      final name = _address?['name'] ?? await AuthController.getSavedName() ?? 'Customer';
      final email = await AuthController.getSavedEmail() ?? '';

      // Amount in paise (1 INR = 100 paise)
      final amountInPaise = (widget.totalAmount * 100).round();

      // Create Razorpay Order on Backend
      final rzpOrder = await ApiService.createRazorpayOrder(
        amount: widget.totalAmount,
      );

      final orderId = rzpOrder?['id']?.toString();

      var options = {
        'key': Constants.razorpayKey,
        'amount': amountInPaise,
        'name': 'Krishi Bhandar',
        'description': 'Order Payment',
        'timeout': 300,
        'prefill': {
          'contact': phone,
          'email': email,
          'name': name,
        },
        'theme': {
          'color': '#26842c',
        },
      };

      if (orderId != null && orderId.isNotEmpty) {
        options['order_id'] = orderId;
      }

      _razorpay.open(options);
    } catch (e) {
      debugPrint("Error opening Razorpay: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error initiating payment: $e"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _createOrder({
    required String paymentMethod,
    required String financialStatus,
    String? razorpayPaymentId,
    String? razorpayOrderId,
  }) async {
    setState(() => _isLoading = true);

    try {
      final phone = _address?['phone'] ?? await AuthController.getSavedPhone() ?? '';
      final name = _address?['name'] ?? await AuthController.getSavedName() ?? 'Customer';
      final email = await AuthController.getSavedEmail() ?? '';
      final customerId = await AuthController.getCustomerId();

      final List<Map<String, dynamic>> items = widget.cartItems.map((item) {
        final price = double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
        return {
          'variant_id': item.id,
          'product_id': item.productId,
          'title': item.title,
          'variant_title': item.variantTitle,
          'quantity': item.qty,
          'price': price,
          'image': item.image,
        };
      }).toList();

      final orderPayload = {
        'customer': {
          'id': customerId,
          'name': name,
          'phone': phone,
          'email': email,
        },
        'line_items': items,
        'shipping_address': _address ?? {},
        'payment_method': paymentMethod,
        'financial_status': financialStatus,
        'total_amount': widget.totalAmount,
        'coupon_code': widget.couponCode,
        'discount_amount': widget.discountAmount,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_order_id': razorpayOrderId,
      };

      final res = await ApiService.createOrder(orderPayload);

      if (res.success && res.data != null) {
        final orderNumber = (res.data!['name'] ?? res.data!['order_number'] ?? res.data!['_id'] ?? 'CONFIRMED').toString();

        await CartController.clearCart();

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => OrderSuccessView(
                orderNumber: orderNumber,
                totalAmount: widget.totalAmount,
                paymentId: razorpayPaymentId ?? 'COD',
              ),
            ),
            (route) => route.isFirst,
          );
        }
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message ?? "Failed to create order. Please try again."),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("Order creation error: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error creating order: $e"),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onProceedToPay() {
    if (_address == null ||
        (_address!['address1'] ?? '').toString().trim().isEmpty ||
        (_address!['pincode'] ?? '').toString().trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please provide a valid delivery address"),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _changeAddress();
      return;
    }

    if (_selectedPaymentMethod == 'Razorpay') {
      _startRazorpayPayment();
    } else {
      _createOrder(
        paymentMethod: 'COD',
        financialStatus: 'pending',
      );
    }
  }

  Future<void> _changeAddress() async {
    final newAddress = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressView(),
      ),
    );

    if (newAddress != null && mounted) {
      setState(() {
        _address = newAddress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Checkout",
          style: GoogleFonts.outfit(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Address Card
                    _buildAddressCard(),
                    const SizedBox(height: 16),

                    // Order Items Summary
                    _buildItemsSummary(),
                    const SizedBox(height: 16),

                    // Payment Method Selector
                    _buildPaymentSelector(),
                    const SizedBox(height: 16),

                    // Bill Summary Card
                    _buildBillSummary(),
                  ],
                ),
              ),
            ),

            // Bottom Pay Button
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    final hasAddress = _address != null &&
        (_address!['address1'] ?? '').toString().isNotEmpty &&
        (_address!['city'] ?? '').toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded, color: Constants.baseColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Delivery Address",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _changeAddress,
                child: Text(
                  hasAddress ? "Change" : "Add Address",
                  style: GoogleFonts.inter(
                    color: Constants.baseColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasAddress) ...[
            Text(
              "${_address!['name'] ?? ''} (${_address!['phone'] ?? ''})",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              "${_address!['address1'] ?? ''}, ${_address!['address2'] ?? ''}\n${_address!['city'] ?? ''}, ${_address!['state'] ?? ''} - ${_address!['pincode'] ?? ''}",
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.4),
            ),
          ] else ...[
            Text(
              "No delivery address selected. Tap 'Add Address' to set up.",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Items in Order (${widget.cartItems.length})",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.cartItems.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = widget.cartItems[index];
              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey.shade100,
                      child: item.image.isNotEmpty
                          ? KskNetworkImage(item.image, fit: BoxFit.cover)
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        if (item.variantTitle.isNotEmpty)
                          Text(
                            item.variantTitle,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                          ),
                        Text(
                          "Qty: ${item.qty}",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${Constants.inr}${item.price}",
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Payment Method",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),

          // Razorpay Option
          _buildPaymentTile(
            title: "Online Payment (Razorpay)",
            subtitle: "UPI, Google Pay, PhonePe, Paytm, Cards, NetBanking",
            value: 'Razorpay',
            icon: Icons.flash_on_rounded,
            badge: "Fast & Secure",
          ),
          const SizedBox(height: 10),

          // COD Option
          _buildPaymentTile(
            title: "Cash on Delivery (COD)",
            subtitle: "Pay cash upon order delivery",
            value: 'COD',
            icon: Icons.payments_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? Constants.baseColor.withOpacity(0.04) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Constants.baseColor : Colors.grey.shade200,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Constants.baseColor : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 12),
            Icon(icon, color: isSelected ? Constants.baseColor : Colors.grey.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isSelected ? Colors.black87 : Colors.grey.shade800,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Constants.baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBillSummary() {
    double subtotal = 0;
    for (var item in widget.cartItems) {
      final price = double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
      subtotal += price * item.qty;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Bill Details",
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildBillRow("Item Total", "${Constants.inr}${subtotal.toStringAsFixed(2)}"),
          if (widget.discountAmount > 0) ...[
            const SizedBox(height: 8),
            _buildBillRow("Discount (${widget.couponCode ?? 'Promo'})", "-${Constants.inr}${widget.discountAmount.toStringAsFixed(2)}", isDiscount: true),
          ],
          const SizedBox(height: 8),
          _buildBillRow("Delivery Fee", "FREE", isFree: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          _buildBillRow("To Pay", "${Constants.inr}${widget.totalAmount.toStringAsFixed(2)}", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildBillRow(String title, String value, {bool isDiscount = false, bool isFree = false, bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500,
            color: isTotal ? Colors.black87 : Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 17 : 14,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: isDiscount || isFree ? Constants.baseColor : (isTotal ? Constants.baseColor : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Total Amount",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
              Text(
                "${Constants.inr}${widget.totalAmount.toStringAsFixed(2)}",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Constants.baseColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _onProceedToPay,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Constants.baseColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        _selectedPaymentMethod == 'Razorpay' ? "Pay with Razorpay" : "Place COD Order",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
