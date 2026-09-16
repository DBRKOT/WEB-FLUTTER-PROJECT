import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/format.dart';
import '../core/form_api_errors.dart';
import '../core/permissions.dart';
import '../models/product.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Product? _product;

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
      final product = await context.read<ProductListNotifier>().findById(
        widget.productId,
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить товар: ${apiErrorMessage(e)}';
        _status = LoadStatus.error;
      });
    }
  }

  Future<void> _confirmSoftDelete(Product product) async {
    final ok = await _confirm(
      title: 'Логическое удаление',
      message: 'Скрыть товар «${product.name}» из каталога?',
      action: 'Удалить',
    );
    if (!ok || !mounted) return;
    await context.read<ProductListNotifier>().softDelete(product.id);
    if (!mounted) return;
    _leave();
  }

  Future<void> _confirmHardDelete(Product product) async {
    final ok = await _confirm(
      title: 'Физическое удаление',
      message: 'Стереть товар «${product.name}» навсегда?',
      action: 'Стереть',
    );
    if (!ok || !mounted) return;
    await context.read<ProductListNotifier>().hardDelete(product.id);
    if (!mounted) return;
    _leave();
  }

  Future<void> _restore(Product product) async {
    await context.read<ProductListNotifier>().restore(product.id);
    if (!mounted) return;
    await _load();
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/products');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final product = _product;

    return Scaffold(
      appBar: AppBar(
        title: Text(product?.name ?? 'Карточка товара'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
        actions: [
          if (product != null && !product.isDeleted && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/products/${product.id}/edit'),
            ),
          if (product != null && !product.isDeleted && auth.canEditCatalog)
            IconButton(
              tooltip: 'Удалить (логически)',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmSoftDelete(product),
            ),
          if (product != null && product.isDeleted && auth.canRestore)
            IconButton(
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore),
              onPressed: () => _restore(product),
            ),
          if (product != null && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever),
              onPressed: () => _confirmHardDelete(product),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: product == null,
        emptyMessage: 'Товар не найден',
        onRetry: _load,
        child: product == null
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
                              _row('Название', product.name),
                              _row('Артикул', product.sku),
                              _row('Цена', formatPrice(product.price)),
                              _row(
                                'Гарантия',
                                '${product.warrantyMonths} мес.',
                              ),
                              _row('Бренд', _orDash(product.brandName)),
                              _row('Категория', _orDash(product.categoryName)),
                              _row('Поставщик', _orDash(product.supplierName)),
                              _row('Описание', _orDash(product.description)),
                              if (product.isDeleted)
                                ListTile(
                                  leading: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  title: const Text('Состояние'),
                                  subtitle: const Text(
                                    'Товар удалён из каталога',
                                  ),
                                ),
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
