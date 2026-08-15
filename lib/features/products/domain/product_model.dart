/// Product as returned by GET /api/products.
class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.categoryId,
    this.sku,
    required this.isActive,
  });

  final String id;
  final String name;
  final String? categoryId;
  final String? sku;
  final bool isActive;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? '';
    final name = json['name']?.toString() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw FormatException('Invalid product JSON: $json');
    }
    return ProductModel(
      id: id,
      name: name,
      categoryId: json['category_id']?.toString(),
      sku: json['sku']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}
