import '../models/page_result.dart';
import '../repositories/crud_repository.dart';
import 'entity_list_notifier.dart';

class CrudListNotifier<T, Q> extends EntityListNotifier<T, Q> {
  CrudListNotifier(this._repository, super.initialQuery, {this.onInvalidate});

  final CrudRepository<T, Q> _repository;

  final void Function()? onInvalidate;

  CrudRepository<T, Q> get repository => _repository;

  @override
  Future<PageResult<T>> fetch(Q query) => _repository.find(query);

  @override
  Future<T?> fetchById(String id) => _repository.findById(id);

  @override
  Future<List<T>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<T> doCreate(T item) => _repository.create(item);

  @override
  Future<T> doUpdate(T item) => _repository.update(item);

  @override
  Future<void> doSoftDelete(String id) => _repository.softDelete(id);

  @override
  Future<void> doHardDelete(String id) => _repository.hardDelete(id);

  @override
  Future<void> doRestore(String id) => _repository.restore(id);

  @override
  Future<int> doDeleteMany(List<String> ids) => _repository.deleteMany(ids);

  @override
  void onChanged() => onInvalidate?.call();
}
