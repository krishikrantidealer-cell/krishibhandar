import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../components/products_grid.dart';
import '../model/product_model.dart';
import '../model/technical_mapping_model.dart';

class TechnicalProductsView extends StatelessWidget {
  final TechnicalMappingModel mapping;

  const TechnicalProductsView({super.key, required this.mapping});

  @override
  Widget build(BuildContext context) {
    // Convert technical products to minimal ProductModel for ProductCard reuse
    final List<ProductModel> products = mapping.products.map((tp) {
      return ProductModel(
        id: tp.id,
        title: tp.title,
        body: '',
        vendor: '',
        productType: '',
        handle: tp.handle,
        images: tp.image != null ? [tp.image!] : [],
        image: tp.image,
        variants: [
          VariantModel(
            id: tp.id,
            title: 'Default',
            price: tp.price,
            inventoryQuantity: 1,
          )
        ],
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          mapping.technicalName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              "Products Using This Formula",
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.65, // Match existing aspect ratio
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return ProductCard(product: products[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
