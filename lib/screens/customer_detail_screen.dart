import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/form_api_errors.dart';
import '../core/permissions.dart';
import '../models/customer.dart';
import '../models/order_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  Customer? _customer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final customer = await context.read<CustomerListNotifier>().findById(
        widget.customerId,
      );
      if (!mounted) return;
      setState(() {
        _customer = customer;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e);
        _status = LoadStatus.error;
      });
    }
  }

  Future<void> _confirmDelete(Customer customer) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление профиля'),
        content: Text(
          'Удалить профиль клиента «${customer.displayName}»? '
          'Профиль будет стёрт безвозвратно, учётная запись останется.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<CustomerListNotifier>().hardDelete(customer.id);
    if (mounted) context.go('/customers');
  }

  String _formatDay(DateTime? value) {
    if (value == null) return 'не указана';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day.$month.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final customer = _customer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиент'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/customers'),
        ),
        actions: [
          if (customer != null && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/customers/${customer.id}/edit'),
            ),
          if (customer != null && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(customer),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _status == LoadStatus.success && customer == null,
        emptyMessage: 'Профиль клиента не найден',
        onRetry: _load,
        child: customer == null
            ? const SizedBox.shrink()
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.displayName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          _row(context, 'Почта', customer.email),
                          _row(
                            context,
                            'Телефон',
                            customer.phone.isEmpty
                                ? 'не указан'
                                : customer.phone,
                          ),
                          _row(
                            context,
                            'Адрес',
                            customer.address.isEmpty
                                ? 'не указан'
                                : customer.address,
                          ),
                          _row(
                            context,
                            'Дата рождения',
                            _formatDay(customer.birthDate),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (auth.canManageOrders)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.assignment_outlined),
                      label: const Text('Заказы этого клиента'),
                      onPressed: () => context.go(
                        OrderQuery(clientId: customer.userId).toLocation(),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
