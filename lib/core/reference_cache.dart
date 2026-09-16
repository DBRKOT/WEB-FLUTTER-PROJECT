import '../models/brand.dart';
import '../models/category.dart';
import '../models/customer.dart';
import '../models/master.dart';
import '../models/product.dart';
import '../models/service.dart';
import '../models/supplier.dart';
import '../repositories/catalog_repositories.dart';
import '../repositories/service_repositories.dart';

// ignore_for_file: prefer_initializing_formals

class ReferenceCache {
  ReferenceCache({
    required PbBrandRepository brands,
    required PbCategoryRepository categories,
    required PbSupplierRepository suppliers,
    required PbProductRepository products,
    required PbServiceRepository services,
    required PbMasterRepository masters,
    required PbCustomerRepository customers,
  }) : _brands = brands,
       _categories = categories,
       _suppliers = suppliers,
       _products = products,
       _services = services,
       _masters = masters,
       _customers = customers;

  final PbBrandRepository _brands;
  final PbCategoryRepository _categories;
  final PbSupplierRepository _suppliers;
  final PbProductRepository _products;
  final PbServiceRepository _services;
  final PbMasterRepository _masters;
  final PbCustomerRepository _customers;

  List<Brand>? _brandCache;
  List<Category>? _categoryCache;
  List<Supplier>? _supplierCache;
  List<Product>? _productCache;
  List<Service>? _serviceCache;
  List<Master>? _masterCache;
  List<Customer>? _customerCache;

  Future<List<Brand>> brands() async => _brandCache ??= await _brands.findAll();

  Future<List<Category>> categories() async =>
      _categoryCache ??= await _categories.findAll();

  Future<List<Supplier>> suppliers() async =>
      _supplierCache ??= await _suppliers.findAll();

  Future<List<Product>> products() async =>
      _productCache ??= await _products.findAll();

  Future<List<Service>> services() async =>
      _serviceCache ??= await _services.findAll();

  Future<List<Master>> masters() async =>
      _masterCache ??= await _masters.findAll();

  Future<List<Customer>> customers() async =>
      _customerCache ??= await _customers.findAll();

  void invalidateBrands() => _brandCache = null;
  void invalidateCategories() => _categoryCache = null;
  void invalidateSuppliers() => _supplierCache = null;
  void invalidateProducts() => _productCache = null;
  void invalidateServices() => _serviceCache = null;
  void invalidateMasters() => _masterCache = null;
  void invalidateCustomers() => _customerCache = null;

  void invalidateAll() {
    invalidateBrands();
    invalidateCategories();
    invalidateSuppliers();
    invalidateProducts();
    invalidateServices();
    invalidateMasters();
    invalidateCustomers();
  }
}
