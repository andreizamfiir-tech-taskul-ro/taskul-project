import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/business.dart';
import 'base_api.dart';

class BusinessApi {
  static String _extractError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Eroare (${res.statusCode})';
  }

  static Future<Business?> fetchBusiness({required int userId}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/business/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode == 404) {
      return null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) {
        return Business.fromJson(data);
      }
    }
    throw Exception(_extractError(res));
  }

  static Future<Business> upsertBusiness({
    required int userId,
    required BusinessDraft draft,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/business'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        ...draft.toJson(),
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return Business.fromJson(data);
    }
    throw Exception(_extractError(res));
  }

  static Future<void> deleteBusiness({required int userId}) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/business/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }
    throw Exception(_extractError(res));
  }
}

class BusinessDraft {
  final int? categoryId;
  final String name;
  final String? description;
  final String? address;
  final String? city;
  final String? country;
  final String? website;
  final String? email;
  final String? phone;

  const BusinessDraft({
    required this.name,
    this.categoryId,
    this.description,
    this.address,
    this.city,
    this.country,
    this.website,
    this.email,
    this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'country': country,
      'website': website,
      'email': email,
      'phone': phone,
    };
  }
}
