import '../models/page_result.dart';

abstract interface class CrudRepository<T, Q> {
  Future<PageResult<T>> find(Q query);

  Future<List<T>> findAll({bool includeDeleted = false});

  Future<T?> findById(String id);

  Future<T> create(T item);

  Future<T> update(T item);

  Future<void> softDelete(String id);

  Future<void> hardDelete(String id);

  Future<void> restore(String id);

  Future<int> deleteMany(List<String> ids);
}
