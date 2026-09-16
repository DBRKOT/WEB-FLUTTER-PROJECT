import '../repositories/pb_collection_client.dart';

enum OrderStatus {
  created,
  paid,
  shipped,
  done,
  cancelled;

  static OrderStatus fromApi(String? value) => switch (value) {
    'paid' => OrderStatus.paid,
    'shipped' => OrderStatus.shipped,
    'done' => OrderStatus.done,
    'cancelled' => OrderStatus.cancelled,
    _ => OrderStatus.created,
  };

  String get apiValue => switch (this) {
    OrderStatus.created => 'new',
    OrderStatus.paid => 'paid',
    OrderStatus.shipped => 'shipped',
    OrderStatus.done => 'done',
    OrderStatus.cancelled => 'cancelled',
  };

  String get label => switch (this) {
    OrderStatus.created => 'Новый',
    OrderStatus.paid => 'Оплачен',
    OrderStatus.shipped => 'Отправлен',
    OrderStatus.done => 'Выполнен',
    OrderStatus.cancelled => 'Отменён',
  };
}

class Order {
  final String id;
  final String clientId;
  final OrderStatus status;
  final int total;
  final String comment;
  final bool archived;
  final DateTime? createdAt;

  final String clientName;

  const Order({
    required this.id,
    required this.clientId,
    this.status = OrderStatus.created,
    this.total = 0,
    this.comment = '',
    this.archived = false,
    this.createdAt,
    this.clientName = '',
  });

  bool get isDeleted => archived;

  Order copyWith({
    String? clientId,
    OrderStatus? status,
    int? total,
    String? comment,
    bool? archived,
  }) {
    return Order(
      id: id,
      clientId: clientId ?? this.clientId,
      status: status ?? this.status,
      total: total ?? this.total,
      comment: comment ?? this.comment,
      archived: archived ?? this.archived,
      createdAt: createdAt,
      clientName: clientName,
    );
  }

  Map<String, dynamic> toJson() => {
    'client': clientId,
    'status': status.apiValue,
    'total': total,
    'comment': comment,
    'archived': archived,
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    final client = pbExpanded(json, 'client');
    return Order(
      id: json['id'] as String? ?? '',
      clientId: json['client'] as String? ?? '',
      status: OrderStatus.fromApi(json['status'] as String?),
      total: (json['total'] as num?)?.round() ?? 0,
      comment: json['comment'] as String? ?? '',
      archived: json['archived'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['created'] as String? ?? ''),
      clientName: (client?['fullName'] ?? client?['email'] ?? '') as String,
    );
  }
}
