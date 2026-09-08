class Category {
  final int id;
  final String name;
  final String description;
  final DateTime? deletedAt;

  const Category({
    required this.id,
    required this.name,
    this.description = '',
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Category copyWith({
    String? name,
    String? description,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as int? ?? 0,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(json['deletedAt'] as String),
      );
}
