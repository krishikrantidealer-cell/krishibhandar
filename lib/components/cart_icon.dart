import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/cart/cart_bloc.dart';
import '../blocs/cart/cart_state.dart';
import '../controller/constants.dart';
import '../view/cart_view.dart';
import '../controller/routers.dart';

class KskCartIcon extends StatelessWidget {
  final Color? color;
  final bool showBackground;

  const KskCartIcon({
    super.key,
    this.color,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        final cartCount = cartState.itemCount;

        Widget icon = badges.Badge(
          showBadge: cartCount > 0,
          badgeContent: Text(
            "$cartCount",
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          badgeStyle: const badges.BadgeStyle(
            badgeColor: Color(0xFFE53935), // Urgent Red for visibility
            padding: EdgeInsets.all(5),
            elevation: 2,
            borderSide: BorderSide(color: Colors.white, width: 1.5),
          ),
          position: badges.BadgePosition.topEnd(top: -8, end: -8),
          child: Icon(
            Icons.shopping_cart_outlined,
            color: color ??
                (showBackground ? Colors.black87 : Constants.baseColor),
            size: 26,
          ),
        );

        if (showBackground) {
          return GestureDetector(
            onTap: () => Routers.goTO(context, toBody: const CartView()),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey[100]!, width: 1),
              ),
              child: Center(child: icon),
            ),
          );
        }

        return GestureDetector(
          onTap: () => Routers.goTO(context, toBody: const CartView()),
          child: icon,
        );
      },
    );
  }
}
