import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/core/validators.dart';

void main() {
  group('V.required', () {
    test('пустая строка отклоняется', () {
      expect(V.required()(''), isNotNull);
      expect(V.required()('   '), isNotNull);
      expect(V.required()(null), isNotNull);
    });

    test('непустая строка принимается', () {
      expect(V.required()('AirPods Pro'), isNull);
    });
  });

  group('V.email', () {
    test('некорректный email отклоняется', () {
      expect(V.email()('без-собаки'), isNotNull);
      expect(V.email()('a@'), isNotNull);
    });

    test('корректный email принимается', () {
      expect(V.email()('user@example.com'), isNull);
    });
  });

  group('V.strongPassword', () {
    test('слабый пароль отклоняется', () {
      expect(V.strongPassword()('short'), isNotNull);
      expect(V.strongPassword()('NoDigit!!!!'), isNotNull);
      expect(V.strongPassword()('NoSpecial1'), isNotNull);
    });

    test('сильный пароль принимается', () {
      expect(V.strongPassword()('Secret1!'), isNull);
    });
  });

  group('V.positiveInt', () {
    test('ноль и отрицательные отклоняются', () {
      expect(V.positiveInt()('0'), isNotNull);
      expect(V.positiveInt()('-3'), isNotNull);
      expect(V.positiveInt()('abc'), isNotNull);
    });

    test('положительное целое принимается', () {
      expect(V.positiveInt()('12'), isNull);
    });
  });
}
