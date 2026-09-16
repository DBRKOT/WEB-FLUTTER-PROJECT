import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class BrandListScreen extends StatefulWidget {
  const BrandListScreen({super.key});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
  final Map<String, Timer> _debounces = {};
  late final TextEditingController _searchController;
  late final TextEditingController _countryController;
  late final TextEditingController _foundedFromController;
  late final TextEditingController _foundedToController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _countryController = TextEditingController();
    _foundedFromController = TextEditingController();
    _foundedToController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromUrl();
  }

  @override
  void dispose() {
    for (final timer in _debounces.values) {
      timer.cancel();
    }
    _searchController.dispose();
    _countryController.dispose();
    _foundedFromController.dispose();
    _foundedToController.dispose();
    super.dispose();
  }

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = BrandQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<BrandListNotifier>();
    if (fromUrl == notifier.query) {
      _fillControllers(fromUrl);
      return;
    }

    _applyingFromUrl = true;
    _fillControllers(fromUrl);
    notifier.applyQuery(fromUrl).whenComplete(() {
      _applyingFromUrl = false;
    });
  }

  void _fillControllers(BrandQuery query) {
    _setText(_searchController, query.search);
    _setText(_countryController, query.country ?? '');
    _setText(_foundedFromController, query.foundedFrom?.toString() ?? '');
    _setText(_foundedToController, query.foundedTo?.toString() ?? '');
  }

  void _setText(TextEditingController controller, String value) {
    if (controller.text != value) controller.text = value;
  }

  Future<void> _apply(BrandQuery next) async {
    await context.read<BrandListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation();
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _debounced(String field, void Function(BrandQuery query) action) {
    _debounces[field]?.cancel();
    _debounces[field] = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      action(context.read<BrandListNotifier>().query);
    });
  }

  void _onSearchChanged(String value) {
    _debounced('search', (q) => _apply(q.copyWith(search: value)));
  }

  void _onCountryChanged(String value) {
    final country = value.trim();
    _debounced(
      'country',
      (q) => _apply(q.copyWith(country: country.isEmpty ? null : country)),
    );
  }

  void _onFoundedFromChanged(String value) {
    final year = int.tryParse(value.trim());
    _debounced('foundedFrom', (q) => _apply(q.copyWith(foundedFrom: year)));
  }

  void _onFoundedToChanged(String value) {
    final year = int.tryParse(value.trim());
    _debounced('foundedTo', (q) => _apply(q.copyWith(foundedTo: year)));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<BrandListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бренды'),
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
            onPressed: () => context.read<BrandListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новый бренд',
              onPressed: () => context.push('/brands/new'),
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
                    key: const Key('brand-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по названию',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    key: const Key('brand-country'),
                    controller: _countryController,
                    decoration: const InputDecoration(
                      labelText: 'Страна',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onCountryChanged,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const Key('brand-founded-from'),
                    controller: _foundedFromController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Год от',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onFoundedFromChanged,
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    key: const Key('brand-founded-to'),
                    controller: _foundedToController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Год до',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onFoundedToChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('brand-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Название')),
                      DropdownMenuItem(
                        value: 'foundedYear',
                        child: Text('Год основания'),
                      ),
                      DropdownMenuItem(value: 'country', child: Text('Страна')),
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
              emptyMessage: 'Бренды не найдены',
              onRetry: () => context.read<BrandListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _BrandCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onDelete: (b) => _confirmDelete(context, b),
                    )
                  : EntityTable<Brand>(
                      items: notifier.result.items,
                      idOf: (b) => b.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) =>
                          context.read<BrandListNotifier>().toggleSelection(id),
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
                          build: (b) => tableCellText(b.name),
                        ),
                        TableColumnSpec(
                          label: 'Страна',
                          sortField: 'country',
                          build: (b) => tableCellText(
                            b.country.isEmpty ? '—' : b.country,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Год основания',
                          sortField: 'foundedYear',
                          numeric: true,
                          build: (b) => Text(
                            b.foundedYear == 0 ? '—' : '${b.foundedYear}',
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Описание',
                          build: (b) => tableCellText(
                            b.description.isEmpty ? '—' : b.description,
                          ),
                        ),
                      ],
                      actions: (b) => _actions(context, b),
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

  List<Widget> _actions(BuildContext context, Brand brand) {
    final auth = context.watch<AuthNotifier>();
    return [
      IconButton(
        tooltip: 'Карточка',
        icon: const Icon(Icons.info_outline),
        onPressed: () => context.push('/brands/${brand.id}'),
      ),
      if (auth.canEditCatalog)
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/brands/${brand.id}/edit'),
        ),
      if (auth.canHardDelete)
        IconButton(
          tooltip: 'Удалить',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, brand),
        ),
    ];
  }

  Future<void> _confirmDelete(BuildContext context, Brand brand) async {
    final ok = await _confirm(
      context,
      title: 'Удаление бренда',
      message: 'Удалить бренд «${brand.name}» навсегда?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<BrandListNotifier>().softDelete(brand.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<BrandListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Удалить ${notifier.selected.length} бренд(ов) навсегда?',
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

class _BrandCards extends StatelessWidget {
  const _BrandCards({
    required this.items,
    required this.selected,
    required this.onDelete,
  });

  final List<Brand> items;
  final Set<String> selected;
  final Future<void> Function(Brand brand) onDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<BrandListNotifier>();
    final auth = context.watch<AuthNotifier>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final b = items[index];
        final year = b.foundedYear == 0 ? '—' : '${b.foundedYear}';
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(b.id),
              onChanged: (_) => notifier.toggleSelection(b.id),
            ),
            title: Text(b.name),
            subtitle: Text(
              '${b.country.isEmpty ? 'страна не указана' : b.country} · '
              'основан: $year',
            ),
            onTap: () => context.push('/brands/${b.id}'),
            trailing: auth.canEditCatalog || auth.canHardDelete
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/brands/${b.id}/edit');
                        case 'delete':
                          await onDelete(b);
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
