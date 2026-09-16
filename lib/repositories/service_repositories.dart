import 'package:dio/dio.dart';

import '../models/customer.dart';
import '../models/master.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_query.dart';
import '../models/page_result.dart';
import '../models/repair_order.dart';
import '../models/repair_query.dart';
import '../models/service.dart';
import '../models/simple_query.dart';
import 'catalog_repositories.dart';
import 'crud_repository.dart';
import 'pb_collection_client.dart';
import 'pb_entity_repository.dart';

class PbCustomerRepository implements CrudRepository<Customer, SimpleQuery> {
  PbCustomerRepository(Dio dio)
    : _repo = PbEntityRepository<Customer>(
        dio: dio,
        collection: 'profiles',
        fromJson: Customer.fromJson,
        toJson: (c) => c.toJson(),
        expand: 'user',
        supportsArchive: false,
      );

  final PbEntityRepository<Customer> _repo;

  String _sortField(String field) => switch (field) {
    'name' || 'fullName' => 'user.fullName',
    'email' => 'user.email',
    _ => field,
  };

  @override
  Future<PageResult<Customer>> find(SimpleQuery q) => _repo.findPage(
    filter: pbSearch(q.search, [
      'user.fullName',
      'user.email',
      'phone',
      'address',
    ]),
    sort: pbSort(_sortField(q.sortField), q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Customer>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(sort: 'user.fullName');

  @override
  Future<Customer?> findById(String id) => _repo.findById(id);

  @override
  Future<Customer> create(Customer item) => _repo.create(item);

  @override
  Future<Customer> update(Customer item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<bool> isUserTaken(String userId, {String? excludeId}) =>
      _repo.isValueTaken('user', userId, excludeId: excludeId);

  Future<Customer?> findByUser(String userId) async {
    final page = await _repo.findPage(
      filter: 'user = ${pbQuote(userId)}',
      size: 1,
    );
    return page.items.isEmpty ? null : page.items.first;
  }
}

class PbServiceRepository implements CrudRepository<Service, SimpleQuery> {
  PbServiceRepository(Dio dio)
    : _repo = PbEntityRepository<Service>(
        dio: dio,
        collection: 'services',
        fromJson: Service.fromJson,
        toJson: (s) => s.toJson(),
      );

  final PbEntityRepository<Service> _repo;

  @override
  Future<PageResult<Service>> find(SimpleQuery q) => _repo.findPage(
    filter: pbAnd([
      if (!q.includeDeleted) 'archived = false',
      pbSearch(q.search, ['name']),
    ]),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Service>> findAll({bool includeDeleted = false}) => _repo.findAll(
    filter: includeDeleted ? '' : 'archived = false',
    sort: 'name',
  );

  @override
  Future<Service?> findById(String id) => _repo.findById(id);

  @override
  Future<Service> create(Service item) => _repo.create(item);

  @override
  Future<Service> update(Service item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<bool> isNameTaken(String name, {String? excludeId}) =>
      _repo.isValueTaken('name', name, excludeId: excludeId);
}

class PbMasterRepository implements CrudRepository<Master, SimpleQuery> {
  PbMasterRepository(Dio dio)
    : _repo = PbEntityRepository<Master>(
        dio: dio,
        collection: 'masters',
        fromJson: Master.fromJson,
        toJson: (m) => m.toJson(),
      );

  final PbEntityRepository<Master> _repo;

  String _sortField(String field) => switch (field) {
    'name' => 'fullName',
    _ => field,
  };

  @override
  Future<PageResult<Master>> find(SimpleQuery q) => _repo.findPage(
    filter: pbAnd([
      if (!q.includeDeleted) 'archived = false',
      pbSearch(q.search, ['fullName', 'specialization']),
    ]),
    sort: pbSort(_sortField(q.sortField), q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Master>> findAll({bool includeDeleted = false}) => _repo.findAll(
    filter: includeDeleted ? '' : 'archived = false',
    sort: 'fullName',
  );

  @override
  Future<Master?> findById(String id) => _repo.findById(id);

  @override
  Future<Master> create(Master item) => _repo.create(item);

  @override
  Future<Master> update(Master item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);
}

class PbRepairRepository implements CrudRepository<RepairOrder, RepairQuery> {
  PbRepairRepository(Dio dio)
    : _repo = PbEntityRepository<RepairOrder>(
        dio: dio,
        collection: 'repair_orders',
        fromJson: RepairOrder.fromJson,
        toJson: (r) => r.toJson(),
        expand: 'client,product,master,services',
      );

  final PbEntityRepository<RepairOrder> _repo;

  String _filter(RepairQuery q) => pbAnd([
    if (!q.includeDeleted) 'archived = false',
    pbSearch(q.search, ['problem']),
    if (q.status != null) 'status = ${pbQuote(q.status!.apiValue)}',
    if (q.masterId != null) 'master = ${pbQuote(q.masterId!)}',
    if (q.clientId != null) 'client = ${pbQuote(q.clientId!)}',
  ]);

  @override
  Future<PageResult<RepairOrder>> find(RepairQuery q) => _repo.findPage(
    filter: _filter(q),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<RepairOrder>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(
        filter: includeDeleted ? '' : 'archived = false',
        sort: '-startAt',
      );

  @override
  Future<RepairOrder?> findById(String id) => _repo.findById(id);

  @override
  Future<RepairOrder> create(RepairOrder item) => _repo.create(item);

  @override
  Future<RepairOrder> update(RepairOrder item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<RepairOrder> changeStatus(String id, RepairStatus status) =>
      _repo.patch(id, {'status': status.apiValue});

  Future<List<RepairOrder>> findMasterSchedule(
    String masterId, {
    String? excludeId,
  }) async {
    if (masterId.isEmpty) return const [];
    final filter = pbAnd([
      'master = ${pbQuote(masterId)}',
      'archived = false',
      'status != "issued"',
      'status != "rejected"',
      if (excludeId != null && excludeId.isNotEmpty)
        'id != ${pbQuote(excludeId)}',
    ]);
    return _repo.findAll(filter: filter, sort: 'startAt');
  }
}

class PbOrderRepository implements CrudRepository<Order, OrderQuery> {
  PbOrderRepository(Dio dio)
    : _repo = PbEntityRepository<Order>(
        dio: dio,
        collection: 'orders',
        fromJson: Order.fromJson,
        toJson: (o) => o.toJson(),
        expand: 'client',
      );

  final PbEntityRepository<Order> _repo;

  String _filter(OrderQuery q) => pbAnd([
    if (!q.includeDeleted) 'archived = false',
    pbSearch(q.search, ['comment', 'client.fullName', 'client.email']),
    if (q.status != null) 'status = ${pbQuote(q.status!.apiValue)}',
    if (q.clientId != null) 'client = ${pbQuote(q.clientId!)}',
  ]);

  @override
  Future<PageResult<Order>> find(OrderQuery q) => _repo.findPage(
    filter: _filter(q),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Order>> findAll({bool includeDeleted = false}) => _repo.findAll(
    filter: includeDeleted ? '' : 'archived = false',
    sort: '-created',
  );

  @override
  Future<Order?> findById(String id) => _repo.findById(id);

  @override
  Future<Order> create(Order item) => _repo.create(item);

  @override
  Future<Order> update(Order item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<Order> changeStatus(String id, OrderStatus status) =>
      _repo.patch(id, {'status': status.apiValue});

  Future<Order> updateTotal(String id, int total) =>
      _repo.patch(id, {'total': total});
}

class PbOrderItemRepository {
  PbOrderItemRepository(Dio dio)
    : _repo = PbEntityRepository<OrderItem>(
        dio: dio,
        collection: 'order_items',
        fromJson: OrderItem.fromJson,
        toJson: (i) => i.toJson(),
        expand: 'product',
        supportsArchive: false,
      );

  final PbEntityRepository<OrderItem> _repo;

  Future<List<OrderItem>> findByOrder(String orderId) =>
      _repo.findAll(filter: 'order = ${pbQuote(orderId)}', sort: 'created');

  Future<OrderItem> create(OrderItem item) => _repo.create(item);

  Future<OrderItem> update(OrderItem item) => _repo.update(item.id, item);

  Future<void> delete(String id) => _repo.hardDelete(id);

  Future<bool> isProductInOrder(
    String orderId,
    String productId, {
    String? excludeId,
  }) async {
    final filter = pbAnd([
      'order = ${pbQuote(orderId)}',
      'product = ${pbQuote(productId)}',
      if (excludeId != null && excludeId.isNotEmpty)
        'id != ${pbQuote(excludeId)}',
    ]);
    final page = await _repo.findPage(filter: filter, size: 1);
    return page.total > 0;
  }
}
