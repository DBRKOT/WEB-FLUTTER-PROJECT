import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/reference_cache.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _warrantyController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  List<Brand> _brands = const [];
  List<Category> _categories = const [];
  List<Supplier> _suppliers = const [];

  String? _brandId;
  String? _categoryId;
  String? _supplierId;

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Product? _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _warrantyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _markDirty(String field) {
    _serverErrors.remove(field);
    if (!_dirty) {
      setState(() => _dirty = true);
    } else {
      setState(() {});
    }
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final cache = context.read<ReferenceCache>();
      final notifier = context.read<ProductListNotifier>();
      final brands = await cache.brands();
      final categories = await cache.categories();
      final suppliers = await cache.suppliers();

      Product? existing;
      if (widget.isEditing) {
        existing = await notifier.findById(widget.id!);
        if (existing == null) throw StateError('Товар не найден');
        _nameController.text = existing.name;
        _skuController.text = existing.sku;
        _priceController.text = '${existing.price}';
        _warrantyController.text = '${existing.warrantyMonths}';
        _descriptionController.text = existing.description;
      }
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _categories = categories;
        _suppliers = suppliers;
        _existing = existing;
        _brandId = existing?.brandId.isNotEmpty == true
            ? existing!.brandId
            : null;
        _categoryId = existing?.categoryId.isNotEmpty == true
            ? existing!.categoryId
            : null;
        _supplierId = existing?.supplierId.isNotEmpty == true
            ? existing!.supplierId
            : null;
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

  String? _validateName(String? value) {
    final base = V.combine([
      V.required('Укажите название товара'),
      V.length(min: 2, max: 160),
    ])(value);
    return base ?? _serverErrors['title'];
  }

  String? _validateSku(String? value) {
    final base = V.combine([
      V.required('Укажите артикул'),
      V.length(min: 3, max: 40),
    ])(value);
    return base ?? _serverErrors['sku'];
  }

  String? _validatePrice(String? value) {
    final base = V.combine([
      V.required('Укажите цену'),
      V.nonNegativeInt('Цена не может быть отрицательной'),
    ])(value);
    return base ?? _serverErrors['price'];
  }

  String? _validateWarranty(String? value) {
    final base = V.combine([
      V.required('Укажите срок гарантии в месяцах'),
      V.integer(min: 0, max: 120),
    ])(value);
    return base ?? _serverErrors['warrantyMonths'];
  }

  String? _validateDescription(String? value) {
    final base = V.length(max: 2000)(value);
    return base ?? _serverErrors['description'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {
      'title',
      'sku',
      'price',
      'warrantyMonths',
      'brand',
      'category',
      'supplier',
      'description',
    };
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final sku = _skuController.text.trim();
      final notifier = context.read<ProductListNotifier>();

      final taken = await notifier.isSkuTaken(sku, excludeId: _existing?.id);
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'sku': 'Товар с таким артикулом уже есть',
        }, 'Артикул занят');
        return;
      }

      final product = Product(
        id: _existing?.id ?? '',
        name: _nameController.text.trim(),
        sku: sku,
        price: int.parse(_priceController.text.trim()),
        warrantyMonths: int.parse(_warrantyController.text.trim()),
        brandId: _brandId ?? '',
        categoryId: _categoryId ?? '',
        supplierId: _supplierId ?? '',
        description: _descriptionController.text.trim(),
        archived: _existing?.archived ?? false,
      );
      if (widget.isEditing) {
        await notifier.update(product);
      } else {
        await notifier.create(product);
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
      title: widget.isEditing ? 'Изменить товар' : 'Новый товар',
      fallbackPath: '/products',
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
          label: 'Название',
          controller: _nameController,
          onChanged: (_) => _markDirty('title'),
          validator: _validateName,
        ),
        FormFieldSpec(
          label: 'Артикул',
          controller: _skuController,
          onChanged: (_) => _markDirty('sku'),
          validator: _validateSku,
        ),
        FormFieldSpec(
          label: 'Цена, ₽',
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _markDirty('price'),
          validator: _validatePrice,
        ),
        FormFieldSpec(
          label: 'Гарантия, месяцев (от 0 до 120)',
          controller: _warrantyController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _markDirty('warrantyMonths'),
          validator: _validateWarranty,
        ),
        FormFieldSpec(
          label: 'Описание',
          controller: _descriptionController,
          keyboardType: TextInputType.multiline,
          maxLines: 5,
          onChanged: (_) => _markDirty('description'),
          validator: _validateDescription,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('product-form-brand'),
          isExpanded: true,
          initialValue: _brandId,
          decoration: const InputDecoration(
            labelText: 'Бренд',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final b in _brands)
              DropdownMenuItem(
                value: b.id,
                child: Text(b.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          validator: (value) => (value == null || value.isEmpty)
              ? 'Выберите бренд'
              : _serverErrors['brand'],
          onChanged: (value) {
            _brandId = value;
            _markDirty('brand');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('product-form-category'),
          isExpanded: true,
          initialValue: _categoryId,
          decoration: const InputDecoration(
            labelText: 'Категория',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in _categories)
              DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          validator: (value) => (value == null || value.isEmpty)
              ? 'Выберите категорию'
              : _serverErrors['category'],
          onChanged: (value) {
            _categoryId = value;
            _markDirty('category');
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const Key('product-form-supplier'),
          isExpanded: true,
          initialValue: _supplierId,
          decoration: const InputDecoration(
            labelText: 'Поставщик',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('не указан')),
            for (final s in _suppliers)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          validator: (_) => _serverErrors['supplier'],
          onChanged: (value) {
            _supplierId = value;
            _markDirty('supplier');
          },
        ),
      ],
    );
  }
}
