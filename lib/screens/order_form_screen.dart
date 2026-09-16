import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/format.dart';
import '../core/reference_cache.dart';
import '../core/validators.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';

class OrderFormScreen extends StatefulWidget {
  const OrderFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  final _totalController = TextEditingController(text: formatPrice(0));

  final Map<String, String> _serverErrors = {};

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  Order? _existing;
  List<Customer> _customers = const [];
  String? _clientId;
  OrderStatus _status = OrderStatus.created;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _totalController.dispose();
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
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final customers = await context.read<ReferenceCache>().customers();
      Order? existing;
      if (widget.isEditing) {
        if (!mounted) return;
        existing = await context.read<OrderListNotifier>().findById(widget.id!);
        if (existing == null) throw StateError('Заказ не найден');
        _commentController.text = existing.comment;
        _totalController.text = formatPrice(existing.total);
      }
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _existing = existing;
        _clientId = existing?.clientId;
        _status = existing?.status ?? OrderStatus.created;
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

  String? _validateComment(String? value) {
    final base = V.optional(V.length(max: 500))(value);
    return base ?? _serverErrors['comment'];
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {'client', 'status', 'total', 'comment'};
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
      final notifier = context.read<OrderListNotifier>();
      final order = Order(
        id: _existing?.id ?? '',
        clientId: _clientId ?? '',
        status: _status,
        total: _existing?.total ?? 0,
        comment: _commentController.text.trim(),
        archived: _existing?.archived ?? false,
      );
      if (widget.isEditing) {
        await notifier.update(order);
      } else {
        await notifier.create(order);
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
      title: widget.isEditing ? 'Изменить заказ' : 'Новый заказ',
      fallbackPath: '/orders',
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
          label: 'Комментарий (до 500 символов)',
          controller: _commentController,
          maxLines: 4,
          onChanged: (_) => _markDirty('comment'),
          validator: _validateComment,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _customers.any((c) => c.userId == _clientId)
              ? _clientId
              : null,
          decoration: const InputDecoration(
            labelText: 'Заказчик',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final customer in _customers)
              DropdownMenuItem(
                value: customer.userId,
                child: Text(
                  customer.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            setState(() => _clientId = value);
            _markDirty('client');
          },
          validator: (value) =>
              value == null ? 'Выберите заказчика' : _serverErrors['client'],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<OrderStatus>(
          isExpanded: true,
          initialValue: _status,
          decoration: const InputDecoration(
            labelText: 'Статус',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final status in OrderStatus.values)
              DropdownMenuItem(value: status, child: Text(status.label)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _status = value);
            _markDirty('status');
          },
          validator: (value) =>
              value == null ? 'Выберите статус' : _serverErrors['status'],
        ),
        const SizedBox(height: 16),
        TextFormField(
          readOnly: true,
          controller: _totalController,
          decoration: InputDecoration(
            labelText: 'Сумма заказа',
            border: const OutlineInputBorder(),
            helperText:
                'Итог считается по составу заказа и меняется '
                'при изменении позиций',
            errorText: _serverErrors['total'],
          ),
        ),
      ],
    );
  }
}
