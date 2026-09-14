import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_notifier.dart';
import '../core/breakpoints.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  List<({String path, IconData icon, String label})> _destinationsFor(
    AuthNotifier auth,
  ) {
    final items = <({String path, IconData icon, String label})>[
      (path: '/products', icon: Icons.devices, label: 'Товары'),
    ];
    if (auth.canEditCatalog) {
      items.addAll([
        (path: '/brands', icon: Icons.factory_outlined, label: 'Бренды'),
        (
          path: '/categories',
          icon: Icons.category_outlined,
          label: 'Категории',
        ),
        (
          path: '/suppliers',
          icon: Icons.local_shipping_outlined,
          label: 'Поставщики',
        ),
        (path: '/customers', icon: Icons.people_outline, label: 'Клиенты'),
        (path: '/orders', icon: Icons.assignment_outlined, label: 'Заказы'),
      ]);
    }
    if (auth.canViewMyOrders) {
      items.add((
        path: '/my-orders',
        icon: Icons.shopping_bag_outlined,
        label: 'Мои заказы',
      ));
    }
    if (auth.canManageUsers) {
      items.add((
        path: '/admin/users',
        icon: Icons.manage_accounts_outlined,
        label: 'Пользователи',
      ));
    }
    if (auth.canViewStats) {
      items.add((
        path: '/admin/stats',
        icon: Icons.bar_chart_outlined,
        label: 'Статистика',
      ));
    }
    return items;
  }

  int _selectedIndex(
    List<({String path, IconData icon, String label})> destinations,
  ) {
    for (var i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].path)) return i;
    }
    return 0;
  }

  void _onSelect(BuildContext context, String path) {
    context.go(path);
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthNotifier>().logout();
    if (context.mounted) context.go('/login');
  }

  Future<void> _spoofAdmin(BuildContext context) async {
    final auth = context.read<AuthNotifier>();
    await auth.spoofUiRole(UserRole.admin);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'UI: роль «Администратор». JWT не менялся — сервер ответит 403.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  Future<void> _reloadLocalUser(BuildContext context) async {
    final ok = await context.read<AuthNotifier>().reloadUserFromLocalStorage();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Профиль перечитан из localStorage'
              : 'В localStorage нет auth_user_json',
        ),
      ),
    );
  }

  Widget _userHeader(BuildContext context) {
    final user = context.watch<AuthNotifier>().user;
    if (user == null) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            Icons.person_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(user.displayName, overflow: TextOverflow.ellipsis),
          subtitle: Text(user.role.label, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<String>(
            tooltip: 'Сессия',
            onSelected: (value) async {
              switch (value) {
                case 'spoof':
                  await _spoofAdmin(context);
                case 'reload':
                  await _reloadLocalUser(context);
                case 'logout':
                  await _logout(context);
              }
            },
            itemBuilder: (context) => [
              if (user.role != UserRole.admin)
                const PopupMenuItem(
                  value: 'spoof',
                  child: Text('Демо: UI как у админа'),
                ),
              const PopupMenuItem(
                value: 'reload',
                child: Text('Перечитать localStorage'),
              ),
              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final destinations = _destinationsFor(auth);
    final size = screenSizeOf(context);
    final index = _selectedIndex(destinations)
        .clamp(0, destinations.length - 1);

    if (size == ScreenSize.compact) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ТехноМаркет'),
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Сессия',
              onSelected: (value) async {
                switch (value) {
                  case 'spoof':
                    await _spoofAdmin(context);
                  case 'reload':
                    await _reloadLocalUser(context);
                  case 'logout':
                    await _logout(context);
                }
              },
              itemBuilder: (context) {
                final role = context.read<AuthNotifier>().user?.role;
                return [
                  if (role != UserRole.admin)
                    const PopupMenuItem(
                      value: 'spoof',
                      child: Text('Демо: UI как у админа'),
                    ),
                  const PopupMenuItem(
                    value: 'reload',
                    child: Text('Перечитать localStorage'),
                  ),
                  const PopupMenuItem(value: 'logout', child: Text('Выйти')),
                ];
              },
            ),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          labelBehavior: destinations.length > 3
              ? NavigationDestinationLabelBehavior.onlyShowSelected
              : NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) =>
              _onSelect(context, destinations[i].path),
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.label),
          ],
        ),
      );
    }

    final railWidth = size == ScreenSize.expanded ? 240.0 : 200.0;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: railWidth,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ТехноМаркет',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          ListTile(
                            leading: Icon(destinations[i].icon),
                            title: Text(destinations[i].label),
                            selected: i == index,
                            selectedTileColor: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () =>
                                _onSelect(context, destinations[i].path),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  _userHeader(context),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
