class Supplier {
  final String id;
  final String name;
  final String city;
  final String phone;
  final String email;
  final String contractNumber;

  const Supplier({
    required this.id,
    required this.name,
    required this.city,
    this.phone = '',
    this.email = '',
    this.contractNumber = '',
  });

  Supplier copyWith({
    String? name,
    String? city,
    String? phone,
    String? email,
    String? contractNumber,
  }) {
    return Supplier(
      id: id,
      name: name ?? this.name,
      city: city ?? this.city,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      contractNumber: contractNumber ?? this.contractNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'city': city,
    'phone': phone,
    'email': email,
    'contractNumber': contractNumber,
  };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    city: json['city'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    email: json['email'] as String? ?? '',
    contractNumber: json['contractNumber'] as String? ?? '',
  );
}
