import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;

  const OrderStatusBadge({
    super.key,
    required this.status,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = status.toLowerCase();
    Color bg;
    Color fg;
    IconData icon;

    if (statusLower.contains('delivered') || statusLower.contains('completed')) {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
      icon = Icons.check_circle_rounded;
    } else if (statusLower.contains('cancelled')) {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFC62828);
      icon = Icons.cancel_rounded;
    } else if (statusLower.contains('shipped') || statusLower.contains('transit') || statusLower.contains('delivery')) {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
      icon = Icons.local_shipping_rounded;
    } else if (statusLower.contains('processing') || statusLower.contains('packed')) {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE65100);
      icon = Icons.inventory_2_rounded;
    } else {
      bg = const Color(0xFFF5F5F5);
      fg = const Color(0xFF616161);
      icon = Icons.shopping_bag_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize + 3, color: fg),
          const SizedBox(width: 5),
          Text(
            status,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
