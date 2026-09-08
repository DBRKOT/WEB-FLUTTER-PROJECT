import '../models/category.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';

abstract interface class CategoryRepository {
  Future<PageResult<Category>> find(SimpleQuery query);
  Future<List<Category>> findAll({bool includeDeleted = false});
  Future<Category?> findById(int id);
  Future<Category> create(Category category);
  Future<Category> update(Category category);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
}
