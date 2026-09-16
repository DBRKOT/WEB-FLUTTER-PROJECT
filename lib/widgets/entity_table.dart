import 'package:flutter/material.dart';

class TableColumnSpec<T> {
  final String label;
  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.isDeleted,
  });

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final bool Function(T item)? isDeleted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.sizeOf(context).width,
          ),
          child: DataTable(
            sortColumnIndex: _sortColumnIndex(),
            sortAscending: sortAscending,
            columns: [
              if (onToggleSelect != null) const DataColumn(label: Text('')),
              for (final column in columns)
                DataColumn(
                  label: Text(column.label),
                  numeric: column.numeric,
                  onSort: column.sortField == null || onSort == null
                      ? null
                      : (_, _) => onSort!(column.sortField!),
                ),
              if (actions != null) const DataColumn(label: Text('Действия')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  selected: selected.contains(idOf(item)),
                  color: (isDeleted?.call(item) ?? false)
                      ? WidgetStatePropertyAll(
                          Theme.of(context).colorScheme.errorContainer
                              .withValues(alpha: 0.35),
                        )
                      : null,
                  cells: [
                    if (onToggleSelect != null)
                      DataCell(
                        Checkbox(
                          value: selected.contains(idOf(item)),
                          onChanged: (_) => onToggleSelect!(idOf(item)),
                        ),
                      ),
                    for (final column in columns) DataCell(column.build(item)),
                    if (actions != null)
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: actions!(item),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  int? _sortColumnIndex() {
    if (sortField == null) return null;
    var index = onToggleSelect == null ? 0 : 1;
    for (final column in columns) {
      if (column.sortField == sortField) return index;
      index++;
    }
    return null;
  }
}
