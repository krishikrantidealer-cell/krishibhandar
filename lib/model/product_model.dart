class ProductModel {
  final String id;
  final String title;
  final String body;
  final String vendor;
  final String productType;
  final String handle;
  final List<VariantModel> variants;
  final List<String> images;
  final String? image;
  final String? collectionId;

  ProductModel({
    required this.id,
    required this.title,
    required this.body,
    required this.vendor,
    required this.productType,
    required this.handle,
    required this.variants,
    required this.images,
    this.image,
    this.collectionId,
  });

  String get category => productType;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Extract image URLs safely from list of Maps or Strings
    final rawImages = json['images'] as List? ?? [];
    final List<String> extractedImages = [];
    for (var img in rawImages) {
      if (img is String && img.trim().isNotEmpty) {
        extractedImages.add(img.trim());
      } else if (img is Map) {
        final url = img['original'] ??
            img['medium'] ??
            img['url'] ??
            img['src'] ??
            img['low'];
        if (url != null && url.toString().trim().isNotEmpty) {
          extractedImages.add(url.toString().trim());
        }
      }
    }

    String? singleImg;
    if (json['image'] != null) {
      if (json['image'] is String && json['image'].toString().trim().isNotEmpty) {
        singleImg = json['image'].toString().trim();
      } else if (json['image'] is Map) {
        final u = (json['image']['original'] ??
                json['image']['medium'] ??
                json['image']['url'] ??
                json['image']['src'])
            ?.toString();
        if (u != null && u.trim().isNotEmpty) {
          singleImg = u.trim();
        }
      }
    }
    if ((singleImg == null || singleImg.isEmpty) && extractedImages.isNotEmpty) {
      singleImg = extractedImages.first;
    }

    final rawVariants = json['variants'] as List? ?? [];
    final List<VariantModel> parsedVariants = rawVariants.map((v) {
      if (v is Map<String, dynamic>) {
        return VariantModel.fromJson(v);
      } else if (v is Map) {
        return VariantModel.fromJson(Map<String, dynamic>.from(v));
      }
      return VariantModel(
        id: '',
        title: '',
        price: '0',
        inventoryQuantity: 0,
      );
    }).toList();

    return ProductModel(
      id: (json['id'] ?? json['_id'] ?? json['shopifyId'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      body: (json['description'] ?? json['body_html'] ?? json['body'] ?? '').toString(),
      vendor: (json['vendor'] ?? '').toString(),
      productType: (json['product_type'] ?? json['productType'] ?? '').toString(),
      handle: (json['handle'] ?? json['slug'] ?? '').toString(),
      variants: parsedVariants,
      images: extractedImages,
      image: singleImg,
      collectionId: json['collectionId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body_html': body,
      'vendor': vendor,
      'product_type': productType,
      'handle': handle,
      'variants': variants.map((v) => v.toJson()).toList(),
      'images': images,
      'image': image,
      'collectionId': collectionId,
    };
  }
}

class VariantModel {
  final String id;
  final String title;
  final String price;
  final String? compareAtPrice;
  final int inventoryQuantity;

  VariantModel({
    required this.id,
    required this.title,
    required this.price,
    this.compareAtPrice,
    required this.inventoryQuantity,
  });

  factory VariantModel.fromJson(Map<String, dynamic> json) {
    return VariantModel(
      id: (json['id'] ?? json['_id'] ?? json['shopifyVariantId'] ?? json['sku'] ?? '').toString(),
      title: (json['title'] ?? json['option'] ?? json['name'] ?? '').toString(),
      price: (json['price'] ?? '0').toString(),
      compareAtPrice: json['compare_at_price']?.toString() ?? json['compareAtPrice']?.toString(),
      inventoryQuantity: int.tryParse(json['stock']?.toString() ?? '') ??
          int.tryParse(json['inventory_quantity']?.toString() ?? '') ??
          int.tryParse(json['inventoryQuantity']?.toString() ?? '') ??
          0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'compare_at_price': compareAtPrice,
      'inventory_quantity': inventoryQuantity,
    };
  }
}
