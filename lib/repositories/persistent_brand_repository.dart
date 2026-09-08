import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import 'brand_repository.dart';
import 'seed_data.dart';

class PersistentBrandRepository implements BrandRepository {
  static const _key = 'brands_v1';

  final SharedPreferences _prefs;
  List<Brand> _brands = [];
  int _nextId = 1;

  PersistentBrandRepository(this._prefs) {
    _restore();
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      _brands = [...seedBrands];
      _nextId = _maxId() + 1;
      _persist();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _brands =
          list.map((e) => Brand.fromJson(e as Map<String, dynamic>)).toList();
      _nextId = _maxId() + 1;
    } catch (_) {
      _brands = [...seedBrands];
      _nextId = _maxId() + 1;
      _persist();
    }
  }

  int _maxId() {
    if (_brands.isEmpty) return 0;
    return _brands.map((b) => b.id).reduce((a, b) => a > b ? a : b);
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _key,
      jsonEncode(_brands.map((b) => b.toJson()).toList()),
    );
  }

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) async {
    return _brands
        .where((b) => includeDeleted || !b.isDeleted)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<PageResult<Brand>> find(BrandQuery q) async {
    await Future.delayed(const Duration(milliseconds: 250));
    var rows = _brands.where((b) => q.includeDeleted || !b.isDeleted).toList();
    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows
          .where(
            (b) =>
                b.name.toLowerCase().contains(needle) ||
                b.country.toLowerCase().contains(needle) ||
                b.email.toLowerCase().contains(needle),
          )
          .toList();
    }
    if (q.country != null) {
      rows = rows.where((b) => b.country == q.country).toList();
    }
    if (q.foundedFrom != null) {
      rows = rows.where((b) => b.foundedYear >= q.foundedFrom!).toList();
    }
    if (q.foundedTo != null) {
      rows = rows.where((b) => b.foundedYear <= q.foundedTo!).toList();
    }
    rows.sort((a, b) {
      final result = switch (q.sortField) {
        'foundedYear' => a.foundedYear.compareTo(b.foundedYear),
        'country' => a.country.toLowerCase().compareTo(b.country.toLowerCase()),
        'email' => a.email.toLowerCase().compareTo(b.email.toLowerCase()),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return q.sortAscending ? result : -result;
    });
    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final items = from >= total ? <Brand>[] : rows.sublist(from, to);
    return PageResult(items: items, page: q.page, size: q.size, total: total);
  }

  @override
  Future<Brand?> findById(int id) async {
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      return _brands.firstWhere((b) => b.id == id);
    } on StateError {
      return null;
    }
  }

  @override
  Future<Brand> create(Brand brand) async {
    final created = Brand(
      id: _nextId++,
      name: brand.name,
      foundedYear: brand.foundedYear,
      country: brand.country,
      email: brand.email,
    );
    _brands.add(created);
    await _persist();
    return created;
  }

  @override
  Future<Brand> update(Brand brand) async {
    final i = _brands.indexWhere((b) => b.id == brand.id);
    if (i == -1) {
      throw StateError('Бренд ${brand.id} не найден');
    }
    _brands[i] = brand;
    await _persist();
    return brand;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _brands.indexWhere((b) => b.id == id);
    if (i == -1) {
      throw StateError('Бренд $id не найден');
    }
    _brands[i] = _brands[i].copyWith(deletedAt: DateTime.now());
    await _persist();
  }

  @override
  Future<void> hardDelete(int id) async {
    _brands.removeWhere((b) => b.id == id);
    await _persist();
  }

  @override
  Future<void> restore(int id) async {
    final i = _brands.indexWhere((b) => b.id == id);
    if (i == -1) {
      throw StateError('Бренд $id не найден');
    }
    _brands[i] = _brands[i].copyWith(clearDeletedAt: true);
    await _persist();
  }

  @override
  Future<int> deleteMany(List<int> ids) async {
    var count = 0;
    for (final id in ids) {
      final i = _brands.indexWhere((b) => b.id == id && !b.isDeleted);
      if (i != -1) {
        _brands[i] = _brands[i].copyWith(deletedAt: DateTime.now());
        count++;
      }
    }
    await _persist();
    return count;
  }
}
