import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/form_api_errors.dart';
import '../core/permissions.dart';
import '../models/supplier.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Supplier? _supplier;
  int _productCount = 0;

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
      final supplier = await context.read<SupplierListNotifier>().findById(
        widget.supplierId,
      );
      if (!mounted) return;
      var count = 0;
      if (supplier != null) {
        count = await context.read<ProductListNotifier>().countBySupplier(
          supplier.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _supplier = supplier;
        _productCount = count;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить поставщика: ${apiErrorMessage(e)}';
        _status = LoadStatus.error;
      });
    }
  }

  Future<void> _confirmDelete(Supplier supplier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление поставщика'),
        content: Text(
          'Удалить поставщика «${supplier.name}»? '
          'Запись будет стёрта безвозвратно.'
          '${_productCount > 0 ? '\n\nНа поставщика ссылается товаров: $_productCount. '
                    'У этих товаров поставщик будет очищен.' : ''}',
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
    await context.read<SupplierListNotifier>().softDelete(supplier.id);
    if (!mounted) return;
    _leave();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/suppliers');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final supplier = _supplier;

    return Scaffold(
      appBar: AppBar(
        title: Text(supplier?.name ?? 'Карточка поставщика'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
        actions: [
          if (supplier != null && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/suppliers/${supplier.id}/edit'),
            ),
          if (supplier != null && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(supplier),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: supplier == null,
        emptyMessage: 'Поставщик не найден',
        onRetry: _load,
        child: supplier == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _row('Название', supplier.name),
                              _row('Город', _orDash(supplier.city)),
                              _row('Телефон', _orDash(supplier.phone)),
                              _row('Почта', _orDash(supplier.email)),
                              _row(
                                'Номер договора',
                                _orDash(supplier.contractNumber),
                              ),
                              _row('Товаров поставщика', '$_productCount'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  static String _orDash(String value) => value.isEmpty ? '—' : value;

  Widget _row(String label, String value) =>
      ListTile(title: Text(label), subtitle: Text(value));
}
