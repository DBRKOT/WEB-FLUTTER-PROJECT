import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/auth_notifier.dart';
import 'core/reference_cache.dart';
import 'core/router.dart';
import 'core/storage_migration.dart';
import 'repositories/api_brand_repository.dart';
import 'repositories/api_category_repository.dart';
import 'repositories/api_customer_repository.dart';
import 'repositories/api_loan_service.dart';
import 'repositories/api_product_repository.dart';
import 'repositories/api_supplier_repository.dart';
import 'repositories/api_user_repository.dart';
import 'repositories/brand_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/supplier_repository.dart';
import 'state/brand_list_notifier.dart';
import 'state/category_list_notifier.dart';
import 'state/customer_list_notifier.dart';
import 'state/product_list_notifier.dart';
import 'state/supplier_list_notifier.dart';
import 'widgets/session_guard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  final prefs = await SharedPreferences.getInstance();
  final migration = await StorageMigration.run(prefs);

  late final AuthNotifier auth;
  final dio = buildDio(
    tokenProvider: () => auth.accessToken,
    authProvider: () => auth,
  );
  auth = AuthNotifier(prefs, dio);
  await auth.restore();

  final products = ApiProductRepository(dio);
  final brands = ApiBrandRepository(dio);
  final categories = ApiCategoryRepository(dio);
  final suppliers = ApiSupplierRepository(dio, products);
  final customers = ApiCustomerRepository(dio);
  final cache = ReferenceCache(
    brands: brands,
    categories: categories,
    suppliers: suppliers,
  );

  runApp(
    TechStoreApp(
      prefs: prefs,
      migrationMessage: migration.message,
      dio: dio,
      auth: auth,
      products: products,
      brands: brands,
      categories: categories,
      suppliers: suppliers,
      customers: customers,
      loans: ApiLoanService(dio),
      referenceCache: cache,
    ),
  );
}

class TechStoreApp extends StatefulWidget {
  const TechStoreApp({
    super.key,
    required this.prefs,
    required this.dio,
    required this.auth,
    required this.products,
    required this.brands,
    required this.categories,
    required this.suppliers,
    required this.customers,
    required this.loans,
    required this.referenceCache,
    this.migrationMessage,
  });

  final SharedPreferences prefs;
  final Dio dio;
  final AuthNotifier auth;
  final ProductRepository products;
  final BrandRepository brands;
  final CategoryRepository categories;
  final SupplierRepository suppliers;
  final CustomerRepository customers;
  final ApiLoanService loans;
  final ReferenceCache referenceCache;
  final String? migrationMessage;

  @override
  State<TechStoreApp> createState() => _TechStoreAppState();
}

class _TechStoreAppState extends State<TechStoreApp> {
  late final GoRouter _router = createAppRouter(widget.auth);
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
        Provider<Dio>.value(value: widget.dio),
        ChangeNotifierProvider<AuthNotifier>.value(value: widget.auth),
        Provider<ApiLoanService>.value(value: widget.loans),
        Provider<ApiUserRepository>(
          create: (context) => ApiUserRepository(context.read<Dio>()),
        ),
        Provider<ReferenceCache>.value(value: widget.referenceCache),
        Provider<ProductRepository>.value(value: widget.products),
        Provider<BrandRepository>.value(value: widget.brands),
        Provider<CategoryRepository>.value(value: widget.categories),
        Provider<SupplierRepository>.value(value: widget.suppliers),
        Provider<CustomerRepository>.value(value: widget.customers),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthNotifier>();
            final notifier =
                ProductListNotifier(context.read<ProductRepository>());
            _loadWhenAuthenticated(auth, notifier.load);
            return notifier;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthNotifier>();
            final notifier = BrandListNotifier(
              context.read<BrandRepository>(),
              cache: context.read<ReferenceCache>(),
            );
            _loadWhenAuthenticated(auth, notifier.load);
            return notifier;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthNotifier>();
            final notifier = CategoryListNotifier(
              context.read<CategoryRepository>(),
              cache: context.read<ReferenceCache>(),
            );
            _loadWhenAuthenticated(auth, notifier.load);
            return notifier;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthNotifier>();
            final notifier = SupplierListNotifier(
              context.read<SupplierRepository>(),
              cache: context.read<ReferenceCache>(),
            );
            _loadWhenAuthenticated(auth, notifier.load);
            return notifier;
          },
        ),
        ChangeNotifierProvider(
          create: (context) {
            final auth = context.read<AuthNotifier>();
            final notifier =
                CustomerListNotifier(context.read<CustomerRepository>());
            _loadWhenAuthenticated(auth, notifier.load);
            return notifier;
          },
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
        builder: (context, child) => SessionGuard(
          child: child ?? const SizedBox.shrink(),
        ),
        routerConfig: _router,
      ),
    );
  }
}

void _loadWhenAuthenticated(
  AuthNotifier auth,
  Future<void> Function() load,
) {
  if (auth.isAuthenticated) {
    load();
    return;
  }
  void listener() {
    if (auth.isAuthenticated) {
      auth.removeListener(listener);
      load();
    }
  }

  auth.addListener(listener);
}
