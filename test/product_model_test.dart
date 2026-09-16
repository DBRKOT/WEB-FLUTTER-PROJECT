import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/models/product.dart';
import 'package:tech_store/models/stock.dart';

void main() {
  group('Product.fromJson', () {
    test('подставляет значения по умолчанию при неполном ответе', () {
      final product = Product.fromJson({'id': 'prd0000000000001'});
      expect(product.id, 'prd0000000000001');
      expect(product.name, '');
      expect(product.sku, '');
      expect(product.price, 0);
      expect(product.brandId, '');
      expect(product.categoryId, '');
      expect(product.archived, isFalse);
    });

    test('читает поля и названия связанных записей из expand', () {
      final product = Product.fromJson({
        'id': 'prd0000000000007',
        'title': 'Galaxy S24',
        'sku': 'SM-S24',
        'price': 79990,
        'warrantyMonths': 24,
        'brand': 'brn0000000000003',
        'category': 'cat0000000000001',
        'supplier': 'sup0000000000002',
        'archived': true,
        'expand': {
          'brand': {'id': 'brn0000000000003', 'name': 'Samsung'},
          'category': {'id': 'cat0000000000001', 'name': 'Смартфоны'},
          'supplier': {'id': 'sup0000000000002', 'name': 'ЗАО «Электроснаб»'},
        },
      });

      expect(product.name, 'Galaxy S24');
      expect(product.brandId, 'brn0000000000003');
      expect(product.brandName, 'Samsung');
      expect(product.categoryName, 'Смартфоны');
      expect(product.supplierName, 'ЗАО «Электроснаб»');
      expect(product.isDeleted, isTrue);
    });

    test('в запрос уходит имя поля базы, а не имя поля модели', () {
      const product = Product(
        id: 'prd0000000000001',
        name: 'Galaxy S24',
        sku: 'SM-S24',
        price: 79990,
        brandId: 'brn0000000000003',
        categoryId: 'cat0000000000001',
      );

      final json = product.toJson();
      expect(json['title'], 'Galaxy S24');
      expect(json['brand'], 'brn0000000000003');
      expect(json['category'], 'cat0000000000001');
      expect(json.containsKey('supplier'), isFalse);
    });
  });

  group('Stock', () {
    test('нулевой остаток считается отсутствием товара', () {
      const stock = Stock(
        id: 'stk0000000000001',
        productId: 'prd0000000000001',
        quantity: 0,
      );
      expect(stock.isAvailable, isFalse);
      expect(stock.statusLabel, 'Нет в наличии');
    });

    test('малый остаток отмечается отдельно', () {
      const stock = Stock(
        id: 'stk0000000000001',
        productId: 'prd0000000000001',
        quantity: 3,
      );
      expect(stock.isLow, isTrue);
      expect(stock.statusLabel, 'Мало');
    });

    test('название товара приходит из expand', () {
      final stock = Stock.fromJson({
        'id': 'stk0000000000001',
        'product': 'prd0000000000001',
        'quantity': 12,
        'location': 'A-01-03',
        'expand': {
          'product': {'title': 'Galaxy S24', 'sku': 'SM-S24-128'},
        },
      });
      expect(stock.productName, 'Galaxy S24');
      expect(stock.productSku, 'SM-S24-128');
      expect(stock.statusLabel, 'В наличии');
    });
  });
}
