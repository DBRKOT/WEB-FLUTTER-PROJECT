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
import 'repositories/api_user_repository.dart';
import 'repositories/catalog_repositories.dart';
import 'repositories/service_repositories.dart';
import 'state/entity_notifiers.dart';
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

  runApp(
    TechStoreApp(migrationMessage: migration.message, dio: dio, auth: auth),
  );
}

class TechStoreApp extends StatefulWidget {
  const TechStoreApp({
    super.key,
    required this.dio,
    required this.auth,
    this.migrationMessage,
  });

  final Dio dio;
  final AuthNotifier auth;
  final String? migrationMessage;

  @override
  State<TechStoreApp> createState() => _TechStoreAppState();
}

class _TechStoreAppState extends State<TechStoreApp> {
  late final GoRouter _router = createAppRouter(widget.auth);
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  late final PbProductRepository _products = PbProductRepository(widget.dio);
  late final PbBrandRepository _brands = PbBrandRepository(widget.dio);
  late final PbCategoryRepository _categories = PbCategoryRepository(
    widget.dio,
  );
  late final PbSupplierRepository _suppliers = PbSupplierRepository(widget.dio);
  late final PbStockRepository _stock = PbStockRepository(widget.dio);
  late final PbCustomerRepository _customers = PbCustomerRepository(widget.dio);
  late final PbServiceRepository _services = PbServiceRepository(widget.dio);
  late final PbMasterRepository _masters = PbMasterRepository(widget.dio);
  late final PbRepairRepository _repairs = PbRepairRepository(widget.dio);
  late final PbOrderRepository _orders = PbOrderRepository(widget.dio);
  late final PbOrderItemRepository _orderItems = PbOrderItemRepository(
    widget.dio,
  );

  late final ReferenceCache _cache = ReferenceCache(
    brands: _brands,
    categories: _categories,
    suppliers: _suppliers,
    products: _products,
    services: _services,
    masters: _masters,
    customers: _customers,
  );

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

  ChangeNotifierProvider<T> _listProvider<T extends ChangeNotifier>(
    T Function() create,
    Future<void> Function(T notifier) load,
  ) {
    return ChangeNotifierProvider<T>(
      create: (_) {
        final notifier = create();
        _loadWhenAuthenticated(widget.auth, () => load(notifier));
        return notifier;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Dio>.value(value: widget.dio),
        ChangeNotifierProvider<AuthNotifier>.value(value: widget.auth),
        Provider<ReferenceCache>.value(value: _cache),
        Provider<ApiUserRepository>(
          create: (context) => ApiUserRepository(context.read<Dio>()),
        ),
        Provider<PbProductRepository>.value(value: _products),
        Provider<PbStockRepository>.value(value: _stock),
        Provider<PbCustomerRepository>.value(value: _customers),
        Provider<PbRepairRepository>.value(value: _repairs),
        Provider<PbOrderRepository>.value(value: _orders),
        Provider<PbOrderItemRepository>.value(value: _orderItems),

        _listProvider<ProductListNotifier>(
          () => ProductListNotifier(
            _products,
            onInvalidate: _cache.invalidateProducts,
          ),
          (n) => n.load(),
        ),
        _listProvider<BrandListNotifier>(
          () =>
              BrandListNotifier(_brands, onInvalidate: _cache.invalidateBrands),
          (n) => n.load(),
        ),
        _listProvider<CategoryListNotifier>(
          () => CategoryListNotifier(
            _categories,
            onInvalidate: _cache.invalidateCategories,
          ),
          (n) => n.load(),
        ),
        _listProvider<SupplierListNotifier>(
          () => SupplierListNotifier(
            _suppliers,
            onInvalidate: _cache.invalidateSuppliers,
          ),
          (n) => n.load(),
        ),
        _listProvider<CustomerListNotifier>(
          () => CustomerListNotifier(
            _customers,
            onInvalidate: _cache.invalidateCustomers,
          ),
          (n) => n.load(),
        ),

        ChangeNotifierProvider<StockListNotifier>(
          create: (_) => StockListNotifier(_stock),
        ),
        ChangeNotifierProvider<ServiceListNotifier>(
          create: (_) => ServiceListNotifier(
            _services,
            onInvalidate: _cache.invalidateServices,
          ),
        ),
        ChangeNotifierProvider<MasterListNotifier>(
          create: (_) => MasterListNotifier(
            _masters,
            onInvalidate: _cache.invalidateMasters,
          ),
        ),
        ChangeNotifierProvider<RepairListNotifier>(
          create: (_) => RepairListNotifier(_repairs),
        ),
        ChangeNotifierProvider<OrderListNotifier>(
          create: (_) => OrderListNotifier(_orders),
        ),
        ChangeNotifierProvider<OrderItemsNotifier>(
          create: (_) => OrderItemsNotifier(_orderItems, _orders),
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
        builder: (context, child) =>
            SessionGuard(child: child ?? const SizedBox.shrink()),
        routerConfig: _router,
      ),
    );
  }
}

void _loadWhenAuthenticated(AuthNotifier auth, Future<void> Function() load) {
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
