import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'auth_notifier.dart';
import 'config.dart';

Dio buildDio({
  String? Function()? tokenProvider,
  AuthNotifier? Function()? authProvider,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenProvider?.call();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = token;
        }

        if (kDebugMode) {
          debugPrint('[API] → ${options.method} ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) async {
        if (kDebugMode) {
          debugPrint(
            '[API] ← ${response.statusCode} ${response.requestOptions.uri}',
          );
        }

        final status = response.statusCode ?? 0;
        final opts = response.requestOptions;
        final alreadyRetried = opts.extra['authRetried'] == true;
        final isAuthCall = opts.path.contains('auth-');
        final auth = authProvider?.call();

        if (status == 401 && auth != null && !alreadyRetried && !isAuthCall) {
          try {
            await auth.refreshOrLogin(dio);
            opts.extra['authRetried'] = true;
            opts.headers['Authorization'] = auth.accessToken;
            final retry = await dio.fetch(opts);
            return handler.resolve(retry);
          } catch (_) {
            await auth.logout(reason: 'обновление токена после 401 не удалось');
          }
        }

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
      onError: (error, handler) {
        if (kDebugMode) {
          debugPrint('[API] сбой ${error.requestOptions.uri}: ${error.type}');
        }
        return handler.next(error);
      },
    ),
  );

  return dio;
}
