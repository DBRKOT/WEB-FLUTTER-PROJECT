import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/core/auth_notifier.dart';
import 'package:tech_store/core/reference_cache.dart';
import 'package:tech_store/main.dart';
import 'package:tech_store/models/app_user.dart';
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

  testWidgets('каталог загружает товары после входа', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final products = PersistentProductRepository(prefs);
    final brands = PersistentBrandRepository(prefs);
    final categories = PersistentCategoryRepository(prefs);
    final suppliers = PersistentSupplierRepository(prefs, products);
    final dio = Dio();
    final auth = AuthNotifier(prefs, dio);
    auth.seedForTest(
      const AppUser(
        id: 1,
        username: 'admin',
        fullName: 'Администратор ТехноМаркет',
        email: 'admin@technomarket.local',
        role: UserRole.admin,
      ),
    );
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
        auth: auth,
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
    expect(find.textContaining('Администратор ТехноМаркет'), findsOneWidget);
  });

  testWidgets('без входа открывается экран логина', (tester) async {
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
        auth: AuthNotifier(prefs, dio),
        products: products,
        brands: brands,
        categories: categories,
        suppliers: suppliers,
        customers: PersistentCustomerRepository(prefs),
        loans: ApiLoanService(dio),
        referenceCache: cache,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Вход в систему'), findsOneWidget);
    expect(find.text('Войти'), findsOneWidget);
  });
}
