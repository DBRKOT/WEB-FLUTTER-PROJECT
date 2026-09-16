import '../repositories/pb_collection_client.dart';

enum RepairStatus {
  newRequest,
  diagnostics,
  inWork,
  ready,
  issued,
  rejected;

  static RepairStatus fromApi(String? value) => switch (value) {
    'diagnostics' => RepairStatus.diagnostics,
    'in_work' => RepairStatus.inWork,
    'ready' => RepairStatus.ready,
    'issued' => RepairStatus.issued,
    'rejected' => RepairStatus.rejected,
    _ => RepairStatus.newRequest,
  };

  String get apiValue => switch (this) {
    RepairStatus.newRequest => 'new',
    RepairStatus.diagnostics => 'diagnostics',
    RepairStatus.inWork => 'in_work',
    RepairStatus.ready => 'ready',
    RepairStatus.issued => 'issued',
    RepairStatus.rejected => 'rejected',
  };

  String get label => switch (this) {
    RepairStatus.newRequest => 'Новая',
    RepairStatus.diagnostics => 'Диагностика',
    RepairStatus.inWork => 'В работе',
    RepairStatus.ready => 'Готова',
    RepairStatus.issued => 'Выдана',
    RepairStatus.rejected => 'Отказ',
  };

  bool get isClosed =>
      this == RepairStatus.issued || this == RepairStatus.rejected;
}

class RepairOrder {
  final String id;
  final String clientId;
  final String productId;
  final String masterId;
  final List<String> serviceIds;
  final String problem;
  final DateTime startAt;
  final DateTime endAt;
  final RepairStatus status;
  final int total;
  final bool archived;

  final String clientName;
  final String productName;
  final String masterName;
  final List<String> serviceNames;

  const RepairOrder({
    required this.id,
    required this.clientId,
    this.productId = '',
    this.masterId = '',
    this.serviceIds = const [],
    required this.problem,
    required this.startAt,
    required this.endAt,
    this.status = RepairStatus.newRequest,
    this.total = 0,
    this.archived = false,
    this.clientName = '',
    this.productName = '',
    this.masterName = '',
    this.serviceNames = const [],
  });

  bool get isDeleted => archived;

  Duration get duration => endAt.difference(startAt);

  //проверка пересечения интервалов: один мастер не может выполнять
  //две заявки одновременно. Используется при записи в сервис.
  bool conflictsWith(RepairOrder other) {
    if (id == other.id) return false;
    if (masterId.isEmpty || masterId != other.masterId) return false;
    if (status.isClosed || other.status.isClosed) return false;
    return startAt.isBefore(other.endAt) && other.startAt.isBefore(endAt);
  }

  RepairOrder copyWith({
    String? clientId,
    String? productId,
    String? masterId,
    List<String>? serviceIds,
    String? problem,
    DateTime? startAt,
    DateTime? endAt,
    RepairStatus? status,
    int? total,
    bool? archived,
  }) {
    return RepairOrder(
      id: id,
      clientId: clientId ?? this.clientId,
      productId: productId ?? this.productId,
      masterId: masterId ?? this.masterId,
      serviceIds: serviceIds ?? this.serviceIds,
      problem: problem ?? this.problem,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      total: total ?? this.total,
      archived: archived ?? this.archived,
      clientName: clientName,
      productName: productName,
      masterName: masterName,
      serviceNames: serviceNames,
    );
  }

  Map<String, dynamic> toJson() => {
    'client': clientId,
    if (productId.isNotEmpty) 'product': productId,
    if (masterId.isNotEmpty) 'master': masterId,
    'services': serviceIds,
    'problem': problem,
    'startAt': startAt.toUtc().toIso8601String(),
    'endAt': endAt.toUtc().toIso8601String(),
    'status': status.apiValue,
    'total': total,
    'archived': archived,
  };

  factory RepairOrder.fromJson(Map<String, dynamic> json) {
    final client = pbExpanded(json, 'client');
    final services = pbExpandedList(json, 'services');
    return RepairOrder(
      id: json['id'] as String? ?? '',
      clientId: json['client'] as String? ?? '',
      productId: json['product'] as String? ?? '',
      masterId: json['master'] as String? ?? '',
      serviceIds: pbIdList(json['services']),
      problem: json['problem'] as String? ?? '',
      startAt:
          DateTime.tryParse(json['startAt'] as String? ?? '') ?? DateTime.now(),
      endAt:
          DateTime.tryParse(json['endAt'] as String? ?? '') ?? DateTime.now(),
      status: RepairStatus.fromApi(json['status'] as String?),
      total: (json['total'] as num?)?.round() ?? 0,
      archived: json['archived'] as bool? ?? false,
      clientName: (client?['fullName'] ?? client?['email'] ?? '') as String,
      productName: pbExpanded(json, 'product')?['title'] as String? ?? '',
      masterName: pbExpanded(json, 'master')?['fullName'] as String? ?? '',
      serviceNames: [for (final s in services) s['name'] as String? ?? ''],
    );
  }
}
