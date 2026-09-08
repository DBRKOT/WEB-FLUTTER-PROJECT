import 'package:flutter/foundation.dart';

import '../models/page_result.dart';
import '../models/simple_query.dart';
import 'load_status.dart';

abstract class EntityListNotifier<T> extends ChangeNotifier {
  bool _disposed = false;
  SimpleQuery _query = const SimpleQuery();
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _failNext = false;
  final Set<int> _selected = {};

  SimpleQuery get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<PageResult<T>> fetch(SimpleQuery query);
  Future<T?> fetchById(int id);
  Future<List<T>> fetchAll({bool includeDeleted = false});
  Future<T> doCreate(T item);
  Future<T> doUpdate(T item);
  Future<void> doSoftDelete(int id);
  Future<void> doHardDelete(int id);
  Future<void> doRestore(int id);
  Future<int> doDeleteMany(List<int> ids);

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      if (_failNext) {
        _failNext = false;
        throw Exception('Сервер временно недоступен');
      }
      _result = await fetch(_query);
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(SimpleQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(int id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _safeNotify();
  }

  Future<void> softDelete(int id) async {
    await doSoftDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await doHardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await doRestore(id);
    await load();
  }

  Future<void> deleteSelected() async {
    await doDeleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> simulateError() {
    _failNext = true;
    return load();
  }

  Future<T?> findById(int id) => fetchById(id);

  Future<List<T>> findAll({bool includeDeleted = false}) =>
      fetchAll(includeDeleted: includeDeleted);

  Future<T> create(T item) async {
    final created = await doCreate(item);
    await load();
    return created;
  }

  Future<T> update(T item) async {
    final updated = await doUpdate(item);
    await load();
    return updated;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
