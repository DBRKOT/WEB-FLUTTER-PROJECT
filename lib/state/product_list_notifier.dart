import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../repositories/product_repository.dart';
import 'load_status.dart';

class ProductListNotifier extends ChangeNotifier {
  ProductListNotifier(this._repository);

  final ProductRepository _repository;
  bool _disposed = false;

  ProductQuery _query = const ProductQuery();
  PageResult<Product> _result = PageResult.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _failNext = false;
  final Set<int> _selected = {};
  CancelToken? _findCancel;

  ProductQuery get query => _query;
  PageResult<Product> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<int> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    _findCancel?.cancel('устарел');
    final token = CancelToken();
    _findCancel = token;

    _status = LoadStatus.loading;
    _error = null;
    _safeNotify();
    try {
      if (_failNext) {
        _failNext = false;
        throw Exception('Сервер временно недоступен');
      }
      _result = await _repository.find(_query, cancelToken: token);
      if (token.isCancelled) return;
      _status = LoadStatus.success;
    } on RequestCancelledException {
      return;
    } on ApiException catch (e) {
      if (token.isCancelled) return;
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      if (token.isCancelled) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _safeNotify();
  }

  Future<void> applyQuery(ProductQuery next) async {
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

  Future<Product?> findById(int id) => _repository.findById(id);

  Future<Product> create(Product product) async {
    final created = await _repository.create(product);
    await load();
    return created;
  }

  Future<Product> update(Product product) async {
    final updated = await _repository.update(product);
    await load();
    return updated;
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _findCancel?.cancel('dispose');
    _disposed = true;
    super.dispose();
  }
}
