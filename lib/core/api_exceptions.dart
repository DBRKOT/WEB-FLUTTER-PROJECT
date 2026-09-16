import 'package:dio/dio.dart';

sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException([
    super.message = 'Сервер недоступен. Проверьте соединение.',
  ]);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Требуется вход в систему.']);
}

class ForbiddenException extends ApiException {
  const ForbiddenException([
    super.message = 'Недостаточно прав для этого действия.',
  ]);
}

class NotFoundException extends ApiException {
  const NotFoundException([super.message = 'Запись не найдена.']);
}

class ConflictException extends ApiException {
  final Map<String, String> errors;
  const ConflictException(super.message, [this.errors = const {}]);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

class ServerException extends ApiException {
  const ServerException([
    super.message = 'Ошибка на сервере. Попробуйте позже.',
  ]);
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException([super.message = 'Запрос отменён.']);
}

({Map<String, String> errors, bool hasConflict}) _parsePbFieldErrors(
  dynamic body,
) {
  final raw = (body is Map) ? body['data'] : null;
  if (raw is! Map) {
    return (errors: const <String, String>{}, hasConflict: false);
  }

  final errors = <String, String>{};
  var conflict = false;
  raw.forEach((key, value) {
    if (value is Map) {
      final code = value['code'] as String?;
      if (code == 'validation_not_unique') conflict = true;
      errors['$key'] = _pbFieldMessage(code, value['message'] as String?);
    } else {
      errors['$key'] = '$value';
    }
  });
  return (errors: errors, hasConflict: conflict);
}

String _pbFieldMessage(String? code, String? fallback) => switch (code) {
  'validation_required' => 'Поле обязательно для заполнения.',
  'validation_not_unique' => 'Такое значение уже есть.',
  'validation_min_text_constraint' => 'Слишком короткое значение.',
  'validation_max_text_constraint' => 'Слишком длинное значение.',
  'validation_min_number_constraint' => 'Значение меньше допустимого.',
  'validation_max_number_constraint' => 'Значение больше допустимого.',
  'validation_is_email' => 'Неверный формат адреса.',
  'validation_invalid_email' => 'Неверный формат адреса.',
  'validation_match_invalid' => 'Значение не соответствует формату.',
  'validation_values_mismatch' => 'Значения не совпадают.',
  'validation_missing_rel_records' => 'Связанная запись не найдена.',
  _ => fallback ?? 'Некорректное значение.',
};

ApiException mapHttpError(int status, dynamic body) {
  final message = (body is Map && body['message'] is String)
      ? body['message'] as String
      : null;

  return switch (status) {
    400 => _mapBadRequest(message, body),
    401 => UnauthorizedException(message ?? 'Требуется вход в систему.'),
    403 => ForbiddenException(
      message ?? 'Недостаточно прав для этого действия.',
    ),
    404 => NotFoundException(message ?? 'Запись не найдена.'),
    409 => ConflictException(message ?? 'Операция невозможна.'),
    422 => ValidationException(
      message ?? 'Ошибка валидации',
      (body is Map && body['errors'] is Map)
          ? (body['errors'] as Map).map((k, v) => MapEntry('$k', '$v'))
          : const {},
    ),
    _ => ServerException(message ?? 'Неизвестная ошибка (код $status).'),
  };
}

ApiException _mapBadRequest(String? message, dynamic body) {
  final parsed = _parsePbFieldErrors(body);
  if (parsed.errors.isEmpty) {
    return ValidationException(message ?? 'Некорректный запрос.', const {});
  }
  if (parsed.hasConflict) {
    return ConflictException(
      'Запись с такими данными уже существует.',
      parsed.errors,
    );
  }
  return ValidationException(
    message ?? 'Проверьте заполнение полей.',
    parsed.errors,
  );
}

ApiException mapDioError(DioException e) {
  final existing = e.error;
  if (existing is ApiException) return existing;

  if (e.type == DioExceptionType.cancel || CancelToken.isCancel(e)) {
    return const RequestCancelledException();
  }

  return switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const NetworkException(
      'Сервер не ответил вовремя.',
    ),
    DioExceptionType.connectionError => const NetworkException(
      'Не удалось соединиться с сервером. '
      'Если сервер запущен, откройте консоль браузера и проверьте наличие ошибки CORS.',
    ),
    DioExceptionType.cancel => const RequestCancelledException(),
    _ => const ServerException(),
  };
}

Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}

Future<T> guardRead<T>(Future<T> Function() action) async {
  var attempt = 0;
  while (true) {
    try {
      return await guard(action);
    } on RequestCancelledException {
      rethrow;
    } on NetworkException {
      attempt++;
      if (attempt >= 3) rethrow;
      await Future<void>.delayed(
        Duration(milliseconds: 250 * attempt * attempt),
      );
    } on ServerException {
      attempt++;
      if (attempt >= 3) rethrow;
      await Future<void>.delayed(
        Duration(milliseconds: 250 * attempt * attempt),
      );
    }
  }
}
