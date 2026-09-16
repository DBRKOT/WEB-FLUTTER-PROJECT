import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/order_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

String formatOrderDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Timer? _searchDebounce;
  late final TextEditingController _searchController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;
  List<Customer> _customers = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<OrderListNotifier>();
      if (notifier.status == LoadStatus.idle) notifier.load();
      _loadCustomers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromUrl();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await context.read<ReferenceCache>().customers();
      if (!mounted) return;
      setState(() => _customers = customers);
    } catch (_) {}
  }

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = OrderQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<OrderListNotifier>();
    if (fromUrl == notifier.query) {
      if (_searchController.text != fromUrl.search) {
        _searchController.text = fromUrl.search;
      }
      return;
    }

    _applyingFromUrl = true;
    if (_searchController.text != fromUrl.search) {
      _searchController.text = fromUrl.search;
    }
    notifier.applyQuery(fromUrl).whenComplete(() {
      _applyingFromUrl = false;
    });
  }

  Future<void> _apply(OrderQuery next) async {
    await context.read<OrderListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/orders');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<OrderListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<OrderListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заказы'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (notifier.hasSelection && auth.canManageOrders)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () => context.read<OrderListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canManageOrders
          ? FloatingActionButton(
              tooltip: 'Новый заказ',
              onPressed: () => context.push('/orders/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const Key('order-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по комментарию и заказчику',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<OrderStatus?>(
                    key: ValueKey('order-status-${q.status?.apiValue ?? ''}'),
                    isExpanded: true,
                    initialValue: q.status,
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<OrderStatus?>(
                        value: null,
                        child: Text('Все статусы'),
                      ),
                      for (final status in OrderStatus.values)
                        DropdownMenuItem<OrderStatus?>(
                          value: status,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) => _apply(q.copyWith(status: value)),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey('order-client-${q.clientId ?? ''}'),
                    isExpanded: true,
                    initialValue: _customers.any((c) => c.userId == q.clientId)
                        ? q.clientId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Заказчик',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Все заказчики'),
                      ),
                      for (final customer in _customers)
                        DropdownMenuItem<String?>(
                          value: customer.userId,
                          child: Text(
                            customer.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => _apply(q.copyWith(clientId: value)),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('order-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'created',
                        child: Text('Дата создания'),
                      ),
                      DropdownMenuItem(value: 'total', child: Text('Сумма')),
                      DropdownMenuItem(value: 'status', child: Text('Статус')),
                    ],
                    onChanged: (value) {
                      if (value != null) _apply(q.copyWith(sortField: value));
                    },
                  ),
                ),
                IconButton(
                  tooltip: q.sortAscending ? 'По возрастанию' : 'По убыванию',
                  onPressed: () =>
                      _apply(q.copyWith(sortAscending: !q.sortAscending)),
                  icon: Icon(
                    q.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ),
                FilterChip(
                  label: const Text('Показать удалённые'),
                  selected: q.includeDeleted,
                  onSelected: (value) =>
                      _apply(q.copyWith(includeDeleted: value)),
                ),
              ],
            ),
          ),
          Expanded(
            child: LoadStateView(
              status: notifier.status,
              error: notifier.error,
              isEmpty: notifier.result.items.isEmpty,
              emptyMessage: 'Заказы не найдены',
              onRetry: () => context.read<OrderListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _OrderCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onSoftDelete: (o) => _confirmSoftDelete(context, o),
                      onHardDelete: (o) => _confirmHardDelete(context, o),
                    )
                  : EntityTable<Order>(
                      items: notifier.result.items,
                      idOf: (o) => o.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) =>
                          context.read<OrderListNotifier>().toggleSelection(id),
                      isDeleted: (o) => o.isDeleted,
                      sortField: q.sortField,
                      sortAscending: q.sortAscending,
                      onSort: (field) => _apply(
                        q.copyWith(
                          sortField: field,
                          sortAscending: field == q.sortField
                              ? !q.sortAscending
                              : true,
                        ),
                      ),
                      columns: [
                        TableColumnSpec(
                          label: 'Заказчик',
                          build: (o) => Text(
                            o.clientName.isEmpty ? '—' : o.clientName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: o.isDeleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Создан',
                          sortField: 'created',
                          build: (o) =>
                              tableCellText(formatOrderDate(o.createdAt)),
                        ),
                        TableColumnSpec(
                          label: 'Статус',
                          sortField: 'status',
                          build: (o) => tableCellText(o.status.label),
                        ),
                        TableColumnSpec(
                          label: 'Сумма',
                          sortField: 'total',
                          numeric: true,
                          build: (o) => Text(formatPrice(o.total)),
                        ),
                        TableColumnSpec(
                          label: 'Состояние',
                          build: (o) =>
                              tableCellText(o.isDeleted ? 'Удалён' : 'Активен'),
                        ),
                      ],
                      actions: (o) => _actions(context, o),
                    ),
            ),
          ),
          if (notifier.status == LoadStatus.success ||
              notifier.status == LoadStatus.loading)
            PaginatorBar(
              page: notifier.result.page,
              totalPages: notifier.result.totalPages,
              total: notifier.result.total,
              size: q.size,
              onPageChanged: (page) => _apply(q.copyWith(page: page)),
              onSizeChanged: (size) => _apply(q.copyWith(size: size, page: 1)),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Order order) {
    final auth = context.watch<AuthNotifier>();
    final buttons = <Widget>[
      IconButton(
        tooltip: 'Открыть заказ',
        icon: const Icon(Icons.receipt_long_outlined),
        onPressed: () => context.push('/orders/${order.id}'),
      ),
    ];

    if (order.isDeleted) {
      if (auth.canRestore) {
        buttons.add(
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () =>
                context.read<OrderListNotifier>().restore(order.id),
          ),
        );
      }
      if (auth.canHardDelete) {
        buttons.add(
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmHardDelete(context, order),
          ),
        );
      }
      return buttons;
    }

    if (auth.canManageOrders) {
      buttons.addAll([
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/orders/${order.id}/edit'),
        ),
        IconButton(
          tooltip: 'Удалить (логически)',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmSoftDelete(context, order),
        ),
      ]);
    }
    if (auth.canHardDelete) {
      buttons.add(
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, order),
        ),
      );
    }
    return buttons;
  }

  Future<void> _confirmSoftDelete(BuildContext context, Order order) async {
    final ok = await _confirm(
      context,
      title: 'Логическое удаление',
      message: 'Скрыть заказ ${_orderTitle(order)}?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<OrderListNotifier>().softDelete(order.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Order order) async {
    final ok = await _confirm(
      context,
      title: 'Физическое удаление',
      message: 'Стереть заказ ${_orderTitle(order)} навсегда?',
      action: 'Стереть',
    );
    if (ok && context.mounted) {
      await context.read<OrderListNotifier>().hardDelete(order.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<OrderListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Логически удалить ${notifier.selected.length} заказ(ов)?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await notifier.deleteSelected();
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
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
}

String _orderTitle(Order order) {
  final client = order.clientName.isEmpty ? 'без заказчика' : order.clientName;
  return '$client от ${formatOrderDate(order.createdAt)}';
}

class _OrderCards extends StatelessWidget {
  const _OrderCards({
    required this.items,
    required this.selected,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  final List<Order> items;
  final Set<String> selected;
  final Future<void> Function(Order order) onSoftDelete;
  final Future<void> Function(Order order) onHardDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<OrderListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final canManage = auth.canManageOrders;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final o = items[index];
        final showMenu =
            canManage || (o.isDeleted && auth.canRestore) || auth.canHardDelete;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: o.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(o.id),
              onChanged: (_) => notifier.toggleSelection(o.id),
            ),
            title: Text(
              o.clientName.isEmpty ? 'Без заказчика' : o.clientName,
              style: o.isDeleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${formatOrderDate(o.createdAt)} · ${o.status.label} · '
              '${formatPrice(o.total)}'
              '${o.isDeleted ? ' · удалён' : ''}',
            ),
            onTap: () => context.push('/orders/${o.id}'),
            trailing: showMenu
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'open':
                          context.push('/orders/${o.id}');
                        case 'edit':
                          context.push('/orders/${o.id}/edit');
                        case 'soft':
                          await onSoftDelete(o);
                        case 'hard':
                          await onHardDelete(o);
                        case 'restore':
                          await notifier.restore(o.id);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Text('Открыть'),
                      ),
                      if (!o.isDeleted) ...[
                        if (canManage) ...[
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Изменить'),
                          ),
                          const PopupMenuItem(
                            value: 'soft',
                            child: Text('Удалить логически'),
                          ),
                        ],
                      ] else if (auth.canRestore)
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Восстановить'),
                        ),
                      if (auth.canHardDelete)
                        const PopupMenuItem(
                          value: 'hard',
                          child: Text('Удалить навсегда'),
                        ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
