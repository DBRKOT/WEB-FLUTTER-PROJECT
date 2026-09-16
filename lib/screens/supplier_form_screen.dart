import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/supplier.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _contractController = TextEditingController();

  final Map<String, String> _serverErrors = {};

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
    _cityController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _contractController.dispose();
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
    if (!widget.isEditing) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final existing = await context.read<SupplierListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Поставщик не найден');
      _nameController.text = existing.name;
      _cityController.text = existing.city;
      _phoneController.text = existing.phone;
      _emailController.text = existing.email;
      _contractController.text = existing.contractNumber;
      if (!mounted) return;
      setState(() {
        _existing = existing;
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
      V.required('Укажите название поставщика'),
      V.length(min: 2, max: 120),
    ])(value);
    return base ?? _serverErrors['name'];
  }

  String? _validateCity(String? value) {
    final base = V.length(max: 60)(value);
    return base ?? _serverErrors['city'];
  }

  String? _validatePhone(String? value) {
    final base = V.optional(V.phone(max: 20))(value);
    return base ?? _serverErrors['phone'];
  }

  String? _validateEmail(String? value) {
    final base = V.optional(V.email())(value);
    return base ?? _serverErrors['email'];
  }

  String? _validateContract(String? value) {
    final base = V.length(max: 40)(value);
    return base ?? _serverErrors['contractNumber'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'name', 'city', 'phone', 'email', 'contractNumber'};
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
      final notifier = context.read<SupplierListNotifier>();
      final supplier = Supplier(
        id: _existing?.id ?? '',
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        contractNumber: _contractController.text.trim(),
      );
      if (widget.isEditing) {
        await notifier.update(supplier);
      } else {
        await notifier.create(supplier);
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
          onChanged: (_) => _markDirty('name'),
          validator: _validateName,
        ),
        FormFieldSpec(
          label: 'Город',
          controller: _cityController,
          onChanged: (_) => _markDirty('city'),
          validator: _validateCity,
        ),
        FormFieldSpec(
          label: 'Телефон',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: (_) => _markDirty('phone'),
          validator: _validatePhone,
        ),
        FormFieldSpec(
          label: 'Почта',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _markDirty('email'),
          validator: _validateEmail,
        ),
        FormFieldSpec(
          label: 'Номер договора',
          controller: _contractController,
          onChanged: (_) => _markDirty('contractNumber'),
          validator: _validateContract,
        ),
      ],
    );
  }
}
