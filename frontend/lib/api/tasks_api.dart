import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';
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

Future<void> acceptTaskApi(int taskId) async {
  await http.post(Uri.parse('$baseUrl/tasks/$taskId/accept'));
}

Future<void> refuseTaskApi(int taskId) async {
  await http.post(Uri.parse('$baseUrl/tasks/$taskId/refuse'));
}
