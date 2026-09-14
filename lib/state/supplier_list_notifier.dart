import '../core/field_validation_exception.dart';
import '../core/reference_cache.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import '../repositories/supplier_repository.dart';
import 'entity_list_notifier.dart';

// ignore_for_file: prefer_initializing_formals

class SupplierListNotifier extends EntityListNotifier<Supplier> {
  SupplierListNotifier(this._repository, {ReferenceCache? cache})
    : _cache = cache;

  final SupplierRepository _repository;
  final ReferenceCache? _cache;

  void _invalidate() => _cache?.invalidateSuppliers();

  @override
  Future<PageResult<Supplier>> fetch(SimpleQuery query) =>
      _repository.find(query);

  @override
  Future<Supplier?> fetchById(int id) => _repository.findById(id);

  @override
  Future<List<Supplier>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<Supplier> doCreate(Supplier item) async {
    final created = await _repository.create(item);
    _invalidate();
    return created;
  }

  @override
  Future<Supplier> doUpdate(Supplier item) async {
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

  Future<int> countProducts(int supplierId) =>
      _repository.countProducts(supplierId);

  Future<void> softDeleteChecked(int id) async {
    try {
      await softDelete(id);
    } on FieldValidationException {
      rethrow;
    }
  }

  Future<void> hardDeleteChecked(int id) async {
    try {
      await hardDelete(id);
    } on FieldValidationException {
      rethrow;
    }
  }
}
