import 'package:dio/dio.dart';

import '../models/brand.dart';
import '../models/brand_query.dart';
import '../models/category.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/simple_query.dart';
import '../models/stock.dart';
import '../models/supplier.dart';
import 'crud_repository.dart';
import 'pb_collection_client.dart';
import 'pb_entity_repository.dart';

String pbSort(String field, bool ascending) => '${ascending ? '' : '-'}$field';

String pbSearch(String search, List<String> fields) {
  final text = search.trim();
  if (text.isEmpty) return '';
  return pbOr([for (final f in fields) '$f ~ ${pbQuote(text)}']);
}

class PbBrandRepository implements CrudRepository<Brand, BrandQuery> {
  PbBrandRepository(Dio dio)
    : _repo = PbEntityRepository<Brand>(
        dio: dio,
        collection: 'brands',
        fromJson: Brand.fromJson,
        toJson: (b) => b.toJson(),
        supportsArchive: false,
      );

  final PbEntityRepository<Brand> _repo;

  String _filter(BrandQuery q) => pbAnd([
    pbSearch(q.search, ['name', 'country']),
    if (q.country != null && q.country!.trim().isNotEmpty)
      'country ~ ${pbQuote(q.country!.trim())}',
    if (q.foundedFrom != null) 'foundedYear >= ${q.foundedFrom}',
    if (q.foundedTo != null) 'foundedYear <= ${q.foundedTo}',
  ]);

  @override
  Future<PageResult<Brand>> find(BrandQuery q) => _repo.findPage(
    filter: _filter(q),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Brand>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(sort: 'name');

  @override
  Future<Brand?> findById(String id) => _repo.findById(id);

  @override
  Future<Brand> create(Brand item) => _repo.create(item);

  @override
  Future<Brand> update(Brand item) => _repo.update(item.id, item);

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

class PbCategoryRepository implements CrudRepository<Category, SimpleQuery> {
  PbCategoryRepository(Dio dio)
    : _repo = PbEntityRepository<Category>(
        dio: dio,
        collection: 'categories',
        fromJson: Category.fromJson,
        toJson: (c) => c.toJson(),
        supportsArchive: false,
      );

  final PbEntityRepository<Category> _repo;

  @override
  Future<PageResult<Category>> find(SimpleQuery q) => _repo.findPage(
    filter: pbSearch(q.search, ['name', 'description']),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Category>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(sort: 'name');

  @override
  Future<Category?> findById(String id) => _repo.findById(id);

  @override
  Future<Category> create(Category item) => _repo.create(item);

  @override
  Future<Category> update(Category item) => _repo.update(item.id, item);

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

class PbSupplierRepository implements CrudRepository<Supplier, SimpleQuery> {
  PbSupplierRepository(Dio dio)
    : _repo = PbEntityRepository<Supplier>(
        dio: dio,
        collection: 'suppliers',
        fromJson: Supplier.fromJson,
        toJson: (s) => s.toJson(),
        supportsArchive: false,
      );

  final PbEntityRepository<Supplier> _repo;

  @override
  Future<PageResult<Supplier>> find(SimpleQuery q) => _repo.findPage(
    filter: pbSearch(q.search, ['name', 'city', 'contractNumber']),
    sort: pbSort(q.sortField, q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Supplier>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(sort: 'name');

  @override
  Future<Supplier?> findById(String id) => _repo.findById(id);

  @override
  Future<Supplier> create(Supplier item) => _repo.create(item);

  @override
  Future<Supplier> update(Supplier item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);
}

class PbProductRepository implements CrudRepository<Product, ProductQuery> {
  PbProductRepository(Dio dio)
    : _repo = PbEntityRepository<Product>(
        dio: dio,
        collection: 'products',
        fromJson: Product.fromJson,
        toJson: (p) => p.toJson(),
        expand: 'brand,category,supplier',
      );

  final PbEntityRepository<Product> _repo;

  String _sortField(String field) => switch (field) {
    'name' => 'title',
    'year' => 'warrantyMonths',
    _ => field,
  };

  String _filter(ProductQuery q) => pbAnd([
    if (!q.includeDeleted) 'archived = false',
    pbSearch(q.search, ['title', 'sku', 'description']),
    if (q.brandId != null) 'brand = ${pbQuote(q.brandId!)}',
    if (q.categoryId != null) 'category = ${pbQuote(q.categoryId!)}',
    if (q.supplierId != null) 'supplier = ${pbQuote(q.supplierId!)}',
    if (q.priceFrom != null) 'price >= ${q.priceFrom}',
    if (q.priceTo != null) 'price <= ${q.priceTo}',
  ]);

  @override
  Future<PageResult<Product>> find(ProductQuery q) => _repo.findPage(
    filter: _filter(q),
    sort: pbSort(_sortField(q.sortField), q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Product>> findAll({bool includeDeleted = false}) => _repo.findAll(
    filter: includeDeleted ? '' : 'archived = false',
    sort: 'title',
  );

  @override
  Future<Product?> findById(String id) => _repo.findById(id);

  @override
  Future<Product> create(Product item) => _repo.create(item);

  @override
  Future<Product> update(Product item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<bool> isSkuTaken(String sku, {String? excludeId}) =>
      _repo.isValueTaken('sku', sku, excludeId: excludeId);

  Future<int> countBySupplier(String supplierId) =>
      _repo.countWhere('supplier = ${pbQuote(supplierId)}');

  Future<int> countByBrand(String brandId) =>
      _repo.countWhere('brand = ${pbQuote(brandId)}');

  Future<int> countByCategory(String categoryId) =>
      _repo.countWhere('category = ${pbQuote(categoryId)}');
}

class PbStockRepository implements CrudRepository<Stock, SimpleQuery> {
  PbStockRepository(Dio dio)
    : _repo = PbEntityRepository<Stock>(
        dio: dio,
        collection: 'stock',
        fromJson: Stock.fromJson,
        toJson: (s) => s.toJson(),
        expand: 'product',
        supportsArchive: false,
      );

  final PbEntityRepository<Stock> _repo;

  String _sortField(String field) => switch (field) {
    'name' => 'product.title',
    _ => field,
  };

  @override
  Future<PageResult<Stock>> find(SimpleQuery q) => _repo.findPage(
    filter: pbSearch(q.search, ['product.title', 'product.sku', 'location']),
    sort: pbSort(_sortField(q.sortField), q.sortAscending),
    page: q.page,
    size: q.size,
  );

  @override
  Future<List<Stock>> findAll({bool includeDeleted = false}) =>
      _repo.findAll(sort: 'product.title');

  @override
  Future<Stock?> findById(String id) => _repo.findById(id);

  @override
  Future<Stock> create(Stock item) => _repo.create(item);

  @override
  Future<Stock> update(Stock item) => _repo.update(item.id, item);

  @override
  Future<void> softDelete(String id) => _repo.softDelete(id);

  @override
  Future<void> hardDelete(String id) => _repo.hardDelete(id);

  @override
  Future<void> restore(String id) => _repo.restore(id);

  @override
  Future<int> deleteMany(List<String> ids) => _repo.deleteMany(ids);

  Future<bool> isProductTaken(String productId, {String? excludeId}) =>
      _repo.isValueTaken('product', productId, excludeId: excludeId);

  Future<Stock?> findByProduct(String productId) async {
    final page = await _repo.findPage(
      filter: 'product = ${pbQuote(productId)}',
      size: 1,
    );
    return page.items.isEmpty ? null : page.items.first;
  }
}
