import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';

class ApiProductRepository implements ProductRepository {
  ApiProductRepository(this._dio);

  final Dio _dio;

  @override
  Future<PageResult<Product>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) =>
      guardRead(() async {
        final sortField = switch (q.sortField) {
          'name' => 'title',
          'sku' => 'isbn',
          'stockTotal' => 'copiesTotal',
          'stockAvailable' => 'copiesAvailable',
          'price' => 'pages',
          _ => q.sortField,
        };

        final response = await _dio.get(
          '/books',
          queryParameters: {
            if (q.search.trim().isNotEmpty) 'search': q.search.trim(),
            if (q.categoryId != null) 'genreId': q.categoryId,
            if (q.brandId != null) 'authorId': q.brandId,
            if (q.supplierId != null) 'publisherId': q.supplierId,
            if (q.yearFrom != null) 'yearFrom': q.yearFrom,
            if (q.yearTo != null) 'yearTo': q.yearTo,
            'sort': '$sortField,${q.sortAscending ? 'asc' : 'desc'}',
            'page': q.page,
            'size': q.size,
            if (q.includeDeleted) 'includeDeleted': true,
          },
          cancelToken: cancelToken,
        );

        final data = response.data as Map<String, dynamic>;
        return PageResult(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(Product.fromJson)
              .toList(),
          page: data['page'] as int? ?? 1,
          size: data['size'] as int? ?? q.size,
          total: data['total'] as int? ?? 0,
        );
      });

  @override
  Future<Product?> findById(int id) => guardRead(() async {
        try {
          final response = await _dio.get('/books/$id');
          return Product.fromJson(response.data as Map<String, dynamic>);
        } on DioException catch (e) {
          final mapped = mapDioError(e);
          if (mapped is NotFoundException) return null;
          throw mapped;
        }
      });

  @override
  Future<Product> create(Product product) => guard(() async {
        final response = await _dio.post('/books', data: _toBookBody(product));
        return Product.fromJson(response.data as Map<String, dynamic>);
      });

  @override
  Future<Product> update(Product product) => guard(() async {
        final response =
            await _dio.put('/books/${product.id}', data: _toBookBody(product));
        return Product.fromJson(response.data as Map<String, dynamic>);
      });

  @override
  Future<void> softDelete(int id) =>
      guard(() => _dio.delete('/books/$id'));

  @override
  Future<void> hardDelete(int id) =>
      guard(() => _dio.delete('/books/$id', queryParameters: {'hard': true}));

  @override
  Future<void> restore(int id) =>
      guard(() => _dio.post('/books/$id/restore'));

  @override
  Future<int> deleteMany(List<int> ids) => guard(() async {
        final response =
            await _dio.post('/books/bulk-delete', data: {'ids': ids});
        return (response.data as Map<String, dynamic>)['deleted'] as int? ?? 0;
      });

  @override
  Future<bool> isSkuTaken(String sku, {int? excludeId}) => guardRead(() async {
        final response = await _dio.get(
          '/books',
          queryParameters: {'search': sku.trim(), 'size': 50},
        );
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List).whereType<Map<String, dynamic>>();
        for (final item in items) {
          final product = Product.fromJson(item);
          if (product.sku == sku.trim() && product.id != excludeId) {
            return true;
          }
        }
        return false;
      });

  @override
  Future<int> countBySupplier(int supplierId) => guardRead(() async {
        final response = await _dio.get(
          '/books',
          queryParameters: {
            'publisherId': supplierId,
            'page': 1,
            'size': 1,
          },
        );
        final data = response.data as Map<String, dynamic>;
        return data['total'] as int? ?? 0;
      });

  Map<String, dynamic> _toBookBody(Product product) => {
        'title': product.name,
        'isbn': product.sku,
        'year': product.year,
        'pages': product.price > 0 ? product.price : 1,
        'publisherId': product.supplierId,
        'authorIds': product.brandIds,
        'genreIds': product.categoryIds,
        'copiesTotal': product.stockTotal,
      };
}
