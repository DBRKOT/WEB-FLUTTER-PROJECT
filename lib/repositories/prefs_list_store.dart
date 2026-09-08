import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/page_result.dart';
import '../models/simple_query.dart';

typedef JsonMap = Map<String, dynamic>;

class PrefsListStore<T> {
  PrefsListStore({
    required SharedPreferences prefs,
    required String key,
    required List<T> seed,
    required T Function(JsonMap) fromJson,
    required JsonMap Function(T) toJson,
    required int Function(T) idOf,
    required T Function(T item, int id) withId,
  })  : _prefs = prefs,
        _key = key,
        _seed = seed,
        _fromJson = fromJson,
        _toJson = toJson,
        _idOf = idOf,
        _withId = withId {
    _restore();
  }

  final SharedPreferences _prefs;
  final String _key;
  final List<T> _seed;
  final T Function(JsonMap) _fromJson;
  final JsonMap Function(T) _toJson;
  final int Function(T) _idOf;
  final T Function(T item, int id) _withId;

  List<T> items = [];
  int nextId = 1;

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      items = [..._seed];
      nextId = _maxId() + 1;
      persistSync();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      items = list.map((e) => _fromJson(e as JsonMap)).toList();
      nextId = _maxId() + 1;
    } catch (_) {
      items = [..._seed];
      nextId = _maxId() + 1;
      persistSync();
    }
  }

  int _maxId() {
    if (items.isEmpty) return 0;
    return items.map(_idOf).reduce((a, b) => a > b ? a : b);
  }

  void persistSync() {
    _prefs.setString(_key, jsonEncode(items.map(_toJson).toList()));
  }

  Future<void> persist() async => persistSync();

  T? byId(int id) {
    try {
      return items.firstWhere((e) => _idOf(e) == id);
    } on StateError {
      return null;
    }
  }

  T add(T item) {
    final created = _withId(item, nextId++);
    items.add(created);
    persistSync();
    return created;
  }

  T replace(T item) {
    final i = items.indexWhere((e) => _idOf(e) == _idOf(item));
    if (i == -1) throw StateError('Запись ${_idOf(item)} не найдена');
    items[i] = item;
    persistSync();
    return item;
  }

  void remove(int id) {
    items.removeWhere((e) => _idOf(e) == id);
    persistSync();
  }

  PageResult<T> page(
    SimpleQuery q, {
    required bool Function(T) isDeleted,
    required bool Function(T, String needle) matchesSearch,
    required int Function(T a, T b) compare,
  }) {
    var rows = items.where((e) => q.includeDeleted || !isDeleted(e)).toList();
    if (q.search.trim().isNotEmpty) {
      final needle = q.search.trim().toLowerCase();
      rows = rows.where((e) => matchesSearch(e, needle)).toList();
    }
    rows.sort((a, b) {
      final result = compare(a, b);
      return q.sortAscending ? result : -result;
    });
    final total = rows.length;
    final from = (q.page - 1) * q.size;
    final to = (from + q.size) > total ? total : (from + q.size);
    final pageItems = from >= total ? <T>[] : rows.sublist(from, to);
    return PageResult(items: pageItems, page: q.page, size: q.size, total: total);
  }
}
