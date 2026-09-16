import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/form_api_errors.dart';
import '../core/permissions.dart';
import '../models/category.dart';
import '../models/product_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  Category? _category;

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
      final category = await context.read<CategoryListNotifier>().findById(
        widget.categoryId,
      );
      if (!mounted) return;
      setState(() {
        _category = category;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить категорию: ${apiErrorMessage(e)}';
        _status = LoadStatus.error;
      });
    }
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/categories');
    }
  }

  Future<void> _confirmDelete(Category category) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление категории'),
        content: Text('Удалить категорию «${category.name}» навсегда?'),
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
      await context.read<CategoryListNotifier>().softDelete(category.id);
      if (!mounted) return;
      context.go('/categories');
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
    final category = _category;

    return Scaffold(
      appBar: AppBar(
        title: Text(category?.name ?? 'Карточка категории'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBack,
        ),
        actions: [
          if (category != null && auth.canEditCatalog)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/categories/${category.id}/edit'),
            ),
          if (category != null && auth.canHardDelete)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(category),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: category == null,
        emptyMessage: 'Категория не найдена',
        onRetry: _load,
        child: category == null
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
                              subtitle: Text(category.name),
                            ),
                            ListTile(
                              title: const Text('Описание'),
                              subtitle: Text(
                                category.description.isEmpty
                                    ? '—'
                                    : category.description,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: () => context.go(
                          ProductQuery(categoryId: category.id).toLocation(),
                        ),
                        icon: const Icon(Icons.inventory_2_outlined),
                        label: const Text('Товары категории'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
