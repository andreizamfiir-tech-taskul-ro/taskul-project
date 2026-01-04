import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
import '../models/task_review.dart';
import 'base_api.dart';

Future<List<Task>> fetchTasks() async {
  final res = await http.get(Uri.parse('$baseUrl/tasks'));

  if (res.statusCode == 200) {
    final List data = jsonDecode(res.body);
    return data.map((e) => Task.fromJson(e)).toList();
  } else {
    throw Exception('Backend-ul a zis nu');
  }
}

Future<List<Task>> fetchMyTasks(int userId) async {
  final res = await http.get(Uri.parse('$baseUrl/tasks/my/$userId'));
  if (res.statusCode == 200) {
    final List data = jsonDecode(res.body);
    return data.map((e) => Task.fromJson(e)).toList();
  } else {
    throw Exception('Backend-ul a zis nu');
  }
}

Future<void> acceptTaskApi(int taskId, {required int userId}) async {
  await http.post(
    Uri.parse('$baseUrl/tasks/$taskId/accept'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_id': userId}),
  );
}

Future<void> refuseTaskApi(int taskId, {required int userId}) async {
  await http.post(
    Uri.parse('$baseUrl/tasks/$taskId/refuse'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'user_id': userId}),
  );
}

Future<Task> createTaskApi({
  required String title,
  String? description,
  required int creatorId,
  double? price,
  double? lat,
  double? lng,
  int? estimatedDurationMinutes,
  DateTime? startTime,
  String? address,
  int? cityId,
  int? countyId,
  int? countryId,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/tasks'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'title': title,
      'description': description,
      'creator_id': creatorId,
      'price': price,
      'lat': lat,
      'lng': lng,
      'estimated_duration_minutes': estimatedDurationMinutes,
      'start_time': startTime?.toIso8601String(),
      'address': address,
      'city_id': cityId,
      'county_id': countyId,
      'country_id': countryId,
    }),
  );

  if (res.statusCode >= 200 && res.statusCode < 300) {
    final data = jsonDecode(res.body);
    return Task.fromJson(data);
  } else {
    throw Exception('Task create failed (${res.statusCode})');
  }
}

Future<void> updateTaskStatus({
  required int taskId,
  required int statusId,
  String? note,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/tasks/$taskId/status'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'status_id': statusId,
      'note': note,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Nu am putut schimba statusul');
  }
}

Future<void> createTaskReview({
  required int taskId,
  required int authorId,
  required int targetId,
  required int rating,
  String? comment,
}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/tasks/$taskId/reviews'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'author_id': authorId,
      'target_id': targetId,
      'rating': rating,
      'comment': comment,
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Nu am putut salva review-ul');
  }
}

Future<List<TaskReview>> fetchTaskReviews(int taskId) async {
  final res = await http.get(Uri.parse('$baseUrl/tasks/$taskId/reviews'));
  if (res.statusCode >= 200 && res.statusCode < 300) {
    final List data = jsonDecode(res.body);
    return data.map((e) => TaskReview.fromJson(e)).toList();
  }
  throw Exception('Nu am putut incarca review-urile');
}
