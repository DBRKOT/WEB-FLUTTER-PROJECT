import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class BrandFormScreen extends StatefulWidget {
  const BrandFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _foundedYearController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Brand? _existing;

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
    _foundedYearController.dispose();
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
    if (!widget.isEditing) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final existing = await context.read<BrandListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Бренд не найден');
      _nameController.text = existing.name;
      _countryController.text = existing.country;
      _foundedYearController.text = existing.foundedYear == 0
          ? ''
          : '${existing.foundedYear}';
      _descriptionController.text = existing.description;
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
      V.required('Укажите название бренда'),
      V.length(min: 2, max: 100),
    ])(value);
    return base ?? _serverErrors['name'];
  }

  String? _validateCountry(String? value) {
    final base = V.optional(V.length(max: 60))(value);
    return base ?? _serverErrors['country'];
  }

  String? _validateFoundedYear(String? value) {
    final base = V.optional(V.integer(min: 1800, max: 2100))(value);
    return base ?? _serverErrors['foundedYear'];
  }

  String? _validateDescription(String? value) {
    final base = V.optional(V.length(max: 1000))(value);
    return base ?? _serverErrors['description'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'name', 'country', 'foundedYear', 'description'};
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
      final name = _nameController.text.trim();
      final notifier = context.read<BrandListNotifier>();

      final taken = await notifier.isNameTaken(name, excludeId: _existing?.id);
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'name': 'Бренд с таким названием уже есть',
        }, 'Название занято');
        return;
      }

      final brand = Brand(
        id: _existing?.id ?? '',
        name: name,
        country: _countryController.text.trim(),
        foundedYear: int.tryParse(_foundedYearController.text.trim()) ?? 0,
        description: _descriptionController.text.trim(),
      );
      if (widget.isEditing) {
        await notifier.update(brand);
      } else {
        await notifier.create(brand);
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
      title: widget.isEditing ? 'Изменить бренд' : 'Новый бренд',
      fallbackPath: '/brands',
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
          label: 'Страна',
          controller: _countryController,
          onChanged: (_) => _markDirty('country'),
          validator: _validateCountry,
        ),
        FormFieldSpec(
          label: 'Год основания (от 1800 до 2100)',
          controller: _foundedYearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _markDirty('foundedYear'),
          validator: _validateFoundedYear,
        ),
        FormFieldSpec(
          label: 'Описание',
          controller: _descriptionController,
          keyboardType: TextInputType.multiline,
          maxLines: 4,
          onChanged: (_) => _markDirty('description'),
          validator: _validateDescription,
        ),
      ],
    );
  }
}
