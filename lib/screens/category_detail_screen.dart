import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../state/category_list_notifier.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({super.key, required this.categoryId});

  final int categoryId;

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
        _error = 'Не удалось загрузить категорию: $e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_category?.name ?? 'Категория'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/categories');
            }
          },
        ),
        actions: [
          if (_category != null && !_category!.isDeleted)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push('/categories/${_category!.id}/edit'),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _category == null,
        emptyMessage: 'Категория не найдена',
        onRetry: _load,
        child: _category == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ListTile(
                        dense: true,
                        title: const Text('Название'),
                        subtitle: Text(_category!.name),
                      ),
                      ListTile(
                        dense: true,
                        title: const Text('Описание'),
                        subtitle: Text(
                          _category!.description.isEmpty
                              ? '—'
                              : _category!.description,
                        ),
                      ),
                      if (_category!.isDeleted)
                        ListTile(
                          dense: true,
                          title: const Text('Статус'),
                          subtitle: const Text('Удалена'),
                          leading: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
