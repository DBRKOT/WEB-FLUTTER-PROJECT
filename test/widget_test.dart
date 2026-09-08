import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/main.dart';

Future<void> _bindView(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _waitForLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('каталог загружает товары из памяти', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await _bindView(tester);
    await tester.pumpWidget(TechStoreApp(prefs: prefs));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _waitForLoad(tester);

    expect(find.text('Каталог товаров'), findsOneWidget);
    expect(find.text('AirPods Pro 2'), findsOneWidget);
  });
}
