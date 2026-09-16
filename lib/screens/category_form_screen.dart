import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/category.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Category? _existing;

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
      final existing = await context.read<CategoryListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Категория не найдена');
      _nameController.text = existing.name;
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
      V.required('Укажите название категории'),
      V.length(min: 2, max: 80),
    ])(value);
    return base ?? _serverErrors['name'];
  }

  String? _validateDescription(String? value) {
    final base = V.optional(V.length(max: 500))(value);
    return base ?? _serverErrors['description'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'name', 'description'};
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
      final notifier = context.read<CategoryListNotifier>();

      final taken = await notifier.isNameTaken(name, excludeId: _existing?.id);
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'name': 'Категория с таким названием уже есть',
        }, 'Название занято');
        return;
      }

      final category = Category(
        id: _existing?.id ?? '',
        name: name,
        description: _descriptionController.text.trim(),
      );
      if (widget.isEditing) {
        await notifier.update(category);
      } else {
        await notifier.create(category);
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
      title: widget.isEditing ? 'Изменить категорию' : 'Новая категория',
      fallbackPath: '/categories',
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
