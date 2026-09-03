class Product {
  final int id;
  final String name;
  final String sku;
  final int year;
  final int price;
  final int brandId;
  final String category;
  final int stockTotal;
  final int stockAvailable;
  final DateTime? deletedAt;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.year,
    required this.price,
    required this.brandId,
    required this.category,
    required this.stockTotal,
    required this.stockAvailable,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Product copyWith({
    String? name,
    String? sku,
    int? year,
    int? price,
    int? brandId,
    String? category,
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
      brandId: brandId ?? this.brandId,
      category: category ?? this.category,
      stockTotal: stockTotal ?? this.stockTotal,
      stockAvailable: stockAvailable ?? this.stockAvailable,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
