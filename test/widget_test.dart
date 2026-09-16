import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/core/auth_notifier.dart';
import 'package:tech_store/main.dart';
import 'package:tech_store/models/app_user.dart';

import 'support/fake_pb_server.dart';

Future<ResponseBody> _handle(RequestOptions options) async {
  final path = options.path;
  if (path.contains('/collections/products/records')) {
    return jsonBody(pbPage([pbProduct()], totalItems: 1));
  }
  if (path.contains('/collections/brands/records')) {
    return jsonBody(
      pbPage([
        {
          'id': 'brn0000000000001',
          'name': 'Samsung',
          'country': 'Республика Корея',
          'foundedYear': 1938,
        },
      ], totalItems: 1),
    );
  }
  if (path.contains('/collections/categories/records')) {
    return jsonBody(
      pbPage([
        {'id': 'cat0000000000001', 'name': 'Смартфоны'},
      ], totalItems: 1),
    );
  }
  return jsonBody(pbPage([]));
}

Future<void> _bindView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _waitForLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('каталог загружает товары после входа', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = fakeDio(FakePbAdapter(_handle));
    final auth = AuthNotifier(prefs, dio);
    auth.seedForTest(
      const AppUser(
        id: 'usr0000000000001',
        fullName: 'Соколова Ольга Павловна',
        email: 'admin@tm.local',
        role: UserRole.admin,
      ),
    );

    await _bindView(tester);
    await tester.pumpWidget(TechStoreApp(dio: dio, auth: auth));
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await _waitForLoad(tester);

    expect(find.textContaining('Samsung Galaxy S24'), findsWidgets);
    expect(find.textContaining('Соколова Ольга Павловна'), findsOneWidget);
  });

  testWidgets('без входа открывается экран входа', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final dio = fakeDio(FakePbAdapter(_handle));

    await _bindView(tester);
    await tester.pumpWidget(
      TechStoreApp(dio: dio, auth: AuthNotifier(prefs, dio)),
    );
    await _waitForLoad(tester);

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
