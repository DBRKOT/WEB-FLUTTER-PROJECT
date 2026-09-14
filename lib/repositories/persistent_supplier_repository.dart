import 'package:shared_preferences/shared_preferences.dart';

import '../core/field_validation_exception.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import 'prefs_list_store.dart';
import 'product_repository.dart';
import 'seed_data.dart';
import 'supplier_repository.dart';

class PersistentSupplierRepository implements SupplierRepository {
  PersistentSupplierRepository(SharedPreferences prefs, this._products)
    : _store = PrefsListStore<Supplier>(
        prefs: prefs,
        key: 'suppliers_v1',
        seed: seedSuppliers,
        fromJson: Supplier.fromJson,
        toJson: (s) => s.toJson(),
        idOf: (s) => s.id,
        withId: (s, id) => Supplier(
          id: id,
          name: s.name,
          country: s.country,
          phone: s.phone,
          deletedAt: s.deletedAt,
        ),
      );

  final ProductRepository _products;
  final PrefsListStore<Supplier> _store;

  @override
  Future<PageResult<Supplier>> find(SimpleQuery q) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _store.page(
      q,
      isDeleted: (s) => s.isDeleted,
      matchesSearch: (s, needle) =>
          s.name.toLowerCase().contains(needle) ||
          s.country.toLowerCase().contains(needle) ||
          s.phone.toLowerCase().contains(needle),
      compare: (a, b) => switch (q.sortField) {
        'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      },
    );
  }

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) async {
    return _store.items.where((s) => includeDeleted || !s.isDeleted).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<Supplier?> findById(int id) async => _store.byId(id);

  @override
  Future<Supplier> create(Supplier supplier) async => _store.add(supplier);

  @override
  Future<Supplier> update(Supplier supplier) async => _store.replace(supplier);

  Future<void> _ensureNoProducts(int id) async {
    final count = await _products.countBySupplier(id);
    if (count > 0) {
      throw FieldValidationException({
        'supplier': 'Нельзя удалить: есть $count связанн(ых) товар(ов)',
      }, 'Нельзя удалить поставщика: есть $count связанн(ых) товар(ов)');
    }
  }

  @override
  Future<void> softDelete(int id) async {
    await _ensureNoProducts(id);
    final item = _store.byId(id);
    if (item == null) throw StateError('Поставщик $id не найден');
    _store.replace(item.copyWith(deletedAt: DateTime.now()));
  }

  @override
  Future<void> hardDelete(int id) async {
    await _ensureNoProducts(id);
    _store.remove(id);
  }

  @override
  Future<void> restore(int id) async {
    final item = _store.byId(id);
    if (item == null) throw StateError('Поставщик $id не найден');
    _store.replace(item.copyWith(clearDeletedAt: true));
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final linked = await _products.countBySupplier(id);
      if (linked > 0) continue;
      final item = _store.byId(id);
      if (item != null && !item.isDeleted) {
        _store.replace(item.copyWith(deletedAt: DateTime.now()));
        count++;
      }
    }
    return count;
  }

  @override
  Future<int> countProducts(int supplierId) =>
      _products.countBySupplier(supplierId);
}
