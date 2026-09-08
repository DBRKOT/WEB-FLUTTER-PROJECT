import '../models/category.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../repositories/category_repository.dart';
import 'entity_list_notifier.dart';

class CategoryListNotifier extends EntityListNotifier<Category> {
  CategoryListNotifier(this._repository);

  final CategoryRepository _repository;

  @override
  Future<PageResult<Category>> fetch(SimpleQuery query) =>
      _repository.find(query);

  @override
  Future<Category?> fetchById(int id) => _repository.findById(id);

  @override
  Future<List<Category>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<Category> doCreate(Category item) => _repository.create(item);

  @override
  Future<Category> doUpdate(Category item) => _repository.update(item);

  @override
  Future<void> doSoftDelete(int id) => _repository.softDelete(id);

  @override
  Future<void> doHardDelete(int id) => _repository.hardDelete(id);

  @override
  Future<void> doRestore(int id) => _repository.restore(id);

  @override
  Future<int> doDeleteMany(List<int> ids) => _repository.deleteMany(ids);
}
