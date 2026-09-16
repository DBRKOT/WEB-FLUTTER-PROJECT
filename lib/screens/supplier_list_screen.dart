import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
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

    final fromUrl = SimpleQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<SupplierListNotifier>();
    if (_searchController.text != fromUrl.search) {
      _searchController.text = fromUrl.search;
    }
    if (fromUrl == notifier.query) {
      if (notifier.status == LoadStatus.idle) notifier.load();
      return;
    }

    _applyingFromUrl = true;
    notifier.applyQuery(fromUrl).whenComplete(() {
      _applyingFromUrl = false;
    });
  }

  Future<void> _apply(SimpleQuery next) async {
    await context.read<SupplierListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/suppliers');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<SupplierListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<SupplierListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поставщики'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (notifier.hasSelection && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () =>
                context.read<SupplierListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новый поставщик',
              onPressed: () => context.push('/suppliers/new'),
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
                  width: 280,
                  child: TextField(
                    key: const Key('supplier-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск: название, город, договор',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('supplier-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Название')),
                      DropdownMenuItem(value: 'city', child: Text('Город')),
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
              ],
            ),
          ),
          Expanded(
            child: LoadStateView(
              status: notifier.status,
              error: notifier.error,
              isEmpty: notifier.result.items.isEmpty,
              emptyMessage: 'Поставщики не найдены',
              onRetry: () => context.read<SupplierListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _SupplierCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onDelete: (s) => _confirmDelete(context, s),
                    )
                  : EntityTable<Supplier>(
                      items: notifier.result.items,
                      idOf: (s) => s.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<SupplierListNotifier>()
                          .toggleSelection(id),
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
                          label: 'Название',
                          sortField: 'name',
                          build: (s) => tableCellText(s.name),
                        ),
                        TableColumnSpec(
                          label: 'Город',
                          sortField: 'city',
                          build: (s) =>
                              tableCellText(s.city.isEmpty ? '—' : s.city),
                        ),
                        TableColumnSpec(
                          label: 'Телефон',
                          build: (s) =>
                              tableCellText(s.phone.isEmpty ? '—' : s.phone),
                        ),
                        TableColumnSpec(
                          label: 'Почта',
                          build: (s) =>
                              tableCellText(s.email.isEmpty ? '—' : s.email),
                        ),
                        TableColumnSpec(
                          label: 'Договор',
                          build: (s) => tableCellText(
                            s.contractNumber.isEmpty ? '—' : s.contractNumber,
                          ),
                        ),
                      ],
                      actions: (s) => _actions(context, s),
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

  List<Widget> _actions(BuildContext context, Supplier supplier) {
    final auth = context.watch<AuthNotifier>();
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => context.push('/suppliers/${supplier.id}'),
      ),
      if (auth.canEditCatalog)
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/suppliers/${supplier.id}/edit'),
        ),
      if (auth.canHardDelete)
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, supplier),
        ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context, Supplier supplier) async {
    final ok = await _confirm(
      context,
      title: 'Удаление поставщика',
      message:
          'Удалить поставщика «${supplier.name}»? '
          'Запись будет стёрта безвозвратно, восстановить её нельзя.',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<SupplierListNotifier>().softDelete(supplier.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<SupplierListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message:
          'Удалить ${notifier.selected.length} поставщик(ов)? '
          'Восстановить записи будет нельзя.',
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

class _SupplierCards extends StatelessWidget {
  const _SupplierCards({
    required this.items,
    required this.selected,
    required this.onDelete,
  });

  final List<Supplier> items;
  final Set<String> selected;
  final Future<void> Function(Supplier supplier) onDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<SupplierListNotifier>();
    final auth = context.watch<AuthNotifier>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        final contacts = [
          if (s.phone.isNotEmpty) s.phone,
          if (s.email.isNotEmpty) s.email,
        ].join(' · ');
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(s.id),
              onChanged: (_) => notifier.toggleSelection(s.id),
            ),
            title: Text(s.name),
            subtitle: Text(
              '${s.city.isEmpty ? 'город не указан' : s.city}\n'
              '${contacts.isEmpty ? 'контакты не указаны' : contacts}',
            ),
            isThreeLine: true,
            onTap: () => context.push('/suppliers/${s.id}'),
            trailing: auth.canEditCatalog || auth.canHardDelete
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/suppliers/${s.id}/edit');
                        case 'delete':
                          await onDelete(s);
                      }
                    },
                    itemBuilder: (context) => [
                      if (auth.canEditCatalog)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Изменить'),
                        ),
                      if (auth.canHardDelete)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
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
