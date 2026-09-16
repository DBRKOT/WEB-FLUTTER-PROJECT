import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/form_api_errors.dart';
import '../core/permissions.dart';
import '../models/brand.dart';
import '../models/product_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class BrandDetailScreen extends StatefulWidget {
  const BrandDetailScreen({super.key, required this.brandId});

  final String brandId;

  @override
  State<BrandDetailScreen> createState() => _BrandDetailScreenState();
}

class _BrandDetailScreenState extends State<BrandDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Brand? _brand;

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
      final brand = await context.read<BrandListNotifier>().findById(
        widget.brandId,
      );
      if (!mounted) return;
      setState(() {
        _brand = brand;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить бренд: ${apiErrorMessage(e)}';
        _status = LoadStatus.error;
      });
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/brands');
    }
  }

  Future<void> _confirmDelete(Brand brand) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление бренда'),
        content: Text('Удалить бренд «${brand.name}» навсегда?'),
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
    if (ok != true || !mounted) return;
    try {
      await context.read<BrandListNotifier>().softDelete(brand.id);
      if (!mounted) return;
      context.go('/brands');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить: ${apiErrorMessage(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final brand = _brand;

    return Scaffold(
      appBar: AppBar(
        title: Text(brand?.name ?? 'Карточка бренда'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          if (brand != null && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/brands/${brand.id}/edit'),
            ),
          if (brand != null && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(brand),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: brand == null,
        emptyMessage: 'Бренд не найден',
        onRetry: _load,
        child: brand == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: const Text('Название'),
                              subtitle: Text(brand.name),
                            ),
                            ListTile(
                              title: const Text('Страна'),
                              subtitle: Text(
                                brand.country.isEmpty ? '—' : brand.country,
                              ),
                            ),
                            ListTile(
                              title: const Text('Год основания'),
                              subtitle: Text(
                                brand.foundedYear == 0
                                    ? '—'
                                    : '${brand.foundedYear}',
                              ),
                            ),
                            ListTile(
                              title: const Text('Описание'),
                              subtitle: Text(
                                brand.description.isEmpty
                                    ? '—'
                                    : brand.description,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(
                          ProductQuery(brandId: brand.id).toLocation(),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Товары бренда'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
