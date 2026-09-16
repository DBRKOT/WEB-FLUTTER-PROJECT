import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../models/repair_query.dart';
import '../state/entity_notifiers.dart';
import '../widgets/load_state_view.dart';
import 'repair_list_screen.dart' show formatRepairInterval;

class MyRepairsScreen extends StatefulWidget {
  const MyRepairsScreen({super.key});

  @override
  State<MyRepairsScreen> createState() => _MyRepairsScreenState();
}

class _MyRepairsScreenState extends State<MyRepairsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = context.read<AuthNotifier>().user?.id;
      if (userId == null) return;
      context.read<RepairListNotifier>().applyQuery(
        RepairQuery(clientId: userId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canViewMyRepairs) {
      return const Center(child: Text('Раздел только для клиентов'));
    }
    final notifier = context.watch<RepairListNotifier>();
    final items = notifier.result.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Мои заявки')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новая заявка',
        onPressed: () => context.push('/repairs/new'),
        child: const Icon(Icons.add),
      ),
      body: LoadStateView(
        status: notifier.status,
        error: notifier.error,
        isEmpty: items.isEmpty,
        emptyMessage: 'У вас пока нет заявок на ремонт',
        onRetry: () => context.read<RepairListNotifier>().load(),
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final repair = items[index];
            return Card(
              child: ListTile(
                title: Text(
                  repair.productName.isEmpty
                      ? 'Ремонт без указания товара'
                      : repair.productName,
                ),
                subtitle: Text(
                  '${repair.problem}\n'
                  '${formatRepairInterval(repair)}\n'
                  '${repair.status.label} · ${formatPrice(repair.total)}',
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/repairs/${repair.id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}
