import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/form_api_errors.dart';
import '../core/format.dart';
import '../core/reference_cache.dart';
import '../core/validators.dart';
import '../models/customer.dart';
import '../models/master.dart';
import '../models/product.dart';
import '../models/repair_order.dart';
import '../models/service.dart';
import '../state/entity_notifiers.dart';
import '../widgets/entity_form_scaffold.dart';
import '../widgets/id_chip_form_field.dart';
import 'repair_list_screen.dart' show formatRepairMoment;

const int serviceHourlyRate = 1200;

class RepairFormScreen extends StatefulWidget {
  const RepairFormScreen({super.key, this.id});

  final String? id;
  bool get isEditing => id != null;

  @override
  State<RepairFormScreen> createState() => _RepairFormScreenState();
}

class _RepairFormScreenState extends State<RepairFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _problemController = TextEditingController();


  final Map<String, String> _serverErrors = {};

  String? _clientId;
  String _productId = '';
  String _masterId = '';
  List<String> _serviceIds = [];
  DateTime? _startAt;
  DateTime? _endAt;
  RepairStatus _status = RepairStatus.newRequest;

  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _loadError;
  RepairOrder? _existing;

  List<Customer> _customers = const [];
  List<Product> _products = const [];
  List<Master> _masters = const [];
  List<Service> _services = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _problemController.dispose();
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
    try {
      final cache = context.read<ReferenceCache>();
      final notifier = context.read<RepairListNotifier>();
      final customers = await cache.customers();
      final products = await cache.products();
      final masters = await cache.masters();
      final services = await cache.services();

      RepairOrder? existing;
      if (widget.isEditing) {
        existing = await notifier.findById(widget.id!);
        if (existing == null) throw StateError('Заявка не найдена');
        _problemController.text = existing.problem;
        _clientId = existing.clientId;
        _productId = existing.productId;
        _masterId = existing.masterId;
        _serviceIds = [...existing.serviceIds];
        _startAt = existing.startAt.toLocal();
        _endAt = existing.endAt.toLocal();
        _status = existing.status;
      }
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _products = products;
        _masters = masters;
        _services = services;
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

  //cтоимость заявки не вводится руками: она складывается из цен
  //выбранных услуг и норма-часов по ставке сервисного центра.
  int get _total {
    var sum = 0;
    for (final service in _services) {
      if (_serviceIds.contains(service.id)) {
        sum += service.costFor(hourlyRate: serviceHourlyRate);
      }
    }
    return sum;
  }

  void _applyServerErrors(Map<String, String> errors, String fallback) {
    const known = {
      'client',
      'product',
      'master',
      'services',
      'problem',
      'startAt',
      'endAt',
      'status',
      'total',
    };
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

  Future<void> _pickMoment({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final base = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null || !mounted) return;
    onPicked(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  RepairOrder _collect() => RepairOrder(
    id: _existing?.id ?? '',
    clientId: _clientId ?? '',
    productId: _productId,
    masterId: _masterId,
    serviceIds: [..._serviceIds],
    problem: _problemController.text.trim(),
    startAt: _startAt!,
    endAt: _endAt!,
    status: _status,
    total: _total,
    archived: _existing?.archived ?? false,
  );


  Future<String?> _masterBusyError(RepairOrder planned) async {
    if (planned.masterId.isEmpty) return null;
    final schedule = await context.read<RepairListNotifier>().masterSchedule(
      planned.masterId,
      excludeId: _existing?.id,
    );
    for (final busy in schedule) {
      if (planned.conflictsWith(busy)) {
        return 'Мастер занят заявкой с ${formatRepairMoment(busy.startAt)} '
            'до ${formatRepairMoment(busy.endAt)}';
      }
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final notifier = context.read<RepairListNotifier>();
    try {
      final planned = _collect();
      final busy = await _masterBusyError(planned);
      if (busy != null) {
        if (!mounted) return;
        _applyServerErrors({'master': busy}, busy);
        return;
      }

      if (widget.isEditing) {
        await notifier.update(planned);
      } else {
        await notifier.create(planned);
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

  String? _validateProblem(String? value) {
    final base = V.combine([
      V.required('Опишите неисправность'),
      V.length(min: 5, max: 1000),
    ])(value);
    return base ?? _serverErrors['problem'];
  }

  @override
  Widget build(BuildContext context) {

    final clientValue = _customers.any((c) => c.userId == _clientId)
        ? _clientId
        : null;
    final productValue = _products.any((p) => p.id == _productId)
        ? _productId
        : '';
    final masterValue = _masters.any((m) => m.id == _masterId) ? _masterId : '';

    return EntityFormScaffold(
      title: widget.isEditing ? 'Изменить заявку' : 'Новая заявка',
      fallbackPath: '/repairs',
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
          label: 'Неисправность (от 5 до 1000 символов)',
          controller: _problemController,
          maxLines: 5,
          onChanged: (_) => _markDirty('problem'),
          validator: _validateProblem,
        ),
      ],
      extraChildren: [
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('repair-client-${clientValue ?? ''}'),
          isExpanded: true,
          initialValue: clientValue,
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
            _clientId = value;
            _markDirty('client');
          },
          validator: (value) =>
              value == null ? 'Выберите заказчика' : _serverErrors['client'],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('repair-product-$productValue'),
          isExpanded: true,
          initialValue: productValue,
          decoration: const InputDecoration(
            labelText: 'Товар',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('не указан')),
            for (final product in _products)
              DropdownMenuItem(
                value: product.id,
                child: Text(product.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            _productId = value ?? '';
            _markDirty('product');
          },
          validator: (_) => _serverErrors['product'],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('repair-master-$masterValue'),
          isExpanded: true,
          initialValue: masterValue,
          decoration: const InputDecoration(
            labelText: 'Мастер',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: '', child: Text('не указан')),
            for (final master in _masters)
              DropdownMenuItem(
                value: master.id,
                child: Text(master.fullName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) {
            _masterId = value ?? '';
            _markDirty('master');
          },
          validator: (_) => _serverErrors['master'],
        ),
        const SizedBox(height: 16),
        IdChipFormField(
          label: 'Услуги (хотя бы одна)',
          emptyError: 'Выберите хотя бы одну услугу',
          initialValue: _serviceIds,
          options: [
            for (final service in _services)
              (id: service.id, name: service.name),
          ],
          onSaved: (value) => _serviceIds = value ?? [],
          onChanged: (value) {
            _serviceIds = value;
            _markDirty('services');
          },
        ),
        if (_serverErrors['services'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _serverErrors['services']!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 16),
        _momentField(
          label: 'Начало работ',
          fieldName: 'startAt',
          value: _startAt,
          onPicked: (value) => setState(() {
            _startAt = value;
            _serverErrors.remove('startAt');
            _dirty = true;
          }),
        ),
        const SizedBox(height: 16),
        _momentField(
          label: 'Окончание работ',
          fieldName: 'endAt',
          value: _endAt,
          onPicked: (value) => setState(() {
            _endAt = value;
            _serverErrors.remove('endAt');
            _dirty = true;
          }),
          extraCheck: (value) {
            final start = _startAt;
            if (start != null && !value.isAfter(start)) {
              return 'Окончание должно быть позже начала';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('repair-status-${_status.apiValue}'),
          isExpanded: true,
          initialValue: _status.apiValue,
          decoration: const InputDecoration(
            labelText: 'Статус',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final status in RepairStatus.values)
              DropdownMenuItem(
                value: status.apiValue,
                child: Text(status.label),
              ),
          ],
          onChanged: (value) {
            if (value == null) return;
            _status = RepairStatus.fromApi(value);
            _markDirty('status');
          },
          validator: (value) => value == null || value.isEmpty
              ? 'Выберите статус'
              : _serverErrors['status'],
        ),
        const SizedBox(height: 16),
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Стоимость',
            border: const OutlineInputBorder(),
            helperText:
                'Считается по выбранным услугам: цена плюс норма-часы '
                'по ставке ${formatPrice(serviceHourlyRate)} за час',
            errorText: _serverErrors['total'],
          ),
          child: Text(
            formatPrice(_total),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ],
    );
  }

  Widget _momentField({
    required String label,
    required String fieldName,
    required DateTime? value,
    required ValueChanged<DateTime> onPicked,
    String? Function(DateTime value)? extraCheck,
  }) {
    return FormField<DateTime>(

      key: ValueKey('$fieldName-$value-$_startAt'),
      initialValue: value,
      validator: (picked) {
        if (picked == null) return 'Выберите дату и время';
        return extraCheck?.call(picked) ?? _serverErrors[fieldName];
      },
      builder: (field) => InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: field.errorText,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'не выбрано' : formatRepairMoment(value),
              ),
            ),
            TextButton.icon(
              onPressed: () => _pickMoment(current: value, onPicked: onPicked),
              icon: const Icon(Icons.event),
              label: const Text('Выбрать'),
            ),
          ],
        ),
      ),
    );
  }
}
