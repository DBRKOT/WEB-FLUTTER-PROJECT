import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../models/brand.dart';
import '../models/product.dart';
import '../state/brand_list_notifier.dart';
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
  Brand? _brand;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
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
      final product = await productNotifier.findById(widget.productId);
      if (product == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = LoadStatus.success;
          _product = null;
        });
        return;
      }
      final brand = await brandNotifier.findById(product.brandId);
      if (!mounted) {
        return;
      }
      setState(() {
        _product = product;
        _brand = brand;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
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
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _product == null,
        emptyMessage: 'Товар не найден',
        onRetry: _load,
        child: _product == null
            ? const SizedBox.shrink()
            : _ProductCard(product: _product!, brand: _brand),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.brand});

  final Product product;
  final Brand? brand;

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
                    _row('Категория', product.category),
                    _row('Бренд', brand?.name ?? '—'),
                    _row('Год выпуска', '${product.year}'),
                    _row('Цена', formatPrice(product.price)),
                    _row('На складе', '${product.stockAvailable} из ${product.stockTotal}'),
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
