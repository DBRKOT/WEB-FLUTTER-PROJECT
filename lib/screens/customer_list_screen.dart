import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/permissions.dart';

import '../core/breakpoints.dart';
import '../models/customer.dart';
import '../models/simple_query.dart';
import '../state/customer_list_notifier.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  Timer? _searchDebounce;
  late final TextEditingController _searchController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
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
      defaultSort: 'fullName',
    );
    final notifier = context.read<CustomerListNotifier>();
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
    await context.read<CustomerListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/customers');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = context.read<CustomerListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CustomerListNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Клиенты'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('${notifier.selected.length}')),
            ),
          if (notifier.hasSelection)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
        ],
      ),
      floatingActionButton: context.watch<AuthNotifier>().canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новый клиент',
              onPressed: () => context.push('/customers/new'),
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
                  width: 220,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                FilterChip(
                  label: const Text('Удалённые'),
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
              emptyMessage: 'Клиенты не найдены',
              onRetry: () => context.read<CustomerListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _CustomerCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                    )
                  : EntityTable<Customer>(
                      items: notifier.result.items,
                      idOf: (c) => c.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<CustomerListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (c) => c.isDeleted,
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
                          label: 'ФИО',
                          sortField: 'fullName',
                          build: (c) => tableCellText(c.fullName),
                        ),
                        TableColumnSpec(
                          label: 'Email',
                          sortField: 'email',
                          build: (c) => tableCellText(c.email),
                        ),
                        TableColumnSpec(
                          label: 'Карта',
                          build: (c) => tableCellText(
                            '${c.card.number} · ${c.card.level}',
                          ),
                        ),
                      ],
                      actions: (c) => _actions(context, c),
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

  List<Widget> _actions(BuildContext context, Customer customer) {
    final n = context.read<CustomerListNotifier>();
    final auth = context.watch<AuthNotifier>();
    if (customer.isDeleted) {
      return [
        if (auth.canRestore)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => n.restore(customer.id),
          ),
        if (auth.canHardDelete)
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmHardDelete(context, customer),
          ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => context.push('/customers/${customer.id}'),
      ),
      if (auth.canEditCatalog) ...[
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/customers/${customer.id}/edit'),
        ),
        IconButton(
          tooltip: 'Удалить (логически)',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmSoftDelete(context, customer),
        ),
      ],
      if (auth.canHardDelete)
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, customer),
        ),
    ];
  }

  Future<void> _confirmSoftDelete(
    BuildContext context,
    Customer customer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Логическое удаление'),
        content: Text('Скрыть клиента «${customer.fullName}»?'),
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
    if (ok == true && context.mounted) {
      await context.read<CustomerListNotifier>().softDelete(customer.id);
    }
  }

  Future<void> _confirmHardDelete(
    BuildContext context,
    Customer customer,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Физическое удаление'),
        content: Text('Стереть клиента «${customer.fullName}» навсегда?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Стереть'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<CustomerListNotifier>().hardDelete(customer.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<CustomerListNotifier>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные'),
        content: Text(
          'Логически удалить ${notifier.selected.length} клиент(ов)?',
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
    if (ok == true && context.mounted) {
      await context.read<CustomerListNotifier>().deleteSelected();
    }
  }
}

class _CustomerCards extends StatelessWidget {
  const _CustomerCards({required this.items, required this.selected});

  final List<Customer> items;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<CustomerListNotifier>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: c.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            dense: true,
            leading: Checkbox(
              value: selected.contains(c.id),
              onChanged: (_) => notifier.toggleSelection(c.id),
            ),
            title: Text(c.fullName),
            subtitle: Text('${c.email} · ${c.card.level}'),
            onTap: () => context.push('/customers/${c.id}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    context.push('/customers/${c.id}/edit');
                  case 'soft':
                    await notifier.softDelete(c.id);
                  case 'hard':
                    await notifier.hardDelete(c.id);
                  case 'restore':
                    await notifier.restore(c.id);
                }
              },
              itemBuilder: (context) {
                final auth = context.watch<AuthNotifier>();
                return [
                  if (!c.isDeleted) ...[
                    const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    const PopupMenuItem(
                      value: 'soft',
                      child: Text('Удалить логически'),
                    ),
                    if (auth.canHardDelete)
                      const PopupMenuItem(
                        value: 'hard',
                        child: Text('Удалить навсегда'),
                      ),
                  ] else ...[
                    if (auth.canRestore)
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
                ];
              },
            ),
          ),
        );
      },
    );
  }
}
