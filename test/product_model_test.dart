import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/models/product.dart';

void main() {
  group('Product.fromJson', () {
    test('подставляет значения по умолчанию при неполном JSON', () {
      final product = Product.fromJson({'id': 1});
      expect(product.id, 1);
      expect(product.name, '');
      expect(product.sku, '');
      expect(product.brandIds, isEmpty);
      expect(product.categoryIds, isEmpty);
      expect(product.supplierId, 1);
      expect(product.deletedAt, isNull);
    });

    test('читает поля и связи', () {
      final product = Product.fromJson({
        'id': 7,
        'name': 'Galaxy S24',
        'sku': 'SM-S24',
        'year': 2024,
        'price': 79990,
        'supplierId': 2,
        'brandIds': [3, 5],
        'categoryIds': [1],
        'stockTotal': 10,
        'stockAvailable': 4,
      });
      expect(product.name, 'Galaxy S24');
      expect(product.sku, 'SM-S24');
      expect(product.brandIds, [3, 5]);
      expect(product.categoryIds, [1]);
      expect(product.supplierId, 2);
      expect(product.stockAvailable, 4);
    });
  });
}
