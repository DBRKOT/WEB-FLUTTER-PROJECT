import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tech_store/state/load_status.dart';
import 'package:tech_store/widgets/load_state_view.dart';

void main() {
  testWidgets('пустой список показывает emptyMessage без индикатора', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoadStateView(
          status: LoadStatus.success,
          error: null,
          isEmpty: true,
          emptyMessage: 'Товары не найдены',
          onRetry: () {},
          child: const Text('список'),
        ),
      ),
    );

    expect(find.text('Товары не найдены'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('список'), findsNothing);
  });

  testWidgets('ошибка показывает кнопку Повторить', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoadStateView(
          status: LoadStatus.error,
          error: 'Сеть недоступна',
          isEmpty: false,
          emptyMessage: 'пусто',
          onRetry: () => retried = true,
          child: const SizedBox.shrink(),
        ),
      ),
    );

    expect(find.text('Сеть недоступна'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
