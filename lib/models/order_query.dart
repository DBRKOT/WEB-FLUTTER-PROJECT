import 'order.dart';

class OrderQuery {
  final String search;
  final OrderStatus? status;
  final String? clientId;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const OrderQuery({
    this.search = '',
    this.status,
    this.clientId,
    this.sortField = 'created',
    this.sortAscending = false,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  factory OrderQuery.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final sortRaw = q['sort'] ?? 'created,desc';
    final parts = sortRaw.split(',');
    final field = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'created';
    final ascending = parts.length > 1 && parts[1].toLowerCase() == 'asc';
    String? nonEmpty(String? value) =>
        (value == null || value.isEmpty) ? null : value;
    final statusRaw = nonEmpty(q['status']);
    return OrderQuery(
      search: q['search'] ?? '',
      status: statusRaw == null ? null : OrderStatus.fromApi(statusRaw),
      clientId: nonEmpty(q['clientId']),
      sortField: field,
      sortAscending: ascending,
      page: int.tryParse(q['page'] ?? '') ?? 1,
      size: int.tryParse(q['size'] ?? '') ?? 10,
      includeDeleted: q['includeDeleted'] == 'true',
    );
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    if (search.trim().isNotEmpty) params['search'] = search.trim();
    if (status != null) params['status'] = status!.apiValue;
    if (clientId != null) params['clientId'] = clientId!;
    params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  String toLocation([String path = '/orders']) {
    final params = toQueryParameters();
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  OrderQuery copyWith({
    String? search,
    Object? status = _unset,
    Object? clientId = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return OrderQuery(
      search: search ?? this.search,
      status: status == _unset ? this.status : status as OrderStatus?,
      clientId: clientId == _unset ? this.clientId : clientId as String?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OrderQuery &&
        other.search == search &&
        other.status == status &&
        other.clientId == clientId &&
        other.sortField == sortField &&
        other.sortAscending == sortAscending &&
        other.page == page &&
        other.size == size &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(
    search,
    status,
    clientId,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );

  static const _unset = Object();
}
