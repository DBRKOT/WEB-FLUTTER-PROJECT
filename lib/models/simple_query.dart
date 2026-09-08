class SimpleQuery {
  final String search;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final bool includeDeleted;

  const SimpleQuery({
    this.search = '',
    this.sortField = 'name',
    this.sortAscending = true,
    this.page = 1,
    this.size = 10,
    this.includeDeleted = false,
  });

  factory SimpleQuery.fromUri(Uri uri, {String defaultSort = 'name'}) {
    final q = uri.queryParameters;
    final sortRaw = q['sort'] ?? '$defaultSort,asc';
    final parts = sortRaw.split(',');
    final field =
        parts.isNotEmpty && parts.first.isNotEmpty ? parts.first : defaultSort;
    final ascending = parts.length < 2 || parts[1].toLowerCase() != 'desc';
    return SimpleQuery(
      search: q['search'] ?? '',
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
    params['sort'] = '$sortField,${sortAscending ? 'asc' : 'desc'}';
    if (page != 1) params['page'] = '$page';
    if (size != 10) params['size'] = '$size';
    if (includeDeleted) params['includeDeleted'] = 'true';
    return params;
  }

  String toLocation(String path) {
    final params = toQueryParameters();
    if (params.isEmpty) return path;
    return Uri(path: path, queryParameters: params).toString();
  }

  SimpleQuery copyWith({
    String? search,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    bool? includeDeleted,
  }) {
    return SimpleQuery(
      search: search ?? this.search,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? 1,
      size: size ?? this.size,
      includeDeleted: includeDeleted ?? this.includeDeleted,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SimpleQuery &&
        other.search == search &&
        other.sortField == sortField &&
        other.sortAscending == sortAscending &&
        other.page == page &&
        other.size == size &&
        other.includeDeleted == includeDeleted;
  }

  @override
  int get hashCode => Object.hash(
        search,
        sortField,
        sortAscending,
        page,
        size,
        includeDeleted,
      );
}
