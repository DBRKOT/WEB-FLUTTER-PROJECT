class Product {
  final int id;
  final String name;
  final String sku;
  final int year;
  final int price;
  final int supplierId; // многие к одному
  final List<int> brandIds;// многие ко многим
  final List<int> categoryIds;// многие ко многим
  final int stockTotal;
  final int stockAvailable;
  final DateTime? deletedAt;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.year,
    required this.price,
    required this.supplierId,
    required this.brandIds,
    required this.categoryIds,
    required this.stockTotal,
    required this.stockAvailable,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  int get brandId => brandIds.isEmpty ? 0 : brandIds.first;

  Product copyWith({
    String? name,
    String? sku,
    int? year,
    int? price,
    int? supplierId,
    List<int>? brandIds,
    List<int>? categoryIds,
    int? stockTotal,
    int? stockAvailable,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Product(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      year: year ?? this.year,
      price: price ?? this.price,
      supplierId: supplierId ?? this.supplierId,
      brandIds: brandIds ?? this.brandIds,
      categoryIds: categoryIds ?? this.categoryIds,
      stockTotal: stockTotal ?? this.stockTotal,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'year': year,
        'price': price,
        'supplierId': supplierId,
        'brandIds': brandIds,
        'categoryIds': categoryIds,
        'stockTotal': stockTotal,
        'stockAvailable': stockAvailable,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    final brandIds = <int>[];
    if (json['brandIds'] is List) {
      brandIds.addAll((json['brandIds'] as List).whereType<int>());
    } else if (json['brandId'] is int && (json['brandId'] as int) > 0) {
      brandIds.add(json['brandId'] as int);
    }

    final categoryIds = <int>[];
    if (json['categoryIds'] is List) {
      categoryIds.addAll((json['categoryIds'] as List).whereType<int>());
    }

    return Product(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      year: json['year'] as int? ?? 0,
      price: json['price'] as int? ?? 0,
      supplierId: json['supplierId'] as int? ?? 1,
      brandIds: brandIds,
      categoryIds: categoryIds,
      stockTotal: json['stockTotal'] as int? ?? 0,
      stockAvailable: json['stockAvailable'] as int? ?? 0,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.tryParse(json['deletedAt'] as String),
    );
  }
}
