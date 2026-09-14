import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/customer.dart';
import '../state/customer_list_notifier.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final int customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
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
        _error = 'Не удалось загрузить клиента: $e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer?.fullName ?? 'Клиент'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/customers');
            }
          },
        ),
        actions: [
          if (_customer != null && !_customer!.isDeleted)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/customers/${_customer!.id}/edit'),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _customer == null,
        emptyMessage: 'Клиент не найден',
        onRetry: _load,
        child: _customer == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('ФИО'),
                        subtitle: Text(_customer!.fullName),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Email'),
                        subtitle: Text(_customer!.email),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Телефон'),
                        subtitle: Text(
                          _customer!.phone.isEmpty ? '—' : _customer!.phone,
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        dense: true,
                        title: const Text('Клубная карта'),
                        subtitle: Text(_customer!.card.number),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Уровень'),
                        subtitle: Text(_customer!.card.level),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Год выдачи'),
                        subtitle: Text('${_customer!.card.issuedYear}'),
                      ),
                      if (_customer!.isDeleted)
                        ListTile(
                          dense: true,
                          title: const Text('Статус'),
                          subtitle: const Text('Удалён'),
                          leading: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
