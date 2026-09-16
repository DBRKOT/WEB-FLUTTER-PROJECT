import '../repositories/pb_collection_client.dart';

class Product {
  final String id;
  final String name;
  final String sku;
  final int price;
  final int warrantyMonths;
  final String brandId;
  final String categoryId;
  final String supplierId;
  final String description;
  final bool archived;

  final String brandName;
  final String categoryName;
  final String supplierName;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    this.warrantyMonths = 0,
    required this.brandId,
    required this.categoryId,
    this.supplierId = '',
    this.description = '',
    this.archived = false,
    this.brandName = '',
    this.categoryName = '',
    this.supplierName = '',
  });

  bool get isDeleted => archived;

  Product copyWith({
    String? name,
    String? sku,
    int? price,
    int? warrantyMonths,
    String? brandId,
    String? categoryId,
    String? supplierId,
    String? description,
    bool? archived,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      warrantyMonths: warrantyMonths ?? this.warrantyMonths,
      brandId: brandId ?? this.brandId,
      categoryId: categoryId ?? this.categoryId,
      supplierId: supplierId ?? this.supplierId,
      description: description ?? this.description,
      archived: archived ?? this.archived,
      brandName: brandName,
      categoryName: categoryName,
      supplierName: supplierName,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': name,
    'sku': sku,
    'price': price,
    'warrantyMonths': warrantyMonths,
    'brand': brandId,
    'category': categoryId,
    if (supplierId.isNotEmpty) 'supplier': supplierId,
    'description': description,
    'archived': archived,
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String? ?? '',
    name: json['title'] as String? ?? '',
    sku: json['sku'] as String? ?? '',
    price: (json['price'] as num?)?.round() ?? 0,
    warrantyMonths: (json['warrantyMonths'] as num?)?.toInt() ?? 0,
    brandId: json['brand'] as String? ?? '',
    categoryId: json['category'] as String? ?? '',
    supplierId: json['supplier'] as String? ?? '',
    description: json['description'] as String? ?? '',
    archived: json['archived'] as bool? ?? false,
    brandName: pbExpanded(json, 'brand')?['name'] as String? ?? '',
    categoryName: pbExpanded(json, 'category')?['name'] as String? ?? '',
    supplierName: pbExpanded(json, 'supplier')?['name'] as String? ?? '',
  );
}
