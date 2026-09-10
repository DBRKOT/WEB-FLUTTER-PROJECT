import 'package:dio/dio.dart';

import 'api_exceptions.dart';

class AuthSession {
  String? accessToken;
  String? refreshToken;

  Future<void> ensureAdmin(Dio dio, {bool force = false}) async {
    if (!force && accessToken != null) return;
    await login(dio, username: 'admin', password: 'admin123');
  }

  Future<void> login(
    Dio dio, {
    required String username,
    required String password,
  }) async {
    await guard(() async {
      final response = await dio.post(
        '/auth/login',
        data: {'username': username, 'password': password},
      );
      final data = response.data as Map<String, dynamic>;
      accessToken = data['accessToken'] as String?;
      refreshToken = data['refreshToken'] as String?;
    });
  }

  Future<void> refreshOrLogin(Dio dio) async {
    final currentRefresh = refreshToken;
    if (currentRefresh == null) {
      await ensureAdmin(dio, force: true);
      return;
    }
    try {
      await guard(() async {
        final response = await dio.post(
          '/auth/refresh',
          data: {'refreshToken': currentRefresh},
        );
        final data = response.data as Map<String, dynamic>;
        accessToken = data['accessToken'] as String?;
        refreshToken = data['refreshToken'] as String?;
      });
    } on ApiException {
      await ensureAdmin(dio, force: true);
    }
  }
}
