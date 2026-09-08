class FieldValidationException implements Exception {
  FieldValidationException(this.errors, [this.message = 'Ошибка валидации']);

  final String message;
  final Map<String, String> errors;

  @override
  String toString() => message;
}
