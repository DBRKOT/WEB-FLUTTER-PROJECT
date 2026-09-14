import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/brand.dart';
import '../state/brand_list_notifier.dart';
import '../widgets/entity_form_scaffold.dart';

class BrandFormScreen extends StatefulWidget {
  const BrandFormScreen({super.key, this.id});

  final int? id;
  bool get isEditing => id != null;

  @override
  State<BrandFormScreen> createState() => _BrandFormScreenState();
}

class _BrandFormScreenState extends State<BrandFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController();
  final _foundedYearController = TextEditingController();
  final _emailController = TextEditingController();

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
    _emailController.dispose();
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
      final existing = await context.read<BrandListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Бренд не найден');
      _nameController.text = existing.name;
      _countryController.text = existing.country;
      _foundedYearController.text = '${existing.foundedYear}';
      _emailController.text = existing.email;
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
      final brand = Brand(
        id: _existing?.id ?? 0,
        name: _nameController.text.trim(),
        country: _countryController.text.trim(),
        foundedYear: int.parse(_foundedYearController.text.trim()),
        email: _emailController.text.trim(),
        deletedAt: _existing?.deletedAt,
      );
      final notifier = context.read<BrandListNotifier>();
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
      final msg = e.errors.values.isEmpty ? e.message : e.errors.values.first;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      submitLabel: widget.isEditing ? 'Сохранить изменения' : 'Создать бренд',
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
          label: 'Год основания',
          controller: _foundedYearController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите год'),
            V.integer(min: 1600, max: 2100),
          ]),
        ),
        FormFieldSpec(
          label: 'Email для связи',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: _markDirty,
          validator: V.combine([V.required('Укажите email'), V.email()]),
        ),
      ],
    );
  }
}
