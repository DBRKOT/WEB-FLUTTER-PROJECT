import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  Timer? _searchDebounce;
  Timer? _priceDebounce;
  late final TextEditingController _searchController;
  late final TextEditingController _priceFromController;
  late final TextEditingController _priceToController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;

  List<Brand> _brands = const [];
  List<Category> _categories = const [];
  List<Supplier> _suppliers = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _priceFromController = TextEditingController();
    _priceToController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadReferences();
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
    _priceDebounce?.cancel();
    _searchController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  Future<void> _loadReferences() async {
    final cache = context.read<ReferenceCache>();
    try {
      final brands = await cache.brands();
      final categories = await cache.categories();
      final suppliers = await cache.suppliers();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _categories = categories;
        _suppliers = suppliers;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {});
    }
  }

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = ProductQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<ProductListNotifier>();
    _syncFields(fromUrl);
    if (fromUrl == notifier.query) {
      if (notifier.status == LoadStatus.idle) notifier.load();
      return;
    }

    _applyingFromUrl = true;
    notifier.applyQuery(fromUrl).whenComplete(() {
      _applyingFromUrl = false;
    });
  }

  void _syncFields(ProductQuery q) {
    if (_searchController.text != q.search) _searchController.text = q.search;
    final from = q.priceFrom?.toString() ?? '';
    if (_priceFromController.text != from) _priceFromController.text = from;
    final to = q.priceTo?.toString() ?? '';
    if (_priceToController.text != to) _priceToController.text = to;
  }

  Future<void> _apply(ProductQuery next) async {
    await context.read<ProductListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/products');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<ProductListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  void _onPriceChanged(String _) {
    _priceDebounce?.cancel();
    _priceDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final q = context.read<ProductListNotifier>().query;
      _apply(
        q.copyWith(
          priceFrom: int.tryParse(_priceFromController.text.trim()),
          priceTo: int.tryParse(_priceToController.text.trim()),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProductListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог товаров'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (notifier.hasSelection && auth.canEditCatalog)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () =>
                context.read<ProductListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новый товар',
              onPressed: () => context.push('/products/new'),
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
                    key: const Key('product-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск: название, артикул, описание',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('product-brand-${q.brandId}'),
                    isExpanded: true,
                    initialValue: q.brandId,
                    decoration: const InputDecoration(
                      labelText: 'Бренд',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все')),
                      for (final b in _brands)
                        DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => _apply(q.copyWith(brandId: value)),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('product-category-${q.categoryId}'),
                    isExpanded: true,
                    initialValue: q.categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Категория',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все')),
                      for (final c in _categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => _apply(q.copyWith(categoryId: value)),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('product-supplier-${q.supplierId}'),
                    isExpanded: true,
                    initialValue: q.supplierId,
                    decoration: const InputDecoration(
                      labelText: 'Поставщик',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Все')),
                      for (final s in _suppliers)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => _apply(q.copyWith(supplierId: value)),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('product-price-from'),
                    controller: _priceFromController,
                    decoration: const InputDecoration(
                      labelText: 'Цена от',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onPriceChanged,
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: TextField(
                    key: const Key('product-price-to'),
                    controller: _priceToController,
                    decoration: const InputDecoration(
                      labelText: 'Цена до',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onPriceChanged,
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('product-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Название')),
                      DropdownMenuItem(value: 'price', child: Text('Цена')),
                      DropdownMenuItem(value: 'sku', child: Text('Артикул')),
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
              emptyMessage: 'Товары не найдены',
              onRetry: () => context.read<ProductListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _ProductCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onSoftDelete: (p) => _confirmSoftDelete(context, p),
                      onHardDelete: (p) => _confirmHardDelete(context, p),
                    )
                  : EntityTable<Product>(
                      items: notifier.result.items,
                      idOf: (p) => p.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<ProductListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (p) => p.isDeleted,
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
                          build: (p) => Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: p.isDeleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Артикул',
                          sortField: 'sku',
                          build: (p) => tableCellText(p.sku),
                        ),
                        TableColumnSpec(
                          label: 'Цена',
                          sortField: 'price',
                          numeric: true,
                          build: (p) => Text(formatPrice(p.price)),
                        ),
                        TableColumnSpec(
                          label: 'Бренд',
                          build: (p) => tableCellText(
                            p.brandName.isEmpty ? '—' : p.brandName,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Категория',
                          build: (p) => tableCellText(
                            p.categoryName.isEmpty ? '—' : p.categoryName,
                          ),
                        ),
                      ],
                      actions: (p) => _actions(context, p),
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

  List<Widget> _actions(BuildContext context, Product product) {
    final auth = context.watch<AuthNotifier>();

    if (product.isDeleted) {
      return [
        if (auth.canRestore)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () =>
                context.read<ProductListNotifier>().restore(product.id),
          ),
        if (auth.canHardDelete)
          IconButton(
            tooltip: 'Удалить навсегда',
            icon: const Icon(Icons.delete_forever),
            onPressed: () => _confirmHardDelete(context, product),
          ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Открыть',
        icon: const Icon(Icons.visibility_outlined),
        onPressed: () => context.push('/products/${product.id}'),
      ),
      if (auth.canEditCatalog) ...[
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.push('/products/${product.id}/edit'),
        ),
        IconButton(
          tooltip: 'Удалить (логически)',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmSoftDelete(context, product),
        ),
      ],
      if (auth.canHardDelete)
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, product),
        ),
    ];
  }

  Future<void> _confirmSoftDelete(BuildContext context, Product product) async {
    final ok = await _confirm(
      context,
      title: 'Логическое удаление',
      message: 'Скрыть товар «${product.name}» из каталога?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<ProductListNotifier>().softDelete(product.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Product product) async {
    final ok = await _confirm(
      context,
      title: 'Физическое удаление',
      message: 'Стереть товар «${product.name}» навсегда?',
      action: 'Стереть',
    );
    if (ok && context.mounted) {
      await context.read<ProductListNotifier>().hardDelete(product.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<ProductListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Логически удалить ${notifier.selected.length} товар(ов)?',
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

class _ProductCards extends StatelessWidget {
  const _ProductCards({
    required this.items,
    required this.selected,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  final List<Product> items;
  final Set<String> selected;
  final Future<void> Function(Product product) onSoftDelete;
  final Future<void> Function(Product product) onHardDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ProductListNotifier>();
    final auth = context.watch<AuthNotifier>();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        final reference = [
          if (p.brandName.isNotEmpty) p.brandName,
          if (p.categoryName.isNotEmpty) p.categoryName,
        ].join(' · ');
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: p.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(p.id),
              onChanged: (_) => notifier.toggleSelection(p.id),
            ),
            title: Text(
              p.name,
              style: p.isDeleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${p.sku} · ${formatPrice(p.price)}\n'
              '${reference.isEmpty ? 'связи не указаны' : reference}'
              '${p.isDeleted ? ' · удалён' : ''}',
            ),
            isThreeLine: true,
            onTap: () => context.push('/products/${p.id}'),
            trailing: auth.canEditCatalog || auth.canHardDelete
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/products/${p.id}/edit');
                        case 'soft':
                          await onSoftDelete(p);
                        case 'hard':
                          await onHardDelete(p);
                        case 'restore':
                          await notifier.restore(p.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!p.isDeleted) ...[
                        if (auth.canEditCatalog) ...[
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
