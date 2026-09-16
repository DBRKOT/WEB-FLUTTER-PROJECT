import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/master.dart';
import '../models/simple_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

String formatHireDate(DateTime? date) {
  if (date == null) return '—';
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day.$month.${date.year}';
}

class MasterListScreen extends StatefulWidget {
  const MasterListScreen({super.key});

  @override
  State<MasterListScreen> createState() => _MasterListScreenState();
}

class _MasterListScreenState extends State<MasterListScreen> {
  Timer? _searchDebounce;
  late final TextEditingController _searchController;
  String? _lastSyncedLocation;
  bool _applyingFromUrl = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = context.read<MasterListNotifier>();
      if (notifier.status == LoadStatus.idle) notifier.load();
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

  void _syncFromUrl() {
    final location = GoRouterState.of(context).uri.toString();
    if (location == _lastSyncedLocation) return;
    _lastSyncedLocation = location;

    final fromUrl = SimpleQuery.fromUri(GoRouterState.of(context).uri);
    final notifier = context.read<MasterListNotifier>();
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

  Future<void> _apply(SimpleQuery next) async {
    await context.read<MasterListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/masters');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<MasterListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MasterListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мастера'),
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
              tooltip: 'Удалить выбранных',
              onPressed: () => _confirmDeleteSelected(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            tooltip: 'Показать ошибку загрузки',
            onPressed: () => context.read<MasterListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canManageService
          ? FloatingActionButton(
              tooltip: 'Новый мастер',
              onPressed: () => context.push('/masters/new'),
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
                    key: const Key('master-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск: имя или специализация',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('master-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Имя')),
                      DropdownMenuItem(
                        value: 'specialization',
                        child: Text('Специализация'),
                      ),
                      DropdownMenuItem(
                        value: 'hireDate',
                        child: Text('Дата приёма'),
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
                  label: const Text('Показать удалённых'),
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
              emptyMessage: 'Мастера не найдены',
              onRetry: () => context.read<MasterListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _MasterCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onSoftDelete: (m) => _confirmSoftDelete(context, m),
                      onHardDelete: (m) => _confirmHardDelete(context, m),
                    )
                  : EntityTable<Master>(
                      items: notifier.result.items,
                      idOf: (m) => m.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<MasterListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (m) => m.isDeleted,
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
                          label: 'Имя',
                          sortField: 'name',
                          build: (m) => Text(
                            m.fullName,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: m.isDeleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Специализация',
                          sortField: 'specialization',
                          build: (m) => tableCellText(
                            m.specialization.isEmpty ? '—' : m.specialization,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Дата приёма',
                          sortField: 'hireDate',
                          build: (m) => Text(formatHireDate(m.hireDate)),
                        ),
                        TableColumnSpec(
                          label: 'Состояние',
                          build: (m) =>
                              tableCellText(m.isDeleted ? 'Удалён' : 'Активен'),
                        ),
                      ],
                      actions: (m) => _actions(context, m),
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

  List<Widget> _actions(BuildContext context, Master master) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canManageService) return const [];

    if (master.isDeleted) {
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () =>
              context.read<MasterListNotifier>().restore(master.id),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, master),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/masters/${master.id}/edit'),
      ),
      IconButton(
        tooltip: 'Удалить (логически)',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmSoftDelete(context, master),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _confirmHardDelete(context, master),
      ),
    ];
  }

  Future<void> _confirmSoftDelete(BuildContext context, Master master) async {
    final ok = await _confirm(
      context,
      title: 'Логическое удаление',
      message: 'Скрыть мастера «${master.fullName}»?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<MasterListNotifier>().softDelete(master.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Master master) async {
    final ok = await _confirm(
      context,
      title: 'Физическое удаление',
      message: 'Стереть мастера «${master.fullName}» навсегда?',
      action: 'Стереть',
    );
    if (ok && context.mounted) {
      await context.read<MasterListNotifier>().hardDelete(master.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<MasterListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранных',
      message: 'Логически удалить ${notifier.selected.length} мастер(ов)?',
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

class _MasterCards extends StatelessWidget {
  const _MasterCards({
    required this.items,
    required this.selected,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  final List<Master> items;
  final Set<String> selected;
  final Future<void> Function(Master master) onSoftDelete;
  final Future<void> Function(Master master) onHardDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<MasterListNotifier>();
    final canManage = context.watch<AuthNotifier>().canManageService;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final m = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: m.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(m.id),
              onChanged: (_) => notifier.toggleSelection(m.id),
            ),
            title: Text(
              m.fullName,
              style: m.isDeleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${m.specialization.isEmpty ? 'Специализация не указана' : m.specialization}'
              ' · принят: ${formatHireDate(m.hireDate)}'
              '${m.isDeleted ? ' · удалён' : ''}',
            ),
            onTap: canManage
                ? () => context.push('/masters/${m.id}/edit')
                : null,
            trailing: canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/masters/${m.id}/edit');
                        case 'soft':
                          await onSoftDelete(m);
                        case 'hard':
                          await onHardDelete(m);
                        case 'restore':
                          await notifier.restore(m.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!m.isDeleted) ...[
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
