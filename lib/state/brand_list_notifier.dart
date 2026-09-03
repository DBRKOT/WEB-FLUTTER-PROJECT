import 'package:flutter/foundation.dart';

import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/page_result.dart';
import '../repositories/brand_repository.dart';
import 'load_status.dart';

class BrandListNotifier extends ChangeNotifier {
  BrandListNotifier(this._repository);

  final BrandRepository _repository;
  bool _disposed = false;

  BrandQuery _query = const BrandQuery();
  PageResult<Brand> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _failNext = false;
  final Set<int> _selected = {};

  BrandQuery get query => _query;
  PageResult<Brand> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      if (_failNext) {
        _failNext = false;
        throw Exception('Сервер временно недоступен');
      }
      _result = await _repository.find(_query);
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(BrandQuery next) async {
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

  void clearSelection() {
    _selected.clear();
    _safeNotify();
  }

  Future<void> softDelete(int id) async {
    await _repository.softDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> hardDelete(int id) async {
    await _repository.hardDelete(id);
    _selected.remove(id);
    await load();
  }

  Future<void> restore(int id) async {
    await _repository.restore(id);
    await load();
  }

  Future<void> deleteSelected() async {
    await _repository.deleteMany(_selected.toList());
    _selected.clear();
    await load();
  }

  Future<void> simulateError() {
    _failNext = true;
    return load();
  }

  Future<Brand?> findById(int id) => _repository.findById(id);

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
