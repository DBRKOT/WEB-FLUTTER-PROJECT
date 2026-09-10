import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../core/api_exceptions.dart';
import '../core/field_validation_exception.dart';
import '../models/simple_query.dart';
import '../models/supplier.dart';
import '../state/load_status.dart';
import '../state/supplier_list_notifier.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';

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
    await context.read<SupplierListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/suppliers');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = context.read<SupplierListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  Future<void> _runDelete(
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on FieldValidationException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Нельзя удалить'),
          content: Text(e.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('409: ${e.message}')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<SupplierListNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поставщики'),
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
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новый поставщик',
        onPressed: () => context.push('/suppliers/new'),
        child: const Icon(Icons.add),
      ),
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
              emptyMessage: 'Поставщики не найдены',
              onRetry: () => context.read<SupplierListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _SupplierCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onDelete: _runDelete,
                    )
                  : EntityTable<Supplier>(
                      items: notifier.result.items,
                      idOf: (s) => s.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<SupplierListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (s) => s.isDeleted,
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
                          build: (s) => Text(s.name),
                        ),
                        TableColumnSpec(
                          label: 'Страна',
                          sortField: 'country',
                          build: (s) => Text(s.country),
                        ),
                        TableColumnSpec(
                          label: 'Телефон',
                          build: (s) => Text(s.phone.isEmpty ? '—' : s.phone),
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
              onSizeChanged: (size) =>
                  _apply(q.copyWith(size: size, page: 1)),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, Supplier supplier) {
    final n = context.read<SupplierListNotifier>();
    if (supplier.isDeleted) {
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () => n.restore(supplier.id),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, supplier),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => context.push('/suppliers/${supplier.id}'),
      ),
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/suppliers/${supplier.id}/edit'),
      ),
      IconButton(
        tooltip: 'Удалить (логически)',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmSoftDelete(context, supplier),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _confirmHardDelete(context, supplier),
      ),
    ];
  }

  Future<void> _confirmSoftDelete(
    BuildContext context,
    Supplier supplier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Логическое удаление'),
        content: Text('Скрыть поставщика «${supplier.name}»?'),
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
      await _runDelete(
        () => context.read<SupplierListNotifier>().softDelete(supplier.id),
      );
    }
  }

  Future<void> _confirmHardDelete(
    BuildContext context,
    Supplier supplier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Физическое удаление'),
        content: Text('Стереть поставщика «${supplier.name}» навсегда?'),
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
      await _runDelete(
        () => context.read<SupplierListNotifier>().hardDelete(supplier.id),
      );
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<SupplierListNotifier>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные'),
        content: Text(
          'Логически удалить ${notifier.selected.length} поставщик(ов)?',
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
      await _runDelete(() => notifier.deleteSelected());
    }
  }
}

class _SupplierCards extends StatelessWidget {
  const _SupplierCards({
    required this.items,
    required this.selected,
    required this.onDelete,
  });

  final List<Supplier> items;
  final Set<int> selected;
  final Future<void> Function(Future<void> Function() action) onDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<SupplierListNotifier>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: s.isDeleted
              ? Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            dense: true,
            leading: Checkbox(
              value: selected.contains(s.id),
              onChanged: (_) => notifier.toggleSelection(s.id),
            ),
            title: Text(s.name),
            subtitle: Text(
              [
                s.country,
                if (s.phone.isNotEmpty) s.phone,
              ].join(' · '),
            ),
            onTap: () => context.push('/suppliers/${s.id}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'edit':
                    context.push('/suppliers/${s.id}/edit');
                  case 'soft':
                    await onDelete(() => notifier.softDelete(s.id));
                  case 'hard':
                    await onDelete(() => notifier.hardDelete(s.id));
                  case 'restore':
                    await notifier.restore(s.id);
                }
              },
              itemBuilder: (context) => [
                if (!s.isDeleted) ...[
                  const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                  const PopupMenuItem(
                    value: 'soft',
                    child: Text('Удалить логически'),
                  ),
                  const PopupMenuItem(
                    value: 'hard',
                    child: Text('Удалить навсегда'),
                  ),
                ] else ...[
                  const PopupMenuItem(
                    value: 'restore',
                    child: Text('Восстановить'),
                  ),
                  const PopupMenuItem(
                    value: 'hard',
                    child: Text('Удалить навсегда'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
