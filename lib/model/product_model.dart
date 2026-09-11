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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Collect all images from various possible schemas (images array, image string, featuredImage, etc.)
    List<String> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List).map((e) {
        if (e is Map) {
          return (e['original'] ?? e['medium'] ?? e['low'] ?? e['url'] ?? e['src'] ?? '').toString();
        }
        return e.toString();
      }).where((s) => s.isNotEmpty).toList();
    }

    String? singleImg;
    if (json['image'] != null) {
      if (json['image'] is Map) {
        singleImg = (json['image']['original'] ?? json['image']['medium'] ?? json['image']['url'] ?? json['image']['src'])?.toString();
      } else {
        singleImg = json['image'].toString();
      }
    } else if (json['featuredImage'] != null) {
      if (json['featuredImage'] is Map) {
        singleImg = (json['featuredImage']['original'] ?? json['featuredImage']['medium'] ?? json['featuredImage']['url'] ?? json['featuredImage']['src'])?.toString();
      } else {
        singleImg = json['featuredImage'].toString();
      }
    }

    if (singleImg != null && singleImg.isNotEmpty && !imgList.contains(singleImg)) {
      imgList.insert(0, singleImg);
    }

    // Parse variants
    List<VariantModel> varList = [];
    if (json['variants'] is List && (json['variants'] as List).isNotEmpty) {
      varList = (json['variants'] as List)
          .map((v) => VariantModel.fromJson(v is Map ? Map<String, dynamic>.from(v) : {}))
          .toList();
    } else {
      // Fallback single variant if top-level price is provided
      varList = [
        VariantModel(
          id: (json['variantId'] ?? json['id'] ?? json['_id'] ?? '1').toString(),
          title: json['variantTitle'] ?? json['option'] ?? 'Default Title',
          price: (json['price'] ?? '0').toString(),
          compareAtPrice: json['compareAtPrice']?.toString() ?? json['compare_at_price']?.toString(),
          inventoryQuantity: int.tryParse(json['stock']?.toString() ?? '') ?? json['inventory_quantity'] ?? json['inventoryQuantity'] ?? 100,
        )
      ];
    }

    return ProductModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title'] ?? '',
      body: json['bodyHtml'] ?? json['body_html'] ?? json['description'] ?? json['body'] ?? '',
      vendor: json['vendor'] ?? '',
      productType: json['product_type'] ?? json['productType'] ?? json['category']?.toString() ?? '',
      handle: json['handle'] ?? json['slug'] ?? (json['id'] ?? json['_id'] ?? '').toString(),
      variants: varList,
      images: imgList,
      image: singleImg ?? (imgList.isNotEmpty ? imgList.first : null),
      collectionId: json['collectionId']?.toString() ?? json['category']?.toString(),
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
      id: (json['id'] ?? json['_id'] ?? json['sku'] ?? json['variantId'] ?? '').toString(),
      title: json['title'] ?? json['option'] ?? json['variantTitle'] ?? 'Default Title',
      price: json['price']?.toString() ?? '0',
      compareAtPrice: json['compare_at_price']?.toString() ?? json['compareAtPrice']?.toString(),
      inventoryQuantity: int.tryParse(json['stock']?.toString() ?? '') ?? json['inventory_quantity'] ?? json['inventoryQuantity'] ?? json['inventory'] ?? 100,
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
