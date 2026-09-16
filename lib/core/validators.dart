typedef Validator = String? Function(String?);

class V {
  static Validator required([String message = 'Поле обязательно']) {
    return (value) => (value == null || value.trim().isEmpty) ? message : null;
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

  static Validator positiveInt([
    String message = 'Число должно быть больше 0',
  ]) {
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

  static Validator strongPassword() {
    return (value) {
      final text = value ?? '';
      if (text.length < 8) return 'Не короче 8 символов';
      if (!RegExp(r'\d').hasMatch(text)) return 'Нужна хотя бы одна цифра';
      if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\/;~`]').hasMatch(text)) {
        return 'Нужен специальный символ (!@#\$% и т.п.)';
      }
      return null;
    };
  }

  static Validator decimal({double? min, double? max}) {
    return (value) {
      final text = (value ?? '').trim().replaceAll(',', '.');
      final n = double.tryParse(text);
      if (n == null) return 'Введите число';
      if (min != null && n < min) return 'Значение не меньше $min';
      if (max != null && n > max) return 'Значение не больше $max';
      return null;
    };
  }

  static Validator phone({int max = 20}) {
    final re = RegExp(r'^[0-9+()\- ]*$');
    return (value) {
      final text = (value ?? '').trim();
      if (text.length > max) return 'Не длиннее $max символов';
      if (!re.hasMatch(text)) return 'Только цифры, пробел и символы + ( ) -';
      return null;
    };
  }

  static Validator optional(Validator validator) {
    return (value) =>
        (value == null || value.trim().isEmpty) ? null : validator(value);
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
