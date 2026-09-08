import 'package:shared_preferences/shared_preferences.dart';

import '../core/field_validation_exception.dart';
import '../models/customer.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import 'customer_repository.dart';
import 'prefs_list_store.dart';
import 'seed_data.dart';

class PersistentCustomerRepository implements CustomerRepository {
  PersistentCustomerRepository(SharedPreferences prefs)
      : _store = PrefsListStore<Customer>(
          prefs: prefs,
          key: 'customers_v1',
          seed: seedCustomers,
          fromJson: Customer.fromJson,
          toJson: (c) => c.toJson(),
          idOf: (c) => c.id,
          withId: (c, id) => Customer(
            id: id,
            fullName: c.fullName,
            email: c.email,
            phone: c.phone,
            card: c.card,
            deletedAt: c.deletedAt,
          ),
        );

  final PrefsListStore<Customer> _store;

  void _ensureUniqueEmail(String email, {int? excludeId}) {
    final taken = _store.items.any(
      (c) =>
          c.email.toLowerCase() == email.trim().toLowerCase() &&
          (excludeId == null || c.id != excludeId),
    );
    if (taken) {
      throw FieldValidationException(
        {'email': 'Клиент с таким email уже существует'},
      );
    }
  }

  @override
  Future<bool> isEmailTaken(String email, {int? excludeId}) async {
    return _store.items.any(
      (c) =>
          c.email.toLowerCase() == email.trim().toLowerCase() &&
          (excludeId == null || c.id != excludeId),
    );
  }

  @override
  Future<PageResult<Customer>> find(SimpleQuery q) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _store.page(
      q,
      isDeleted: (c) => c.isDeleted,
      matchesSearch: (c, needle) =>
          c.fullName.toLowerCase().contains(needle) ||
          c.email.toLowerCase().contains(needle) ||
          c.card.number.toLowerCase().contains(needle),
      compare: (a, b) => switch (q.sortField) {
        'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        'fullName' =>
          a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      },
    );
  }

  @override
  Future<List<Customer>> findAll({bool includeDeleted = false}) async {
    return _store.items
        .where((c) => includeDeleted || !c.isDeleted)
        .toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );
  }

  @override
  Future<Customer?> findById(int id) async => _store.byId(id);

  @override
  Future<Customer> create(Customer customer) async {
    _ensureUniqueEmail(customer.email);
    return _store.add(customer);
  }

  @override
  Future<Customer> update(Customer customer) async {
    _ensureUniqueEmail(customer.email, excludeId: customer.id);
    return _store.replace(customer);
  }

  @override
  Future<void> softDelete(int id) async {
    final item = _store.byId(id);
    if (item == null) throw StateError('Клиент $id не найден');
    _store.replace(item.copyWith(deletedAt: DateTime.now()));
  }

  @override
  Future<void> hardDelete(int id) async => _store.remove(id);

  @override
  Future<void> restore(int id) async {
    final item = _store.byId(id);
    if (item == null) throw StateError('Клиент $id не найден');
    _store.replace(item.copyWith(clearDeletedAt: true));
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final item = _store.byId(id);
      if (item != null && !item.isDeleted) {
        _store.replace(item.copyWith(deletedAt: DateTime.now()));
        count++;
      }
    }
    return count;
  }
}
