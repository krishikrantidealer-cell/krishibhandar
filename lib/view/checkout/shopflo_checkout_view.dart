import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../controller/auth_controller.dart';
import '../../controller/cart_controller.dart';
import '../../controller/constants.dart';
import '../../services/attribution_service.dart';
import '../../services/shopflo_service.dart';
import '../../shopify/shopify.dart';
import '../../utils/firebase_events.dart';
import 'order_success_view.dart';

class ShopfloCheckoutView extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? couponCode;
  final Map<String, dynamic>? shippingAddress;
  final double discountAmount;
  final String customerPhone;
  final String? customerEmail;
  final String? initialCheckoutUrl;

  const ShopfloCheckoutView({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    this.couponCode,
    this.shippingAddress,
    this.discountAmount = 0.0,
    required this.customerPhone,
    this.customerEmail,
    this.initialCheckoutUrl,
  });

  @override
  State<ShopfloCheckoutView> createState() => _ShopfloCheckoutViewState();
}

class _ShopfloCheckoutViewState extends State<ShopfloCheckoutView>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _isRedirecting = false;
  bool _isSuccessLogged = false;
  String? _errorMessage;
  String? _checkoutUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();

    if (widget.initialCheckoutUrl != null &&
        widget.initialCheckoutUrl!.isNotEmpty) {
      _checkoutUrl = widget.initialCheckoutUrl;
      _loadCheckoutUrl(_checkoutUrl!);
    } else {
      _initiateShopfloCheckout();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isRedirecting) {
      if (mounted) {
        debugPrint("Returning from payment intent. Popping checkout screen.");
        Navigator.pop(context);
      }
    }
  }

  Future<void> _initiateShopfloCheckout() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customerId = await AuthController.getShopifyCustomerId();
      final attribution = await AttributionService().getAttribution();

      final result = await ShopfloService.createCheckoutToken(
        cartItems: widget.cartItems,
        couponCode: widget.couponCode,
        customerPhone: widget.customerPhone,
        customerEmail: widget.customerEmail,
        customerToken: customerId,
        shippingAddress: widget.shippingAddress,
        attributionParams: attribution,
      );

      if (!mounted) return;

      if (result.isSuccess && result.checkoutUrl != null) {
        _checkoutUrl = result.checkoutUrl;
        _loadCheckoutUrl(_checkoutUrl!);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = result.errorMessage ?? 'Failed to initialize checkout';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing checkout: $e';
      });
    }
  }

  void _loadCheckoutUrl(String url) {
    debugPrint("🛍️ [ShopfloCheckoutView] Loading checkout URL: $url");
    _controller.loadRequest(Uri.parse(url));
  }

  void _showInstallMessage(String url) {
    String appName = "this UPI app";
    if (url.contains("paytm")) appName = "Paytm";
    if (url.contains("phonepe")) appName = "PhonePe";
    if (url.contains("tez") || url.contains("gpay")) appName = "Google Pay";

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please first download $appName to continue."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isPaymentScheme(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.startsWith('upi://') ||
        lowerUrl.startsWith('phonepe://') ||
        lowerUrl.startsWith('paytmmp://') ||
        lowerUrl.startsWith('paytm://') ||
        lowerUrl.startsWith('tez://') ||
        lowerUrl.startsWith('gpay://') ||
        lowerUrl.startsWith('bhim://');
  }

  bool _isSuccessUrl(String url) {
    final lower = url.toLowerCase();

    // 1. Back to cart is NOT success
    if (lower.contains("action=backtocart") ||
        lower.endsWith("/cart") ||
        lower.contains("/cart?")) {
      return false;
    }

    // 2. Direct success URL patterns
    if (lower.contains("checkout/success") ||
        lower.contains("checkout_success") ||
        lower.contains("/orders/") ||
        lower.contains("/order/") ||
        lower.contains("order-success") ||
        lower.contains("order_success") ||
        lower.contains("thank-you") ||
        lower.contains("thank_you") ||
        lower.contains("thankyou") ||
        lower.contains("order_placed") ||
        lower.contains("orderplaced") ||
        lower.contains("order-confirmation") ||
        lower.contains("orderconfirmation") ||
        lower.contains("post-order") ||
        lower.contains("payment/success") ||
        lower.contains("payments/success") ||
        lower.contains("payment-success")) {
      return true;
    }

    // 3. Shopflo thank you / confirmation pages
    if (lower.contains("shopflo.co") &&
        (lower.contains("thank") ||
            lower.contains("success") ||
            lower.contains("confirmed"))) {
      return true;
    }

    // 4. Redirect back to store domain (krishibhandar.com or myshopify.com)
    // after checkout started (and not back to cart or asset file)
    if ((lower.contains("krishibhandar.com") || lower.contains("myshopify.com")) &&
        !lower.contains("checkout.shopflo.co") &&
        !lower.contains("/cart") &&
        !lower.contains("/cdn/") &&
        !lower.contains(".js") &&
        !lower.contains(".css") &&
        !lower.contains(".png") &&
        !lower.contains(".jpg")) {
      return true;
    }

    return false;
  }

  bool _checkAndHandleUrl(String url) {
    // 1. Back to Cart interception
    if (url.contains("action=backToCart") ||
        url.endsWith("/cart") ||
        url.contains("/cart?")) {
      debugPrint("🛍️ [ShopfloCheckoutView] Back to Cart action detected ($url). Popping WebView.");
      if (mounted) {
        Navigator.pop(context);
      }
      return true;
    }

    // 2. Order Success Detection
    if (!_isSuccessLogged && _isSuccessUrl(url)) {
      _isSuccessLogged = true;

      double val = widget.totalAmount;
      String txId = DateTime.now().millisecondsSinceEpoch.toString();

      final uri = Uri.tryParse(url);
      if (uri != null) {
        if (uri.queryParameters.containsKey('order_id')) {
          txId = uri.queryParameters['order_id']!;
        } else if (uri.queryParameters.containsKey('orderId')) {
          txId = uri.queryParameters['orderId']!;
        } else if (uri.queryParameters.containsKey('tokenId')) {
          txId = uri.queryParameters['tokenId']!;
        } else if (uri.pathSegments.isNotEmpty &&
            uri.pathSegments.last.isNotEmpty &&
            uri.pathSegments.last != 'success' &&
            uri.pathSegments.last != 'thank_you') {
          txId = uri.pathSegments.last;
        }
      }

      if (url.contains('/orders/')) {
        try {
          final parts = url.split('/orders/');
          if (parts.length > 1) {
            txId = parts[1].split('?')[0].split('/')[0].toUpperCase();
          }
        } catch (_) {}
      }

      debugPrint("✅ [ShopfloCheckoutView] PAYMENT SUCCESS DETECTED via: $url");
      debugPrint("💰 Purchase Value: $val");
      debugPrint("🧾 Transaction ID: $txId");

      // Attribution tracking (Meta + AppsFlyer)
      try {
        final productIds = widget.cartItems
            .map((item) => item.productId ?? item.id)
            .toList();
        AttributionService.logPurchase(val, productIds);
      } catch (e) {
        debugPrint("Error logging Purchase attribution: $e");
      }

      try {
        final productList = widget.cartItems.map((item) {
          final price = double.tryParse(
                  item.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
              0.0;
          return {
            'id': item.id,
            'name': item.title,
            'price': price,
            'quantity': item.qty,
          };
        }).toList();

        FirebaseEvents.trackPurchase(
          totalAmount: val,
          transactionId: txId,
          productList: productList,
        );
      } catch (e) {
        debugPrint("Error logging Firebase Purchase: $e");
      }

      _handleSuccess(txId, url);
      return true;
    }

    return false;
  }

  void _initController() {
    debugPrint("🛍️ [ShopfloCheckoutView] Initializing WebViewController");

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'ShopfloBridge',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('🛍️ [ShopfloBridge] Message: ${message.message}');
          final msg = message.message.toLowerCase();
          if (msg.contains('success') ||
              msg.contains('order_placed') ||
              msg.contains('completed') ||
              msg.contains('thank_you') ||
              msg.contains('orderplaced')) {
            _checkAndHandleUrl('https://krishibhandar.com/checkout/success');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100;
              });
            }
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) {
              debugPrint("🛍️ [ShopfloCheckoutView] URL Changed: $url");
              _checkAndHandleUrl(url);
            }
          },
          onPageStarted: (String url) {
            debugPrint("🛍️ [ShopfloCheckoutView] Navigation Started: $url");
            if (_checkAndHandleUrl(url)) {
              return;
            }
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            debugPrint("🛍️ [ShopfloCheckoutView] Navigation Finished: $url");
            if (_checkAndHandleUrl(url)) {
              return;
            }

            // Inject window postMessage bridge to capture any Shopflo checkout completion event
            await _controller.runJavaScript('''
              (function() {
                if (!window._shopfloBridgeInjected) {
                  window._shopfloBridgeInjected = true;
                  window.addEventListener('message', function(e) {
                    try {
                      var data = typeof e.data === 'string' ? e.data : JSON.stringify(e.data);
                      if (window.ShopfloBridge) {
                        window.ShopfloBridge.postMessage(data);
                      }
                    } catch(err) {}
                  });
                }
              })();
            ''');

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) async {
            debugPrint(
                "🛍️ [ShopfloCheckoutView] Resource Error: ${error.description} (Code: ${error.errorCode})");
            final failingUrl = error.url;
            if (failingUrl != null &&
                !failingUrl.startsWith('http://') &&
                !failingUrl.startsWith('https://')) {
              debugPrint(
                  "🛍️ [ShopfloCheckoutView] Intercepted custom scheme in onWebResourceError: $failingUrl");
              try {
                String targetUrl = failingUrl;
                if (targetUrl.startsWith('tez://')) {
                  targetUrl = targetUrl.replaceFirst('tez://', 'upi://');
                } else if (targetUrl.startsWith('paytm://')) {
                  targetUrl = targetUrl.replaceFirst('paytm://', 'upi://');
                }

                if (failingUrl.startsWith('intent://')) {
                  String scheme = 'upi';
                  if (failingUrl.contains('#')) {
                    final fragment = failingUrl.split('#').last;
                    final schemeMatch =
                        RegExp(r'scheme=([^;]+)').firstMatch(fragment);
                    if (schemeMatch != null) {
                      scheme = schemeMatch.group(1) ?? 'upi';
                    }
                  }
                  final pathAndQuery =
                      failingUrl.replaceFirst('intent://', '').split('#').first;
                  targetUrl = '$scheme://$pathAndQuery';
                }

                final uri = Uri.parse(targetUrl);
                if (await canLaunchUrl(uri)) {
                  if (mounted) {
                    setState(() {
                      _isRedirecting = _isPaymentScheme(targetUrl);
                      _isLoading = false;
                    });
                  }
                  await launchUrl(uri,
                      mode: LaunchMode.externalNonBrowserApplication);
                } else {
                  _showInstallMessage(failingUrl);
                  _controller.goBack();
                }

                _controller.loadHtmlString("""
                  <!DOCTYPE html><html><body style='display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;'>
                    <h3 style='color:#26842c'>Redirecting to payment app...</h3>
                  </body></html>
                """);
              } catch (e) {
                debugPrint(
                    "🛍️ [ShopfloCheckoutView] External App Launch Exception in error handler: $e");
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            debugPrint("🛍️ [ShopfloCheckoutView] Navigation Request: $url");

            if (_checkAndHandleUrl(url)) {
              return NavigationDecision.prevent;
            }

            // Detect payment app schemes (UPI, intent, known payment schemes)
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              debugPrint(
                  "🛍️ [ShopfloCheckoutView] Detected External Scheme, Attempting Launch: $url");
              try {
                String targetUrl = url;
                if (targetUrl.startsWith('tez://')) {
                  targetUrl = targetUrl.replaceFirst('tez://', 'upi://');
                } else if (targetUrl.startsWith('paytm://')) {
                  targetUrl = targetUrl.replaceFirst('paytm://', 'upi://');
                }

                if (url.startsWith('intent://')) {
                  String scheme = 'upi';
                  if (url.contains('#')) {
                    final fragment = url.split('#').last;
                    final schemeMatch =
                        RegExp(r'scheme=([^;]+)').firstMatch(fragment);
                    if (schemeMatch != null) {
                      scheme = schemeMatch.group(1) ?? 'upi';
                    }
                  }
                  final pathAndQuery =
                      url.replaceFirst('intent://', '').split('#').first;
                  targetUrl = '$scheme://$pathAndQuery';
                }
                final uri = Uri.parse(targetUrl);
                if (await canLaunchUrl(uri)) {
                  if (mounted) {
                    setState(() {
                      _isRedirecting = _isPaymentScheme(targetUrl);
                      _isLoading = false;
                    });
                  }
                  await launchUrl(uri,
                      mode: LaunchMode.externalNonBrowserApplication);
                } else {
                  _showInstallMessage(url);
                }
              } catch (e) {
                debugPrint("🛍️ [ShopfloCheckoutView] External App Launch Exception: $e");
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );
  }

  String _resolvePaymentId(String url) {
    final lower = url.toLowerCase();
    final uri = Uri.tryParse(url);
    final query = uri?.queryParameters ?? {};

    final paymentHint = (query['payment_method'] ??
            query['payment_type'] ??
            query['gateway'] ??
            query['payment_gateway'] ??
            '')
        .toLowerCase();

    if (paymentHint.contains('cod') ||
        paymentHint.contains('cash') ||
        lower.contains('payment_method=cod') ||
        lower.contains('gateway=cod') ||
        lower.contains('cash_on_delivery') ||
        lower.contains('cash-on-delivery')) {
      return "Cash on Delivery";
    }

    return "Online";
  }

  void _handleSuccess(String orderNumber, String successUrl) {
    final paymentId = _resolvePaymentId(successUrl);
    debugPrint(
        "🛍️ [ShopfloCheckoutView] Success Pattern Detected. Navigating to Native OrderSuccessView for Order: $orderNumber ($paymentId)");

    // Instantly blank the webview so the store website never renders on screen
    try {
      _controller.loadHtmlString(
          "<!DOCTYPE html><html><body style='background-color:#ffffff;'></body></html>");
    } catch (_) {}

    // Immediately push the native success view
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderSuccessView(
            orderNumber: orderNumber,
            totalAmount: widget.totalAmount,
            paymentId: paymentId,
          ),
        ),
      );
    }

    // Run cart clearing and order attribution sync in background
    CartController.clearCart();
    final shippingPhone = widget.shippingAddress?['phone']?.toString();
    _runBackgroundSync(orderNumber, shippingPhone);
  }

  Future<void> _runBackgroundSync(
      String orderNumber, String? shippingPhone) async {
    debugPrint('🛍️ [ShopfloCheckoutView] Starting sync for $orderNumber');
    try {
      await ShopifyAPI.updateOrderAttribution(orderNumber);
      await AttributionService().clearAttribution();
    } catch (e) {
      debugPrint("Error updating Shopify order notes: $e");
    }

    try {
      await AuthController.syncCustomerFromOrder(orderNumber);
      final existingId = await AuthController.getShopifyCustomerId();
      if (existingId == null || existingId == "null") {
        final phone = shippingPhone ?? await AuthController.getSavedPhone();
        if (phone != null && phone.isNotEmpty) {
          final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
          final digits = normalized.length > 10
              ? normalized.substring(normalized.length - 10)
              : normalized;
          if (digits.length == 10) {
            debugPrint('🛍️ [ShopfloCheckoutView] Fallback — syncing customer by phone: $digits');
            await AuthController.syncWithShopify(digits);
          }
        }
      }
    } catch (e) {
      debugPrint("Error syncing customer in background: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _controller.canGoBack()) {
          _controller.goBack();
        } else {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            "Secure Checkout",
            style: GoogleFonts.outfit(
              color: Constants.baseColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              } else {
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    color: Constants.baseColor,
                    backgroundColor: Colors.grey[200],
                    minHeight: 2,
                  ),
                )
              : null,
        ),
        body: _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 56, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Unable to load checkout",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _initiateShopfloCheckout,
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                        label: Text(
                          "Retry",
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Constants.baseColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading && !_isRedirecting && _checkoutUrl == null)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Constants.baseColor),
                          const SizedBox(height: 16),
                          Text(
                            "Securing checkout session...",
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
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
