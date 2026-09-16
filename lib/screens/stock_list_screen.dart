import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/simple_query.dart';
import '../models/stock.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  Timer? _searchDebounce;
  late final TextEditingController _searchController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;

  bool _onlyOutOfStock = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<StockListNotifier>();
      if (notifier.status == LoadStatus.idle) notifier.load();
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

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = SimpleQuery.fromUri(
      GoRouterState.of(context).uri,
      defaultSort: 'name',
    );
    final notifier = context.read<StockListNotifier>();
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

  Future<void> _apply(SimpleQuery next) async {
    await context.read<StockListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/stock');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<StockListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  List<Stock> _visible(List<Stock> items) =>
      _onlyOutOfStock ? items.where((s) => s.quantity == 0).toList() : items;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<StockListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;
    final items = _visible(notifier.result.items);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Склад'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (notifier.hasSelection && auth.canManageStock)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () => context.read<StockListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canManageStock
          ? FloatingActionButton(
              tooltip: 'Новая складская запись',
              onPressed: () => context.push('/stock/new'),
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
                  width: 260,
                  child: TextField(
                    key: const Key('stock-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск: товар, артикул, место',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('stock-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Товар')),
                      DropdownMenuItem(
                        value: 'quantity',
                        child: Text('Остаток'),
                      ),
                      DropdownMenuItem(
                        value: 'location',
                        child: Text('Место хранения'),
                      ),
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
                  label: const Text('Только нулевой остаток (на странице)'),
                  selected: _onlyOutOfStock,
                  onSelected: (value) =>
                      setState(() => _onlyOutOfStock = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: LoadStateView(
              status: notifier.status,
              error: notifier.error,
              isEmpty: items.isEmpty,
              emptyMessage: _onlyOutOfStock
                  ? 'На этой странице нет товаров с нулевым остатком'
                  : 'Складские записи не найдены',
              onRetry: () => context.read<StockListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _StockCards(
                      items: items,
                      selected: notifier.selected,
                      onDelete: _confirmDelete,
                    )
                  : EntityTable<Stock>(
                      items: items,
                      idOf: (s) => s.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) =>
                          context.read<StockListNotifier>().toggleSelection(id),
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
                          label: 'Товар',
                          sortField: 'name',
                          build: (s) => tableCellText(
                            s.productName.isEmpty ? '—' : s.productName,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Артикул',
                          build: (s) => tableCellText(s.productSku),
                        ),
                        TableColumnSpec(
                          label: 'Остаток',
                          sortField: 'quantity',
                          numeric: true,
                          build: (s) => Text(
                            '${s.quantity}',
                            style: TextStyle(
                              fontWeight: s.quantity == 0
                                  ? FontWeight.bold
                                  : null,
                              color: s.quantity == 0
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Место',
                          sortField: 'location',
                          build: (s) => tableCellText(
                            s.location.isEmpty ? '—' : s.location,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Состояние',
                          build: (s) => tableCellText(s.statusLabel),
                        ),
                      ],
                      actions: _actions,
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

  List<Widget> _actions(Stock stock) {
    if (!context.watch<AuthNotifier>().canManageStock) return const [];
    return [
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/stock/${stock.id}/edit'),
      ),
      IconButton(
        tooltip: 'Удалить',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmDelete(stock),
      ),
    ];
  }

  Future<void> _confirmDelete(Stock stock) async {
    final ok = await _confirm(
      title: 'Удаление складской записи',
      message:
          'Удалить складскую запись товара «${stock.productName}»? '
          'Сам товар останется в каталоге.',
      action: 'Удалить',
    );
    if (ok && mounted) {
      await context.read<StockListNotifier>().hardDelete(stock.id);
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final notifier = context.read<StockListNotifier>();
    final ok = await _confirm(
      title: 'Удалить выбранные',
      message: 'Удалить ${notifier.selected.length} складских записей?',
      action: 'Удалить',
    );
    if (ok && mounted) await notifier.deleteSelected();
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
}

class _StockCards extends StatelessWidget {
  const _StockCards({
    required this.items,
    required this.selected,
    required this.onDelete,
  });

  final List<Stock> items;
  final Set<String> selected;
  final Future<void> Function(Stock stock) onDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<StockListNotifier>();
    final canManage = context.watch<AuthNotifier>().canManageStock;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: s.quantity == 0
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(s.id),
              onChanged: (_) => notifier.toggleSelection(s.id),
            ),
            title: Text(s.productName.isEmpty ? '—' : s.productName),
            subtitle: Text(
              'Остаток: ${s.quantity} · ${s.statusLabel}'
              '${s.location.isEmpty ? '' : ' · место ${s.location}'}',
            ),
            onTap: canManage ? () => context.push('/stock/${s.id}/edit') : null,
            trailing: canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/stock/${s.id}/edit');
                        case 'delete':
                          await onDelete(s);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Изменить')),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
