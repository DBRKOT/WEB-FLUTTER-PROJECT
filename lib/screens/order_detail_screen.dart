import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/form_api_errors.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../core/validators.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';
import 'orders_screen.dart';

List<OrderStatus> nextOrderStatuses(OrderStatus current) => switch (current) {
  OrderStatus.created => const [OrderStatus.paid, OrderStatus.cancelled],
  OrderStatus.paid => const [OrderStatus.shipped, OrderStatus.cancelled],
  OrderStatus.shipped => const [OrderStatus.done],
  OrderStatus.done || OrderStatus.cancelled => const [],
};

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Order? _order;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadOrder();
      context.read<OrderItemsNotifier>().load(widget.orderId);
    });
  }

  Future<void> _loadOrder() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final order = await context.read<OrderListNotifier>().findById(
        widget.orderId,
      );
      if (!mounted) return;
      setState(() {
        _order = order;
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

  Future<void> _changeStatus(OrderStatus next) async {
    try {
      await context.read<OrderListNotifier>().changeStatus(
        widget.orderId,
        next,
      );
      if (!mounted) return;
      await _loadOrder();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openItemDialog({OrderItem? item}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _OrderItemDialog(orderId: widget.orderId, item: item),
    );
    if (saved == true && mounted) await _loadOrder();
  }

  Future<void> _confirmRemoveItem(OrderItem item) async {
    final name = item.productName.isEmpty ? 'позицию' : item.productName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление позиции'),
        content: Text('Убрать $name из заказа?'),
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
    try {
      await context.read<OrderItemsNotifier>().remove(item.id);
      if (!mounted) return;
      await _loadOrder();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final items = context.watch<OrderItemsNotifier>();
    final order = _order;
    final canManage = auth.canManageOrders;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка заказа'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(auth.canViewMyOrders ? '/my-orders' : '/orders');
            }
          },
        ),
        actions: [
          if (order != null && canManage) ...[
            if (nextOrderStatuses(order.status).isNotEmpty)
              PopupMenuButton<OrderStatus>(
                tooltip: 'Сменить статус',
                icon: const Icon(Icons.swap_horiz),
                onSelected: _changeStatus,
                itemBuilder: (context) => [
                  for (final status in nextOrderStatuses(order.status))
                    PopupMenuItem(value: status, child: Text(status.label)),
                ],
              ),
            IconButton(
              tooltip: 'Изменить заказ',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/orders/${order.id}/edit'),
            ),
          ],
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: order == null,
        emptyMessage: 'Заказ не найден',
        onRetry: _loadOrder,
        child: order == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              _row(
                                'Заказчик',
                                order.clientName.isEmpty
                                    ? '—'
                                    : order.clientName,
                              ),
                              _row('Создан', formatOrderDate(order.createdAt)),
                              _row('Статус', order.status.label),
                              _row(
                                'Комментарий',
                                order.comment.isEmpty ? '—' : order.comment,
                              ),
                              _row('Итог', formatPrice(order.total)),
                              if (order.isDeleted)
                                _row('Состояние', 'Заказ удалён'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Состав заказа',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (canManage)
                            FilledButton.tonalIcon(
                              onPressed: () => _openItemDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить позицию'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LoadStateView(
                        status: items.status,
                        error: items.error,
                        isEmpty: items.items.isEmpty,
                        emptyMessage: 'В заказе пока нет позиций',
                        onRetry: () => context.read<OrderItemsNotifier>().load(
                          widget.orderId,
                        ),
                        child: Card(
                          child: Column(
                            children: [
                              for (final item in items.items)
                                ListTile(
                                  title: Text(
                                    item.productName.isEmpty
                                        ? 'Товар'
                                        : item.productName,
                                  ),
                                  subtitle: Text(
                                    '${item.productSku.isEmpty ? '' : '${item.productSku} · '}'
                                    '${item.quantity} шт. × '
                                    '${formatPrice(item.price)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(formatPrice(item.sum)),
                                      if (canManage) ...[
                                        IconButton(
                                          tooltip: 'Изменить позицию',
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: () =>
                                              _openItemDialog(item: item),
                                        ),
                                        IconButton(
                                          tooltip: 'Удалить позицию',
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: () =>
                                              _confirmRemoveItem(item),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              const Divider(height: 1),
                              ListTile(
                                title: const Text('Итого по составу'),
                                trailing: Text(
                                  formatPrice(items.total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
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

  Widget _row(String label, String value) =>
      ListTile(title: Text(label), subtitle: Text(value));
}

class _OrderItemDialog extends StatefulWidget {
  const _OrderItemDialog({required this.orderId, this.item});

  final String orderId;
  final OrderItem? item;

  @override
  State<_OrderItemDialog> createState() => _OrderItemDialogState();
}

class _OrderItemDialogState extends State<_OrderItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  List<Product> _products = const [];
  String? _productId;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _productId = item.productId;
      _quantityController.text = '${item.quantity}';
      _priceController.text = '${item.price}';
    } else {
      _quantityController.text = '1';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadProducts();
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final products = await context.read<ReferenceCache>().products();
      if (!mounted) return;
      setState(() {
        _products = products
            .where((p) => !p.isDeleted || p.id == _productId)
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  void _onProductChanged(String? value) {
    if (value == null) return;
    setState(() {
      _productId = value;
      _serverErrors.remove('product');
      for (final product in _products) {
        if (product.id == value) _priceController.text = '${product.price}';
      }
    });
  }

  String? _validateQuantity(String? value) {
    final base = V.combine([
      V.required('Укажите количество'),
      V.integer(min: 1, max: 1000),
    ])(value);
    return base ?? _serverErrors['quantity'];
  }

  String? _validatePrice(String? value) {
    final base = V.combine([
      V.required('Укажите цену'),
      V.nonNegativeInt('Цена не может быть отрицательной'),
    ])(value);
    return base ?? _serverErrors['price'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'order', 'product', 'quantity', 'price'};
    final unknown = <String>[];
    setState(() {
      _serverErrors.clear();
      errors.forEach((field, message) {
        if (known.contains(field)) {
          _serverErrors[field] = message;
        } else {
          unknown.add(message);
        }
      });
      if (_serverErrors.isEmpty) {
        _serverErrors['order'] = unknown.isEmpty ? fallback : unknown.first;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final productId = _productId;
    if (productId == null) return;

    setState(() => _saving = true);
    try {
      final notifier = context.read<OrderItemsNotifier>();
      final duplicate = await notifier.isProductInOrder(
        productId,
        excludeId: widget.item?.id,
      );
      if (duplicate) {
        if (!mounted) return;
        setState(
          () => _serverErrors['product'] =
              'Этот товар уже есть в заказе: '
              'измените количество в существующей позиции',
        );
        _formKey.currentState?.validate();
        return;
      }

      final item = OrderItem(
        id: widget.item?.id ?? '',
        orderId: widget.orderId,
        productId: productId,
        quantity: int.parse(_quantityController.text.trim()),
        price: int.parse(_priceController.text.trim()),
      );
      if (widget.item == null) {
        await notifier.add(item);
      } else {
        await notifier.edit(item);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ValidationException catch (e) {
      if (!mounted) return;
      _applyServerErrors(e.errors, e.message);
    } on ConflictException catch (e) {
      if (!mounted) return;
      _applyServerErrors(e.errors, e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      _applyServerErrors(const {}, e.message);
    } catch (e) {
      if (!mounted) return;
      _applyServerErrors(const {}, apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generalError = _serverErrors['order'];

    return AlertDialog(
      title: Text(widget.item == null ? 'Новая позиция' : 'Изменение позиции'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            : _loadError != null
            ? Text(_loadError!)
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (generalError != null) ...[
                        Text(
                          generalError,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _products.any((p) => p.id == _productId)
                            ? _productId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Товар',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          for (final product in _products)
                            DropdownMenuItem(
                              value: product.id,
                              child: Text(
                                product.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _onProductChanged,
                        validator: (value) => value == null
                            ? 'Выберите товар'
                            : _serverErrors['product'],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Количество (от 1 до 1000)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => _serverErrors.remove('quantity')),
                        validator: _validateQuantity,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Цена за штуку, ₽',
                          helperText: 'Цена фиксируется на момент продажи',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) =>
                            setState(() => _serverErrors.remove('price')),
                        validator: _validatePrice,
                      ),
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving || _loading || _loadError != null ? null : _submit,
          child: Text(_saving ? 'Сохранение…' : 'Сохранить'),
        ),
      ],
    );
  }
}
