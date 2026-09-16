import '../repositories/pb_collection_client.dart';

class Stock {
  final String id;
  final String productId;
  final int quantity;
  final String location;

  final String productName;
  final String productSku;

  const Stock({
    required this.id,
    required this.productId,
    required this.quantity,
    this.location = '',
    this.productName = '',
    this.productSku = '',
  });

  bool get isAvailable => quantity > 0;

  bool get isLow => quantity > 0 && quantity < 5;

  String get statusLabel {
    if (quantity == 0) return 'Нет в наличии';
    if (isLow) return 'Мало';
    return 'В наличии';
  }

  Stock copyWith({String? productId, int? quantity, String? location}) {
    return Stock(
      id: id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      location: location ?? this.location,
      productName: productName,
      productSku: productSku,
    );
  }

  Map<String, dynamic> toJson() => {
    'product': productId,
    'quantity': quantity,
    'location': location,
  };

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
    id: json['id'] as String? ?? '',
    productId: json['product'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    location: json['location'] as String? ?? '',
    productName: pbExpanded(json, 'product')?['title'] as String? ?? '',
    productSku: pbExpanded(json, 'product')?['sku'] as String? ?? '',
  );
}
