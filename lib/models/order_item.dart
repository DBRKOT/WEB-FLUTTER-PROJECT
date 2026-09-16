import '../repositories/pb_collection_client.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int quantity;
  final int price;

  final String productName;
  final String productSku;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.productName = '',
    this.productSku = '',
  });

  int get sum => quantity * price;

  OrderItem copyWith({
    String? orderId,
    String? productId,
    int? quantity,
    int? price,
  }) {
    return OrderItem(
      id: id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      productName: productName,
      productSku: productSku,
    );
  }

  Map<String, dynamic> toJson() => {
    'order': orderId,
    'product': productId,
    'quantity': quantity,
    'price': price,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final product = pbExpanded(json, 'product');
    return OrderItem(
      id: json['id'] as String? ?? '',
      orderId: json['order'] as String? ?? '',
      productId: json['product'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      price: (json['price'] as num?)?.round() ?? 0,
      productName: product?['title'] as String? ?? '',
      productSku: product?['sku'] as String? ?? '',
    );
  }
}
