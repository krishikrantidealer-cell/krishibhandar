class CategoriesModel {
  final String id;
  final String title, handle, image, description;
  final String? iconImage;
  final String? categoryId;

  CategoriesModel({
    required this.id,
    required this.title,
    required this.handle,
    required this.description,
    required this.image,
    this.iconImage,
    this.categoryId,
  });

  factory CategoriesModel.fromJson(Map<String, dynamic> json) {
    final rawId =
        (json['_id'] ?? json['id'] ?? json['categoryId'] ?? '').toString();
    final name = (json['title'] ?? json['name'] ?? '').toString();
    final icon = (json['iconImage'] ?? json['icon_image'])?.toString();

    // Dynamically resolve category image strictly from backend response
    String img = '';
    if (json['imageUrl'] != null &&
        json['imageUrl'].toString().isNotEmpty &&
        json['imageUrl'].toString() != 'null') {
      img = json['imageUrl'].toString();
    } else if (json['bannerImage'] != null &&
        json['bannerImage'].toString().isNotEmpty &&
        json['bannerImage'].toString() != 'null') {
      img = json['bannerImage'].toString();
    } else if (json['image'] is Map) {
      img = (json['image']['src'] ?? json['image']['url'] ?? '').toString();
    } else if (json['image'] != null &&
        json['image'].toString().isNotEmpty &&
        json['image'].toString() != 'null') {
      img = json['image'].toString();
    } else if (icon != null && icon.isNotEmpty && icon != 'null') {
      img = icon;
    }

    return CategoriesModel(
      id: rawId,
      title: name,
      handle: (json['handle'] ?? json['slug'] ?? rawId).toString(),
      description: (json['description'] ?? '').toString(),
      image: img,
      iconImage: icon != null && icon.isNotEmpty && icon != 'null' ? icon : null,
      categoryId: rawId,
    );
  }
}
