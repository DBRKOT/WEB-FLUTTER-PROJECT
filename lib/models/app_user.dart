enum UserRole {
  client,
  manager,
  admin;

  static UserRole fromApi(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'manager' => UserRole.manager,
      _ => UserRole.client,
    };
  }

  String get apiValue => switch (this) {
    UserRole.admin => 'admin',
    UserRole.manager => 'manager',
    UserRole.client => 'client',
  };

  String get label => switch (this) {
    UserRole.admin => 'Администратор',
    UserRole.manager => 'Менеджер сервиса',
    UserRole.client => 'Клиент',
  };

  int get level => switch (this) {
    UserRole.client => 1,
    UserRole.manager => 2,
    UserRole.admin => 3,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.verified = false,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final bool verified;

  String get displayName => fullName.trim().isEmpty ? email : fullName.trim();

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    UserRole? role,
    bool? verified,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      verified: verified ?? this.verified,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'fullName': fullName,
    'role': role.apiValue,
    'verified': verified,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String? ?? '',
    email: json['email'] as String? ?? '',
    fullName: (json['fullName'] ?? json['name'] ?? '') as String,
    role: UserRole.fromApi(json['role'] as String?),
    verified: json['verified'] as bool? ?? false,
  );
}
