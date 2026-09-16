import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../core/reference_cache.dart';
import '../models/master.dart';
import '../models/repair_order.dart';
import '../models/repair_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

String formatRepairMoment(DateTime value) {
  final local = value.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mi = local.minute.toString().padLeft(2, '0');
  return '$dd.$mm.${local.year} $hh:$mi';
}

String formatRepairInterval(RepairOrder repair) =>
    '${formatRepairMoment(repair.startAt)} — '
    '${formatRepairMoment(repair.endAt)}';

class RepairListScreen extends StatefulWidget {
  const RepairListScreen({super.key});

  @override
  State<RepairListScreen> createState() => _RepairListScreenState();
}

class _RepairListScreenState extends State<RepairListScreen> {
  Timer? _searchDebounce;
  late final TextEditingController _searchController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;
  List<Master> _masters = const [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<RepairListNotifier>();
      if (notifier.status == LoadStatus.idle) notifier.load();
      _loadMasters();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromUrl();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMasters() async {
    try {
      final masters = await context.read<ReferenceCache>().masters();
      if (!mounted) return;
      setState(() => _masters = masters);
    } catch (_) {}
  }

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = RepairQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<RepairListNotifier>();
    if (fromUrl == notifier.query) {
      if (_searchController.text != fromUrl.search) {
        _searchController.text = fromUrl.search;
      }
      return;
    }

    _applyingFromUrl = true;
    if (_searchController.text != fromUrl.search) {
      _searchController.text = fromUrl.search;
    }
    notifier.applyQuery(fromUrl).whenComplete(() {
      _applyingFromUrl = false;
    });
  }

  Future<void> _apply(RepairQuery next) async {
    await context.read<RepairListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/repairs');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<RepairListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RepairListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;
    final masterValue = _masters.any((m) => m.id == q.masterId)
        ? q.masterId!
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Заявки на ремонт'),
        actions: [
          if (notifier.hasSelection)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text('Выбрано: ${notifier.selected.length}'),
              ),
            ),
          if (notifier.hasSelection && auth.canManageService)
            IconButton(
              tooltip: 'Удалить выбранные',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () => context.read<RepairListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canManageService
          ? FloatingActionButton(
              tooltip: 'Новая заявка',
              onPressed: () => context.push('/repairs/new'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  child: TextField(
                    key: const Key('repair-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по неисправности',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('repair-status-${q.status?.apiValue ?? ''}'),
                    isExpanded: true,
                    initialValue: q.status?.apiValue ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Статус',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Все статусы'),
                      ),
                      for (final status in RepairStatus.values)
                        DropdownMenuItem(
                          value: status.apiValue,
                          child: Text(status.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _apply(
                        q.copyWith(
                          status: value.isEmpty
                              ? null
                              : RepairStatus.fromApi(value),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(
                      'repair-master-$masterValue-${_masters.length}',
                    ),
                    isExpanded: true,
                    initialValue: masterValue,
                    decoration: const InputDecoration(
                      labelText: 'Мастер',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Все мастера'),
                      ),
                      for (final master in _masters)
                        DropdownMenuItem(
                          value: master.id,
                          child: Text(
                            master.fullName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _apply(
                        q.copyWith(masterId: value.isEmpty ? null : value),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('repair-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'startAt',
                        child: Text('Дата начала'),
                      ),
                      DropdownMenuItem(value: 'status', child: Text('Статус')),
                      DropdownMenuItem(
                        value: 'total',
                        child: Text('Стоимость'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) _apply(q.copyWith(sortField: value));
                    },
                  ),
                ),
                IconButton(
                  tooltip: q.sortAscending ? 'По возрастанию' : 'По убыванию',
                  onPressed: () =>
                      _apply(q.copyWith(sortAscending: !q.sortAscending)),
                  icon: Icon(
                    q.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ),
                FilterChip(
                  label: const Text('Показать удалённые'),
                  selected: q.includeDeleted,
                  onSelected: (value) =>
                      _apply(q.copyWith(includeDeleted: value)),
                ),
              ],
            ),
          ),
          Expanded(
            child: LoadStateView(
              status: notifier.status,
              error: notifier.error,
              isEmpty: notifier.result.items.isEmpty,
              emptyMessage: 'Заявки не найдены',
              onRetry: () => context.read<RepairListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _RepairCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onSoftDelete: (r) => _confirmSoftDelete(context, r),
                      onHardDelete: (r) => _confirmHardDelete(context, r),
                    )
                  : EntityTable<RepairOrder>(
                      items: notifier.result.items,
                      idOf: (r) => r.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<RepairListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (r) => r.isDeleted,
                      sortField: q.sortField,
                      sortAscending: q.sortAscending,
                      onSort: (field) => _apply(
                        q.copyWith(
                          sortField: field,
                          sortAscending: field == q.sortField
                              ? !q.sortAscending
                              : true,
                        ),
                      ),
                      columns: [
                        TableColumnSpec(
                          label: 'Заказчик',
                          build: (r) => Text(
                            r.clientName.isEmpty ? '—' : r.clientName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: r.isDeleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Товар',
                          build: (r) => tableCellText(
                            r.productName.isEmpty ? '—' : r.productName,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Мастер',
                          build: (r) => tableCellText(
                            r.masterName.isEmpty ? 'не назначен' : r.masterName,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Интервал',
                          sortField: 'startAt',
                          build: (r) => tableCellText(formatRepairInterval(r)),
                        ),
                        TableColumnSpec(
                          label: 'Статус',
                          sortField: 'status',
                          build: (r) => tableCellText(r.status.label),
                        ),
                        TableColumnSpec(
                          label: 'Стоимость',
                          sortField: 'total',
                          numeric: true,
                          build: (r) => Text(formatPrice(r.total)),
                        ),
                      ],
                      actions: (r) => _actions(context, r),
                    ),
            ),
          ),
          if (notifier.status == LoadStatus.success ||
              notifier.status == LoadStatus.loading)
            PaginatorBar(
              page: notifier.result.page,
              totalPages: notifier.result.totalPages,
              total: notifier.result.total,
              size: q.size,
              onPageChanged: (page) => _apply(q.copyWith(page: page)),
              onSizeChanged: (size) => _apply(q.copyWith(size: size, page: 1)),
            ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, RepairOrder repair) {
    final auth = context.watch<AuthNotifier>();
    final open = IconButton(
      tooltip: 'Открыть карточку',
      icon: const Icon(Icons.open_in_new),
      onPressed: () => context.push('/repairs/${repair.id}'),
    );
    if (!auth.canManageService) return [open];

    if (repair.isDeleted) {
      return [
        open,
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () =>
              context.read<RepairListNotifier>().restore(repair.id),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, repair),
        ),
      ];
    }
    return [
      open,
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/repairs/${repair.id}/edit'),
      ),
      IconButton(
        tooltip: 'Удалить (логически)',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmSoftDelete(context, repair),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _confirmHardDelete(context, repair),
      ),
    ];
  }

  Future<void> _confirmSoftDelete(
    BuildContext context,
    RepairOrder repair,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Логическое удаление',
      message: 'Скрыть заявку «${_shortProblem(repair)}»?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<RepairListNotifier>().softDelete(repair.id);
    }
  }

  Future<void> _confirmHardDelete(
    BuildContext context,
    RepairOrder repair,
  ) async {
    final ok = await _confirm(
      context,
      title: 'Физическое удаление',
      message: 'Стереть заявку «${_shortProblem(repair)}» навсегда?',
      action: 'Стереть',
    );
    if (ok && context.mounted) {
      await context.read<RepairListNotifier>().hardDelete(repair.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<RepairListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Логически удалить ${notifier.selected.length} заявку(и)?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await notifier.deleteSelected();
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }
}

String _shortProblem(RepairOrder repair) {
  final text = repair.problem.trim();
  if (text.length <= 40) return text;
  return '${text.substring(0, 40)}…';
}

class _RepairCards extends StatelessWidget {
  const _RepairCards({
    required this.items,
    required this.selected,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  final List<RepairOrder> items;
  final Set<String> selected;
  final Future<void> Function(RepairOrder repair) onSoftDelete;
  final Future<void> Function(RepairOrder repair) onHardDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<RepairListNotifier>();
    final canManage = context.watch<AuthNotifier>().canManageService;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final r = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: r.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(r.id),
              onChanged: (_) => notifier.toggleSelection(r.id),
            ),
            title: Text(
              r.clientName.isEmpty ? _shortProblem(r) : r.clientName,
              style: r.isDeleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${r.productName.isEmpty ? 'товар не указан' : r.productName}\n'
              '${formatRepairInterval(r)}\n'
              '${r.status.label} · ${formatPrice(r.total)}'
              '${r.isDeleted ? ' · удалена' : ''}',
            ),
            isThreeLine: true,
            onTap: () => context.push('/repairs/${r.id}'),
            trailing: canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/repairs/${r.id}/edit');
                        case 'soft':
                          await onSoftDelete(r);
                        case 'hard':
                          await onHardDelete(r);
                        case 'restore':
                          await notifier.restore(r.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!r.isDeleted) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Изменить'),
                        ),
                        const PopupMenuItem(
                          value: 'soft',
                          child: Text('Удалить логически'),
                        ),
                      ] else
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('Восстановить'),
                        ),
                      const PopupMenuItem(
                        value: 'hard',
                        child: Text('Удалить навсегда'),
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}
