import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/core/api_exceptions.dart';
import 'package:tech_store/models/product.dart';
import 'package:tech_store/models/product_query.dart';
import 'package:tech_store/repositories/api_product_repository.dart';

class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (cancelFuture != null) {
      var cancelled = false;
      cancelFuture.then((_) => cancelled = true);
      await Future<void>.delayed(Duration.zero);
      if (cancelled || options.cancelToken?.isCancelled == true) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: const RequestCancelledException(),
        );
      }
    }
    return _handler(options);
  }
}

Dio _dioWith(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test/api',
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.httpClientAdapter = _MockAdapter(handler);
  dio.interceptors.add(
    InterceptorsWrapper(
      onResponse: (response, handler) {
        final status = response.statusCode ?? 0;
        if (status >= 400) {
          return handler.reject(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
              error: mapHttpError(status, response.data),
            ),
            true,
          );
        }
        return handler.next(response);
      },
    ),
  );
  return dio;
}

ResponseBody _json(Object data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _book({
  int id = 1,
  String title = 'iPhone 15 Pro',
  String isbn = 'TM-000001',
}) =>
    {
      'id': id,
      'title': title,
      'isbn': isbn,
      'year': 2023,
      'pages': 129990,
      'publisherId': 1,
      'authors': [
        {'id': 1, 'fullName': 'Apple'}
      ],
      'genres': [
        {'id': 1, 'name': 'Смартфоны'}
      ],
      'copiesTotal': 20,
      'copiesAvailable': 14,
    };

void main() {
  test('find парсит page/size/total и query-параметры', () async {
    late RequestOptions seen;
    final repo = ApiProductRepository(
      _dioWith((options) async {
        seen = options;
        return _json({
          'items': [_book()],
          'page': 2,
          'size': 10,
          'total': 42,
        });
      }),
    );

    final page = await repo.find(
      const ProductQuery(
        search: 'мир',
        categoryId: 2,
        brandId: 1,
        supplierId: 3,
        page: 2,
        size: 10,
        sortField: 'name',
        sortAscending: false,
      ),
    );

    expect(page.items, hasLength(1));
    expect(page.items.first.name, 'iPhone 15 Pro');
    expect(page.items.first.sku, 'TM-000001');
    expect(page.page, 2);
    expect(page.size, 10);
    expect(page.total, 42);
    expect(seen.queryParameters['search'], 'мир');
    expect(seen.queryParameters['genreId'], 2);
    expect(seen.queryParameters['authorId'], 1);
    expect(seen.queryParameters['publisherId'], 3);
    expect(seen.queryParameters['sort'], 'title,desc');
    expect(seen.queryParameters['page'], 2);
    expect(seen.queryParameters['size'], 10);
  });

  test('create пробрасывает ValidationException (422)', () async {
    final repo = ApiProductRepository(
      _dioWith(
        (_) async => _json(
          {
            'message': 'Ошибка валидации',
            'errors': {'isbn': 'ISBN уже занят'},
          },
          status: 422,
        ),
      ),
    );

    expect(
      () => repo.create(
        const Product(
          id: 0,
          name: 'X',
          sku: 'dup',
          year: 2020,
          price: 100,
          supplierId: 1,
          brandIds: [1],
          categoryIds: [1],
          stockTotal: 1,
          stockAvailable: 1,
        ),
      ),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.errors['isbn'],
          'isbn',
          'ISBN уже занят',
        ),
      ),
    );
  });

  test('findById возвращает null при 404', () async {
    final repo = ApiProductRepository(
      _dioWith(
        (_) async => _json({'message': 'Не найдено'}, status: 404),
      ),
    );

    expect(await repo.findById(999), isNull);
  });

  test('сетевая ошибка при чтении даёт NetworkException после retry', () async {
    var attempts = 0;
    final repo = ApiProductRepository(
      _dioWith((options) async {
        attempts++;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }),
    );

    await expectLater(
      repo.find(const ProductQuery()),
      throwsA(isA<NetworkException>()),
    );
    expect(attempts, 3);
  });

  test('запись (create) не ретраится при сетевой ошибке', () async {
    var attempts = 0;
    final repo = ApiProductRepository(
      _dioWith((options) async {
        attempts++;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      }),
    );

    await expectLater(
      repo.create(
        const Product(
          id: 0,
          name: 'X',
          sku: '1',
          year: 2020,
          price: 1,
          supplierId: 1,
          brandIds: [1],
          categoryIds: [1],
          stockTotal: 1,
          stockAvailable: 1,
        ),
      ),
      throwsA(isA<NetworkException>()),
    );
    expect(attempts, 1);
  });

  test('CancelToken отменяет find', () async {
    final token = CancelToken();
    final repo = ApiProductRepository(
      _dioWith((options) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return _json({
          'items': [_book()],
          'page': 1,
          'size': 10,
          'total': 1,
        });
      }),
    );

    final future = repo.find(const ProductQuery(), cancelToken: token);
    token.cancel('тест');
    await expectLater(future, throwsA(isA<RequestCancelledException>()));
  });
}
