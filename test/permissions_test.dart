import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tech_store/core/auth_notifier.dart';
import 'package:tech_store/core/permissions.dart';
import 'package:tech_store/models/app_user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AuthNotifier> make(UserRole role) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthNotifier(prefs, Dio());
    auth.seedForTest(
      AppUser(
        id: 'usr0000000000001',
        fullName: 'Пользователь',
        email: 'u@tm.local',
        role: role,
      ),
    );
    return auth;
  }

  test('клиент видит каталог, свои заказы и свои заявки', () async {
    final auth = await make(UserRole.client);
    expect(auth.canEditCatalog, isFalse);
    expect(auth.canViewMyOrders, isTrue);
    expect(auth.canViewMyRepairs, isTrue);
    expect(auth.canManageOrders, isFalse);
    expect(auth.canManageUsers, isFalse);
    expect(auth.canManageService, isFalse);
    expect(auth.canOpenPath('/products'), isTrue);
    expect(auth.canOpenPath('/products/abc123'), isTrue);
    expect(auth.canOpenPath('/products/new'), isFalse);
    expect(auth.canOpenPath('/my-orders'), isTrue);
    expect(auth.canOpenPath('/my-repairs'), isTrue);
    expect(auth.canOpenPath('/orders'), isFalse);
    expect(auth.canOpenPath('/repairs'), isFalse);
    expect(auth.canOpenPath('/admin/users'), isFalse);
    expect(auth.canOpenPath('/stock'), isFalse);
    expect(auth.canOpenPath('/brands'), isFalse);
  });

  test('менеджер владеет сервисным центром, но не админкой', () async {
    final auth = await make(UserRole.manager);
    expect(auth.canEditCatalog, isTrue);
    expect(auth.canManageService, isTrue);
    expect(auth.canHardDelete, isFalse);
    expect(auth.canManageStock, isFalse);
    expect(auth.canViewMyOrders, isFalse);
    expect(auth.canManageOrders, isTrue);
    expect(auth.canManageUsers, isFalse);
    expect(auth.canOpenPath('/orders'), isTrue);
    expect(auth.canOpenPath('/products/new'), isTrue);
    expect(auth.canOpenPath('/repairs'), isTrue);
    expect(auth.canOpenPath('/masters'), isTrue);
    expect(auth.canOpenPath('/admin/stats'), isFalse);
    expect(auth.canOpenPath('/stock'), isFalse);
    expect(auth.canOpenPath('/my-orders'), isFalse);
  });

  test(
    'администратор владеет пользователями и складом, но не сервисом',
    () async {
      final auth = await make(UserRole.admin);
      expect(auth.canHardDelete, isTrue);
      expect(auth.canRestore, isTrue);
      expect(auth.canManageUsers, isTrue);
      expect(auth.canManageStock, isTrue);
      expect(auth.canViewStats, isTrue);
      expect(auth.canEditCatalog, isTrue);
      expect(auth.canOpenPath('/admin/users'), isTrue);
      expect(auth.canOpenPath('/admin/stats'), isTrue);
      expect(auth.canOpenPath('/stock'), isTrue);

      expect(auth.canManageService, isFalse);
      expect(auth.canOpenPath('/repairs'), isFalse);
    },
  );

  test('у каждой роли есть исключительный раздел', () async {
    final client = await make(UserRole.client);
    final manager = await make(UserRole.manager);
    final admin = await make(UserRole.admin);

    expect(client.canOpenPath('/my-repairs'), isTrue);
    expect(manager.canOpenPath('/my-repairs'), isFalse);
    expect(admin.canOpenPath('/my-repairs'), isFalse);

    expect(manager.canOpenPath('/repairs'), isTrue);
    expect(client.canOpenPath('/repairs'), isFalse);
    expect(admin.canOpenPath('/repairs'), isFalse);

    expect(admin.canOpenPath('/admin/users'), isTrue);
    expect(client.canOpenPath('/admin/users'), isFalse);
    expect(manager.canOpenPath('/admin/users'), isFalse);
  });

  test('подмена роли в интерфейсе не меняет токен', () async {
    final auth = await make(UserRole.client);
    expect(auth.canOpenPath('/admin/users'), isFalse);
    await auth.spoofUiRole(UserRole.admin);
    expect(auth.user?.role, UserRole.admin);
    expect(auth.canManageUsers, isTrue);
    expect(auth.canOpenPath('/admin/users'), isTrue);
    expect(auth.accessToken, 'test-token');
  });

  test('reloadUserFromLocalStorage читает подменённую роль', () async {
    final auth = await make(UserRole.client);
    await auth.spoofUiRole(UserRole.admin);
    auth.seedForTest(
      const AppUser(
        id: 'usr0000000000001',
        fullName: 'Пользователь',
        email: 'u@tm.local',
        role: UserRole.client,
      ),
    );
    final ok = await auth.reloadUserFromLocalStorage();
    expect(ok, isTrue);
    expect(auth.user?.role, UserRole.admin);
  });

  test('has(): администратор включает права менеджера', () async {
    final auth = await make(UserRole.admin);
    expect(auth.has(UserRole.client), isTrue);
    expect(auth.has(UserRole.manager), isTrue);
    expect(auth.has(UserRole.admin), isTrue);

    final client = await make(UserRole.client);
    expect(client.has(UserRole.manager), isFalse);
    expect(client.has(UserRole.admin), isFalse);
  });
}
