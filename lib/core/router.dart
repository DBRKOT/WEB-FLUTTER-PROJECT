import 'package:go_router/go_router.dart';

import '../screens/brand_detail_screen.dart';
import '../screens/brand_list_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_list_screen.dart';
import '../widgets/app_scaffold.dart';

GoRouter createAppRouter() {
  return GoRouter(
    initialLocation: '/products',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/products'),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(location: state.uri.path, child: child);
        },
        routes: [
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return ProductDetailScreen(productId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/brands',
            builder: (context, state) => const BrandListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) {
                  final id = int.parse(state.pathParameters['id']!);
                  return BrandDetailScreen(brandId: id);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
