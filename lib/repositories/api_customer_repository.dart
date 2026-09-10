import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import 'api_collection_client.dart';
import 'customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  ApiCustomerRepository(Dio dio) : _api = ApiCollectionClient(dio, 'readers');

  final ApiCollectionClient _api;

  @override
  Future<PageResult<Customer>> find(SimpleQuery q) async {
    final sortField = switch (q.sortField) {
      'fullName' => 'fullName',
      'name' => 'fullName',
      _ => q.sortField,
    };
    final page = await _api.findPage(
      search: q.search,
      sortField: sortField,
      sortAscending: q.sortAscending,
      page: q.page,
      size: q.size,
      includeDeleted: q.includeDeleted,
    );
    return PageResult(
      items: page.items.map(Customer.fromJson).toList(),
      page: page.page,
      size: page.size,
      total: page.total,
    );
  }

  @override
  Future<List<Customer>> findAll({bool includeDeleted = false}) async {
    final rows = await _api.findAll(includeDeleted: includeDeleted);
    return rows.map(Customer.fromJson).toList();
  }

  @override
  Future<Customer?> findById(int id) async {
    final row = await _api.findById(id);
    return row == null ? null : Customer.fromJson(row);
  }

  @override
  Future<Customer> create(Customer customer) async {
    final row = await _api.create(_toReaderBody(customer));
    return Customer.fromJson(row);
  }

  @override
  Future<Customer> update(Customer customer) async {
    final row = await _api.update(customer.id, _toReaderBody(customer));
    return Customer.fromJson(row);
  }

  @override
  Future<void> softDelete(int id) => _api.softDelete(id);

  @override
  Future<void> hardDelete(int id) => _api.hardDelete(id);

  @override
  Future<void> restore(int id) => _api.restore(id);

  @override
  Future<int> deleteMany(List<int> ids) => _api.deleteMany(ids);

  @override
  Future<bool> isEmailTaken(String email, {int? excludeId}) => guard(() async {
        final page = await _api.findPage(search: email.trim(), size: 50);
        for (final row in page.items) {
          final customer = Customer.fromJson(row);
          if (customer.email.toLowerCase() == email.trim().toLowerCase() &&
              customer.id != excludeId) {
            return true;
          }
        }
        return false;
      });

  Map<String, dynamic> _toReaderBody(Customer customer) => {
        'fullName': customer.fullName,
        'email': customer.email,
        'phone': customer.phone,
      };
}
