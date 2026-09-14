import '../core/reference_cache.dart';
import '../models/category.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../repositories/category_repository.dart';
import 'entity_list_notifier.dart';

// ignore_for_file: prefer_initializing_formals

class CategoryListNotifier extends EntityListNotifier<Category> {
  CategoryListNotifier(this._repository, {ReferenceCache? cache})
    : _cache = cache;

  final CategoryRepository _repository;
  final ReferenceCache? _cache;

  void _invalidate() => _cache?.invalidateCategories();

  @override
  Future<PageResult<Category>> fetch(SimpleQuery query) =>
      _repository.find(query);

  @override
  Future<Category?> fetchById(int id) => _repository.findById(id);

  @override
  Future<List<Category>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<Category> doCreate(Category item) async {
    final created = await _repository.create(item);
    _invalidate();
    return created;
  }

  @override
  Future<Category> doUpdate(Category item) async {
    final updated = await _repository.update(item);
    _invalidate();
    return updated;
  }

  @override
  Future<void> doSoftDelete(int id) async {
    await _repository.softDelete(id);
    _invalidate();
  }

  @override
  Future<void> doHardDelete(int id) async {
    await _repository.hardDelete(id);
    _invalidate();
  }

  @override
  Future<void> doRestore(int id) async {
    await _repository.restore(id);
    _invalidate();
  }

  @override
  Future<int> doDeleteMany(List<int> ids) async {
    final n = await _repository.deleteMany(ids);
    _invalidate();
    return n;
  }
}
