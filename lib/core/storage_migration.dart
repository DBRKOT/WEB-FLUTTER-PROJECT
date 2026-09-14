import 'package:shared_preferences/shared_preferences.dart';

class StorageMigrationResult {
  const StorageMigrationResult({required this.didMigrate, this.message});

  final bool didMigrate;
  final String? message;
}

class StorageMigration {
  static const schemaKey = 'schema_version';
  static const currentVersion = 3;

  static const _entityKeys = [
    'products_v1',
    'products_v2',
    'products_v3',
    'brands_v1',
    'brands_v2',
    'categories_v1',
    'categories_v2',
    'suppliers_v1',
    'suppliers_v2',
    'customers_v1',
    'customers_v2',
  ];

  static Future<StorageMigrationResult> run(SharedPreferences prefs) async {
    final stored = prefs.getInt(schemaKey);

    if (stored == null) {
      await prefs.setInt(schemaKey, currentVersion);
      return const StorageMigrationResult(didMigrate: false);
    }

    if (stored == currentVersion) {
      return const StorageMigrationResult(didMigrate: false);
    }

    for (final key in _entityKeys) {
      await prefs.remove(key);
    }
    await prefs.setInt(schemaKey, currentVersion);

    return StorageMigrationResult(
      didMigrate: true,
      message:
          'Формат данных обновлён (v$stored → v$currentVersion). '
          'Локальное хранилище сброшено к начальному набору, чтобы приложение не падало.',
    );
  }
}
