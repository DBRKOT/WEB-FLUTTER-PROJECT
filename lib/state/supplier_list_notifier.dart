import '../core/field_validation_exception.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import '../repositories/supplier_repository.dart';
import 'entity_list_notifier.dart';

class SupplierListNotifier extends EntityListNotifier<Supplier> {
  SupplierListNotifier(this._repository);

  final SupplierRepository _repository;

  @override
  Future<PageResult<Supplier>> fetch(SimpleQuery query) =>
      _repository.find(query);

  @override
  Future<Supplier?> fetchById(int id) => _repository.findById(id);

  @override
  Future<List<Supplier>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<Supplier> doCreate(Supplier item) => _repository.create(item);

  @override
  Future<Supplier> doUpdate(Supplier item) => _repository.update(item);

  @override
  Future<void> doSoftDelete(int id) => _repository.softDelete(id);

  @override
  Future<void> doHardDelete(int id) => _repository.hardDelete(id);

  @override
  Future<void> doRestore(int id) => _repository.restore(id);

  @override
  Future<int> doDeleteMany(List<int> ids) => _repository.deleteMany(ids);

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
