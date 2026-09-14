class Product {
  final int id;
  final String name;
  final String sku;
  final int year;
  final int price;
  final int supplierId; // многие к одному
  final List<int> brandIds; // многие ко многим
  final List<int> categoryIds; // многие ко многим
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
    final brandIds = <int>[
      ..._idList(json['brandIds']),
      ..._nestedIds(json['authors']),
    ];
    if (json['brandId'] is int && (json['brandId'] as int) > 0) {
      brandIds.add(json['brandId'] as int);
    }

    final categoryIds = <int>[
      ..._idList(json['categoryIds']),
      ..._nestedIds(json['genres']),
    ];

    final publisher = json['publisher'];
    final supplierId =
        json['supplierId'] as int? ??
        json['publisherId'] as int? ??
        (publisher is Map ? publisher['id'] as int? : null) ??
        1;

    return Product(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? json['title'] ?? '') as String,
      sku: (json['sku'] ?? json['isbn'] ?? '') as String,
      year: json['year'] as int? ?? 0,
      price: json['price'] as int? ?? json['pages'] as int? ?? 0,
      supplierId: supplierId,
      brandIds: brandIds.toSet().toList(),
      categoryIds: categoryIds.toSet().toList(),
      stockTotal:
          json['stockTotal'] as int? ?? json['copiesTotal'] as int? ?? 0,
      stockAvailable:
          json['stockAvailable'] as int? ??
          json['copiesAvailable'] as int? ??
          0,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.tryParse(json['deletedAt'] as String),
    );
  }

  static List<int> _idList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<int>().toList();
  }

  static List<int> _nestedIds(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is Map && item['id'] is int) item['id'] as int,
    ];
  }
}
