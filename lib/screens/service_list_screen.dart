import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/format.dart';
import '../core/permissions.dart';
import '../models/service.dart';
import '../models/simple_query.dart';
import '../state/entity_notifiers.dart';
import '../state/load_status.dart';
import '../widgets/entity_table.dart';
import '../widgets/load_state_view.dart';
import '../widgets/paginator_bar.dart';
import '../widgets/table_cell_text.dart';

String formatNormHours(double value) {
  var text = value.toStringAsFixed(2);
  if (text.endsWith('0')) text = text.substring(0, text.length - 1);
  if (text.endsWith('.0')) text = text.substring(0, text.length - 2);
  return text.replaceAll('.', ',');
}

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
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
      final notifier = context.read<ServiceListNotifier>();
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
    final notifier = context.read<ServiceListNotifier>();
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
    await context.read<ServiceListNotifier>().applyQuery(next);
    if (!mounted || _applyingFromUrl) return;
    final location = next.toLocation('/services');
    _lastSyncedLocation = location;
    context.go(location);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = context.read<ServiceListNotifier>().query;
      _apply(q.copyWith(search: value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ServiceListNotifier>();
    final auth = context.watch<AuthNotifier>();
    final q = notifier.query;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Услуги'),
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
            onPressed: () =>
                context.read<ServiceListNotifier>().simulateError(),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ],
      ),
      floatingActionButton: auth.canManageService
          ? FloatingActionButton(
              tooltip: 'Новая услуга',
              onPressed: () => context.push('/services/new'),
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
                    key: const Key('service-search'),
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Поиск по названию',
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
                    key: ValueKey('service-sort-${q.sortField}'),
                    isExpanded: true,
                    initialValue: q.sortField,
                    decoration: const InputDecoration(
                      labelText: 'Сортировка',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'name', child: Text('Название')),
                      DropdownMenuItem(value: 'price', child: Text('Цена')),
                      DropdownMenuItem(
                        value: 'normHours',
                        child: Text('Норма-часы'),
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
              emptyMessage: 'Услуги не найдены',
              onRetry: () => context.read<ServiceListNotifier>().load(),
              child: screenSizeOf(context) == ScreenSize.compact
                  ? _ServiceCards(
                      items: notifier.result.items,
                      selected: notifier.selected,
                      onSoftDelete: (s) => _confirmSoftDelete(context, s),
                      onHardDelete: (s) => _confirmHardDelete(context, s),
                    )
                  : EntityTable<Service>(
                      items: notifier.result.items,
                      idOf: (s) => s.id,
                      selected: notifier.selected,
                      onToggleSelect: (id) => context
                          .read<ServiceListNotifier>()
                          .toggleSelection(id),
                      isDeleted: (s) => s.isDeleted,
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
                          label: 'Название',
                          sortField: 'name',
                          build: (s) => Text(
                            s.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: s.isDeleted
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                        ),
                        TableColumnSpec(
                          label: 'Цена',
                          sortField: 'price',
                          numeric: true,
                          build: (s) => Text(formatPrice(s.price)),
                        ),
                        TableColumnSpec(
                          label: 'Норма-часы',
                          sortField: 'normHours',
                          numeric: true,
                          build: (s) => Text(formatNormHours(s.normHours)),
                        ),
                        TableColumnSpec(
                          label: 'Состояние',
                          build: (s) => tableCellText(
                            s.isDeleted ? 'Удалена' : 'Активна',
                          ),
                        ),
                      ],
                      actions: (s) => _actions(context, s),
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

  List<Widget> _actions(BuildContext context, Service service) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canManageService) return const [];

    if (service.isDeleted) {
      return [
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore),
          onPressed: () =>
              context.read<ServiceListNotifier>().restore(service.id),
        ),
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever),
          onPressed: () => _confirmHardDelete(context, service),
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Изменить',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => context.push('/services/${service.id}/edit'),
      ),
      IconButton(
        tooltip: 'Удалить (логически)',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _confirmSoftDelete(context, service),
      ),
      IconButton(
        tooltip: 'Удалить навсегда',
        icon: const Icon(Icons.delete_forever),
        onPressed: () => _confirmHardDelete(context, service),
      ),
    ];
  }

  Future<void> _confirmSoftDelete(BuildContext context, Service service) async {
    final ok = await _confirm(
      context,
      title: 'Логическое удаление',
      message: 'Скрыть услугу «${service.name}»?',
      action: 'Удалить',
    );
    if (ok && context.mounted) {
      await context.read<ServiceListNotifier>().softDelete(service.id);
    }
  }

  Future<void> _confirmHardDelete(BuildContext context, Service service) async {
    final ok = await _confirm(
      context,
      title: 'Физическое удаление',
      message: 'Стереть услугу «${service.name}» навсегда?',
      action: 'Стереть',
    );
    if (ok && context.mounted) {
      await context.read<ServiceListNotifier>().hardDelete(service.id);
    }
  }

  Future<void> _confirmDeleteSelected(BuildContext context) async {
    final notifier = context.read<ServiceListNotifier>();
    final ok = await _confirm(
      context,
      title: 'Удалить выбранные',
      message: 'Логически удалить ${notifier.selected.length} услуг(и)?',
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

class _ServiceCards extends StatelessWidget {
  const _ServiceCards({
    required this.items,
    required this.selected,
    required this.onSoftDelete,
    required this.onHardDelete,
  });

  final List<Service> items;
  final Set<String> selected;
  final Future<void> Function(Service service) onSoftDelete;
  final Future<void> Function(Service service) onHardDelete;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<ServiceListNotifier>();
    final canManage = context.watch<AuthNotifier>().canManageService;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          color: s.isDeleted
              ? Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.35)
              : null,
          child: ListTile(
            leading: Checkbox(
              value: selected.contains(s.id),
              onChanged: (_) => notifier.toggleSelection(s.id),
            ),
            title: Text(
              s.name,
              style: s.isDeleted
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            subtitle: Text(
              '${formatPrice(s.price)} · '
              'норма-часы: ${formatNormHours(s.normHours)}'
              '${s.isDeleted ? ' · удалена' : ''}',
            ),
            onTap: canManage
                ? () => context.push('/services/${s.id}/edit')
                : null,
            trailing: canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          context.push('/services/${s.id}/edit');
                        case 'soft':
                          await onSoftDelete(s);
                        case 'hard':
                          await onHardDelete(s);
                        case 'restore':
                          await notifier.restore(s.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!s.isDeleted) ...[
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
