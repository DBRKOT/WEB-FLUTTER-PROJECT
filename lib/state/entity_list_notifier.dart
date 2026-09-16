import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import 'load_status.dart';

abstract class EntityListNotifier<T, Q> extends ChangeNotifier {
  EntityListNotifier(Q initialQuery) : _query = initialQuery;

  bool _disposed = false;
  Q _query;
  PageResult<T> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _failNext = false;
  final Set<String> _selected = {};

  Q get query => _query;
  PageResult<T> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<PageResult<T>> fetch(Q query);
  Future<T?> fetchById(String id);
  Future<List<T>> fetchAll({bool includeDeleted = false});
  Future<T> doCreate(T item);
  Future<T> doUpdate(T item);
  Future<void> doSoftDelete(String id);
  Future<void> doHardDelete(String id);
  Future<void> doRestore(String id);
  Future<int> doDeleteMany(List<String> ids);

  void onChanged() {}

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
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(Q next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  void toggleSelection(String id) {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    _safeNotify();
  }

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  Future<void> softDelete(String id) async {
    await doSoftDelete(id);
    onChanged();
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(String id) async {
    await doHardDelete(id);
    onChanged();
    _selected.remove(id);
    await load();
  }

  Future<void> restore(String id) async {
    await doRestore(id);
    onChanged();
    await load();
  }

  Future<void> deleteSelected() async {
    await doDeleteMany(_selected.toList());
    onChanged();
    _selected.clear();
    await load();
  }

  //показ состояния ошибки без остановки сервера — для демонстрации.
  Future<void> simulateError() {
    _failNext = true;
    return load();
  }

  Future<T?> findById(String id) => fetchById(id);

  Future<List<T>> findAll({bool includeDeleted = false}) =>
      fetchAll(includeDeleted: includeDeleted);

  Future<T> create(T item) async {
    final created = await doCreate(item);
    onChanged();
    await load();
    return created;
  }

  Future<T> update(T item) async {
    final updated = await doUpdate(item);
    onChanged();
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
