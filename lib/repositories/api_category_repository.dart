import 'package:dio/dio.dart';

import '../models/category.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import 'api_collection_client.dart';
import 'category_repository.dart';

class ApiCategoryRepository implements CategoryRepository {
  ApiCategoryRepository(Dio dio) : _api = ApiCollectionClient(dio, 'genres');

  final ApiCollectionClient _api;

  @override
  Future<PageResult<Category>> find(SimpleQuery q) async {
    final page = await _api.findPage(
      search: q.search,
      sortField: q.sortField,
      sortAscending: q.sortAscending,
      page: q.page,
      size: q.size,
      includeDeleted: q.includeDeleted,
    );
    return PageResult(
      items: page.items.map(Category.fromJson).toList(),
      page: page.page,
      size: page.size,
      total: page.total,
    );
  }

  @override
  Future<List<Category>> findAll({bool includeDeleted = false}) async {
    final rows = await _api.findAll(includeDeleted: includeDeleted);
    return rows.map(Category.fromJson).toList();
  }

  @override
  Future<Category?> findById(int id) async {
    final row = await _api.findById(id);
    return row == null ? null : Category.fromJson(row);
  }

  @override
  Future<Category> create(Category category) async {
    final row = await _api.create({
      'name': category.name,
      'description': category.description,
    });
    return Category.fromJson(row);
  }

  @override
  Future<Category> update(Category category) async {
    final row = await _api.update(category.id, {
      'name': category.name,
      'description': category.description,
    });
    return Category.fromJson(row);
  }

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);
}
