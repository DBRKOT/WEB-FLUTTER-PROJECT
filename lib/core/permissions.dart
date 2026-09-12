import '../models/app_user.dart';
import 'auth_notifier.dart';

extension AuthPermissions on AuthNotifier {
  UserRole? get role => user?.role;

  bool get isClient => role == UserRole.reader;
  bool get isManager => role == UserRole.librarian;
  bool get isAdmin => role == UserRole.admin;

  //Менеджер и администратор: CRUD каталога и справочников.
  bool get canEditCatalog => has(UserRole.librarian);

  //Только администратор: hard delete и restore.
  bool get canHardDelete => has(UserRole.admin);
  bool get canRestore => has(UserRole.admin);

  // Клиенты магазина (readers API).
  bool get canManageCustomers => has(UserRole.librarian);

  //Все выдачи / заказы (оформление и закрытие).
  bool get canManageOrders => has(UserRole.librarian);

  //Только клиент: свои заказы и продление.
  bool get canViewMyOrders => isClient;

  //Только администратор.
  bool get canManageUsers => isAdmin;
  bool get canViewStats => isAdmin;

  bool canOpenPath(String path) {
    if (path.startsWith('/login') || path.startsWith('/register')) return true;
    if (!isAuthenticated) return false;

    if (path.startsWith('/admin')) return canManageUsers || canViewStats;
    if (path.startsWith('/my-orders')) return canViewMyOrders;
    if (path.startsWith('/orders')) return canManageOrders;

    if (path.startsWith('/products')) {
      if (path.contains('/new') || path.contains('/edit')) {
        return canEditCatalog;
      }
      return true; // просмотр каталога всем
    }

    for (final base in ['/brands', '/categories', '/suppliers', '/customers']) {
      if (path.startsWith(base)) {
        return canEditCatalog;
      }
    }
    return true;
  }
}
