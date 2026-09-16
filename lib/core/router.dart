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
import '../screens/login_screen.dart';
import '../screens/master_form_screen.dart';
import '../screens/master_list_screen.dart';
import '../screens/my_orders_screen.dart';
import '../screens/my_repairs_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/order_form_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/product_detail_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/repair_detail_screen.dart';
import '../screens/repair_form_screen.dart';
import '../screens/repair_list_screen.dart';
import '../screens/service_form_screen.dart';
import '../screens/service_list_screen.dart';
import '../screens/stock_form_screen.dart';
import '../screens/stock_list_screen.dart';
import '../screens/supplier_detail_screen.dart';
import '../screens/supplier_form_screen.dart';
import '../screens/supplier_list_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/deferred_screen.dart';
import 'auth_notifier.dart';
import 'permissions.dart';

import '../screens/forbidden_screen.dart' deferred as forbidden_lib;
import '../screens/register_screen.dart' deferred as register_lib;
import '../screens/stats_screen.dart' deferred as stats_lib;
import '../screens/users_screen.dart' deferred as users_lib;

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
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => DeferredScreen(
          loadLibrary: register_lib.loadLibrary,
          builder: () => register_lib.RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => DeferredScreen(
          loadLibrary: forbidden_lib.loadLibrary,
          builder: () => forbidden_lib.ForbiddenScreen(),
        ),
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

          _entityRoutes(
            path: '/stock',
            list: const StockListScreen(),
            create: const StockFormScreen(),
            edit: (id) => StockFormScreen(id: id),
          ),

          _entityRoutes(
            path: '/services',
            list: const ServiceListScreen(),
            create: const ServiceFormScreen(),
            edit: (id) => ServiceFormScreen(id: id),
          ),
          _entityRoutes(
            path: '/masters',
            list: const MasterListScreen(),
            create: const MasterFormScreen(),
            edit: (id) => MasterFormScreen(id: id),
          ),
          _entityRoutes(
            path: '/repairs',
            list: const RepairListScreen(),
            create: const RepairFormScreen(),
            edit: (id) => RepairFormScreen(id: id),
            detail: (id) => RepairDetailScreen(repairId: id),
          ),

          _entityRoutes(
            path: '/orders',
            list: const OrdersScreen(),
            create: const OrderFormScreen(),
            edit: (id) => OrderFormScreen(id: id),
            detail: (id) => OrderDetailScreen(orderId: id),
          ),

          GoRoute(
            path: '/my-orders',
            builder: (context, state) => const MyOrdersScreen(),
          ),
          GoRoute(
            path: '/my-repairs',
            builder: (context, state) => const MyRepairsScreen(),
          ),

          GoRoute(
            path: '/admin/users',
            builder: (context, state) => DeferredScreen(
              loadLibrary: users_lib.loadLibrary,
              builder: () => users_lib.UsersScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/stats',
            builder: (context, state) => DeferredScreen(
              loadLibrary: stats_lib.loadLibrary,
              builder: () => stats_lib.StatsScreen(),
            ),
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
  required Widget Function(String? id) edit,
  Widget Function(String id)? detail,
}) {
  return GoRoute(
    path: path,
    builder: (context, state) => list,
    routes: [
      GoRoute(path: 'new', builder: (context, state) => create),
      GoRoute(
        path: ':id/edit',
        builder: (context, state) => edit(state.pathParameters['id']),
      ),
      if (detail != null)
        GoRoute(
          path: ':id',
          builder: (context, state) => detail(state.pathParameters['id']!),
        ),
    ],
  );
}
