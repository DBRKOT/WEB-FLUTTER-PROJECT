import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/supplier.dart';
import '../state/supplier_list_notifier.dart';
import '../widgets/entity_form_scaffold.dart';

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.id});

  final int? id;
  bool get isEditing => id != null;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Supplier? _existing;

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
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _markDirty([String? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _bootstrap() async {
    if (!widget.isEditing) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final existing =
          await context.read<SupplierListNotifier>().findById(widget.id!);
      if (existing == null) throw StateError('Поставщик не найден');
      _nameController.text = existing.name;
      _countryController.text = existing.country;
      _phoneController.text = existing.phone;
      if (!mounted) return;
      setState(() {
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
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final supplier = Supplier(
        id: _existing?.id ?? 0,
        name: _nameController.text.trim(),
        country: _countryController.text.trim(),
        phone: _phoneController.text.trim(),
        deletedAt: _existing?.deletedAt,
      );
      final notifier = context.read<SupplierListNotifier>();
      if (widget.isEditing) {
        await notifier.update(supplier);
      } else {
        await notifier.create(supplier);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      context.pop();
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
      title: widget.isEditing ? 'Изменить поставщика' : 'Новый поставщик',
      fallbackPath: '/suppliers',
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
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите название'),
            V.length(min: 2, max: 80),
          ]),
        ),
        FormFieldSpec(
          label: 'Страна',
          controller: _countryController,
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите страну'),
            V.length(min: 2, max: 60),
          ]),
        ),
        FormFieldSpec(
          label: 'Телефон',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: _markDirty,
          validator: V.length(max: 30),
        ),
      ],
    );
  }
}
