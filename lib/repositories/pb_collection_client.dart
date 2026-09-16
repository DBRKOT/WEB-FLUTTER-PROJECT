import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';

String pbQuote(String value) {
  final escaped = value.replaceAll('\\', r'\\').replaceAll('"', r'\"');
  return '"$escaped"';
}

String pbAnd(Iterable<String?> parts) =>
    parts.where((p) => p != null && p.trim().isNotEmpty).join(' && ');

String pbOr(Iterable<String?> parts) {
  final list = parts
      .where((p) => p != null && p.trim().isNotEmpty)
      .map((p) => '($p)')
      .toList();
  return list.join(' || ');
}


class PbCollectionClient {
  PbCollectionClient(this._dio, this.collection);

  final Dio _dio;
  final String collection;

  String get _base => '/collections/$collection/records';

  Future<PageResult<Map<String, dynamic>>> findPage({
    String filter = '',
    String sort = '',
    String expand = '',
    int page = 1,
    int size = 10,
  }) => guardRead(() async {
    final response = await _dio.get(
      _base,
      queryParameters: {
        if (filter.trim().isNotEmpty) 'filter': filter.trim(),
        if (sort.trim().isNotEmpty) 'sort': sort.trim(),
        if (expand.trim().isNotEmpty) 'expand': expand.trim(),
        'page': page,
        'perPage': size,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    return PageResult(
      items: items,
      page: data['page'] as int? ?? page,
      size: data['perPage'] as int? ?? size,
      total: data['totalItems'] as int? ?? items.length,
    );
  });

  Future<List<Map<String, dynamic>>> findAll({
    String filter = '',
    String sort = '',
    String expand = '',
  }) async {
    final page = await findPage(
      filter: filter,
      sort: sort,
      expand: expand,
      size: 500,
    );
    return page.items;
  }

  Future<Map<String, dynamic>?> findById(String id, {String expand = ''}) =>
      guardRead(() async {
        try {
          final response = await _dio.get(
            '$_base/$id',
            queryParameters: {
              if (expand.trim().isNotEmpty) 'expand': expand.trim(),
            },
          );
          return response.data as Map<String, dynamic>;
        } on DioException catch (e) {
          final mapped = mapDioError(e);
          if (mapped is NotFoundException) return null;
          throw mapped;
        }
      });

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) =>
      guard(() async {
        final response = await _dio.post(_base, data: body);
        return response.data as Map<String, dynamic>;
      });

  Future<Map<String, dynamic>> update(String id, Map<String, dynamic> body) =>
      guard(() async {
        final response = await _dio.patch('$_base/$id', data: body);
        return response.data as Map<String, dynamic>;
      });

  //логическое удаление: запись остаётся в базе с признаком archived.
  Future<void> archive(String id) =>
      guard(() => _dio.patch('$_base/$id', data: {'archived': true}));

  Future<void> restore(String id) =>
      guard(() => _dio.patch('$_base/$id', data: {'archived': false}));

  //физическое удаление: запись удаляется из базы безвозвратно.
  Future<void> hardDelete(String id) => guard(() => _dio.delete('$_base/$id'));

  //множественное удаление. PocketBase не имеет пакетной операции,
  /// поэтому записи обрабатываются по очереди.
  Future<int> archiveMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await archive(id);
      count++;
    }
    return count;
  }

  Future<int> hardDeleteMany(List<String> ids) async {
    var count = 0;
    for (final id in ids) {
      await hardDelete(id);
      count++;
    }
    return count;
  }
}


Map<String, dynamic>? pbExpanded(Map<String, dynamic> json, String field) {
  final expand = json['expand'];
  if (expand is! Map) return null;
  final value = expand[field];
  if (value is Map<String, dynamic>) return value;
  return null;
}

List<Map<String, dynamic>> pbExpandedList(
  Map<String, dynamic> json,
  String field,
) {
  final expand = json['expand'];
  if (expand is! Map) return const [];
  final value = expand[field];
  if (value is List) return value.whereType<Map<String, dynamic>>().toList();
  if (value is Map<String, dynamic>) return [value];
  return const [];
}


List<String> pbIdList(dynamic value) {
  if (value is List) return value.whereType<String>().toList();
  if (value is String && value.isNotEmpty) return [value];
  return const [];
}
