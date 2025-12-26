import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'base_api.dart';

class AuthApi {
  static String _extractError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Eroare (${res.statusCode})';
  }

  /// Registers a user using name + email + password. Returns the created user.
  static Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return AppUser.fromJson(data);
    }

    throw Exception(_extractError(res));
  }

  /// Login with email + password.
  static Future<AppUser> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return AppUser.fromJson(data);
    }

    throw Exception(_extractError(res));
  }

  /// DEV: send email verification code (returns the code for testing).
  static Future<String> sendEmailCode({
    required int userId,
    required String email,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify/send-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'email': email}),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['code']?.toString() ?? '';
    }
    throw Exception(_extractError(res));
  }

  static Future<void> verifyEmailCode({
    required int userId,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify/check-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'code': code}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractError(res));
    }
  }

  /// DEV: send phone verification code (returns the code for testing).
  static Future<String> sendPhoneCode({
    required int userId,
    required String phone,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify/send-phone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'phone': phone}),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      return data['code']?.toString() ?? '';
    }
    throw Exception(_extractError(res));
  }

  static Future<void> verifyPhoneCode({
    required int userId,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify/check-phone'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'code': code}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractError(res));
    }
  }
}
