class CategoriesModel {
  final String id;
  final String title, handle, image, description;
  final String? categoryId;

  CategoriesModel({
    required this.id,
    required this.title,
    required this.handle,
    required this.description,
    required this.image,
    this.categoryId,
  });

  factory CategoriesModel.fromJson(Map<String, dynamic> json) {
    final rawId =
        (json['_id'] ?? json['id'] ?? json['categoryId'] ?? '').toString();
    final name = (json['title'] ?? json['name'] ?? '').toString();
    String img = (json['image'] is Map
            ? (json['image']['src'] ?? json['image']['url'])
            : json['image'] ?? json['imageUrl'] ?? '')
        .toString();

    // Default image mapping if image is not populated in category document
    if (img.isEmpty) {
      final n = name.toLowerCase();
      if (n.contains('insect')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Insecticides_1782219848442_full.webp';
      } else if (n.contains('fungi')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fungicides_1782219847975_full.webp';
      } else if (n.contains('nematicide')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio_Nematicide_1782219846072_full.webp';
      } else if (n.contains('micro')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Micronutrients_1782219847036_full.webp';
      } else if (n.contains('fertilizer')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Organic_Fertilizers_1782219847513_full.webp';
      } else if (n.contains('bio')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp';
      } else if (n.contains('antibiotic')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Antibiotics_1782219845579_full.webp';
      } else if (n.contains('pgr') || n.contains('growth')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio-Products_1782219846548_full.webp';
      } else if (n.contains('herb')) {
        img =
            'https://storage.googleapis.com/bhandar-product-images/banners/category/Bio_Nematicide_1782219846072_full.webp';
      }
    }

    return CategoriesModel(
      id: rawId,
      title: name,
      handle: json['handle'] ?? json['slug'] ?? rawId,
      description: json['description'] ?? '',
      image: img,
      categoryId: rawId,
    );
  }
}
