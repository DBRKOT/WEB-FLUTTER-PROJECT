import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../models/repair_order.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';
import 'repair_list_screen.dart' show formatRepairInterval;

List<RepairStatus> nextRepairStatuses(RepairStatus current) =>
    switch (current) {
      RepairStatus.newRequest => const [
        RepairStatus.diagnostics,
        RepairStatus.rejected,
      ],
      RepairStatus.diagnostics => const [
        RepairStatus.inWork,
        RepairStatus.rejected,
      ],
      RepairStatus.inWork => const [RepairStatus.ready],
      RepairStatus.ready => const [RepairStatus.issued],
      RepairStatus.issued || RepairStatus.rejected => const [],
    };

class RepairDetailScreen extends StatefulWidget {
  const RepairDetailScreen({super.key, required this.repairId});

  final String repairId;

  @override
  State<RepairDetailScreen> createState() => _RepairDetailScreenState();
}

class _RepairDetailScreenState extends State<RepairDetailScreen> {
  LoadStatus _status = LoadStatus.loading;
  String? _error;
  RepairOrder? _repair;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final repair = await context.read<RepairListNotifier>().findById(
        widget.repairId,
      );
      if (!mounted) return;
      setState(() {
        _repair = repair;
        _status = LoadStatus.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _status = LoadStatus.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить заявку: $e';
        _status = LoadStatus.error;
      });
    }
  }

  Future<void> _changeStatus(RepairStatus next) async {
    setState(() => _changing = true);
    try {
      await context.read<RepairListNotifier>().changeStatus(
        widget.repairId,
        next,
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Статус изменён: ${next.label}')));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось сменить статус: $e')));
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final repair = _repair;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Карточка заявки'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/repairs');
            }
          },
        ),
        actions: [
          if (repair != null && !repair.isDeleted && auth.canManageService)
            IconButton(
              tooltip: 'Изменить',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/repairs/${repair.id}/edit'),
            ),
        ],
      ),
      body: LoadStateView(
        status: _status,
        error: _error,
        isEmpty: repair == null,
        emptyMessage: 'Заявка не найдена',
        onRetry: _load,
        child: repair == null
            ? const SizedBox.shrink()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Card(
                        child: Column(
                          children: [
                            _row(
                              'Заказчик',
                              repair.clientName.isEmpty
                                  ? '—'
                                  : repair.clientName,
                            ),
                            _row(
                              'Товар',
                              repair.productName.isEmpty
                                  ? 'не указан'
                                  : repair.productName,
                            ),
                            _row(
                              'Мастер',
                              repair.masterName.isEmpty
                                  ? 'не назначен'
                                  : repair.masterName,
                            ),
                            _row(
                              'Услуги',
                              repair.serviceNames.isEmpty
                                  ? '—'
                                  : repair.serviceNames.join(', '),
                            ),
                            _row('Неисправность', repair.problem),
                            _row('Интервал', formatRepairInterval(repair)),
                            _row('Статус', repair.status.label),
                            _row('Стоимость', formatPrice(repair.total)),
                            if (repair.isDeleted)
                              _row('Состояние', 'Удалена (логически)'),
                          ],
                        ),
                      ),
                      if (auth.canManageService && !repair.isDeleted)
                        _StatusActions(
                          current: repair.status,
                          busy: _changing,
                          onChange: _changeStatus,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _row(String label, String value) =>
      ListTile(title: Text(label), subtitle: Text(value));
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.current,
    required this.busy,
    required this.onChange,
  });

  final RepairStatus current;
  final bool busy;
  final Future<void> Function(RepairStatus next) onChange;

  @override
  Widget build(BuildContext context) {
    final next = nextRepairStatuses(current);
    if (next.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text('Заявка завершена: смена статуса недоступна'),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final status in next)
            FilledButton.tonal(
              onPressed: busy ? null : () => onChange(status),
              child: Text('Перевести: ${status.label}'),
            ),
        ],
      ),
    );
  }
}
