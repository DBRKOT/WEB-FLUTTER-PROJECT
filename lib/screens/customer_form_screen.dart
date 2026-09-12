import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/field_validation_exception.dart';
import '../core/form_api_errors.dart';
import '../core/validators.dart';
import '../models/customer.dart';
import '../state/customer_list_notifier.dart';
import '../widgets/entity_form_scaffold.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.id});

  final int? id;
  bool get isEditing => id != null;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  static const _cardLevels = ['Standard', 'Gold', 'Platinum'];

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _issuedYearController = TextEditingController();

  String _cardLevel = 'Standard';
  Map<String, String> _fieldErrors = {};
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Customer? _existing;

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
    _emailController.dispose();
    _phoneController.dispose();
    _cardNumberController.dispose();
    _issuedYearController.dispose();
    super.dispose();
  }

  void _markDirty([String? _]) {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _bootstrap() async {
    if (!widget.isEditing) {
      _issuedYearController.text = '${DateTime.now().year}';
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final existing =
          await context.read<CustomerListNotifier>().findById(widget.id!);
      if (existing == null) throw StateError('Клиент не найден');
      _fullNameController.text = existing.fullName;
      _emailController.text = existing.email;
      _phoneController.text = existing.phone;
      _cardNumberController.text = existing.card.number;
      _issuedYearController.text = '${existing.card.issuedYear}';
      _cardLevel = _cardLevels.contains(existing.card.level)
          ? existing.card.level
          : 'Standard';
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
    setState(() => _fieldErrors = {});
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final customer = Customer(
        id: _existing?.id ?? 0,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        card: MembershipCard(
          number: _cardNumberController.text.trim(),
          level: _cardLevel,
          issuedYear: int.parse(_issuedYearController.text.trim()),
        ),
        deletedAt: _existing?.deletedAt,
      );
      final notifier = context.read<CustomerListNotifier>();
      if (widget.isEditing) {
        await notifier.update(customer);
      } else {
        await notifier.create(customer);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      context.pop();
    } on FieldValidationException catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = e.errors);
      _formKey.currentState!.validate();
    } on ValidationException catch (e) {
      if (!mounted) return;
      setState(() => _fieldErrors = mapApiFieldErrors(e.errors));
      _formKey.currentState!.validate();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
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
      title: widget.isEditing ? 'Изменить клиента' : 'Новый клиент',
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
          label: 'ФИО',
          controller: _fullNameController,
          onChanged: _markDirty,
          validator: V.combine([
            V.required('Укажите ФИО'),
            V.length(min: 2, max: 120),
          ]),
        ),
        FormFieldSpec(
          label: 'Email',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            _markDirty();
            if (_fieldErrors.containsKey('email')) {
              setState(() => _fieldErrors.remove('email'));
            }
          },
          validator: (value) {
            final local = V.combine([
              V.required('Укажите email'),
              V.email(),
            ])(value);
            if (local != null) return local;
            return _fieldErrors['email'];
          },
        ),
        FormFieldSpec(
          label: 'Телефон',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: _markDirty,
          validator: V.length(max: 30),
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Клубная карта',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.fromLTRB(12, 16, 12, 8),
          ),
          child: Column(
            children: [
              TextFormField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Номер карты',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _markDirty,
                validator: V.combine([
                  V.required('Укажите номер карты'),
                  V.length(min: 3, max: 40),
                ]),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _cardLevel,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Уровень',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final level in _cardLevels)
                    DropdownMenuItem(value: level, child: Text(level)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _cardLevel = value;
                    _dirty = true;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _issuedYearController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Год выдачи',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _markDirty,
                validator: V.combine([
                  V.required('Укажите год'),
                  V.integer(min: 2000, max: 2100),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
