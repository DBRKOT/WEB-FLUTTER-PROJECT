import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/permissions.dart';
import '../models/product_query.dart';
import '../repositories/brand_repository.dart';
import '../repositories/category_repository.dart';
import '../repositories/customer_repository.dart';
import '../repositories/product_repository.dart';
import '../repositories/supplier_repository.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  int _products = 0;
  int _brands = 0;
  int _categories = 0;
  int _suppliers = 0;
  int _customers = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final products = await context
          .read<ProductRepository>()
          .find(const ProductQuery(page: 1, size: 1));
      final brands = await context.read<BrandRepository>().findAll();
      final categories = await context.read<CategoryRepository>().findAll();
      final suppliers = await context.read<SupplierRepository>().findAll();
      final customers = await context.read<CustomerRepository>().findAll();

      if (!mounted) return;
      setState(() {
        _products = products.total;
        _brands = brands.length;
        _categories = categories.length;
        _suppliers = suppliers.length;
        _customers = customers.length;
        _status = LoadStatus.success;
      });
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '403: ${e.message}';
        _status = LoadStatus.error;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = LoadStatus.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthNotifier>().canViewStats) {
      return const Center(child: Text('Раздел только для администратора'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: false,
        emptyMessage: '',
        onRetry: _load,
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: MediaQuery.sizeOf(context).width > 800 ? 3 : 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _tile(context, 'Товары', _products, Icons.devices),
            _tile(context, 'Бренды', _brands, Icons.factory_outlined),
            _tile(context, 'Категории', _categories, Icons.category_outlined),
            _tile(
              context,
              'Поставщики',
              _suppliers,
              Icons.local_shipping_outlined,
            ),
            _tile(context, 'Клиенты', _customers, Icons.people_outline),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String label, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const Spacer(),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
            Text(label),
          ],
        ),
      ),
    );
  }
}
