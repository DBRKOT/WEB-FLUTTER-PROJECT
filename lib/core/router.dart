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
import '../screens/product_detail_screen.dart';
import '../screens/product_form_screen.dart';
import '../screens/product_list_screen.dart';
import '../screens/supplier_detail_screen.dart';
import '../screens/supplier_form_screen.dart';
import '../screens/supplier_list_screen.dart';
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
