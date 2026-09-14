import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/api_loan_service.dart';
import '../state/load_status.dart';
import '../state/product_list_notifier.dart';
import '../widgets/load_state_view.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Product? _product;
  List<Brand> _brands = const [];
  List<Category> _categories = const [];
  Supplier? _supplier;
  bool _loanBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final productNotifier = context.read<ProductListNotifier>();
      final cache = context.read<ReferenceCache>();
      final product = await productNotifier.findById(widget.productId);
      if (product == null) {
        if (!mounted) return;
        setState(() {
          _status = LoadStatus.success;
          _product = null;
        });
        return;
      }
      final brands = await cache.brands();
      final categories = await cache.categories();
      final suppliers = await cache.suppliers();
      Supplier? supplier;
      for (final s in suppliers) {
        if (s.id == product.supplierId) {
          supplier = s;
          break;
        }
      }
      if (!mounted) return;
      setState(() {
        _product = product;
        _brands = brands.where((b) => product.brandIds.contains(b.id)).toList();
        _categories = categories
            .where((c) => product.categoryIds.contains(c.id))
            .toList();
        _supplier = supplier;
        _status = LoadStatus.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = LoadStatus.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить товар: $e';
        _status = LoadStatus.error;
      });
    }
  }

  Future<void> _demoLoanConflict() async {
    final product = _product;
    if (product == null) return;
    setState(() => _loanBusy = true);
    final loans = context.read<ApiLoanService>();
    try {
      for (var i = 0; i < 40; i++) {
        await loans.createLoan(readerId: 1, bookId: product.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Экземпляры ещё есть — попробуйте товар с малым остатком',
          ),
        ),
      );
    } on ConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('409: ${e.message}')));
      await _load();
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('403: ${e.message}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loanBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Карточка товара'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/products');
            }
          },
        ),
        actions: [
          if (_product != null && !_product!.isDeleted && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/products/${_product!.id}/edit'),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _product == null,
        emptyMessage: 'Товар не найден',
        onRetry: _load,
        child: _product == null
            ? const SizedBox.shrink()
            : _ProductCard(
                product: _product!,
                brands: _brands,
                categories: _categories,
                supplier: _supplier,
                loanBusy: _loanBusy,
                showConflictDemo: auth.canManageOrders,
                onDemoConflict: _demoLoanConflict,
              ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.brands,
    required this.categories,
    required this.supplier,
    required this.loanBusy,
    required this.showConflictDemo,
    required this.onDemoConflict,
  });

  final Product product;
  final List<Brand> brands;
  final List<Category> categories;
  final Supplier? supplier;
  final bool loanBusy;
  final bool showConflictDemo;
  final VoidCallback onDemoConflict;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    _row('Название', product.name),
                    _row('Артикул', product.sku),
                    _row(
                      'Категории',
                      categories.map((c) => c.name).join(', ').ifEmpty('—'),
                    ),
                    _row(
                      'Бренды',
                      brands.map((b) => b.name).join(', ').ifEmpty('—'),
                    ),
                    _row('Поставщик', supplier?.name ?? '—'),
                    _row('Год выпуска', '${product.year}'),
                    _row('Цена', formatPrice(product.price)),
                    _row(
                      'На складе',
                      '${product.stockAvailable} из ${product.stockTotal}',
                    ),
                  ],
                ),
              ),
            ),
            if (showConflictDemo) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: loanBusy ? null : onDemoConflict,
                icon: loanBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.warning_amber_outlined),
                label: Text(
                  loanBusy
                      ? 'Оформляем выдачи…'
                      : 'Демо 409: выдать до конфликта',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return ListTile(title: Text(label), subtitle: Text(value));
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
