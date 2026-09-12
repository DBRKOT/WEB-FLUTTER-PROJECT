class LoanOrder {
  const LoanOrder({
    required this.id,
    required this.customerName,
    required this.productName,
    required this.productId,
    required this.customerId,
    required this.issuedAt,
    required this.dueAt,
    this.returnedAt,
    required this.status,
  });

  final int id;
  final String customerName;
  final String productName;
  final int productId;
  final int customerId;
  final DateTime issuedAt;
  final DateTime dueAt;
  final DateTime? returnedAt;
  final String status; // active | returned | overdue

  bool get isOpen => returnedAt == null;

  factory LoanOrder.fromJson(Map<String, dynamic> json) {
    final reader = json['reader'];
    final book = json['book'];
    return LoanOrder(
      id: json['id'] as int? ?? 0,
      customerName: reader is Map
          ? (reader['fullName'] as String? ?? '')
          : '',
      productName: book is Map ? (book['title'] as String? ?? '') : '',
      productId: book is Map ? (book['id'] as int? ?? 0) : 0,
      customerId: reader is Map ? (reader['id'] as int? ?? 0) : 0,
      issuedAt: DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      dueAt: DateTime.tryParse(json['dueAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      returnedAt: json['returnedAt'] == null
          ? null
          : DateTime.tryParse(json['returnedAt'] as String),
      status: json['status'] as String? ?? 'active',
    );
  }
}
