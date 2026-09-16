import 'package:dio/dio.dart';

import '../models/page_result.dart';
import 'pb_collection_client.dart';

class PbEntityRepository<T> {
  PbEntityRepository({
    required Dio dio,
    required String collection,
    required this.fromJson,
    required this.toJson,
    this.expand = '',
    this.supportsArchive = true,
  }) : _api = PbCollectionClient(dio, collection);

  final PbCollectionClient _api;
  final T Function(Map<String, dynamic> json) fromJson;
  final Map<String, dynamic> Function(T item) toJson;
  final String expand;

  final bool supportsArchive;

  String get collection => _api.collection;

  Future<PageResult<T>> findPage({
    String filter = '',
    String sort = '',
    int page = 1,
    int size = 10,
  }) async {
    final result = await _api.findPage(
      filter: filter,
      sort: sort,
      expand: expand,
      page: page,
      size: size,
    );
    return PageResult(
      items: result.items.map(fromJson).toList(),
      page: result.page,
      size: result.size,
      total: result.total,
    );
  }

  Future<List<T>> findAll({String filter = '', String sort = ''}) async {
    final rows = await _api.findAll(filter: filter, sort: sort, expand: expand);
    return rows.map(fromJson).toList();
  }

  Future<T?> findById(String id) async {
    final row = await _api.findById(id, expand: expand);
    return row == null ? null : fromJson(row);
  }

  Future<T> create(T item) async {
    final row = await _api.create(toJson(item));
    return fromJson(row);
  }

  Future<T> update(String id, T item) async {
    final row = await _api.update(id, toJson(item));
    return fromJson(row);
  }

  Future<T> patch(String id, Map<String, dynamic> body) async {
    final row = await _api.update(id, body);
    return fromJson(row);
  }

  //логическое удаление, где признак archived не предусмотрен то
  //запись удаляется физически.
  Future<void> softDelete(String id) =>
      supportsArchive ? _api.archive(id) : _api.hardDelete(id);

  Future<void> restore(String id) => _api.restore(id);

  Future<void> hardDelete(String id) => _api.hardDelete(id);

  Future<int> deleteMany(List<String> ids) =>
      supportsArchive ? _api.archiveMany(ids) : _api.hardDeleteMany(ids);

  Future<int> hardDeleteMany(List<String> ids) => _api.hardDeleteMany(ids);

  //проверка занятости значения — используется для полей с уникальным
  /// индексом, чтобы показать ошибку до отправки формы.
  Future<bool> isValueTaken(
    String field,
    String value, {
    String? excludeId,
  }) async {
    if (value.trim().isEmpty) return false;
    final conditions = pbAnd([
      '$field = ${pbQuote(value.trim())}',
      if (excludeId != null && excludeId.isNotEmpty)
        'id != ${pbQuote(excludeId)}',
    ]);
    final page = await _api.findPage(filter: conditions, size: 1);
    return page.total > 0;
  }

  Future<int> countWhere(String filter) async {
    final page = await _api.findPage(filter: filter, size: 1);
    return page.total;
  }
}
