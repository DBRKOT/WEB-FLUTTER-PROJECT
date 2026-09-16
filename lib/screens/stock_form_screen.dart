import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/reference_cache.dart';
import '../core/validators.dart';
import '../models/product.dart';
import '../models/stock.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class StockFormScreen extends StatefulWidget {
  const StockFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<StockFormScreen> createState() => _StockFormScreenState();
}

class _StockFormScreenState extends State<StockFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Stock? _existing;

  List<Product> _products = const [];
  String? _productId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _markDirty(String field) {
    _serverErrors.remove(field);
    setState(() => _dirty = true);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final notifier = context.read<StockListNotifier>();
    try {
      _products = await context.read<ReferenceCache>().products();
      if (widget.isEditing) {
        final existing = await notifier.findById(widget.id!);
        if (existing == null) throw StateError('Складская запись не найдена');
        _quantityController.text = '${existing.quantity}';
        _locationController.text = existing.location;
        _existing = existing;
        _productId = existing.productId;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = apiErrorMessage(e);
        _loading = false;
      });
    }
  }

  String? _validateQuantity(String? value) {
    final base = V.combine([
      V.required('Укажите остаток'),
      V.integer(min: 0, max: 100000),
    ])(value);
    return base ?? _serverErrors['quantity'];
  }

  String? _validateLocation(String? value) {
    final base = V.optional(V.length(max: 40))(value);
    return base ?? _serverErrors['location'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'product', 'quantity', 'location'};
    final unknown = <String>[];
    setState(() {
      _serverErrors.clear();
      errors.forEach((field, message) {
        if (known.contains(field)) {
          _serverErrors[field] = message;
        } else {
          unknown.add(message);
        }
      });
    });
    _formKey.currentState?.validate();
    if (_serverErrors.isEmpty) {
      final message = unknown.isEmpty ? fallback : unknown.first;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submit() async {
    final productId = _productId;
    if (productId == null || productId.isEmpty) {
      _applyServerErrors({'product': 'Выберите товар'}, 'Товар не выбран');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final notifier = context.read<StockListNotifier>();

      final taken = await notifier.isProductTaken(
        productId,
        excludeId: _existing?.id,
      );
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'product': 'У этого товара уже есть складская запись',
        }, 'Складская запись уже существует');
        return;
      }

      final stock = Stock(
        id: _existing?.id ?? '',
        productId: productId,
        quantity: int.parse(_quantityController.text.trim()),
        location: _locationController.text.trim(),
      );
      if (widget.isEditing) {
        await notifier.update(stock);
      } else {
        await notifier.create(stock);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      context.pop();
    } on ValidationException catch (e) {
      if (!mounted) return;
      _applyServerErrors(e.errors, e.message);
    } on ConflictException catch (e) {
      if (!mounted) return;
      _applyServerErrors(e.errors, e.message);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EntityFormScaffold(
      title: widget.isEditing
          ? 'Изменить складскую запись'
          : 'Новая складская запись',
      fallbackPath: '/stock',
      formKey: _formKey,
      isDirty: _dirty,
      loading: _loading,
      saving: _saving,
      loadError: _loadError,
      onRetry: _bootstrap,
      onSubmit: _submit,
      submitLabel: widget.isEditing ? 'Сохранить' : 'Создать',
      fields: [
        FormFieldSpec(
          label: 'Остаток, шт (от 0 до 100000)',
          controller: _quantityController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _markDirty('quantity'),
          validator: _validateQuantity,
        ),
        FormFieldSpec(
          label: 'Место хранения',
          controller: _locationController,
          onChanged: (_) => _markDirty('location'),
          validator: _validateLocation,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('stock-product'),
          isExpanded: true,
          initialValue: _productId,
          decoration: InputDecoration(
            labelText: 'Товар',
            border: const OutlineInputBorder(),
            errorText: _serverErrors['product'],
            helperText: 'У товара может быть только одна складская запись',
          ),
          items: [
            for (final product in _products)
              DropdownMenuItem(
                value: product.id,
                child: Text(
                  '${product.name} · ${product.sku}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Выберите товар' : null,
          onChanged: (value) {
            setState(() {
              _productId = value;
              _dirty = true;
              _serverErrors.remove('product');
            });
          },
        ),
      ],
    );
  }
}
