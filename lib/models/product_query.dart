class ProductQuery {
  final String search;
  final String? categoryId;
  final String? brandId;
  final String? supplierId;
  final int? priceFrom;
  final int? priceTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const ProductQuery({
    this.search = '',
    this.categoryId,
    this.brandId,
    this.supplierId,
    this.priceFrom,
    this.priceTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  factory ProductQuery.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final sortRaw = q['sort'] ?? 'name,asc';
    final parts = sortRaw.split(',');
    final field = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'name';
    final ascending = parts.length < 2 || parts[1].toLowerCase() != 'desc';
    String? nonEmpty(String? value) =>
        (value == null || value.isEmpty) ? null : value;
    return ProductQuery(
      search: q['search'] ?? '',
      categoryId: nonEmpty(q['categoryId']),
      brandId: nonEmpty(q['brandId']),
      supplierId: nonEmpty(q['supplierId']),
      priceFrom: int.tryParse(q['priceFrom'] ?? ''),
      priceTo: int.tryParse(q['priceTo'] ?? ''),
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
    if (categoryId != null) params['categoryId'] = categoryId!;
    if (brandId != null) params['brandId'] = brandId!;
    if (supplierId != null) params['supplierId'] = supplierId!;
    if (priceFrom != null) params['priceFrom'] = '$priceFrom';
    if (priceTo != null) params['priceTo'] = '$priceTo';
    params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  String toLocation([String path = '/products']) {
    final params = toQueryParameters();
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  ProductQuery copyWith({
    String? search,
    Object? categoryId = _unset,
    Object? brandId = _unset,
    Object? supplierId = _unset,
    Object? priceFrom = _unset,
    Object? priceTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return ProductQuery(
      search: search ?? this.search,
      categoryId: categoryId == _unset
          ? this.categoryId
          : categoryId as String?,
      brandId: brandId == _unset ? this.brandId : brandId as String?,
      supplierId: supplierId == _unset
          ? this.supplierId
          : supplierId as String?,
      priceFrom: priceFrom == _unset ? this.priceFrom : priceFrom as int?,
      priceTo: priceTo == _unset ? this.priceTo : priceTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProductQuery &&
        other.search == search &&
        other.categoryId == categoryId &&
        other.brandId == brandId &&
        other.supplierId == supplierId &&
        other.priceFrom == priceFrom &&
        other.priceTo == priceTo &&
        other.sortField == sortField &&
        other.sortAscending == sortAscending &&
        other.page == page &&
        other.size == size &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(
    search,
    categoryId,
    brandId,
    supplierId,
    priceFrom,
    priceTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );

  static const _unset = Object();
}
