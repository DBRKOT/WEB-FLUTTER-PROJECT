import '../models/brand.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../repositories/brand_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/supplier_repository.dart';

// ignore_for_file: prefer_initializing_formals

class ReferenceCache {
  ReferenceCache({
    required BrandRepository brands,
    required CategoryRepository categories,
    required SupplierRepository suppliers,
  }) : _brands = brands,
       _categories = categories,
       _suppliers = suppliers;

  final BrandRepository _brands;
  final CategoryRepository _categories;
  final SupplierRepository _suppliers;

  List<Brand>? _brandCache;
  List<Category>? _categoryCache;
  List<Supplier>? _supplierCache;

  Future<List<Brand>> brands() async {
    return _brandCache ??= await _brands.findAll();
  }

  Future<List<Category>> categories() async {
    return _categoryCache ??= await _categories.findAll();
  }

  Future<List<Supplier>> suppliers() async {
    return _supplierCache ??= await _suppliers.findAll();
  }

  void invalidateBrands() => _brandCache = null;
  void invalidateCategories() => _categoryCache = null;
  void invalidateSuppliers() => _supplierCache = null;

  void invalidateAll() {
    invalidateBrands();
    invalidateCategories();
    invalidateSuppliers();
  }
}
