import 'package:dio/dio.dart';

import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import 'api_collection_client.dart';
import 'product_repository.dart';
import 'supplier_repository.dart';

class ApiSupplierRepository implements SupplierRepository {
  ApiSupplierRepository(Dio dio, this._products)
      : _api = ApiCollectionClient(dio, 'publishers');

  final ApiCollectionClient _api;
  final ProductRepository _products;

  @override
  Future<PageResult<Supplier>> find(SimpleQuery q) async {
    final sortField = switch (q.sortField) {
      'country' => 'city',
      _ => q.sortField,
    };
    final page = await _api.findPage(
      search: q.search,
      sortField: sortField,
      sortAscending: q.sortAscending,
      page: q.page,
      size: q.size,
      includeDeleted: q.includeDeleted,
    );
    return PageResult(
      items: page.items.map(Supplier.fromJson).toList(),
      page: page.page,
      size: page.size,
      total: page.total,
    );
  }

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) async {
    final rows = await _api.findAll(includeDeleted: includeDeleted);
    return rows.map(Supplier.fromJson).toList();
  }

  @override
  Future<Supplier?> findById(int id) async {
    final row = await _api.findById(id);
    return row == null ? null : Supplier.fromJson(row);
  }

  @override
  Future<Supplier> create(Supplier supplier) async {
    final row = await _api.create(_toPublisherBody(supplier));
    return Supplier.fromJson(row);
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    final row = await _api.update(supplier.id, _toPublisherBody(supplier));
    return Supplier.fromJson(row);
  }

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  @override
  Future<int> countProducts(int supplierId) =>
      _products.countBySupplier(supplierId);

  Map<String, dynamic> _toPublisherBody(Supplier supplier) => {
        'name': supplier.name,
        'city': supplier.country,
        'foundedYear': 1990,
      };
}
