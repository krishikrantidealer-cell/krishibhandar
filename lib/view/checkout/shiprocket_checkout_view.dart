import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kisan_sewa_kendra/controller/auth_controller.dart';
import 'package:kisan_sewa_kendra/controller/cart_controller.dart';
import 'package:kisan_sewa_kendra/controller/constants.dart';
import 'package:kisan_sewa_kendra/view/checkout/order_success_view.dart';
import 'package:kisan_sewa_kendra/shopify/shopify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/services.dart'; // For clipboard operations
import 'package:kisan_sewa_kendra/utils/meta_events.dart';
import 'package:kisan_sewa_kendra/utils/firebase_events.dart';

class ShiprocketCheckoutView extends StatefulWidget {
  final List<CartItem> cartItems;
  final double totalAmount;
  final String? couponCode;
  final Map<String, dynamic>? shippingAddress;
  final double discountAmount;

  const ShiprocketCheckoutView({
    super.key,
    required this.cartItems,
    required this.totalAmount,
    this.couponCode,
    this.shippingAddress,
    this.discountAmount = 0.0,
  });

  @override
  State<ShiprocketCheckoutView> createState() => _ShiprocketCheckoutViewState();
}

class _ShiprocketCheckoutViewState extends State<ShiprocketCheckoutView>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _isRedirecting = false;
  bool _isSuccessLogged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
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

  void _initController() {
    debugPrint("DEBUG: Initializing Shiprocket WebView Controller");

    final cartItemsMapped = widget.cartItems.map((item) {
      // Extract numeric IDs from GIDs if necessary
      final productIdStr = item.productId?.split('/').last ?? '';
      final variantIdStr = item.id.split('/').last;

      // Convert to numeric types for Shiprocket payload
      final productId = int.tryParse(productIdStr);
      final variantId = int.tryParse(variantIdStr);
      final price =
          double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;

      return {
        'id': productId,
        'variant_id': variantId,
        'quantity': item.qty,
        'title': item.title,
        'price': price,
        'image': item.image,
      };
    }).toList();

    final cartJson = jsonEncode(cartItemsMapped);

    final html = '''
   <!DOCTYPE html>
   <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <script>
        window.Shopify = {
          shop: "krishibhandar.com"
        };
      </script>
      <script src="https://fastrr-boost-ui.pickrr.com/assets/js/channels/mobileApp.js"></script>
    </head>
   <body style="margin:0;padding:0;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;">
   
   <div id="loader" style="color:#26842c; font-weight: bold;">Redirecting to checkout...</div>

   <script>
     function startCheckout() {
       try {
         if (typeof window.getOneClickCheckoutUrl === "function") {
           const items = $cartJson;

           const checkoutUrl = window.getOneClickCheckoutUrl({
             items: items,
             domain: "krishibhandar.com",
             webUrl: "krishibhandar.com",
             couponCode: ${widget.couponCode != null ? '"${widget.couponCode}"' : 'null'}
           });

           if (checkoutUrl) {
             window.location.href = checkoutUrl;
           } else {
             document.getElementById('loader').innerHTML = "<h3>Checkout URL generation failed</h3>";
           }
         } else {
           setTimeout(startCheckout, 500);
         }
       } catch (e) {
         document.getElementById('loader').innerHTML = "<h3>Error: " + e.message + "</h3>";
       }
     }

     window.onload = function() {
       startCheckout();
     }
   </script>

   </body>
   </html>
   ''';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          debugPrint('DEBUG: JS Bridge message: ${message.message}');
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
          onPageStarted: (String url) {
            debugPrint("DEBUG: WebView Navigation Started: $url");
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) async {
            debugPrint("DEBUG: WebView Navigation Finished: $url");

            // Inject window.Shopify on every page so Pickrr's shopify.js can find it
            await _controller.runJavaScript('''
              (function() {
                if (!window.Shopify) {
                  window.Shopify = { shop: "krishibhandar.com" };
                  console.log("✅ window.Shopify injected on: " + window.location.href);
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
                "DEBUG: WebView Resource Error: ${error.description} (Code: ${error.errorCode})");
            final failingUrl = error.url;
            if (failingUrl != null &&
                !failingUrl.startsWith('http://') &&
                !failingUrl.startsWith('https://')) {
              debugPrint(
                  "DEBUG: Intercepted custom scheme failure in onWebResourceError: $failingUrl");
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
                      _isRedirecting = true;
                      _isLoading = false;
                    });
                  }
                  await launchUrl(uri,
                      mode: LaunchMode.externalNonBrowserApplication);
                } else {
                  _showInstallMessage(failingUrl);
                  _controller.goBack();
                }

                // Hide the default error screen by loading a clean blank page/loader
                _controller.loadHtmlString("""
                  <!DOCTYPE html><html><body style='display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;margin:0;'>
                    <h3 style='color:#26842c'>Redirecting to payment app...</h3>
                  </body></html>
                """);
              } catch (e) {
                debugPrint(
                    "DEBUG: External App Launch Exception in error handler: $e");
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            debugPrint("DEBUG: WebView Navigation Request: $url");

            // Existing success detection logic
            if (!_isSuccessLogged &&
                (url.contains("/orders/") ||
                    url.contains("order-success") ||
                    url.contains("thank-you") ||
                    url.contains("order_placed") ||
                    url.contains("checkout/success"))) {
              _isSuccessLogged = true;

              double val = widget.totalAmount;
              String txId = Uri.tryParse(url)?.pathSegments.last ??
                  DateTime.now().millisecondsSinceEpoch.toString();

              debugPrint("✅ PAYMENT SUCCESS DETECTED");
              debugPrint("💰 Purchase Value: $val");
              debugPrint("🧾 Transaction ID: $txId");

              // Log Meta & Firebase Events
              try {
                MetaEvents.purchase(totalValue: val);
              } catch (e) {
                debugPrint("Error logging Meta Purchase: $e");
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

              // Extract order number if available
              String orderNum = txId;
              if (url.contains('/orders/')) {
                try {
                  final parts = url.split('/orders/');
                  if (parts.length > 1) {
                    orderNum =
                        parts[1].split('?')[0].split('/')[0].toUpperCase();
                  }
                } catch (_) {}
              }

              _handleSuccess(orderNum, url);
              return NavigationDecision.prevent;
            }

            // Detect payment app schemes (UPI, intent, known payment domains) and launch directly.
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              debugPrint(
                  "DEBUG: Detected External Scheme, Attempting Launch: $url");
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
                      _isRedirecting = true;
                      _isLoading = false;
                    });
                  }
                  await launchUrl(uri,
                      mode: LaunchMode.externalNonBrowserApplication);
                } else {
                  _showInstallMessage(url);
                }
              } catch (e) {
                debugPrint("DEBUG: External App Launch Exception: $e");
              }
              return NavigationDecision.prevent;
            }

            // Default navigation for http/https URLs.
            return NavigationDecision.navigate;
          },
        ),
      );

    _controller.loadHtmlString(html);
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

  void _handleSuccess(String orderNumber, String successUrl) async {
    final paymentId = _resolvePaymentId(successUrl);
    debugPrint(
        "DEBUG: Success Pattern Detected. Clearing Cart for Order: $orderNumber ($paymentId)");
    await CartController.clearCart();

    // 1. Try to sync customer from the Shopify order (works when URL has /orders/<id>)
    await AuthController.syncCustomerFromOrder(orderNumber);

    // 2. Fallback: if customer ID still not saved, sync using phone from shipping address.
    //    This handles cases where Shiprocket's success URL is just "thank-you" with no order ID.
    final existingId = await AuthController.getShopifyCustomerId();
    if (existingId == null) {
      final phone = widget.shippingAddress?['phone']?.toString() ??
          await AuthController.getSavedPhone();
      if (phone != null && phone.isNotEmpty) {
        // Normalize to 10-digit
        final normalized = phone.replaceAll(RegExp(r'[^\d]'), '');
        final digits = normalized.length > 10
            ? normalized.substring(normalized.length - 10)
            : normalized;
        if (digits.length == 10) {
          debugPrint('DEBUG: Fallback — syncing customer by phone: $digits');
          await AuthController.syncWithShopify(digits);
        }
      }
    }

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
  }

  Future<void> _processNativeCod() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isRedirecting = true;
      });
    }

    try {
      final customerId = await AuthController.getShopifyCustomerId();
      final email = await AuthController.getSavedEmail();
      final phone = await AuthController.getSavedPhone();

      // Use the address passed from cart, or a minimal fallback
      final Map<String, dynamic> address = Map<String, dynamic>.from(
        widget.shippingAddress ?? {},
      );
      if (address['phone'] == null || address['phone'].toString().isEmpty) {
        address['phone'] = phone ?? '';
      }

      final List<Map<String, dynamic>> items = widget.cartItems.map((item) {
        final price =
            double.tryParse(item.price.replaceAll(RegExp(r'[^\d.]'), '')) ??
                0.0;
        return {
          'variant_id': item.id,
          'quantity': item.qty,
          'price': price,
        };
      }).toList();

      final res = await ShopifyAPI.createOrder(
        customerId: customerId,
        email: email,
        lineItems: items,
        shippingAddress: address,
        totalAmount: widget.totalAmount,
        discountCode: widget.couponCode,
        discountAmount:
            widget.discountAmount > 0 ? widget.discountAmount : null,
        isCod: true,
      );

      if (res['order'] != null) {
        final orderNum =
            res['order']['name']?.toString().replaceAll('#', '') ?? 'CONFIRMED';
        debugPrint('✅ Native COD order created: $orderNum');
        await CartController.clearCart();
        
        // Sync customer details from order
        await AuthController.syncCustomerFromOrder(orderNum);

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderSuccessView(
                orderNumber: orderNum,
                totalAmount: widget.totalAmount,
                paymentId: "Cash on Delivery",
              ),
            ),
          );
        }
      } else {
        final errMsg = res['error']?.toString() ?? 'Unknown error';
        debugPrint('❌ Native COD order failed: $errMsg');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('COD Order failed: $errMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Exception in _processNativeCod: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('COD Order error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRedirecting = false;
        });
      }
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
            style: TextStyle(
                color: Constants.baseColor, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading && !_isRedirecting)
              const Center(
                child: CircularProgressIndicator(color: Color(0xff26842c)),
              ),
          ],
        ),
      ),
    );
  }
}
