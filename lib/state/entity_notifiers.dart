import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/api_exceptions.dart';
import '../core/reference_cache.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/master.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/order_query.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/repair_order.dart';
import '../models/repair_query.dart';
import '../models/service.dart';
import '../models/simple_query.dart';
import '../models/stock.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repositories.dart';
import '../repositories/service_repositories.dart';
import 'crud_list_notifier.dart';
import 'load_status.dart';

class ProductListNotifier extends CrudListNotifier<Product, ProductQuery> {
  ProductListNotifier(PbProductRepository repository, {super.onInvalidate})
    : _products = repository,
      super(repository, const ProductQuery());

  final PbProductRepository _products;

  Future<bool> isSkuTaken(String sku, {String? excludeId}) =>
      _products.isSkuTaken(sku, excludeId: excludeId);

  Future<int> countBySupplier(String supplierId) =>
      _products.countBySupplier(supplierId);
}

class BrandListNotifier extends CrudListNotifier<Brand, BrandQuery> {
  BrandListNotifier(PbBrandRepository repository, {super.onInvalidate})
    : _brands = repository,
      super(repository, const BrandQuery());

  final PbBrandRepository _brands;

  Future<bool> isNameTaken(String name, {String? excludeId}) =>
      _brands.isNameTaken(name, excludeId: excludeId);
}

class CategoryListNotifier extends CrudListNotifier<Category, SimpleQuery> {
  CategoryListNotifier(PbCategoryRepository repository, {super.onInvalidate})
    : _categories = repository,
      super(repository, const SimpleQuery());

  final PbCategoryRepository _categories;

  Future<bool> isNameTaken(String name, {String? excludeId}) =>
      _categories.isNameTaken(name, excludeId: excludeId);
}

class SupplierListNotifier extends CrudListNotifier<Supplier, SimpleQuery> {
  SupplierListNotifier(PbSupplierRepository repository, {super.onInvalidate})
    : super(repository, const SimpleQuery());
}

class StockListNotifier extends CrudListNotifier<Stock, SimpleQuery> {
  StockListNotifier(PbStockRepository repository, {super.onInvalidate})
    : _stock = repository,
      super(repository, const SimpleQuery());

  final PbStockRepository _stock;

  Future<bool> isProductTaken(String productId, {String? excludeId}) =>
      _stock.isProductTaken(productId, excludeId: excludeId);
}

class CustomerListNotifier extends CrudListNotifier<Customer, SimpleQuery> {
  CustomerListNotifier(PbCustomerRepository repository, {super.onInvalidate})
    : _customers = repository,
      super(repository, const SimpleQuery());

  final PbCustomerRepository _customers;

  Future<bool> isUserTaken(String userId, {String? excludeId}) =>
      _customers.isUserTaken(userId, excludeId: excludeId);
}

class ServiceListNotifier extends CrudListNotifier<Service, SimpleQuery> {
  ServiceListNotifier(PbServiceRepository repository, {super.onInvalidate})
    : _services = repository,
      super(repository, const SimpleQuery());

  final PbServiceRepository _services;

  Future<bool> isNameTaken(String name, {String? excludeId}) =>
      _services.isNameTaken(name, excludeId: excludeId);
}

class MasterListNotifier extends CrudListNotifier<Master, SimpleQuery> {
  MasterListNotifier(PbMasterRepository repository, {super.onInvalidate})
    : super(repository, const SimpleQuery());
}

class RepairListNotifier extends CrudListNotifier<RepairOrder, RepairQuery> {
  RepairListNotifier(PbRepairRepository repository, {super.onInvalidate})
    : _repairs = repository,
      super(repository, const RepairQuery());

  final PbRepairRepository _repairs;

  Future<void> changeStatus(String id, RepairStatus status) async {
    await _repairs.changeStatus(id, status);
    await load();
  }

  Future<List<RepairOrder>> masterSchedule(
    String masterId, {
    String? excludeId,
  }) => _repairs.findMasterSchedule(masterId, excludeId: excludeId);
}

class OrderListNotifier extends CrudListNotifier<Order, OrderQuery> {
  OrderListNotifier(PbOrderRepository repository, {super.onInvalidate})
    : _orders = repository,
      super(repository, const OrderQuery());

  final PbOrderRepository _orders;

  Future<void> changeStatus(String id, OrderStatus status) async {
    await _orders.changeStatus(id, status);
    await load();
  }
}

class OrderItemsNotifier extends ChangeNotifier {
  OrderItemsNotifier(this._items, this._orders);

  final PbOrderItemRepository _items;
  final PbOrderRepository _orders;

  String _orderId = '';
  List<OrderItem> _list = const [];
  LoadStatus _status = LoadStatus.idle;
  String? _error;

  String get orderId => _orderId;
  List<OrderItem> get items => _list;
  LoadStatus get status => _status;
  String? get error => _error;

  int get total => _list.fold(0, (sum, item) => sum + item.sum);

  Future<void> load(String orderId) async {
    _orderId = orderId;
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _list = await _items.findByOrder(orderId);
      _status = LoadStatus.success;
    } on ApiException catch (e) {
      _error = e.message;
      _status = LoadStatus.error;
    } catch (e) {
      _error = 'Не удалось загрузить позиции заказа: $e';
      _status = LoadStatus.error;
    }
    notifyListeners();
  }

  Future<bool> isProductInOrder(String productId, {String? excludeId}) =>
      _items.isProductInOrder(_orderId, productId, excludeId: excludeId);

  Future<void> add(OrderItem item) async {
    await _items.create(item);
    await _reloadAndSync();
  }

  Future<void> edit(OrderItem item) async {
    await _items.update(item);
    await _reloadAndSync();
  }

  Future<void> remove(String id) async {
    await _items.delete(id);
    await _reloadAndSync();
  }

  Future<void> _reloadAndSync() async {
    await load(_orderId);
    if (_orderId.isNotEmpty && _status == LoadStatus.success) {
      await _orders.updateTotal(_orderId, total);
    }
  }
}

Invalidate invalidateFor(ReferenceCache cache, String entity) =>
    switch (entity) {
      'brands' => cache.invalidateBrands,
      'categories' => cache.invalidateCategories,
      'suppliers' => cache.invalidateSuppliers,
      'products' => cache.invalidateProducts,
      'services' => cache.invalidateServices,
      'masters' => cache.invalidateMasters,
      'customers' => cache.invalidateCustomers,
      _ => cache.invalidateAll,
    };

typedef Invalidate = void Function();
