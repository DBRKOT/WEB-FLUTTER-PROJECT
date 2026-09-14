import 'package:dio/dio.dart';

import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import 'api_collection_client.dart';
import 'brand_repository.dart';

class ApiBrandRepository implements BrandRepository {
  ApiBrandRepository(Dio dio) : _api = ApiCollectionClient(dio, 'authors');

  final ApiCollectionClient _api;

  @override
  Future<PageResult<Brand>> find(BrandQuery q) async {
    final sortField = switch (q.sortField) {
      'name' => 'fullName',
      'foundedYear' => 'birthYear',
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
    var items = page.items.map(Brand.fromJson).toList();
    if (q.country != null && q.country!.trim().isNotEmpty) {
      final c = q.country!.trim().toLowerCase();
      items = items.where((b) => b.country.toLowerCase().contains(c)).toList();
    }
    if (q.foundedFrom != null) {
      items = items.where((b) => b.foundedYear >= q.foundedFrom!).toList();
    }
    if (q.foundedTo != null) {
      items = items.where((b) => b.foundedYear <= q.foundedTo!).toList();
    }
    return PageResult(
      items: items,
      page: page.page,
      size: page.size,
      total: page.total,
    );
  }

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) async {
    final rows = await _api.findAll(includeDeleted: includeDeleted);
    return rows.map(Brand.fromJson).toList();
  }

  @override
  Future<Brand?> findById(int id) async {
    final row = await _api.findById(id);
    return row == null ? null : Brand.fromJson(row);
  }

  @override
  Future<Brand> create(Brand brand) async {
    final row = await _api.create(_toAuthorBody(brand));
    return Brand.fromJson(row);
  }

  @override
  Future<Brand> update(Brand brand) async {
    final row = await _api.update(brand.id, _toAuthorBody(brand));
    return Brand.fromJson(row);
  }

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  Map<String, dynamic> _toAuthorBody(Brand brand) => {
    'fullName': brand.name,
    'birthYear': brand.foundedYear,
    'country': brand.country,
  };
}
