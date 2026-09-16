import 'api_exceptions.dart';

String apiErrorMessage(Object error) {
  if (error is ForbiddenException) return '403: ${error.message}';
  if (error is ApiException) return error.message;
  return '$error';
}
