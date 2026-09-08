import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/validators.dart';
import '../models/category.dart';
import '../state/category_list_notifier.dart';
import '../widgets/entity_form_scaffold.dart';

class CategoryFormScreen extends StatefulWidget {
  const CategoryFormScreen({super.key, this.id});

  final int? id;
  bool get isEditing => id != null;

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

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
          await context.read<CategoryListNotifier>().findById(widget.id!);
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
        _loadError = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final category = Category(
        id: _existing?.id ?? 0,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        deletedAt: _existing?.deletedAt,
      );
      final notifier = context.read<CategoryListNotifier>();
      if (widget.isEditing) {
        await notifier.update(category);
      } else {
        await notifier.create(category);
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
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите название'),
            V.length(min: 2, max: 80),
          ]),
        ),
        FormFieldSpec(
          label: 'Описание',
          controller: _descriptionController,
          maxLines: 3,
          onChanged: _markDirty,
          validator: V.length(max: 500),
        ),
      ],
    );
  }
}
