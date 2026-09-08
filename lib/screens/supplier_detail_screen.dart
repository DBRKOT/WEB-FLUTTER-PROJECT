import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/supplier.dart';
import '../state/load_status.dart';
import '../state/supplier_list_notifier.dart';
import '../widgets/load_state_view.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final int supplierId;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Supplier? _supplier;

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
      final supplier = await context
          .read<SupplierListNotifier>()
          .findById(widget.supplierId);
      if (!mounted) return;
      setState(() {
        _supplier = supplier;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить поставщика: $e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_supplier?.name ?? 'Поставщик'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/suppliers');
            }
          },
        ),
        actions: [
          if (_supplier != null && !_supplier!.isDeleted)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/suppliers/${_supplier!.id}/edit'),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _supplier == null,
        emptyMessage: 'Поставщик не найден',
        onRetry: _load,
        child: _supplier == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('Название'),
                        subtitle: Text(_supplier!.name),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Страна'),
                        subtitle: Text(_supplier!.country),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Телефон'),
                        subtitle: Text(
                          _supplier!.phone.isEmpty ? '—' : _supplier!.phone,
                        ),
                      ),
                      if (_supplier!.isDeleted)
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
