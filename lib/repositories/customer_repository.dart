import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';

abstract interface class CustomerRepository {
  Future<PageResult<Customer>> find(SimpleQuery query);
  Future<List<Customer>> findAll({bool includeDeleted = false});
  Future<Customer?> findById(int id);
  Future<Customer> create(Customer customer);
  Future<Customer> update(Customer customer);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<bool> isEmailTaken(String email, {int? excludeId});
}
