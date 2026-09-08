import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../repositories/customer_repository.dart';
import 'entity_list_notifier.dart';

class CustomerListNotifier extends EntityListNotifier<Customer> {
  CustomerListNotifier(this._repository);

  final CustomerRepository _repository;

  @override
  Future<PageResult<Customer>> fetch(SimpleQuery query) =>
      _repository.find(query);

  @override
  Future<Customer?> fetchById(int id) => _repository.findById(id);

  @override
  Future<List<Customer>> fetchAll({bool includeDeleted = false}) =>
      _repository.findAll(includeDeleted: includeDeleted);

  @override
  Future<Customer> doCreate(Customer item) => _repository.create(item);

  @override
  Future<Customer> doUpdate(Customer item) => _repository.update(item);

  @override
  Future<void> doSoftDelete(int id) => _repository.softDelete(id);

  @override
  Future<void> doHardDelete(int id) => _repository.hardDelete(id);

  @override
  Future<void> doRestore(int id) => _repository.restore(id);

  @override
  Future<int> doDeleteMany(List<int> ids) => _repository.deleteMany(ids);

  Future<bool> isEmailTaken(String email, {int? excludeId}) =>
      _repository.isEmailTaken(email, excludeId: excludeId);
}
