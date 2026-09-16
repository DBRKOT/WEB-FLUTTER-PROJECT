class Master {
  final String id;
  final String fullName;
  final String specialization;
  final DateTime? hireDate;
  final bool archived;

  const Master({
    required this.id,
    required this.fullName,
    this.specialization = '',
    this.hireDate,
    this.archived = false,
  });

  bool get isDeleted => archived;

  Master copyWith({
    String? fullName,
    String? specialization,
    DateTime? hireDate,
    bool? archived,
    bool clearHireDate = false,
  }) {
    return Master(
      id: id,
      fullName: fullName ?? this.fullName,
      specialization: specialization ?? this.specialization,
      hireDate: clearHireDate ? null : (hireDate ?? this.hireDate),
      archived: archived ?? this.archived,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    'specialization': specialization,
    'hireDate': hireDate?.toUtc().toIso8601String() ?? '',
    'archived': archived,
  };

  factory Master.fromJson(Map<String, dynamic> json) {
    final rawHire = json['hireDate'] as String? ?? '';
    return Master(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      hireDate: rawHire.isEmpty ? null : DateTime.tryParse(rawHire),
      archived: json['archived'] as bool? ?? false,
    );
  }
}
