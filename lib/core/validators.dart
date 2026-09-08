typedef Validator = String? Function(String?);

class V {
  static Validator required([String message = 'Поле обязательно']) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? message : null;
  }

  static Validator length({int min = 0, int max = 255}) {
    return (value) {
      final text = value?.trim() ?? '';
      if (text.length < min) return 'Не короче $min символов';
      if (text.length > max) return 'Не длиннее $max символов';
      return null;
    };
  }

  static Validator integer({int? min, int? max}) {
    return (value) {
      final n = int.tryParse(value?.trim() ?? '');
      if (n == null) return 'Введите целое число';
      if (min != null && n < min) return 'Значение не меньше $min';
      if (max != null && n > max) return 'Значение не больше $max';
      return null;
    };
  }

  static Validator positiveInt([String message = 'Число должно быть больше 0']) {
    return (value) {
      final n = int.tryParse(value?.trim() ?? '');
      if (n == null) return 'Введите целое число';
      if (n <= 0) return message;
      return null;
    };
  }

  static Validator nonNegativeInt([
    String message = 'Число не может быть отрицательным',
  ]) {
    return (value) {
      final n = int.tryParse(value?.trim() ?? '');
      if (n == null) return 'Введите целое число';
      if (n < 0) return message;
      return null;
    };
  }

  static Validator email() {
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    return (value) =>
        re.hasMatch(value?.trim() ?? '') ? null : 'Некорректный адрес почты';
  }

  static Validator combine(List<Validator> validators) {
    return (value) {
      for (final v in validators) {
        final error = v(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}
