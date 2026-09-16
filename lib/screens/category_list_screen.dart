import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/category.dart';
import '../models/simple_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
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
    final notifier = context.read<CategoryListNotifier>();
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
    await context.read<CategoryListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/categories');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<CategoryListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<CategoryListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Категории'),
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
                context.read<CategoryListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новая категория',
              onPressed: () => context.push('/categories/new'),
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
                    key: const Key('category-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по названию и описанию',
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
                    key: ValueKey('category-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Название')),
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
              emptyMessage: 'Категории не найдены',
              onRetry: () => context.read<CategoryListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _CategoryCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onDelete: (c) => _confirmDelete(context, c),
                    )
                  : EntityTable<Category>(
                      items: notifier.result.items,
                      idOf: (c) => c.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<CategoryListNotifier>()
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
                          build: (c) => tableCellText(c.name),
                        ),
                        TableColumnSpec(
                          label: 'Описание',
                          build: (c) => tableCellText(
                            c.description.isEmpty ? '—' : c.description,
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

  List<Widget> _actions(BuildContext context, Category category) {
    final auth = context.watch<AuthNotifier>();
    return [
      IconButton(
        tooltip: 'Карточка',
        icon: const Icon(Icons.info_outline),
        onPressed: () => context.push('/categories/${category.id}'),
      ),
      if (auth.canEditCatalog)
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/categories/${category.id}/edit'),
        ),
      if (auth.canHardDelete)
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, category),
        ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context, Category category) async {
    final ok = await _confirm(
      context,
      title: 'Удаление категории',
      message: 'Удалить категорию «${category.name}» навсегда?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<CategoryListNotifier>().softDelete(category.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<CategoryListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Удалить ${notifier.selected.length} категорию(и) навсегда?',
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

class _CategoryCards extends StatelessWidget {
  const _CategoryCards({
    required this.items,
    required this.selected,
    required this.onDelete,
  });

  final List<Category> items;
  final Set<String> selected;
  final Future<void> Function(Category category) onDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<CategoryListNotifier>();
    final auth = context.watch<AuthNotifier>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final c = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(c.id),
              onChanged: (_) => notifier.toggleSelection(c.id),
            ),
            title: Text(c.name),
            subtitle: Text(
              c.description.isEmpty ? 'Описание не указано' : c.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => context.push('/categories/${c.id}'),
            trailing: auth.canEditCatalog || auth.canHardDelete
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/categories/${c.id}/edit');
                        case 'delete':
                          await onDelete(c);
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
