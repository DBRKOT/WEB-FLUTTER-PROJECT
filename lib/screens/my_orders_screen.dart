import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../models/order_query.dart';
import '../state/entity_notifiers.dart';
import '../widgets/load_state_view.dart';
import 'orders_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  Future<void> _reload() async {
    final clientId = context.read<AuthNotifier>().user?.id;
    await context.read<OrderListNotifier>().applyQuery(
      OrderQuery(clientId: clientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canViewMyOrders) {
      return const Scaffold(
        body: Center(child: Text('Раздел только для клиентов')),
      );
    }

    final notifier = context.watch<OrderListNotifier>();
    final orders = notifier.result.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Мои заказы')),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Оформить заказ',
        onPressed: () => context.push('/orders/new'),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Оформить заказ'),
      ),
      body: LoadStateView(
        status: notifier.status,
        error: notifier.error,
        isEmpty: orders.isEmpty,
        emptyMessage: 'У вас пока нет заказов',
        onRetry: _reload,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('Заказ от ${formatOrderDate(order.createdAt)}'),
                subtitle: Text(
                  '${order.status.label} · ${formatPrice(order.total)}'
                  '${order.comment.isEmpty ? '' : '\n${order.comment}'}',
                ),
                isThreeLine: order.comment.isNotEmpty,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/orders/${order.id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
