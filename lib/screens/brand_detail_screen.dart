import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/brand.dart';
import '../state/brand_list_notifier.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class BrandDetailScreen extends StatefulWidget {
  const BrandDetailScreen({super.key, required this.brandId});

  final int brandId;

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
      final brand = await context.read<BrandListNotifier>().findById(
            widget.brandId,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _brand = brand;
        _status = LoadStatus.success;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Не удалось загрузить бренд: $e';
        _status = LoadStatus.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_brand?.name ?? 'Карточка бренда'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/brands');
            }
          },
        ),
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: _brand == null,
        emptyMessage: 'Бренд не найден',
        onRetry: _load,
        child: _brand == null
            ? const SizedBox.shrink()
            : Center(
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
                              ListTile(
                                title: const Text('Название'),
                                subtitle: Text(_brand!.name),
                              ),
                              ListTile(
                                title: const Text('Страна'),
                                subtitle: Text(_brand!.country),
                              ),
                              ListTile(
                                title: const Text('Год основания'),
                                subtitle: Text('${_brand!.foundedYear}'),
                              ),
                            ],
                          ),
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
