import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../core/auth_notifier.dart';
import '../core/permissions.dart';
import '../models/app_user.dart';
import '../repositories/api_user_repository.dart';
import '../state/load_status.dart';
import '../widgets/load_state_view.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  List<AppUser> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _status = LoadStatus.loading;
      _error = null;
    });
    try {
      final page = await context.read<ApiUserRepository>().find();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _status = LoadStatus.success;
      });
    } on ForbiddenException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '403: ${e.message}';
        _status = LoadStatus.error;
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
        _error = '$e';
        _status = LoadStatus.error;
      });
    }
  }

  void _report(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeRole(AppUser user, UserRole role) async {
    if (role == user.role) return;
    final repository = context.read<ApiUserRepository>();
    try {
      final updated = await repository.changeRole(user.id, role);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final item in _items) item.id == updated.id ? updated : item,
        ];
      });
      _report('Роль «${updated.displayName}» изменена на ${role.label}');
    } on ApiException catch (e) {
      if (!mounted) return;
      _report(e.message);
    }
  }

  Future<void> _delete(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удаление учётной записи'),
        content: Text(
          'Удалить учётную запись «${user.displayName}»? '
          'Вместе с ней исчезнет профиль клиента, а её заказы и заявки '
          'останутся без заказчика.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final repository = context.read<ApiUserRepository>();
    try {
      await repository.delete(user.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((item) => item.id != user.id).toList();
      });
      _report('Учётная запись удалена');
    } on ApiException catch (e) {
      if (!mounted) return;
      _report(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    if (!auth.canManageUsers) {
      return const Center(child: Text('Раздел только для администратора'));
    }
    final currentId = auth.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи и роли'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Учётные записи создаются при регистрации: новый пользователь '
              'получает роль клиента, повысить её может администратор здесь.',
            ),
          ),
          Expanded(
            child: LoadStateView(
              status: _status,
              error: _error,
              isEmpty: _items.isEmpty,
              emptyMessage: 'Пользователи не найдены',
              onRetry: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final user = _items[i];
                  final isSelf = user.id == currentId;
                  return ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user.displayName),
                    subtitle: Text(user.email),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelf)
                          Chip(label: Text(user.role.label))
                        else
                          DropdownButton<UserRole>(
                            value: user.role,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final role in UserRole.values)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(role.label),
                                ),
                            ],
                            onChanged: (role) {
                              if (role != null) _changeRole(user, role);
                            },
                          ),
                        IconButton(
                          tooltip: isSelf
                              ? 'Свою запись удалить нельзя'
                              : 'Удалить',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: isSelf ? null : () => _delete(user),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
