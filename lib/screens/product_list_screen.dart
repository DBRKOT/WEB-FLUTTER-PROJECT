import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/product_query.dart';
import '../models/supplier.dart';
import '../repositories/seed_data.dart';
import '../state/brand_list_notifier.dart';
import '../state/category_list_notifier.dart';
import '../state/load_status.dart';
import '../state/product_list_notifier.dart';
import '../state/supplier_list_notifier.dart';
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

    final fromUrl = ProductQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<ProductListNotifier>();
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
      final q = context.read<ProductListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ProductListNotifier>();
    final brands = context.watch<BrandListNotifier>().result.items;
    final categories = context.watch<CategoryListNotifier>().result.items;
    final suppliers = context.watch<SupplierListNotifier>().result.items;
    final brandNames = {
      for (final b in seedBrands) b.id: b.name,
      for (final b in brands) b.id: b.name,
    };
    final categoryNames = {
      for (final c in seedCategories) c.id: c.name,
      for (final c in categories) c.id: c.name,
    };
    final supplierNames = {
      for (final s in seedSuppliers) s.id: s.name,
      for (final s in suppliers) s.id: s.name,
    };
    final allBrands = {
      for (final b in [...seedBrands, ...brands]) b.id: b,
    }.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final allCategories = {
      for (final c in [...seedCategories, ...categories]) c.id: c,
    }.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    final allSuppliers = {
      for (final s in [...seedSuppliers, ...suppliers]) s.id: s,
    }.values.toList()..sort((a, b) => a.name.compareTo(b.name));

    String brandsLabel(Product p) =>
        p.brandIds.map((id) => brandNames[id] ?? '#$id').join(', ');
    String categoriesLabel(Product p) =>
        p.categoryIds.map((id) => categoryNames[id] ?? '#$id').join(', ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каталог товаров'),
        actions: [
          if (context.watch<AuthNotifier>().canEditCatalog &&
              notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (context.watch<AuthNotifier>().canEditCatalog &&
              notifier.hasSelection)
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
      floatingActionButton: context.watch<AuthNotifier>().canEditCatalog
          ? FloatingActionButton(
              tooltip: 'Новый товар',
              onPressed: () => context.push('/products/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          _ProductFilters(
            notifier: notifier,
            brands: allBrands,
            categories: allCategories,
            suppliers: allSuppliers,
            searchController: _searchController,
            onSearchChanged: _onSearchChanged,
            onApply: _apply,
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
                      brandNames: brandNames,
                      categoryNames: categoryNames,
                      selected: notifier.selected,
                    )
                  : EntityTable<Product>(
                      items: notifier.result.items,
                      idOf: (p) => p.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<ProductListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (p) => p.isDeleted,
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
                          build: (p) => tableCellText(p.name),
                        ),
                        TableColumnSpec(
                          label: 'Артикул',
                          sortField: 'sku',
                          build: (p) => tableCellText(p.sku),
                        ),
                        TableColumnSpec(
                          label: 'Категории',
                          build: (p) => tableCellText(categoriesLabel(p)),
                        ),
                        TableColumnSpec(
                          label: 'Бренды',
                          build: (p) => tableCellText(brandsLabel(p)),
                        ),
                        TableColumnSpec(
                          label: 'Поставщик',
                          build: (p) =>
                              tableCellText(supplierNames[p.supplierId] ?? '—'),
                        ),
                        TableColumnSpec(
                          label: 'Год',
                          sortField: 'year',
                          numeric: true,
                          build: (p) => Text('${p.year}'),
                        ),
                        TableColumnSpec(
                          label: 'Цена',
                          sortField: 'price',
                          numeric: true,
                          build: (p) => Text(formatPrice(p.price)),
                        ),
                      ],
                      actions: (p) => _productActions(context, p),
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

  List<Widget> _productActions(BuildContext context, Product product) {
    final n = context.read<ProductListNotifier>();
    final auth = context.watch<AuthNotifier>();
    if (product.isDeleted) {
      return [
        if (auth.canRestore)
          IconButton(
            tooltip: 'Восстановить',
            icon: const Icon(Icons.restore),
            onPressed: () => n.restore(product.id),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Логическое удаление'),
        content: Text('Скрыть товар «${product.name}» из каталога?'),
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
      await context.read<ProductListNotifier>().softDelete(product.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Физическое удаление'),
        content: Text('Стереть товар «${product.name}» навсегда?'),
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
      await context.read<ProductListNotifier>().hardDelete(product.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<ProductListNotifier>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить выбранные'),
        content: Text(
          'Логически удалить ${notifier.selected.length} товар(ов)?',
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
      await context.read<ProductListNotifier>().deleteSelected();
    }
  }
}

class _ProductFilters extends StatelessWidget {
  const _ProductFilters({
    required this.notifier,
    required this.brands,
    required this.categories,
    required this.suppliers,
    required this.searchController,
    required this.onSearchChanged,
    required this.onApply,
  });

  final ProductListNotifier notifier;
  final List<Brand> brands;
  final List<Category> categories;
  final List<Supplier> suppliers;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(ProductQuery next) onApply;

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
              key: const Key('product-search'),
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Поиск: название или артикул',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: q.categoryId,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Все')),
                for (final c in categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => onApply(q.copyWith(categoryId: value)),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: q.brandId,
              decoration: const InputDecoration(
                labelText: 'Бренд',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Все')),
                for (final b in brands)
                  DropdownMenuItem(
                    value: b.id,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => onApply(q.copyWith(brandId: value)),
            ),
          ),
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<int?>(
              isExpanded: true,
              // ignore: deprecated_member_use
              value: q.supplierId,
              decoration: const InputDecoration(
                labelText: 'Поставщик',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Все')),
                for (final s in suppliers)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => onApply(q.copyWith(supplierId: value)),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('yearFrom-${q.yearFrom}'),
              initialValue: q.yearFrom?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Год от',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => onApply(
                q.copyWith(
                  yearFrom: value.isEmpty ? null : int.tryParse(value),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: TextFormField(
              key: ValueKey('yearTo-${q.yearTo}'),
              initialValue: q.yearTo?.toString() ?? '',
              decoration: const InputDecoration(
                labelText: 'Год до',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => onApply(
                q.copyWith(yearTo: value.isEmpty ? null : int.tryParse(value)),
              ),
            ),
          ),
          FilterChip(
            label: const Text('Показать удалённые'),
            selected: q.includeDeleted,
            onSelected: (value) => onApply(q.copyWith(includeDeleted: value)),
          ),
        ],
      ),
    );
  }
}

class _ProductCards extends StatelessWidget {
  const _ProductCards({
    required this.items,
    required this.brandNames,
    required this.categoryNames,
    required this.selected,
  });

  final List<Product> items;
  final Map<int, String> brandNames;
  final Map<int, String> categoryNames;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ProductListNotifier>();
    final auth = context.watch<AuthNotifier>();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final p = items[index];
        final brands = p.brandIds
            .map((id) => brandNames[id] ?? '#$id')
            .join(', ');
        final cats = p.categoryIds
            .map((id) => categoryNames[id] ?? '#$id')
            .join(', ');
        return Card(
          color: p.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: auth.canEditCatalog
                ? Checkbox(
                    value: selected.contains(p.id),
                    onChanged: (_) => notifier.toggleSelection(p.id),
                  )
                : null,
            title: Text(p.name),
            subtitle: Text(
              '${p.sku} · $cats · $brands · ${p.year}\n'
              '${formatPrice(p.price)}',
            ),
            isThreeLine: true,
            onTap: () => context.push('/products/${p.id}'),
            trailing: !auth.canEditCatalog
                ? null
                : PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/products/${p.id}/edit');
                        case 'soft':
                          await notifier.softDelete(p.id);
                        case 'hard':
                          await notifier.hardDelete(p.id);
                        case 'restore':
                          await notifier.restore(p.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!p.isDeleted) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Изменить'),
                        ),
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
                    ],
                  ),
          ),
        );
      },
    );
  }
}
