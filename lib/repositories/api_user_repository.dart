import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../core/config.dart';
import '../models/app_user.dart';
import '../models/page_result.dart';

class ApiUserRepository {
  ApiUserRepository(this._dio);

  final Dio _dio;

  Future<PageResult<AppUser>> find({int page = 1, int size = 50}) =>
      guard(() async {
        final response = await _dio.get(
          '/collections/$usersCollection/records',
          queryParameters: {'page': page, 'perPage': size, 'sort': 'email'},
        );
        final data = response.data as Map<String, dynamic>;
        return PageResult(
          items: (data['items'] as List)
              .whereType<Map<String, dynamic>>()
              .map(AppUser.fromJson)
              .toList(),
          page: data['page'] as int? ?? page,
          size: data['perPage'] as int? ?? size,
          total: data['totalItems'] as int? ?? 0,
        );
      });

  Future<AppUser?> findById(String id) => guard(() async {
    final response = await _dio.get(
      '/collections/$usersCollection/records/$id',
    );
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  });

  Future<AppUser> changeRole(String id, UserRole role) => guard(() async {
    final response = await _dio.patch(
      '/collections/$usersCollection/records/$id',
      data: {'role': role.apiValue},
    );
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  });

  Future<void> delete(String id) => guard(() async {
    await _dio.delete('/collections/$usersCollection/records/$id');
  });
}
