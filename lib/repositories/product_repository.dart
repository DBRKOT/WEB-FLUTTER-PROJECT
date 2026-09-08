import '../models/page_result.dart';
import '../models/product.dart';
import '../models/product_query.dart';

abstract interface class ProductRepository {
  Future<PageResult<Product>> find(ProductQuery query);
  Future<Product?> findById(int id);
  Future<Product> create(Product product);
  Future<Product> update(Product product);
  Future<void> softDelete(int id);
  Future<void> hardDelete(int id);
  Future<void> restore(int id);
  Future<int> deleteMany(List<int> ids);
  Future<bool> isSkuTaken(String sku, {int? excludeId});
  Future<int> countBySupplier(int supplierId);
}
