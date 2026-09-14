import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/loan_order.dart';
import '../repositories/api_loan_service.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

String _fmtDate(DateTime d) {
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd.$mm.${local.year}';
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  List<LoanOrder> _items = [];

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
      final page = await context.read<ApiLoanService>().findOrders(size: 50);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _status = LoadStatus.success;
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

  Future<void> _returnLoan(LoanOrder order) async {
    try {
      await context.read<ApiLoanService>().returnLoan(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заказ закрыт (товар возвращён)')),
      );
      await _load();
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('403: ${e.message}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canManageOrders) {
      return const Center(child: Text('Раздел только для менеджеров'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Заказы клиентов')),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _items.isEmpty,
        emptyMessage: 'Заказов нет',
        onRetry: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final o = _items[i];
            final compact = screenSizeOf(context) == ScreenSize.compact;
            if (compact) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        o.productName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${o.customerName}\nВыдан ${_fmtDate(o.issuedAt)}, до ${_fmtDate(o.dueAt)} · ${o.status}',
                      ),
                      if (o.isOpen) ...[
                        const SizedBox(height: 8),
                        FilledButton.tonal(
                          onPressed: () => _returnLoan(o),
                          child: const Text('Закрыть'),
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Закрыт'),
                        ),
                    ],
                  ),
                ),
              );
            }
            return Card(
              child: ListTile(
                title: Text(o.productName),
                subtitle: Text(
                  '${o.customerName}\nВыдан ${_fmtDate(o.issuedAt)}, до ${_fmtDate(o.dueAt)} · ${o.status}',
                ),
                isThreeLine: true,
                trailing: o.isOpen
                    ? FilledButton.tonal(
                        onPressed: () => _returnLoan(o),
                        child: const Text('Закрыть'),
                      )
                    : const Text('Закрыт'),
              ),
            );
          },
        ),
      ),
    );
  }
}
