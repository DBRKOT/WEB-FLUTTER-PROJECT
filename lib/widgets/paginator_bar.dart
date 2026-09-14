import 'package:flutter/material.dart';

class PaginatorBar extends StatelessWidget {
  const PaginatorBar({
    super.key,
    required this.page,
    required this.totalPages,
    required this.total,
    required this.size,
    required this.onPageChanged,
    required this.onSizeChanged,
    this.availableSizes = const [10, 25, 50],
  });

  final int page;
  final int totalPages;
  final int total;
  final int size;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onSizeChanged;
  final List<int> availableSizes;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Всего: $total'),
            const SizedBox(width: 8),
            const Text('На странице:'),
            DropdownButton<int>(
              value: availableSizes.contains(size)
                  ? size
                  : availableSizes.first,
              items: [
                for (final s in availableSizes)
                  DropdownMenuItem(value: s, child: Text('$s')),
              ],
              onChanged: (value) {
                if (value != null) onSizeChanged(value);
              },
            ),
            IconButton(
              tooltip: 'Первая',
              onPressed: page > 1 ? () => onPageChanged(1) : null,
              icon: const Icon(Icons.first_page),
            ),
            IconButton(
              tooltip: 'Предыдущая',
              onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Стр. $page из $totalPages'),
            IconButton(
              tooltip: 'Следующая',
              onPressed: page < totalPages
                  ? () => onPageChanged(page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              tooltip: 'Последняя',
              onPressed: page < totalPages
                  ? () => onPageChanged(totalPages)
                  : null,
              icon: const Icon(Icons.last_page),
            ),
          ],
        ),
      ),
    );
  }
}
