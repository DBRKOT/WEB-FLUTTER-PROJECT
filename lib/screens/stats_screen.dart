import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../models/order_query.dart';
import '../models/product_query.dart';
import '../models/simple_query.dart';
import '../repositories/catalog_repositories.dart';
import '../repositories/service_repositories.dart';
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
  final _counts = <String, int>{};

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
      final products = context.read<PbProductRepository>();
      final stock = context.read<PbStockRepository>();
      final customers = context.read<PbCustomerRepository>();
      final orders = context.read<PbOrderRepository>();
      final cache = context.read<ReferenceCache>();

      final productPage = await products.find(const ProductQuery(size: 1));
      final stockPage = await stock.find(const SimpleQuery(size: 1));
      final customerPage = await customers.find(const SimpleQuery(size: 1));
      final orderPage = await orders.find(const OrderQuery(size: 1));
      final brands = await cache.brands();
      final categories = await cache.categories();
      final suppliers = await cache.suppliers();
      final services = await cache.services();
      final masters = await cache.masters();

      if (!mounted) return;
      setState(() {
        _counts
          ..clear()
          ..addAll({
            'Товары': productPage.total,
            'Бренды': brands.length,
            'Категории': categories.length,
            'Поставщики': suppliers.length,
            'Складские записи': stockPage.total,
            'Клиенты': customerPage.total,
            'Заказы': orderPage.total,
            'Услуги': services.length,
            'Мастера': masters.length,
          });
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

  static const _icons = <String, IconData>{
    'Товары': Icons.devices,
    'Бренды': Icons.factory_outlined,
    'Категории': Icons.category_outlined,
    'Поставщики': Icons.local_shipping_outlined,
    'Складские записи': Icons.inventory_2_outlined,
    'Клиенты': Icons.people_outline,
    'Заказы': Icons.assignment_outlined,
    'Услуги': Icons.build_outlined,
    'Мастера': Icons.engineering_outlined,
  };

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
          crossAxisCount: byScreen(context, compact: 1, medium: 2, expanded: 3),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            for (final entry in _counts.entries)
              _tile(
                context,
                entry.key,
                entry.value,
                _icons[entry.key] ?? Icons.dataset_outlined,
              ),
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
            Text(label, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
