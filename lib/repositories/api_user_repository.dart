import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/app_user.dart';
import '../models/page_result.dart';

class ApiUserRepository {
  ApiUserRepository(this._dio);

  final Dio _dio;

  Future<PageResult<AppUser>> find({int page = 1, int size = 50}) =>
      guard(() async {
        final response = await _dio.get(
          '/users',
          queryParameters: {
            'page': page,
            'size': size,
            'sort': 'id,asc',
          },
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AppUser.fromJson)
              .toList(),
          page: data['page'] as int? ?? page,
          size: data['size'] as int? ?? size,
          total: data['total'] as int? ?? 0,
        );
      });
}
