import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:tech_store/core/api_exceptions.dart';

class FakePbAdapter implements HttpClientAdapter {
  FakePbAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  final List<RequestOptions> requests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
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
    return handler(options);
  }
}

ResponseBody jsonBody(Object data, {int status = 200}) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> pbPage(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int perPage = 10,
  int? totalItems,
}) => {
  'items': items,
  'page': page,
  'perPage': perPage,
  'totalItems': totalItems ?? items.length,
  'totalPages': 1,
};

Map<String, dynamic> pbFieldError(String field, String code) => {
  'status': 400,
  'message': 'Failed to create record.',
  'data': {
    field: {'code': code, 'message': 'Value must be unique.'},
  },
};

Dio fakeDio(FakePbAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://test/api',
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.httpClientAdapter = adapter;
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

Map<String, dynamic> pbProduct({
  String id = 'prd0000000000001',
  String title = 'Samsung Galaxy S24 128 ГБ',
  String sku = 'SM-S24-128',
  int price = 74990,
}) => {
  'id': id,
  'title': title,
  'sku': sku,
  'price': price,
  'warrantyMonths': 24,
  'brand': 'brn0000000000001',
  'category': 'cat0000000000001',
  'supplier': 'sup0000000000001',
  'description': 'Гарантия 24 мес.',
  'archived': false,
  'expand': {
    'brand': {'id': 'brn0000000000001', 'name': 'Samsung'},
    'category': {'id': 'cat0000000000001', 'name': 'Смартфоны'},
    'supplier': {'id': 'sup0000000000001', 'name': 'ООО «ТехноОпт»'},
  },
};
