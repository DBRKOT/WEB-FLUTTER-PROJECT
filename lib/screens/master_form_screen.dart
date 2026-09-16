import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/master.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class MasterFormScreen extends StatefulWidget {
  const MasterFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<MasterFormScreen> createState() => _MasterFormScreenState();
}

class _MasterFormScreenState extends State<MasterFormScreen> {
  static final DateTime _minHireDate = DateTime.utc(1950);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _specializationController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  DateTime? _hireDate;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Master? _existing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _specializationController.dispose();
    super.dispose();
  }

  void _markDirty(String field) {
    _serverErrors.remove(field);
    setState(() => _dirty = true);
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
      final existing = await context.read<MasterListNotifier>().findById(
        widget.id!,
      );
      if (existing == null) throw StateError('Мастер не найден');
      _fullNameController.text = existing.fullName;
      _specializationController.text = existing.specialization;
      if (!mounted) return;
      setState(() {
        _existing = existing;
        _hireDate = existing.hireDate;
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  String? _validateFullName(String? value) {
    final base = V.combine([
      V.required('Укажите имя мастера'),
      V.length(min: 2, max: 120),
    ])(value);
    return base ?? _serverErrors['fullName'];
  }

  String? _validateSpecialization(String? value) {
    final base = V.length(max: 80)(value);
    return base ?? _serverErrors['specialization'];
  }

  String? _validateHireDate() {
    final date = _hireDate;
    if (date == null) return _serverErrors['hireDate'];
    if (date.isBefore(_minHireDate)) return 'Дата не раньше 1950 года';
    if (date.isAfter(DateTime.now().toUtc())) {
      return 'Дата не может быть в будущем';
    }
    return _serverErrors['hireDate'];
  }

  Future<void> _pickHireDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Дата приёма на работу',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
    );
    if (picked == null) return;
    setState(() {
      _hireDate = DateTime.utc(picked.year, picked.month, picked.day);
      _dirty = true;
      _serverErrors.remove('hireDate');
    });
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'fullName', 'specialization', 'hireDate'};
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
    if (_validateHireDate() != null) {
      setState(() {});
      return;
    }

    setState(() => _saving = true);
    try {
      final master = Master(
        id: _existing?.id ?? '',
        fullName: _fullNameController.text.trim(),
        specialization: _specializationController.text.trim(),
        hireDate: _hireDate,
        archived: _existing?.archived ?? false,
      );
      final notifier = context.read<MasterListNotifier>();
      if (widget.isEditing) {
        await notifier.update(master);
      } else {
        await notifier.create(master);
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
    final dateError = _validateHireDate();

    return EntityFormScaffold(
      title: widget.isEditing ? 'Изменить мастера' : 'Новый мастер',
      fallbackPath: '/masters',
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
          label: 'Имя',
          controller: _fullNameController,
          onChanged: (_) => _markDirty('fullName'),
          validator: _validateFullName,
        ),
        FormFieldSpec(
          label: 'Специализация',
          controller: _specializationController,
          onChanged: (_) => _markDirty('specialization'),
          validator: _validateSpecialization,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Дата приёма на работу',
            border: const OutlineInputBorder(),
            errorText: dateError,
            helperText: 'Необязательно, не раньше 1950 года и не в будущем',
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _hireDate == null ? 'Не указана' : _formatDate(_hireDate!),
                ),
              ),
              IconButton(
                tooltip: 'Выбрать дату',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: _saving ? null : _pickHireDate,
              ),
              if (_hireDate != null)
                IconButton(
                  tooltip: 'Очистить дату',
                  icon: const Icon(Icons.clear),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                          _hireDate = null;
                          _dirty = true;
                          _serverErrors.remove('hireDate');
                        }),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
