import '../models/app_user.dart';
import 'auth_notifier.dart';

extension AuthPermissions on AuthNotifier {
  UserRole? get role => user?.role;

  bool get isClient => role == UserRole.client;
  bool get isManager => role == UserRole.manager;
  bool get isAdmin => role == UserRole.admin;

  bool get canEditCatalog => has(UserRole.manager);

  bool get canHardDelete => isAdmin;
  bool get canRestore => isAdmin;

  bool get canManageOrders => has(UserRole.manager);
  bool get canViewMyOrders => isClient;

  bool get canViewMyRepairs => isClient;

  bool get canManageService => isManager;

  bool get canManageUsers => isAdmin;
  bool get canManageStock => isAdmin;
  bool get canViewStats => isAdmin;

  bool canOpenPath(String path) {
    if (path.startsWith('/login') || path.startsWith('/register')) return true;
    if (!isAuthenticated) return false;

    if (path.startsWith('/admin')) return canManageUsers || canViewStats;
    if (path.startsWith('/stock')) return canManageStock;

    for (final base in ['/services', '/masters', '/repairs']) {
      if (path.startsWith(base)) return canManageService;
    }
    if (path.startsWith('/my-repairs')) return canViewMyRepairs;
    if (path.startsWith('/my-orders')) return canViewMyOrders;
    if (path.startsWith('/orders')) return canManageOrders;

    if (path.startsWith('/products')) {
      if (path.contains('/new') || path.contains('/edit')) {
        return canEditCatalog;
      }
      return true;
    }

    for (final base in ['/brands', '/categories', '/suppliers', '/customers']) {
      if (path.startsWith(base)) {
        return canEditCatalog;
      }
    }
    return true;
  }
}
