import 'api_exceptions.dart';

String mapApiFieldKey(String key) => switch (key) {
  'title' => 'name',
  'isbn' => 'sku',
  'fullName' => 'name',
  'birthYear' => 'foundedYear',
  'city' => 'country',
  'pages' => 'price',
  'publisherId' => 'supplierId',
  'authorIds' => 'brandIds',
  'genreIds' => 'categoryIds',
  'copiesTotal' => 'stockTotal',
  _ => key,
};

Map<String, String> mapApiFieldErrors(Map<String, String> errors) => {
  for (final e in errors.entries) mapApiFieldKey(e.key): e.value,
};

String apiErrorMessage(Object error) {
  if (error is ForbiddenException) return '403: ${error.message}';
  if (error is ApiException) return error.message;
  return '$error';
}
