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
        id: 1,
        username: 'u',
        fullName: 'User',
        email: 'u@test',
        role: role,
        readerId: role == UserRole.reader ? 1 : null,
      ),
    );
    return auth;
  }

  test('клиент видит только каталог и свои заказы', () async {
    final auth = await make(UserRole.reader);
    expect(auth.canEditCatalog, isFalse);
    expect(auth.canViewMyOrders, isTrue);
    expect(auth.canManageOrders, isFalse);
    expect(auth.canManageUsers, isFalse);
    expect(auth.canOpenPath('/products'), isTrue);
    expect(auth.canOpenPath('/products/1'), isTrue);
    expect(auth.canOpenPath('/products/new'), isFalse);
    expect(auth.canOpenPath('/my-orders'), isTrue);
    expect(auth.canOpenPath('/orders'), isFalse);
    expect(auth.canOpenPath('/admin/users'), isFalse);
    expect(auth.canOpenPath('/brands'), isFalse);
  });

  test('менеджер редактирует каталог и заказы, без админки', () async {
    final auth = await make(UserRole.librarian);
    expect(auth.canEditCatalog, isTrue);
    expect(auth.canHardDelete, isFalse);
    expect(auth.canViewMyOrders, isFalse);
    expect(auth.canManageOrders, isTrue);
    expect(auth.canManageUsers, isFalse);
    expect(auth.canOpenPath('/orders'), isTrue);
    expect(auth.canOpenPath('/products/new'), isTrue);
    expect(auth.canOpenPath('/customers'), isTrue);
    expect(auth.canOpenPath('/admin/stats'), isFalse);
    expect(auth.canOpenPath('/my-orders'), isFalse);
  });

  test('админ: hard delete, пользователи и статистика', () async {
    final auth = await make(UserRole.admin);
    expect(auth.canHardDelete, isTrue);
    expect(auth.canRestore, isTrue);
    expect(auth.canManageUsers, isTrue);
    expect(auth.canViewStats, isTrue);
    expect(auth.canEditCatalog, isTrue);
    expect(auth.canOpenPath('/admin/users'), isTrue);
    expect(auth.canOpenPath('/admin/stats'), isTrue);
  });

  test('подмена UI-роли открывает админ-пути на клиенте', () async {
    final auth = await make(UserRole.reader);
    expect(auth.canOpenPath('/admin/users'), isFalse);
    await auth.spoofUiRole(UserRole.admin);
    expect(auth.user?.role, UserRole.admin);
    expect(auth.canManageUsers, isTrue);
    expect(auth.canOpenPath('/admin/users'), isTrue);
    expect(auth.accessToken, 'test-token');
  });

  test('reloadUserFromLocalStorage читает подменённую роль', () async {
    final auth = await make(UserRole.reader);
    await auth.spoofUiRole(UserRole.admin);
    auth.seedForTest(
      const AppUser(
        id: 1,
        username: 'u',
        fullName: 'User',
        email: 'u@test',
        role: UserRole.reader,
      ),
    );
    final ok = await auth.reloadUserFromLocalStorage();
    expect(ok, isTrue);
    expect(auth.user?.role, UserRole.admin);
  });

  test('иерархия has(): админ включает права менеджера', () async {
    final auth = await make(UserRole.admin);
    expect(auth.has(UserRole.reader), isTrue);
    expect(auth.has(UserRole.librarian), isTrue);
    expect(auth.has(UserRole.admin), isTrue);

    final client = await make(UserRole.reader);
    expect(client.has(UserRole.librarian), isFalse);
    expect(client.has(UserRole.admin), isFalse);
  });
}
