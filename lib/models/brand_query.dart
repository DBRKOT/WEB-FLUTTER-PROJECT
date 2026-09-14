class BrandQuery {
  final String search;
  final String? country;
  final int? foundedFrom;
  final int? foundedTo;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const BrandQuery({
    this.search = '',
    this.country,
    this.foundedFrom,
    this.foundedTo,
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  factory BrandQuery.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final sortRaw = q['sort'] ?? 'name,asc';
    final parts = sortRaw.split(',');
    final field = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : 'name';
    final ascending = parts.length < 2 || parts[1].toLowerCase() != 'desc';
    return BrandQuery(
      search: q['search'] ?? '',
      country: q['country'],
      foundedFrom: int.tryParse(q['foundedFrom'] ?? ''),
      foundedTo: int.tryParse(q['foundedTo'] ?? ''),
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
    if (country != null) params['country'] = country!;
    if (foundedFrom != null) params['foundedFrom'] = '$foundedFrom';
    if (foundedTo != null) params['foundedTo'] = '$foundedTo';
    params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  String toLocation([String path = '/brands']) {
    final params = toQueryParameters();
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  BrandQuery copyWith({
    String? search,
    Object? country = _unset,
    Object? foundedFrom = _unset,
    Object? foundedTo = _unset,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return BrandQuery(
      search: search ?? this.search,
      country: country == _unset ? this.country : country as String?,
      foundedFrom: foundedFrom == _unset
          ? this.foundedFrom
          : foundedFrom as int?,
      foundedTo: foundedTo == _unset ? this.foundedTo : foundedTo as int?,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BrandQuery &&
        other.search == search &&
        other.country == country &&
        other.foundedFrom == foundedFrom &&
        other.foundedTo == foundedTo &&
        other.sortField == sortField &&
        other.sortAscending == sortAscending &&
        other.page == page &&
        other.size == size &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(
    search,
    country,
    foundedFrom,
    foundedTo,
    sortField,
    sortAscending,
    page,
    size,
    includeDeleted,
  );

  static const _unset = Object();
}
