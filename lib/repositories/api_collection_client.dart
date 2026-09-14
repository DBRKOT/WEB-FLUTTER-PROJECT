import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';

class ApiCollectionClient {
  ApiCollectionClient(this._dio, this.collection);

  final Dio _dio;
  final String collection;

  Future<PageResult<Map<String, dynamic>>> findPage({
    String search = '',
    String sortField = 'name',
    bool sortAscending = true,
    int page = 1,
    int size = 10,
    bool includeDeleted = false,
    Map<String, dynamic>? extraQuery,
  }) => guardRead(() async {
    final response = await _dio.get(
      '/$collection',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'sort': '$sortField,${sortAscending ? 'asc' : 'desc'}',
        'page': page,
        'size': size,
        if (includeDeleted) 'includeDeleted': true,
        ...?extraQuery,
      },
    );
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
    return PageResult(
      items: items,
      page: data['page'] as int? ?? page,
      size: data['size'] as int? ?? size,
      total: data['total'] as int? ?? items.length,
    );
  });

  Future<List<Map<String, dynamic>>> findAll({
    bool includeDeleted = false,
  }) async {
    final page = await findPage(size: 100, includeDeleted: includeDeleted);
    return page.items;
  }

  Future<Map<String, dynamic>?> findById(int id) => guardRead(() async {
    try {
      final response = await _dio.get('/$collection/$id');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      final mapped = mapDioError(e);
      if (mapped is NotFoundException) return null;
      throw mapped;
    }
  });

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) =>
      guard(() async {
        final response = await _dio.post('/$collection', data: body);
        return response.data as Map<String, dynamic>;
      });

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) =>
      guard(() async {
        final response = await _dio.put('/$collection/$id', data: body);
        return response.data as Map<String, dynamic>;
      });

  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/$collection/$id'));

  Future<void> hardDelete(int id) => guard(
    () => _dio.delete('/$collection/$id', queryParameters: {'hard': true}),
  );

  Future<void> restore(int id) =>
      guard(() => _dio.post('/$collection/$id/restore'));

  Future<int> deleteMany(List<int> ids) => guard(() async {
    final response = await _dio.post(
      '/$collection/bulk-delete',
      data: {'ids': ids},
    );
    return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
  });
}
