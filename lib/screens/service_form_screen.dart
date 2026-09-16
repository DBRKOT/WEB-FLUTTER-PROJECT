import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/service.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class ServiceFormScreen extends StatefulWidget {
  const ServiceFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _normHoursController = TextEditingController();


  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Service? _existing;

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
    _priceController.dispose();
    _normHoursController.dispose();
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
      final existing = await context.read<ServiceListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Услуга не найдена');
      _nameController.text = existing.name;
      _priceController.text = '${existing.price}';
      _normHoursController.text = _hoursToText(existing.normHours);
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

  static String _hoursToText(double value) {
    var text = value.toStringAsFixed(2);
    if (text.endsWith('0')) text = text.substring(0, text.length - 1);
    if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
    return text;
  }

  static double? _parseHours(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));

  String? _validateName(String? value) {
    final base = V.combine([
      V.required('Укажите название услуги'),
      V.length(min: 2, max: 120),
    ])(value);
    return base ?? _serverErrors['name'];
  }

  String? _validatePrice(String? value) {
    final base = V.combine([
      V.required('Укажите цену'),
      V.nonNegativeInt('Цена не может быть отрицательной'),
    ])(value);
    return base ?? _serverErrors['price'];
  }

  String? _validateNormHours(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Укажите норма-часы';
    final hours = _parseHours(text);
    if (hours == null) return 'Введите число, например 1,5';
    if (hours < 0.1) return 'Значение не меньше 0,1';
    if (hours > 100) return 'Значение не больше 100';
    return _serverErrors['normHours'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'name', 'price', 'normHours'};
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
      final notifier = context.read<ServiceListNotifier>();

      final taken = await notifier.isNameTaken(name, excludeId: _existing?.id);
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'name': 'Услуга с таким названием уже есть',
        }, 'Название занято');
        return;
      }

      final service = Service(
        id: _existing?.id ?? '',
        name: name,
        price: int.parse(_priceController.text.trim()),
        normHours: _parseHours(_normHoursController.text)!,
        archived: _existing?.archived ?? false,
      );
      if (widget.isEditing) {
        await notifier.update(service);
      } else {
        await notifier.create(service);
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
      title: widget.isEditing ? 'Изменить услугу' : 'Новая услуга',
      fallbackPath: '/services',
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
          label: 'Цена, ₽',
          controller: _priceController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _markDirty('price'),
          validator: _validatePrice,
        ),
        FormFieldSpec(
          label: 'Норма-часы (от 0,1 до 100)',
          controller: _normHoursController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          onChanged: (_) => _markDirty('normHours'),
          validator: _validateNormHours,
        ),
      ],
    );
  }
}
