class Business {
  final int id;
  final int ownerProfileId;
  final int? categoryId;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? country;
  final String? website;
  final String? email;
  final String? phone;
  final double? ratingAvg;
  final int? ratingCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Business({
    required this.id,
    required this.ownerProfileId,
    required this.name,
    this.categoryId,
    this.description,
    this.address,
    this.city,
    this.country,
    this.website,
    this.email,
    this.phone,
    this.ratingAvg,
    this.ratingCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Business.fromJson(Map<String, dynamic> json) {
    return Business(
      id: json['id'] as int,
      ownerProfileId: json['owner_profile_id'] as int,
      categoryId: json['category_id'] as int?,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      website: json['website']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      ratingAvg: json['rating_avg'] != null
          ? double.tryParse(json['rating_avg'].toString())
          : null,
      ratingCount: json['rating_count'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
