import '../repositories/pb_collection_client.dart';

class Customer {
  final String id;
  final String userId;
  final String phone;
  final String address;
  final DateTime? birthDate;

  final String fullName;
  final String email;

  const Customer({
    required this.id,
    required this.userId,
    this.phone = '',
    this.address = '',
    this.birthDate,
    this.fullName = '',
    this.email = '',
  });

  String get displayName => fullName.trim().isEmpty ? email : fullName.trim();

  Customer copyWith({
    String? userId,
    String? phone,
    String? address,
    DateTime? birthDate,
    bool clearBirthDate = false,
  }) {
    return Customer(
      id: id,
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      fullName: fullName,
      email: email,
    );
  }

  Map<String, dynamic> toJson() => {
    'user': userId,
    'phone': phone,
    'address': address,
    'birthDate': birthDate?.toUtc().toIso8601String() ?? '',
  };

  factory Customer.fromJson(Map<String, dynamic> json) {
    final user = pbExpanded(json, 'user');
    final rawBirth = json['birthDate'] as String? ?? '';
    return Customer(
      id: json['id'] as String? ?? '',
      userId: json['user'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      birthDate: rawBirth.isEmpty ? null : DateTime.tryParse(rawBirth),
      fullName: (user?['fullName'] ?? user?['name'] ?? '') as String,
      email: user?['email'] as String? ?? '',
    );
  }
}
