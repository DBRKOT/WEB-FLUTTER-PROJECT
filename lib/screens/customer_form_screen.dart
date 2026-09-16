import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/app_user.dart';
import '../models/customer.dart';
import '../repositories/api_user_repository.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Customer? _existing;

  List<AppUser> _users = const [];
  String? _userId;
  DateTime? _birthDate;

  bool _usersRestricted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _markDirty(String field) {
    _serverErrors.remove(field);
    setState(() => _dirty = true);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final notifier = context.read<CustomerListNotifier>();
    try {
      await _loadUsers();
      if (widget.isEditing) {
        final existing = await notifier.findById(widget.id!);
        if (existing == null) throw StateError('Профиль клиента не найден');
        _phoneController.text = existing.phone;
        _addressController.text = existing.address;
        _existing = existing;
        _userId = existing.userId;
        _birthDate = existing.birthDate;
      }
      if (!mounted) return;
      setState(() {
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

  Future<void> _loadUsers() async {
    try {
      final page = await context.read<ApiUserRepository>().find();
      _users = page.items;
      _usersRestricted = false;
    } on ForbiddenException {
      _users = const [];
      _usersRestricted = true;
    }
  }

  String? _validatePhone(String? value) {
    final base = V.optional(V.phone())(value);
    return base ?? _serverErrors['phone'];
  }

  String? _validateAddress(String? value) {
    final base = V.optional(V.length(max: 200))(value);
    return base ?? _serverErrors['address'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'user', 'phone', 'address', 'birthDate'};
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Дата рождения',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _dirty = true;
      _serverErrors.remove('birthDate');
    });
  }

  Future<void> _submit() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _applyServerErrors({
        'user': 'Выберите учётную запись клиента',
      }, 'Учётная запись не выбрана');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final notifier = context.read<CustomerListNotifier>();

      final taken = await notifier.isUserTaken(
        userId,
        excludeId: _existing?.id,
      );
      if (taken) {
        if (!mounted) return;
        _applyServerErrors({
          'user': 'У этой учётной записи уже есть профиль',
        }, 'Профиль уже существует');
        return;
      }

      final customer = Customer(
        id: _existing?.id ?? '',
        userId: userId,
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        birthDate: _birthDate,
      );
      if (widget.isEditing) {
        await notifier.update(customer);
      } else {
        await notifier.create(customer);
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

  Widget _userField() {
    if (widget.isEditing) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Учётная запись',
          border: OutlineInputBorder(),
          helperText: 'Владельца профиля изменить нельзя',
        ),
        child: Text(_existing?.displayName ?? ''),
      );
    }
    if (_usersRestricted) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: 'Учётная запись',
          border: const OutlineInputBorder(),
          errorText: _serverErrors['user'],
        ),
        child: const Text(
          'Список учётных записей доступен только администратору. '
          'Создать профиль для другого пользователя может он.',
        ),
      );
    }
    return DropdownButtonFormField<String>(
      key: const Key('customer-user'),
      isExpanded: true,
      initialValue: _userId,
      decoration: InputDecoration(
        labelText: 'Учётная запись',
        border: const OutlineInputBorder(),
        errorText: _serverErrors['user'],
      ),
      items: [
        for (final user in _users)
          DropdownMenuItem(
            value: user.id,
            child: Text(
              '${user.displayName} · ${user.role.label}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Выберите учётную запись' : null,
      onChanged: (value) {
        setState(() {
          _userId = value;
          _dirty = true;
          _serverErrors.remove('user');
        });
      },
    );
  }

  Widget _birthDateField() {
    final value = _birthDate;
    final text = value == null
        ? 'Не указана'
        : '${value.day.toString().padLeft(2, '0')}.'
              '${value.month.toString().padLeft(2, '0')}.${value.year}';
    return InputDecorator(
      decoration: InputDecoration(
        labelText: 'Дата рождения',
        border: const OutlineInputBorder(),
        errorText: _serverErrors['birthDate'],
      ),
      child: Row(
        children: [
          Expanded(child: Text(text)),
          TextButton(onPressed: _pickBirthDate, child: const Text('Выбрать')),
          if (value != null)
            TextButton(
              onPressed: () => setState(() {
                _birthDate = null;
                _dirty = true;
              }),
              child: const Text('Очистить'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EntityFormScaffold(
      title: widget.isEditing ? 'Изменить профиль' : 'Новый профиль клиента',
      fallbackPath: '/customers',
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
          label: 'Телефон',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+()\- ]')),
          ],
          onChanged: (_) => _markDirty('phone'),
          validator: _validatePhone,
        ),
        FormFieldSpec(
          label: 'Адрес',
          controller: _addressController,
          maxLines: 2,
          onChanged: (_) => _markDirty('address'),
          validator: _validateAddress,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        _userField(),
        const SizedBox(height: 16),
        _birthDateField(),
      ],
    );
  }
}
