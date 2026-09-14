import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/page_result.dart';
import '../models/simple_query.dart';
import 'category_repository.dart';
import 'prefs_list_store.dart';
import 'seed_data.dart';

class PersistentCategoryRepository implements CategoryRepository {
  PersistentCategoryRepository(SharedPreferences prefs)
    : _store = PrefsListStore<Category>(
        prefs: prefs,
        key: 'categories_v1',
        seed: seedCategories,
        fromJson: Category.fromJson,
        toJson: (c) => c.toJson(),
        idOf: (c) => c.id,
        withId: (c, id) => Category(
          id: id,
          name: c.name,
          description: c.description,
          deletedAt: c.deletedAt,
        ),
      );

  final PrefsListStore<Category> _store;

  @override
  Future<PageResult<Category>> find(SimpleQuery q) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _store.page(
      q,
      isDeleted: (c) => c.isDeleted,
      matchesSearch: (c, needle) =>
          c.name.toLowerCase().contains(needle) ||
          c.description.toLowerCase().contains(needle),
      compare: (a, b) => switch (q.sortField) {
        'description' => a.description.toLowerCase().compareTo(
          b.description.toLowerCase(),
        ),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      },
    );
  }

  @override
  Future<List<Category>> findAll({bool includeDeleted = false}) async {
    return _store.items.where((c) => includeDeleted || !c.isDeleted).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<Category?> findById(int id) async => _store.byId(id);

  @override
  Future<Category> create(Category category) async => _store.add(category);

  @override
  Future<Category> update(Category category) async => _store.replace(category);

  @override
  Future<void> softDelete(int id) async {
    final item = _store.byId(id);
    if (item == null) throw StateError('Категория $id не найдена');
    _store.replace(item.copyWith(deletedAt: DateTime.now()));
  }

  @override
  Future<void> hardDelete(int id) async => _store.remove(id);

  @override
  Future<void> restore(int id) async {
    final item = _store.byId(id);
    if (item == null) throw StateError('Категория $id не найдена');
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
