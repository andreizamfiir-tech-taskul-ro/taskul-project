import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/auth_api.dart';
import '../models/app_user.dart';

/// Lightweight auth state holder (email-only auth for demo backend).
class AuthState extends ChangeNotifier {
  AuthState._();

  static final AuthState instance = AuthState._();
  static const _storageKey = 'auth_user';

  AppUser? _user;
  bool _isLoading = false;

  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _user = AppUser.fromJson(decoded);
        notifyListeners();
      }
    } catch (_) {
      // If parsing fails, clear bad data.
      await prefs.remove(_storageKey);
    }
  }

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final loggedUser =
          await AuthApi.loginWithPassword(email: normalizedEmail, password: password);
      _user = loggedUser;
      await _persistUser();
      notifyListeners();
      return loggedUser;
    } finally {
      _setLoading(false);
    }
  }

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      final created =
          await AuthApi.register(
              name: name, email: normalizedEmail, password: password, phone: phone);
      _user = created;
      await _persistUser();
      notifyListeners();
      return created;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> sendEmailVerification() async {
    if (_user == null) throw Exception('Nu exista user logat');
    return AuthApi.sendEmailCode(userId: _user!.id, email: _user!.email);
  }

  Future<void> verifyEmailCode(String code) async {
    if (_user == null) throw Exception('Nu exista user logat');
    await AuthApi.verifyEmailCode(userId: _user!.id, code: code);
    _user = _user!.copyWith(emailVerifiedAt: DateTime.now());
    await _persistUser();
    notifyListeners();
  }

  Future<String> sendPhoneVerification({required String phone}) async {
    if (_user == null) throw Exception('Nu exista user logat');
    return AuthApi.sendPhoneCode(userId: _user!.id, phone: phone);
  }

  Future<void> verifyPhoneCode(String code) async {
    if (_user == null) throw Exception('Nu exista user logat');
    await AuthApi.verifyPhoneCode(userId: _user!.id, code: code);
    _user = _user!.copyWith(phoneVerifiedAt: DateTime.now());
    await _persistUser();
    notifyListeners();
  }

  void logout() {
    _user = null;
    _clearPersistedUser();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> _persistUser() async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_user!.toJson()));
  }

  Future<void> _clearPersistedUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
