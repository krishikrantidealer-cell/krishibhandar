import 'dart:async';
import 'dart:convert';

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kisan_sewa_kendra/generated/assets.dart';

import 'package:kisan_sewa_kendra/l10n/app_localizations.dart';
import '../controller/constants.dart';
import '../controller/pref.dart';
import '../controller/routers.dart';
import '../model/product_model.dart';
import '../shopify/shopify.dart';
import '../view/cart_view.dart';
import '../view/home_view.dart';
import '../view/product_view.dart';
import 'cart_icon.dart';
import 'network_image.dart';
import 'widget_button.dart';
import 'search_delegate.dart';

class KskAppbar extends StatefulWidget implements PreferredSizeWidget {
  final String? title, share, subTitle;
  final Widget? filter;

  const KskAppbar({
    super.key,
    this.title,
    this.share,
    this.subTitle,
    this.filter,
  });

  @override
  State<KskAppbar> createState() => _KskAppbarState();

  @override
  Size get preferredSize => const Size.fromHeight(138);
}

class _KskAppbarState extends State<KskAppbar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E88E5), // Premium Blue
            Color(0xFF2E7D32), // Agri Green
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            systemOverlayStyle: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            centerTitle: false,
            toolbarHeight: 70,
            leadingWidth: 56,
            titleSpacing: 0,
            leading: Builder(
              builder: (context) => IconButton(
                padding: const EdgeInsets.only(left: 16),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Image.asset(
                "assets/logo-removebg-preview.png",
                height: 62, // Polished size
                color: Colors.white,
                fit: BoxFit.contain,
              ),
            ),
            actions: [
              if (Constants.languageList.isNotEmpty && widget.title == null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    icon: Container(
                      height: 40, // Micro-polished height
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            Constants.lang.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    onSelected: (String code) async {
                      Constants.languageController.setLocale(code);
                      Constants.lang = code;
                    },
                    itemBuilder: (context) => Constants.languageList.map((lang) {
                      return PopupMenuItem<String>(
                        value: lang.iso,
                        child: Text(lang.name),
                      );
                    }).toList(),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: KskCartIcon(color: Colors.white),
              ),
            ],
          ),
          // --- FLOATING SEARCH BAR ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: WidgetButton(
              onTap: () => showSearch(
                  context: context, delegate: CustomSearchDelegate()),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: Color(0xFF2E7D32), size: 22),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.searchProducts,
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
