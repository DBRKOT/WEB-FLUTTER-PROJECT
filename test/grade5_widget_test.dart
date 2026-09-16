import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/core/auth_notifier.dart';
import 'package:tech_store/models/app_user.dart';
import 'package:tech_store/screens/login_screen.dart';
import 'package:tech_store/state/load_status.dart';
import 'package:tech_store/widgets/app_scaffold.dart';
import 'package:tech_store/widgets/entity_form_scaffold.dart';
import 'package:tech_store/widgets/load_state_view.dart';
import 'package:tech_store/core/validators.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthNotifier> authWith(UserRole role) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthNotifier(prefs, Dio());
    auth.seedForTest(
      AppUser(
        id: 'usr0000000000001',
        fullName: 'Пользователь',
        email: 'u@tm.local',
        role: role,
      ),
    );
    return auth;
  }

  testWidgets('состояние загрузки показывает индикатор', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoadStateView(
          status: LoadStatus.loading,
          error: null,
          isEmpty: false,
          emptyMessage: 'пусто',
          onRetry: () {},
          child: const Text('данные'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('данные'), findsNothing);
  });

  testWidgets('пустой результат показывает emptyMessage', (tester) async {
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

  testWidgets('валидация формы срабатывает при пустых полях', (tester) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: EntityFormScaffold(
          title: 'Новый товар',
          fallbackPath: '/products',
          formKey: formKey,
          isDirty: false,
          loading: false,
          saving: false,
          onSubmit: () => formKey.currentState!.validate(),
          submitLabel: 'Сохранить',
          fields: [
            FormFieldSpec(
              label: 'Название',
              controller: name,
              validator: V.required('Укажите название'),
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(find.text('Укажите название'), findsOneWidget);
  });

  testWidgets('у клиента скрыты админ-пункты навигации', (tester) async {
    final auth = await authWith(UserRole.client);
    final router = GoRouter(
      initialLocation: '/products',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              AppScaffold(location: state.uri.path, child: child),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const Text('products-body'),
            ),
            GoRoute(
              path: '/my-orders',
              builder: (_, _) => const Text('orders-body'),
            ),
            GoRoute(
              path: '/admin/users',
              builder: (_, _) => const Text('users-body'),
            ),
            GoRoute(
              path: '/admin/stats',
              builder: (_, _) => const Text('stats-body'),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Товары'), findsWidgets);
    expect(find.text('Мои заказы'), findsWidgets);
    expect(find.text('Пользователи'), findsNothing);
    expect(find.text('Статистика'), findsNothing);
    expect(find.text('Бренды'), findsNothing);
  });

  testWidgets('экран входа: пустая почта показывает ошибку валидации', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthNotifier(prefs, Dio());

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: const LoginScreen(),
          routes: {'/register': (_) => const SizedBox.shrink()},
        ),
      ),
    );

    await tester.tap(find.text('Войти'));
    await tester.pump();

    expect(find.text('Введите адрес почты'), findsOneWidget);
    expect(find.text('Введите пароль'), findsOneWidget);
  });
}
