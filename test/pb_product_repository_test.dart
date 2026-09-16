import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/core/api_exceptions.dart';
import 'package:tech_store/models/product.dart';
import 'package:tech_store/models/product_query.dart';
import 'package:tech_store/repositories/catalog_repositories.dart';

import 'support/fake_pb_server.dart';

const _product = Product(
  id: 'prd0000000000001',
  name: 'Samsung Galaxy S24',
  sku: 'SM-S24-128',
  price: 74990,
  brandId: 'brn0000000000001',
  categoryId: 'cat0000000000001',
);

void main() {
  test('отбор товаров превращается в filter и sort для PocketBase', () async {
    final adapter = FakePbAdapter(
      (_) async => jsonBody(pbPage([pbProduct()], page: 2, totalItems: 42)),
    );
    final repo = PbProductRepository(fakeDio(adapter));

    final page = await repo.find(
      const ProductQuery(
        search: 'galaxy',
        brandId: 'brn0000000000001',
        categoryId: 'cat0000000000001',
        supplierId: 'sup0000000000001',
        priceFrom: 10000,
        priceTo: 100000,
        page: 2,
        size: 10,
        sortField: 'name',
        sortAscending: false,
      ),
    );

    final params = adapter.requests.single.queryParameters;
    final filter = params['filter'] as String;
    expect(filter, contains('archived = false'));
    expect(filter, contains('title ~ "galaxy"'));
    expect(filter, contains('brand = "brn0000000000001"'));
    expect(filter, contains('category = "cat0000000000001"'));
    expect(filter, contains('supplier = "sup0000000000001"'));
    expect(filter, contains('price >= 10000'));
    expect(filter, contains('price <= 100000'));
    expect(params['sort'], '-title');
    expect(params['expand'], 'brand,category,supplier');
    expect(params['page'], 2);
    expect(params['perPage'], 10);

    expect(page.total, 42);
    expect(page.items.single.name, 'Samsung Galaxy S24 128 ГБ');
    expect(page.items.single.brandName, 'Samsung');
  });

  test('удалённые товары показываются только по запросу', () async {
    final adapter = FakePbAdapter((_) async => jsonBody(pbPage([])));
    final repo = PbProductRepository(fakeDio(adapter));

    await repo.find(const ProductQuery(includeDeleted: true));

    expect(
      adapter.requests.single.queryParameters['filter'],
      isNot(contains('archived')),
    );
  });

  test('кавычки в поиске экранируются и не ломают фильтр', () async {
    final adapter = FakePbAdapter((_) async => jsonBody(pbPage([])));
    final repo = PbProductRepository(fakeDio(adapter));

    await repo.find(const ProductQuery(search: 'кабель "USB"'));

    expect(
      adapter.requests.single.queryParameters['filter'],
      contains(r'title ~ "кабель \"USB\""'),
    );
  });

  test('нарушение уникальности артикула приходит как конфликт', () async {
    final adapter = FakePbAdapter(
      (_) async =>
          jsonBody(pbFieldError('sku', 'validation_not_unique'), status: 400),
    );
    final repo = PbProductRepository(fakeDio(adapter));

    await expectLater(
      repo.create(_product),
      throwsA(
        isA<ConflictException>().having(
          (e) => e.errors['sku'],
          'ошибка у поля артикула',
          'Такое значение уже есть.',
        ),
      ),
    );
  });

  test('ошибка обязательного поля приходит как ошибка валидации', () async {
    final adapter = FakePbAdapter(
      (_) async =>
          jsonBody(pbFieldError('title', 'validation_required'), status: 400),
    );
    final repo = PbProductRepository(fakeDio(adapter));

    await expectLater(
      repo.create(_product),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['title'],
          'ошибка у поля названия',
          'Поле обязательно для заполнения.',
        ),
      ),
    );
  });

  test('findById возвращает null, если записи нет', () async {
    final adapter = FakePbAdapter(
      (_) async => jsonBody({'message': 'Не найдено'}, status: 404),
    );
    final repo = PbProductRepository(fakeDio(adapter));

    expect(await repo.findById('prd0000000000404'), isNull);
  });

  test('чтение повторяется трижды при обрыве связи', () async {
    var attempts = 0;
    final adapter = FakePbAdapter((options) async {
      attempts++;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final repo = PbProductRepository(fakeDio(adapter));

    await expectLater(
      repo.find(const ProductQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(attempts, 3);
  });

  test('запись не повторяется при обрыве связи', () async {
    var attempts = 0;
    final adapter = FakePbAdapter((options) async {
      attempts++;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });
    final repo = PbProductRepository(fakeDio(adapter));

    await expectLater(repo.create(_product), throwsA(isA<NetworkException>()));
    expect(attempts, 1);
  });

  test('логическое удаление помечает запись, а не удаляет её', () async {
    final adapter = FakePbAdapter((_) async => jsonBody(pbProduct()));
    final repo = PbProductRepository(fakeDio(adapter));

    await repo.softDelete('prd0000000000001');

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect((request.data as Map)['archived'], isTrue);
  });

  test('проверка занятости артикула ищет запись, исключая свою', () async {
    final adapter = FakePbAdapter(
      (_) async => jsonBody(pbPage([pbProduct()], totalItems: 1)),
    );
    final repo = PbProductRepository(fakeDio(adapter));

    final taken = await repo.isSkuTaken(
      'SM-S24-128',
      excludeId: 'prd0000000000002',
    );

    expect(taken, isTrue);
    final filter = adapter.requests.single.queryParameters['filter'] as String;
    expect(filter, contains('sku = "SM-S24-128"'));
    expect(filter, contains('id != "prd0000000000002"'));
  });
}
