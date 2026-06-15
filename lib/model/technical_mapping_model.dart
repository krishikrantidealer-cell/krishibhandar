class TechnicalMappingModel {
  final String technicalName;
  final String slug;
  final List<TechnicalProductModel> products;

  TechnicalMappingModel({
    required this.technicalName,
    required this.slug,
    required this.products,
  });

  factory TechnicalMappingModel.fromJson(Map<String, dynamic> json) {
    return TechnicalMappingModel(
      technicalName: json['technicalName'] ?? '',
      slug: json['slug'] ?? '',
      products: (json['products'] as List? ?? [])
          .map((v) => TechnicalProductModel.fromJson(v))
          .toList(),
    );
  }
}

class TechnicalProductModel {
  final String id;
  final String title;
  final String handle;
  final String price;
  final String? image;

  TechnicalProductModel({
    required this.id,
    required this.title,
    required this.handle,
    required this.price,
    this.image,
  });

  factory TechnicalProductModel.fromJson(Map<String, dynamic> json) {
    return TechnicalProductModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      handle: json['handle'] ?? '',
      price: json['price']?.toString() ?? '0',
      image: json['image'],
    );
  }
}
