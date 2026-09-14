class Brand {
  final int id;
  final String name;
  final int foundedYear;
  final String country;
  final String email;
  final DateTime? deletedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.foundedYear,
    required this.country,
    this.email = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Brand copyWith({
    String? name,
    int? foundedYear,
    String? country,
    String? email,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      foundedYear: foundedYear ?? this.foundedYear,
      country: country ?? this.country,
      email: email ?? this.email,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'foundedYear': foundedYear,
    'country': country,
    'email': email,
    'deletedAt': deletedAt?.toIso8601String(),
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: json['id'] as int? ?? 0,
    name: (json['name'] ?? json['fullName'] ?? '') as String,
    foundedYear: json['foundedYear'] as int? ?? json['birthYear'] as int? ?? 0,
    country: json['country'] as String? ?? '',
    email: json['email'] as String? ?? '',
    deletedAt: json['deletedAt'] == null
        ? null
        : DateTime.tryParse(json['deletedAt'] as String),
  );
}
