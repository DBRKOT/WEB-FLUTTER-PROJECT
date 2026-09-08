import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../state/brand_list_notifier.dart';
import '../state/category_list_notifier.dart';
import '../state/load_status.dart';
import '../state/product_list_notifier.dart';
import '../state/supplier_list_notifier.dart';
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
      final brandNotifier = context.read<BrandListNotifier>();
      final categoryNotifier = context.read<CategoryListNotifier>();
      final supplierNotifier = context.read<SupplierListNotifier>();
      final product = await productNotifier.findById(widget.productId);
      if (product == null) {
        if (!mounted) return;
        setState(() {
          _status = LoadStatus.success;
          _product = null;
        });
        return;
      }
      final brands = await brandNotifier.findAll();
      final categories = await categoryNotifier.findAll();
      final supplier = await supplierNotifier.findById(product.supplierId);
      if (!mounted) return;
      setState(() {
        _product = product;
        _brands = brands.where((b) => product.brandIds.contains(b.id)).toList();
        _categories =
            categories.where((c) => product.categoryIds.contains(c.id)).toList();
        _supplier = supplier;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить товар: $e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_product?.name ?? 'Карточка товара'),
        leading: IconButton(
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
          if (_product != null && !_product!.isDeleted)
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
  });

  final Product product;
  final List<Brand> brands;
  final List<Category> categories;
  final Supplier? supplier;

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
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
