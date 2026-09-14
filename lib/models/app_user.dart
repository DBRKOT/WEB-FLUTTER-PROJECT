enum UserRole {
  reader,
  librarian,
  admin;

  static UserRole fromApi(String? value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'librarian' => UserRole.librarian,
      _ => UserRole.reader,
    };
  }

  String get apiValue => switch (this) {
    UserRole.admin => 'admin',
    UserRole.librarian => 'librarian',
    UserRole.reader => 'reader',
  };

  String get label => switch (this) {
    UserRole.admin => 'Администратор',
    UserRole.librarian => 'Менеджер',
    UserRole.reader => 'Клиент',
  };

  int get level => switch (this) {
    UserRole.reader => 1,
    UserRole.librarian => 2,
    UserRole.admin => 3,
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.role,
    this.readerId,
  });

  final int id;
  final String username;
  final String fullName;
  final String email;
  final UserRole role;
  final int? readerId;

  String get displayName =>
      fullName.trim().isEmpty ? username : fullName.trim();

  AppUser copyWith({
    int? id,
    String? username,
    String? fullName,
    String? email,
    UserRole? role,
    int? readerId,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      readerId: readerId ?? this.readerId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'fullName': fullName,
    'email': email,
    'role': role.apiValue,
    'readerId': readerId,
  };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as int? ?? 0,
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: UserRole.fromApi(json['role'] as String?),
    readerId: json['readerId'] as int?,
  );
}
