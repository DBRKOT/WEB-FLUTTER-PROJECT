import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/field_validation_exception.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../repositories/seed_data.dart';
import '../state/brand_list_notifier.dart';
import '../state/category_list_notifier.dart';
import '../state/product_list_notifier.dart';
import '../state/supplier_list_notifier.dart';
import '../widgets/entity_form_scaffold.dart';
import '../widgets/id_chip_form_field.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.id});

  final int? id;
  bool get isEditing => id != null;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _yearController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockTotalController = TextEditingController();
  final _stockAvailableController = TextEditingController();

  int? _supplierId;
  List<int> _brandIds = [];
  List<int> _categoryIds = [];
  Map<String, String> _fieldErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Product? _existing;
  List<Brand> _brands = const [];
  List<Category> _categories = const [];
  List<Supplier> _suppliers = const [];

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
    _yearController.dispose();
    _priceController.dispose();
    _stockTotalController.dispose();
    _stockAvailableController.dispose();
    super.dispose();
  }

  void _markDirty([String? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  List<Brand> get _availableBrands {
    if (_supplierId == null) return _brands;
    final allowed = supplierBrandIds[_supplierId] ?? const <int>[];
    return _brands.where((b) => allowed.contains(b.id)).toList();
  }

  List<Category> get _availableCategories {
    if (_supplierId == null) return _categories;
    final allowed = supplierCategoryIds[_supplierId] ?? const <int>[];
    return _categories.where((c) => allowed.contains(c.id)).toList();
  }

  void _onSupplierChanged(int? value) {
    final allowedBrands = supplierBrandIds[value] ?? const <int>[];
    final allowedCategories = supplierCategoryIds[value] ?? const <int>[];
    setState(() {
      _supplierId = value;
      _brandIds = _brandIds.where(allowedBrands.contains).toList();
      _categoryIds = _categoryIds.where(allowedCategories.contains).toList();
      _dirty = true;
    });
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final brandNotifier = context.read<BrandListNotifier>();
      final categoryNotifier = context.read<CategoryListNotifier>();
      final supplierNotifier = context.read<SupplierListNotifier>();
      final productNotifier = context.read<ProductListNotifier>();
      final brands = await brandNotifier.findAll();
      final categories = await categoryNotifier.findAll();
      final suppliers = await supplierNotifier.findAll();
      Product? existing;
      if (widget.isEditing) {
        existing = await productNotifier.findById(widget.id!);
        if (existing == null) throw StateError('Товар не найден');
        _nameController.text = existing.name;
        _skuController.text = existing.sku;
        _yearController.text = '${existing.year}';
        _priceController.text = '${existing.price}';
        _stockTotalController.text = '${existing.stockTotal}';
        _stockAvailableController.text = '${existing.stockAvailable}';
        _supplierId = existing.supplierId;
        _brandIds = [...existing.brandIds];
        _categoryIds = [...existing.categoryIds];
      }
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _categories = categories;
        _suppliers = suppliers;
        _existing = existing;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    try {
      final product = Product(
        id: _existing?.id ?? 0,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim(),
        year: int.parse(_yearController.text.trim()),
        price: int.parse(_priceController.text.trim()),
        supplierId: _supplierId!,
        brandIds: [..._brandIds],
        categoryIds: [..._categoryIds],
        stockTotal: int.parse(_stockTotalController.text.trim()),
        stockAvailable: int.parse(_stockAvailableController.text.trim()),
        deletedAt: _existing?.deletedAt,
      );
      final notifier = context.read<ProductListNotifier>();
      if (widget.isEditing) {
        await notifier.update(product);
      } else {
        await notifier.create(product);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      context.pop();
    } on FieldValidationException catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e.errors);
      _formKey.currentState!.validate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
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
      submitLabel:
          widget.isEditing ? 'Сохранить изменения' : 'Создать товар',
      fields: [
        FormFieldSpec(
          label: 'Название',
          controller: _nameController,
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите название'),
            V.length(min: 2, max: 120),
          ]),
        ),
        FormFieldSpec(
          label: 'Артикул (SKU)',
          controller: _skuController,
          onChanged: (_) {
            _markDirty();
            if (_fieldErrors.containsKey('sku')) {
              setState(() => _fieldErrors.remove('sku'));
            }
          },
          validator: (value) {
            final local = V.combine([
              V.required('Укажите артикул'),
              V.length(min: 3, max: 40),
            ])(value);
            if (local != null) return local;
            return _fieldErrors['sku'];
          },
        ),
        FormFieldSpec(
          label: 'Год выпуска',
          controller: _yearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите год'),
            V.integer(min: 1970, max: 2100),
          ]),
        ),
        FormFieldSpec(
          label: 'Цена, ₽',
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите цену'),
            V.positiveInt('Цена должна быть больше 0'),
          ]),
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: _supplierId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Поставщик',
            border: OutlineInputBorder(),
            helperText: 'После выбора сузятся бренды и категории',
          ),
          items: [
            for (final s in _suppliers)
              DropdownMenuItem(
                value: s.id,
                child: Text(s.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: _onSupplierChanged,
          validator: (value) => value == null ? 'Выберите поставщика' : null,
        ),
        const SizedBox(height: 16),
        IdChipFormField(
          key: ValueKey('brands-$_supplierId'),
          label: _supplierId == null
              ? 'Бренды (сначала выберите поставщика)'
              : 'Бренды (доступны для выбранного поставщика)',
          emptyError: 'Выберите хотя бы один бренд',
          initialValue: _brandIds,
          options: [
            for (final b in _availableBrands) (id: b.id, name: b.name),
          ],
          onSaved: (value) => _brandIds = value ?? [],
          onChanged: (value) {
            _brandIds = value;
            _markDirty();
          },
        ),
        const SizedBox(height: 16),
        IdChipFormField(
          key: ValueKey('categories-$_supplierId'),
          label: _supplierId == null
              ? 'Категории (сначала выберите поставщика)'
              : 'Категории (доступны для выбранного поставщика)',
          emptyError: 'Выберите хотя бы одну категорию',
          initialValue: _categoryIds,
          options: [
            for (final c in _availableCategories) (id: c.id, name: c.name),
          ],
          onSaved: (value) => _categoryIds = value ?? [],
          onChanged: (value) {
            _categoryIds = value;
            _markDirty();
          },
        ),
        const SizedBox(height: 16),
        FormFieldSpec(
          label: 'Всего на складе',
          controller: _stockTotalController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) {
            _markDirty();
            setState(() {});
          },
          validator: V.combine([
            V.required('Укажите количество'),
            V.positiveInt(),
          ]),
        ).buildField(),
        const SizedBox(height: 16),
        TextFormField(
          controller: _stockAvailableController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Доступно',
            border: OutlineInputBorder(),
          ),
          onChanged: _markDirty,
          validator: (value) {
            final base = V.combine([
              V.required('Укажите количество'),
              V.nonNegativeInt(),
            ])(value);
            if (base != null) return base;
            final available = int.parse(value!.trim());
            final total = int.tryParse(_stockTotalController.text.trim());
            if (total != null && available > total) {
              return 'Не больше общего количества';
            }
            return null;
          },
        ),
      ],
    );
  }
}

extension on FormFieldSpec {
  Widget buildField() {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}
