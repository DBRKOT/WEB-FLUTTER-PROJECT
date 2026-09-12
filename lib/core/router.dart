import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../screens/brand_detail_screen.dart';
import '../screens/brand_form_screen.dart';
import '../screens/brand_list_screen.dart';
import '../screens/category_detail_screen.dart';
import '../screens/category_form_screen.dart';
import '../screens/category_list_screen.dart';
import '../screens/customer_detail_screen.dart';
import '../screens/customer_form_screen.dart';
import '../screens/customer_list_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/login_screen.dart';
import '../screens/my_orders_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/register_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/supplier_detail_screen.dart';
import '../screens/supplier_form_screen.dart';
import '../screens/supplier_list_screen.dart';
import '../screens/users_screen.dart';
import '../widgets/app_scaffold.dart';
import 'auth_notifier.dart';
import 'permissions.dart';

GoRouter createAppRouter(AuthNotifier auth) {
  return GoRouter(
    initialLocation: '/products',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.isRestoring) return null;

      final loggedIn = auth.isAuthenticated;
      final target = state.matchedLocation;
      final isPublic = target == '/login' || target == '/register';

      if (!loggedIn && !isPublic) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (loggedIn && isPublic) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) return from;
        return '/products';
      }

      if (loggedIn && target != '/forbidden' && !auth.canOpenPath(target)) {
        return '/forbidden';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      GoRoute(path: '/', redirect: (_, _) => '/products'),
      ShellRoute(
        builder: (context, state, child) {
          return AppScaffold(location: state.uri.path, child: child);
        },
        routes: [
          _entityRoutes(
            path: '/products',
            list: const ProductListScreen(),
            create: const ProductFormScreen(),
            edit: (id) => ProductFormScreen(id: id),
            detail: (id) => ProductDetailScreen(productId: id),
          ),
          _entityRoutes(
            path: '/brands',
            list: const BrandListScreen(),
            create: const BrandFormScreen(),
            edit: (id) => BrandFormScreen(id: id),
            detail: (id) => BrandDetailScreen(brandId: id),
          ),
          _entityRoutes(
            path: '/categories',
            list: const CategoryListScreen(),
            create: const CategoryFormScreen(),
            edit: (id) => CategoryFormScreen(id: id),
            detail: (id) => CategoryDetailScreen(categoryId: id),
          ),
          _entityRoutes(
            path: '/suppliers',
            list: const SupplierListScreen(),
            create: const SupplierFormScreen(),
            edit: (id) => SupplierFormScreen(id: id),
            detail: (id) => SupplierDetailScreen(supplierId: id),
          ),
          _entityRoutes(
            path: '/customers',
            list: const CustomerListScreen(),
            create: const CustomerFormScreen(),
            edit: (id) => CustomerFormScreen(id: id),
            detail: (id) => CustomerDetailScreen(customerId: id),
          ),
          GoRoute(
            path: '/my-orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/orders',
            builder: (context, state) => const OrdersScreen(),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => const UsersScreen(),
          ),
          GoRoute(
            path: '/admin/stats',
            builder: (context, state) => const StatsScreen(),
          ),
        ],
      ),
    ],
  );
}

GoRoute _entityRoutes({
  required String path,
  required Widget list,
  required Widget create,
  required Widget Function(int? id) edit,
  required Widget Function(int id) detail,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) => list,
    routes: [
      GoRoute(path: 'new', builder: (context, state) => create),
      GoRoute(
        path: ':id/edit',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return edit(id);
        },
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return detail(id);
        },
      ),
    ],
  );
}
