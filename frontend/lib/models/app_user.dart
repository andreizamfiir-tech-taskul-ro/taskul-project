class AppUser {
  final int id;
  final String name;
  final String email;
  final DateTime? createdAt;
  final String? phone;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.createdAt,
    this.phone,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name']?.toString() ?? 'Fara nume',
      email: json['email']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      phone: json['phone']?.toString(),
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.tryParse(json['email_verified_at'].toString())
          : null,
      phoneVerifiedAt: json['phone_verified_at'] != null
          ? DateTime.tryParse(json['phone_verified_at'].toString())
          : null,
    );
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      createdAt: createdAt,
      phone: phone ?? this.phone,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'created_at': createdAt?.toIso8601String(),
      'phone': phone,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
    };
  }
}
