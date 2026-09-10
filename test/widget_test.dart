import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/core/auth_session.dart';
import 'package:tech_store/core/reference_cache.dart';
import 'package:tech_store/main.dart';
import 'package:tech_store/repositories/api_loan_service.dart';
import 'package:tech_store/repositories/persistent_brand_repository.dart';
import 'package:tech_store/repositories/persistent_category_repository.dart';
import 'package:tech_store/repositories/persistent_customer_repository.dart';
import 'package:tech_store/repositories/persistent_product_repository.dart';
import 'package:tech_store/repositories/persistent_supplier_repository.dart';

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

  testWidgets('каталог загружает товары', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final products = PersistentProductRepository(prefs);
    final brands = PersistentBrandRepository(prefs);
    final categories = PersistentCategoryRepository(prefs);
    final suppliers = PersistentSupplierRepository(prefs, products);
    final dio = Dio();
    final cache = ReferenceCache(
      brands: brands,
      categories: categories,
      suppliers: suppliers,
    );

    await _bindView(tester);
    await tester.pumpWidget(
      TechStoreApp(
        prefs: prefs,
        dio: dio,
        auth: AuthSession(),
        products: products,
        brands: brands,
        categories: categories,
        suppliers: suppliers,
        customers: PersistentCustomerRepository(prefs),
        loans: ApiLoanService(dio),
        referenceCache: cache,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await _waitForLoad(tester);

    expect(find.text('Каталог товаров'), findsOneWidget);
    expect(find.text('AirPods Pro 2'), findsOneWidget);
  });
}
