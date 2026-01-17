import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notification_item.dart';
import 'base_api.dart';

class NotificationsApi {
  static String _extractError(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
    } catch (_) {}
    return 'Eroare (${res.statusCode})';
  }

  static Future<int> fetchUnreadCount({required int userId}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/$userId/unread-count'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      if (data is Map && data['count'] != null) {
        return int.tryParse(data['count'].toString()) ?? 0;
      }
      return 0;
    }

    throw Exception(_extractError(res));
  }

  static Future<List<NotificationItem>> fetchNotifications({
    required int userId,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/notifications/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => NotificationItem.fromJson(e)).toList();
      }
      return [];
    }

    throw Exception(_extractError(res));
  }

  static Future<void> markAllRead({required int userId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/notifications/$userId/mark-read'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    throw Exception(_extractError(res));
  }

  static Future<void> markRead({
    required int userId,
    required int notificationId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/notifications/$userId/$notificationId/read'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return;
    }

    throw Exception(_extractError(res));
  }
}
