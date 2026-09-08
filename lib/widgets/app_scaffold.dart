import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/breakpoints.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const _destinations = [
    (path: '/products', icon: Icons.devices, label: 'Товары'),
    (path: '/brands', icon: Icons.factory_outlined, label: 'Бренды'),
    (path: '/categories', icon: Icons.category_outlined, label: 'Категории'),
    (path: '/suppliers', icon: Icons.local_shipping_outlined, label: 'Поставщики'),
    (path: '/customers', icon: Icons.people_outline, label: 'Клиенты'),
  ];

  int get _selectedIndex {
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  void _onSelect(BuildContext context, int index) {
    context.go(_destinations[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final size = screenSizeOf(context);
    final index = _selectedIndex.clamp(0, _destinations.length - 1);

    if (size == ScreenSize.compact) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _onSelect(context, i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: (i) => _onSelect(context, i),
            extended: size == ScreenSize.expanded,
            labelType: size == ScreenSize.expanded
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
