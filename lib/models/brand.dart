class Brand {
  final int id;
  final String name;
  final int foundedYear;
  final String country;
  final DateTime? deletedAt;

  const Brand({
    required this.id,
    required this.name,
    required this.foundedYear,
    required this.country,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Brand copyWith({
    String? name,
    int? foundedYear,
    String? country,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Brand(
      id: id,
      name: name ?? this.name,
      foundedYear: foundedYear ?? this.foundedYear,
      country: country ?? this.country,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }
}
