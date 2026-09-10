import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/field_validation_exception.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import 'product_repository.dart';
import 'seed_data.dart';

class PersistentProductRepository implements ProductRepository {
  static const _key = 'products_v3';

  final SharedPreferences _prefs;
  List<Product> _products = [];
  int _nextId = 1;

  PersistentProductRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _products = [...seedProducts];
      _nextId = _maxId() + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _products = list
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
      _nextId = _maxId() + 1;
    } catch (_) {
      _products = [...seedProducts];
      _nextId = _maxId() + 1;
      _persist();
    }
  }

  int _maxId() {
    if (_products.isEmpty) return 0;
    return _products.map((p) => p.id).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_products.map((p) => p.toJson()).toList()),
    );
  }

  void _ensureUniqueSku(String sku, {int? excludeId}) {
    final taken = _products.any(
      (p) =>
          p.sku.toLowerCase() == sku.trim().toLowerCase() &&
          (excludeId == null || p.id != excludeId),
    );
    if (taken) {
      throw FieldValidationException(
        {'sku': 'Товар с таким артикулом уже существует'},
      );
    }
  }

  @override
  Future<bool> isSkuTaken(String sku, {int? excludeId}) async {
    return _products.any(
      (p) =>
          p.sku.toLowerCase() == sku.trim().toLowerCase() &&
          (excludeId == null || p.id != excludeId),
    );
  }

  @override
  Future<int> countBySupplier(int supplierId) async {
    return _products.where((p) => p.supplierId == supplierId && !p.isDeleted).length;
  }

  @override
  Future<PageResult<Product>> find(
    ProductQuery q, {
    CancelToken? cancelToken,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    var rows = _products.where((p) => q.includeDeleted || !p.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where(
            (p) =>
                p.name.toLowerCase().contains(needle) ||
                p.sku.toLowerCase().contains(needle),
          )
          .toList();
    }
    if (q.categoryId != null) {
      rows = rows.where((p) => p.categoryIds.contains(q.categoryId)).toList();
    }
    if (q.brandId != null) {
      rows = rows.where((p) => p.brandIds.contains(q.brandId)).toList();
    }
    if (q.supplierId != null) {
      rows = rows.where((p) => p.supplierId == q.supplierId).toList();
    }
    if (q.yearFrom != null) {
      rows = rows.where((p) => p.year >= q.yearFrom!).toList();
    }
    if (q.yearTo != null) {
      rows = rows.where((p) => p.year <= q.yearTo!).toList();
    }
    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'year' => a.year.compareTo(b.year),
        'price' => a.price.compareTo(b.price),
        'sku' => a.sku.toLowerCase().compareTo(b.sku.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });
    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Product>[] : rows.sublist(from, to);
    return PageResult(items: items, page: q.page, size: q.size, total: total);
  }

  @override
  Future<Product?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      return _products.firstWhere((p) => p.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<Product> create(Product product) async {
    _ensureUniqueSku(product.sku);
    final created = Product(
      id: _nextId++,
      name: product.name,
      sku: product.sku,
      year: product.year,
      price: product.price,
      supplierId: product.supplierId,
      brandIds: [...product.brandIds],
      categoryIds: [...product.categoryIds],
      stockTotal: product.stockTotal,
      stockAvailable: product.stockAvailable,
    );
    _products.add(created);
    await _persist();
    return created;
  }

  @override
  Future<Product> update(Product product) async {
    _ensureUniqueSku(product.sku, excludeId: product.id);
    final i = _products.indexWhere((p) => p.id == product.id);
    if (i == -1) {
      throw StateError('Товар ${product.id} не найден');
    }
    _products[i] = product;
    await _persist();
    return product;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _products[i] = _products[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _products.removeWhere((p) => p.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _products.indexWhere((p) => p.id == id);
    if (i == -1) throw StateError('Товар $id не найден');
    _products[i] = _products[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _products.indexWhere((b) => b.id == id && !b.isDeleted);
      if (i != -1) {
        _products[i] = _products[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }
}
