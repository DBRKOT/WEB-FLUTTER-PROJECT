import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router.dart';
import 'repositories/brand_repository.dart';
import 'repositories/in_memory_brand_repository.dart';
import 'repositories/in_memory_product_repository.dart';
import 'repositories/product_repository.dart';
import 'state/brand_list_notifier.dart';
import 'state/product_list_notifier.dart';

void main() {
  usePathUrlStrategy();
  runApp(const TechStoreApp());
}

class TechStoreApp extends StatefulWidget {
  const TechStoreApp({super.key});

  @override
  State<TechStoreApp> createState() => _TechStoreAppState();
}

class _TechStoreAppState extends State<TechStoreApp> {
  late final GoRouter _router = createAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ProductRepository>(
          create: (_) => InMemoryProductRepository(),
        ),
        Provider<BrandRepository>(
          create: (_) => InMemoryBrandRepository(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              ProductListNotifier(context.read<ProductRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (context) =>
              BrandListNotifier(context.read<BrandRepository>())..load(),
        ),
      ],
      child: MaterialApp.router(
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
