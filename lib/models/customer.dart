class MembershipCard {
  final String number;
  final String level;
  final int issuedYear;

  const MembershipCard({
    required this.number,
    this.level = 'Standard',
    required this.issuedYear,
  });

  Map<String, dynamic> toJson() => {
        'number': number,
        'level': level,
        'issuedYear': issuedYear,
      };

  factory MembershipCard.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const MembershipCard(number: '', issuedYear: 2024);
    }
    final issuedAt = json['issuedAt'] as String?;
    final issuedYear = json['issuedYear'] as int? ??
        (issuedAt != null ? DateTime.tryParse(issuedAt)?.year : null) ??
        2024;
    return MembershipCard(
      number: json['number'] as String? ?? '',
      level: json['level'] as String? ?? 'Standard',
      issuedYear: issuedYear,
    );
  }
}

class Customer {
  final int id;
  final String fullName;
  final String email;
  final String phone;
  final MembershipCard card; //один к одному
  final DateTime? deletedAt;

  const Customer({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone = '',
    required this.card,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  Customer copyWith({
    String? fullName,
    String? email,
    String? phone,
    MembershipCard? card,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return Customer(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      card: card ?? this.card,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'card': card.toJson(),
        'deletedAt': deletedAt?.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as int? ?? 0,
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        card: MembershipCard.fromJson(
          json['card'] is Map<String, dynamic>
              ? json['card'] as Map<String, dynamic>
              : null,
        ),
        deletedAt: json['deletedAt'] == null
            ? null
            : DateTime.tryParse(json['deletedAt'] as String),
      );
}
