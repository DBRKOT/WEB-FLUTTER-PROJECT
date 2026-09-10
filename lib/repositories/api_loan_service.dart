import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';

class ApiLoanService {
  ApiLoanService(this._dio);

  final Dio _dio;

  Future<void> createLoan({
    required int readerId,
    required int bookId,
    int days = 14,
  }) =>
      guard(() async {
        await _dio.post(
          '/loans',
          data: {
            'readerId': readerId,
            'bookId': bookId,
            'days': days,
          },
        );
      });
}
