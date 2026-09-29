import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controller/constants.dart';
import '../../controller/cart_controller.dart';
import '../../controller/routers.dart';
import '../../l10n/app_localizations.dart';
import '../../model/order_model.dart';
import '../../view/cart_view.dart';
import '../../view/order_detail_view.dart';
import '../network_image.dart';
import 'order_status_badge.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onRefreshRequired;

  const OrderCard({
    super.key,
    required this.order,
    this.onRefreshRequired,
  });

  void _navigateToDetail(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailView(order: order)),
    ).then((_) {
      if (onRefreshRequired != null) onRefreshRequired!();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = order.trackingStatus;
    final loc = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _navigateToDetail(context),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Header: Status Badge & Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OrderStatusBadge(status: status),
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

                  // Order Summary: Items Count, Date & Thumbnails
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc != null ? loc.items(order.totalQuantity) : "${order.totalQuantity} items",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1E1E1E),
                            ),
                          ),
                          const SizedBox(height: 2),
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
                        child: _buildThumbnailsList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Action Buttons: Details & Reorder
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[800],
                              side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.info_outline_rounded, size: 16),
                            label: Text(
                              loc != null ? loc.details : "Details",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            onPressed: () => _navigateToDetail(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 38,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Constants.baseColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(
                              loc != null ? loc.reorder : "Reorder",
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                            onPressed: () async {
                              final sm = ScaffoldMessenger.of(context);
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
                              sm.showSnackBar(
                                SnackBar(
                                  content: Text(loc != null ? loc.itemsAddedToBag : "Items added to cart"),
                                  backgroundColor: Constants.baseColor,
                                ),
                              );
                              if (context.mounted) {
                                Routers.goTO(context, toBody: const CartView());
                              }
                            },
                          ),
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

  Widget _buildThumbnailsList() {
    final rawItems = order.lineItems;
    // Deduplicate by image URL or product ID so multiple variants of the same product show the image just once
    final seen = <String>{};
    final uniqueItems = <LineItem>[];
    for (final item in rawItems) {
      final key = (item.image != null && item.image!.trim().isNotEmpty)
          ? item.image!.trim()
          : (item.productId != null && item.productId!.trim().isNotEmpty
              ? item.productId!.trim()
              : item.title.trim());
      if (seen.add(key)) {
        uniqueItems.add(item);
      }
    }

    final items = uniqueItems.isNotEmpty ? uniqueItems : rawItems;

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final imgUrl = item.image;
          return Container(
            width: 48,
            height: 48,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              color: const Color(0xFFF9FBF9),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imgUrl != null && imgUrl.isNotEmpty
                  ? KskNetworkImage(
                      imgUrl,
                      fit: BoxFit.cover,
                    )
                  : const Icon(Icons.eco_rounded, size: 20, color: Color(0xFF2E7D32)),
            ),
          );
        },
      ),
    );
  }
}
