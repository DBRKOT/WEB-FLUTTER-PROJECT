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

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthNotifier>().canManageUsers) {
      return const Center(child: Text('Раздел только для администратора'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Пользователи и роли')),
      body: LoadStateView(
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
            final u = _items[i];
            return ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(u.displayName),
              subtitle: Text('@${u.username} · ${u.email}'),
              trailing: Chip(label: Text(u.role.label)),
            );
          },
        ),
      ),
    );
  }
}
