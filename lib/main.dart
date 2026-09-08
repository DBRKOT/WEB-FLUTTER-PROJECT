import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router.dart';
import 'core/storage_migration.dart';
import 'repositories/brand_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/persistent_brand_repository.dart';
import 'repositories/persistent_category_repository.dart';
import 'repositories/persistent_customer_repository.dart';
import 'repositories/persistent_product_repository.dart';
import 'repositories/persistent_supplier_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/supplier_repository.dart';
import 'state/brand_list_notifier.dart';
import 'state/category_list_notifier.dart';
import 'state/customer_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/supplier_list_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  final migration = await StorageMigration.run(prefs);
  runApp(TechStoreApp(prefs: prefs, migrationMessage: migration.message));
}

class TechStoreApp extends StatefulWidget {
  const TechStoreApp({
    super.key,
    required this.prefs,
    this.migrationMessage,
  });

  final SharedPreferences prefs;
  final String? migrationMessage;

  @override
  State<TechStoreApp> createState() => _TechStoreAppState();
}

class _TechStoreAppState extends State<TechStoreApp> {
  late final GoRouter _router = createAppRouter();
  late final ProductRepository _products =
      PersistentProductRepository(widget.prefs);
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final message = widget.migrationMessage;
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 6),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductRepository>.value(value: _products),
        Provider<BrandRepository>(
          create: (_) => PersistentBrandRepository(widget.prefs),
        ),
        Provider<CategoryRepository>(
          create: (_) => PersistentCategoryRepository(widget.prefs),
        ),
        Provider<SupplierRepository>(
          create: (_) => PersistentSupplierRepository(widget.prefs, _products),
        ),
        Provider<CustomerRepository>(
          create: (_) => PersistentCustomerRepository(widget.prefs),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProductListNotifier(context.read<ProductRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              BrandListNotifier(context.read<BrandRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CategoryListNotifier(context.read<CategoryRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              SupplierListNotifier(context.read<SupplierRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              CustomerListNotifier(context.read<CustomerRepository>())..load(),
        ),
      ],
      child: MaterialApp.router(
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'ТехноМаркет',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 109, 55, 217),
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}
