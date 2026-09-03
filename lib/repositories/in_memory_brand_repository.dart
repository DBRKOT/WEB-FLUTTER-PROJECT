import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import 'brand_repository.dart';
import 'seed_data.dart';

class InMemoryBrandRepository implements BrandRepository {
  final List<Brand> _brands = [...seedBrands];
  int _nextId = seedBrands.length + 1;

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
                b.country.toLowerCase().contains(needle),
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
    rows.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
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
      return _brands.firstWhere((b) => b.id == id && !b.isDeleted);
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
    );
    _brands.add(created);
    return created;
  }

  @override
  Future<Brand> update(Brand brand) async {
    final i = _brands.indexWhere((b) => b.id == brand.id);
    if (i == -1) {
      throw StateError('Бренд ${brand.id} не найден');
    }
    _brands[i] = brand;
    return brand;
  }

  @override
  Future<void> softDelete(int id) async {
    final i = _brands.indexWhere((b) => b.id == id);
    if (i == -1) {
      throw StateError('Бренд $id не найден');
    }
    _brands[i] = _brands[i].copyWith(deletedAt: DateTime.now());
  }

  @override
  Future<void> hardDelete(int id) async {
    _brands.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> restore(int id) async {
    final i = _brands.indexWhere((b) => b.id == id);
    if (i == -1) {
      throw StateError('Бренд $id не найден');
    }
    _brands[i] = _brands[i].copyWith(clearDeletedAt: true);
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
    return count;
  }
}
