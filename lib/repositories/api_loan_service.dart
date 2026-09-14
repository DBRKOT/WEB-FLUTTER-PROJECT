import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/loan_order.dart';
import '../models/page_result.dart';

class ApiLoanService {
  ApiLoanService(this._dio);

  final Dio _dio;

  Future<PageResult<LoanOrder>> findOrders({int page = 1, int size = 20}) =>
      guard(() async {
        final response = await _dio.get(
          '/loans',
          queryParameters: {'page': page, 'size': size, 'sort': 'id,desc'},
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(LoanOrder.fromJson)
              .toList(),
          page: data['page'] as int? ?? page,
          size: data['size'] as int? ?? size,
          total: data['total'] as int? ?? 0,
        );
      });

  Future<void> createLoan({
    required int readerId,
    required int bookId,
    int days = 14,
  }) => guard(() async {
    await _dio.post(
      '/loans',
      data: {'readerId': readerId, 'bookId': bookId, 'days': days},
    );
  });

  Future<LoanOrder> returnLoan(int id) => guard(() async {
    final response = await _dio.post('/loans/$id/return');
    return LoanOrder.fromJson(response.data as Map<String, dynamic>);
  });

  Future<LoanOrder> extendLoan(int id, {int days = 14}) => guard(() async {
    final response = await _dio.post('/loans/$id/extend', data: {'days': days});
    return LoanOrder.fromJson(response.data as Map<String, dynamic>);
  });
}
