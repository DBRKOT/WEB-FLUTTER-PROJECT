import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/breakpoints.dart';
import '../models/brand.dart';
import '../models/brand_query.dart';
import '../repositories/seed_data.dart';
import '../state/brand_list_notifier.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';

class BrandListScreen extends StatefulWidget {
  const BrandListScreen({super.key});

  @override
  State<BrandListScreen> createState() => _BrandListScreenState();
}

class _BrandListScreenState extends State<BrandListScreen> {
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

    final fromUrl = BrandQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<BrandListNotifier>();
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

  Future<void> _apply(BrandQuery next) async {
    await context.read<BrandListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/brands');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = context.read<BrandListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<BrandListNotifier>();
    final countries = {
      for (final b in seedBrands) b.country,
    }.toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бренды'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(child: Text('Выбрано: ${notifier.selected.length}')),
            ),
          if (notifier.hasSelection)
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
      body: Column(
        children: [
          _BrandFilters(
            notifier: notifier,
            countries: countries,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onApply: _apply,
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
                    )
                  : EntityTable<Brand>(
                      items: notifier.result.items,
                      idOf: (b) => b.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) =>
                          context.read<BrandListNotifier>().toggleSelection(id),
                      isDeleted: (b) => b.isDeleted,
                      sortField: notifier.query.sortField,
                      sortAscending: notifier.query.sortAscending,
                      onSort: (field) => _apply(
                        notifier.query.copyWith(
                          sortField: field,
                          sortAscending: field == notifier.query.sortField
                              ? !notifier.query.sortAscending
                              : true,
                        ),
                      ),
                      columns: [
                        TableColumnSpec(
                          label: 'Название',
                          sortField: 'name',
                          build: (b) => Text(b.name),
                        ),
                        TableColumnSpec(
                          label: 'Страна',
                          sortField: 'country',
                          build: (b) => Text(b.country),
                        ),
                        TableColumnSpec(
                          label: 'Год основания',
                          sortField: 'foundedYear',
                          numeric: true,
                          build: (b) => Text('${b.foundedYear}'),
                        ),
                      ],
                      actions: (b) => _brandActions(context, b),
                    ),
            ),
          ),
          if (notifier.status == LoadStatus.success ||
              notifier.status == LoadStatus.loading)
            PaginatorBar(
              page: notifier.result.page,
              totalPages: notifier.result.totalPages,
              total: notifier.result.total,
              size: notifier.query.size,
              onPageChanged: (page) =>
                  _apply(notifier.query.copyWith(page: page)),
              onSizeChanged: (size) =>
                  _apply(notifier.query.copyWith(size: size, page: 1)),
            ),
        ],
      ),
    );
  }

  List<Widget> _brandActions(BuildContext context, Brand brand) {
    final n = context.read<BrandListNotifier>();
    if (brand.isDeleted) {
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () => n.restore(brand.id),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, brand),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => context.push('/brands/${brand.id}'),
      ),
      IconButton(
        tooltip: 'Удалить (логически)',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmSoftDelete(context, brand),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _confirmHardDelete(context, brand),
      ),
    ];
  }

  Future<void> _confirmSoftDelete(BuildContext context, Brand brand) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Логическое удаление'),
        content: Text('Скрыть бренд «${brand.name}»?'),
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
      await context.read<BrandListNotifier>().softDelete(brand.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Brand brand) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Физическое удаление'),
        content: Text('Стереть бренд «${brand.name}» навсегда?'),
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
      await context.read<BrandListNotifier>().hardDelete(brand.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<BrandListNotifier>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные'),
        content: Text('Логически удалить ${notifier.selected.length} бренд(ов)?'),
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
      await context.read<BrandListNotifier>().deleteSelected();
    }
  }
}

class _BrandFilters extends StatelessWidget {
  const _BrandFilters({
    required this.notifier,
    required this.countries,
    required this.searchController,
    required this.onSearchChanged,
    required this.onApply,
  });

  final BrandListNotifier notifier;
  final List<String> countries;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(BrandQuery next) onApply;

  @override
  Widget build(BuildContext context) {
    final q = notifier.query;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 240,
            child: TextField(
              key: const Key('brand-search'),
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Поиск: название или страна',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<String?>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: q.country,
              decoration: const InputDecoration(
                labelText: 'Страна',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Все')),
                for (final c in countries)
                  DropdownMenuItem(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => onApply(q.copyWith(country: value)),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              key: ValueKey('foundedFrom-${q.foundedFrom}'),
              initialValue: q.foundedFrom?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Основан от',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => onApply(
                q.copyWith(
                  foundedFrom: value.isEmpty ? null : int.tryParse(value),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: TextFormField(
              key: ValueKey('foundedTo-${q.foundedTo}'),
              initialValue: q.foundedTo?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Основан до',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => onApply(
                q.copyWith(
                  foundedTo: value.isEmpty ? null : int.tryParse(value),
                ),
              ),
            ),
          ),
          FilterChip(
            label: const Text('Показать удалённые'),
            selected: q.includeDeleted,
            onSelected: (value) =>
                onApply(q.copyWith(includeDeleted: value)),
          ),
        ],
      ),
    );
  }
}

class _BrandCards extends StatelessWidget {
  const _BrandCards({required this.items, required this.selected});

  final List<Brand> items;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<BrandListNotifier>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final b = items[index];
        return Card(
          color: b.isDeleted
              ? Theme.of(context)
                  .colorScheme
                  .errorContainer
                  .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(b.id),
              onChanged: (_) => notifier.toggleSelection(b.id),
            ),
            title: Text(b.name),
            subtitle: Text('${b.country} · с ${b.foundedYear} года'),
            onTap: () => context.push('/brands/${b.id}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'soft':
                    await notifier.softDelete(b.id);
                  case 'hard':
                    await notifier.hardDelete(b.id);
                  case 'restore':
                    await notifier.restore(b.id);
                }
              },
              itemBuilder: (context) => [
                if (!b.isDeleted) ...[
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
