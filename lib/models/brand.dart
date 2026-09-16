class Brand {
  final String id;
  final String name;
  final int foundedYear;
  final String country;
  final String description;

  const Brand({
    required this.id,
    required this.name,
    required this.foundedYear,
    required this.country,
    this.description = '',
  });

  Brand copyWith({
    String? name,
    int? foundedYear,
    String? country,
    String? description,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      foundedYear: foundedYear ?? this.foundedYear,
      country: country ?? this.country,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'foundedYear': foundedYear,
    'country': country,
    'description': description,
  };

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    foundedYear: (json['foundedYear'] as num?)?.toInt() ?? 0,
    country: json['country'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}
