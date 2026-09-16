class Service {
  final String id;
  final String name;
  final int price;
  final double normHours;
  final bool archived;

  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.normHours,
    this.archived = false,
  });

  bool get isDeleted => archived;

  int costFor({required int hourlyRate}) =>
      price + (normHours * hourlyRate).round();

  Service copyWith({
    String? name,
    int? price,
    double? normHours,
    bool? archived,
  }) {
    return Service(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      normHours: normHours ?? this.normHours,
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'normHours': normHours,
    'archived': archived,
  };

  factory Service.fromJson(Map<String, dynamic> json) => Service(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    price: (json['price'] as num?)?.round() ?? 0,
    normHours: (json['normHours'] as num?)?.toDouble() ?? 0,
    archived: json['archived'] as bool? ?? false,
  );
}
