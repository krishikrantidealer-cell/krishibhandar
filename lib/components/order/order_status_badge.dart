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
    final s = status.toLowerCase().trim().replaceAll('-', '_').replaceAll(' ', '_');
    Color bg;
    Color fg;
    IconData icon;

    switch (s) {
      case 'not_confirmed':
      case 'pending':
        bg = const Color(0xFFFCEAE6);
        fg = const Color(0xFF9C4221);
        icon = Icons.hourglass_top_rounded;
        break;
      case 'confirmed':
      case 'processing':
        bg = const Color(0xFFE2F0D9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'shipped':
        bg = const Color(0xFFD9E8FB);
        fg = const Color(0xFF1565C0);
        icon = Icons.local_shipping_outlined;
        break;
      case 'rack_up':
      case 'rackup':
        bg = const Color(0xFFD1E1EB);
        fg = const Color(0xFF37474F);
        icon = Icons.inventory_2_outlined;
        break;
      case 'in_transit':
      case 'intransit':
        bg = const Color(0xFFFCF0D3);
        fg = const Color(0xFFD97706);
        icon = Icons.alt_route_rounded;
        break;
      case 'out_for_delivery':
      case 'outfordelivery':
        bg = const Color(0xFF8A1C14);
        fg = Colors.white;
        icon = Icons.delivery_dining_rounded;
        break;
      case 'delivered':
      case 'completed':
        bg = const Color(0xFF38761D);
        fg = Colors.white;
        icon = Icons.verified_rounded;
        break;
      case 'rto_in_transit':
      case 'rtointransit':
        bg = const Color(0xFF3F606F);
        fg = Colors.white;
        icon = Icons.replay_rounded;
        break;
      case 'rto_delivered':
      case 'rtodelivered':
        bg = const Color(0xFFE1D5E7);
        fg = const Color(0xFF6B21A8);
        icon = Icons.assignment_return_rounded;
        break;
      case 'hold':
      case 'on_hold':
        bg = const Color(0xFF4A86E8);
        fg = Colors.white;
        icon = Icons.pause_circle_outline_rounded;
        break;
      case 'delayed':
        bg = const Color(0xFFE69138);
        fg = Colors.white;
        icon = Icons.access_time_rounded;
        break;
      case 'lost':
        bg = const Color(0xFFD9EAD3);
        fg = const Color(0xFF365314);
        icon = Icons.help_outline_rounded;
        break;
      case 'cancelled':
      case 'canceled':
      case 'refunded':
        bg = const Color(0xFFF8CECC);
        fg = const Color(0xFF991B1B);
        icon = Icons.cancel_outlined;
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        icon = Icons.shopping_bag_outlined;
        break;
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
